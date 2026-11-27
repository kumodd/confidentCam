import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/script_sentence_matcher.dart';
import '../../../core/utils/teleprompter_scroll_math.dart';
import '../../../services/recording_audio_service.dart';
import '../../../services/video_recording_service.dart';
import '../../bloc/settings/settings_bloc.dart';
import 'coach_tips_card.dart';
import 'recording_controls.dart';
import 'teleprompter_settings_sheet.dart';
import 'teleprompter_widget.dart';

/// ONE shared camera + teleprompter recording component used across:
/// 1. Warmup sessions (`WarmupRecordingScreen` in warmup mode)
/// 2. 30-Day Challenge (`WarmupRecordingScreen` in dailyChallenge mode)
/// 3. Content Creator AI Scripts (`RecordTab`)
///
/// Supports:
/// - **Text Mirroring** (horizontal flip for physical beam-splitter rigs)
/// - **Landscape & Portrait Recording** (auto-rotation + 1-tap Rotate button)
/// - **5 Recording Layout Templates** (Floating Overlay, Split 40/60, Split 50/50,
///   Script Focus 60/40, Lower Overlay) adapting cleanly to Portrait & Landscape
/// - **Simplified Fast Recording** (Instant 0s mode + tap-to-skip countdown)
/// - **Microphone Input Selection** (lists built-in, wired, USB-C & Bluetooth mics)
/// - **Notification Sound Filtering** (audio focus + stream muting + optional DND)
class UnifiedRecordingView extends StatefulWidget {
  final String? scriptTitle;
  final List<TeleprompterSection> sections;
  final String? emptyScriptMessage;
  final bool embedded;
  final bool showCloseButton;
  final bool showCoachTips;
  final bool showQualitySelector;
  final int maxDurationSeconds;
  final int? progressTargetSeconds;
  final VoidCallback? onClose;
  final VoidCallback? onRecordingStarted;
  final ValueChanged<bool>? onRecordingStateChanged;
  final Future<void> Function(String videoPath) onRecordingCompleted;
  final VoidCallback? onPermissionDenied;

  const UnifiedRecordingView({
    super.key,
    this.scriptTitle,
    required this.sections,
    this.emptyScriptMessage,
    this.embedded = false,
    this.showCloseButton = true,
    this.showCoachTips = false,
    this.showQualitySelector = true,
    this.maxDurationSeconds = 300,
    this.progressTargetSeconds,
    this.onClose,
    this.onRecordingStarted,
    this.onRecordingStateChanged,
    required this.onRecordingCompleted,
    this.onPermissionDenied,
  });

  @override
  State<UnifiedRecordingView> createState() => _UnifiedRecordingViewState();
}

class _UnifiedRecordingViewState extends State<UnifiedRecordingView> {
  late VideoRecordingService _recordingService;
  late RecordingAudioService _audioService;
  StreamSubscription<List<AudioInputDevice>>? _micDevicesSub;

  bool _isInitializing = true;
  bool _isRecording = false;
  int _countdown = 3;
  bool _showingCountdown = false;
  Timer? _countdownTimer;
  Timer? _recordingTimer;
  int _recordingSeconds = 0;

  double _currentSpeed = 1.0;
  double _currentHeight = 0.24;
  double _currentOpacity = 0.35;
  String _currentFontSizeKey = 'medium';
  double _currentFontSize = 16.0;
  Color _currentTextColor = const Color(0xFFF7F8F0);
  bool _autoScrollEnabled = true;
  bool _voiceSyncEnabled = false;
  bool _mirrorText = false;
  RecordingLayoutTemplate _layoutTemplate =
      RecordingLayoutTemplate.classicOverlay;
  int _countdownSeconds = 3;
  bool _silenceNotifications = true;
  int? _preferredMicDeviceId;
  List<AudioInputDevice> _availableMicrophones = const [];
  bool _hasDndPolicyAccess = false;

  String _languagePreference = 'en';
  bool _useFrontCamera = true;
  bool _isScriptVisible = true;

  bool get _hasScript =>
      widget.sections.any((section) => section.body.trim().isNotEmpty);

  @override
  void initState() {
    super.initState();
    _recordingService = sl<VideoRecordingService>();
    _audioService =
        sl.isRegistered<RecordingAudioService>()
            ? sl<RecordingAudioService>()
            : RecordingAudioService();

    // Enable both portrait & landscape recording + immersive edge-to-edge camera
    // mode (hiding status bar so teleprompter text sticks flush at y = 0 near lens).
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _loadSettingsFromBloc();
    _initAudioDevices();
    _initCamera();
  }

  Future<void> _initAudioDevices() async {
    _micDevicesSub = _audioService.onInputDevicesChanged.listen((devices) {
      if (!mounted) return;
      setState(() {
        _availableMicrophones = devices;
        if (_preferredMicDeviceId != null &&
            !devices.any((d) => d.id == _preferredMicDeviceId)) {
          _preferredMicDeviceId = null;
        }
      });
    });

    final devices = await _audioService.listInputDevices();
    final hasDnd = await _audioService.hasDndPolicyAccess();
    if (_preferredMicDeviceId != null &&
        devices.any((d) => d.id == _preferredMicDeviceId)) {
      await _audioService.setPreferredInputDevice(_preferredMicDeviceId);
    } else if (_preferredMicDeviceId != null) {
      _preferredMicDeviceId = null;
    }

    if (mounted) {
      setState(() {
        _availableMicrophones = devices;
        _hasDndPolicyAccess = hasDnd;
      });
    }
  }

  void _loadSettingsFromBloc() {
    final settingsState = context.read<SettingsBloc>().state;
    final settings =
        settingsState is SettingsLoadSuccess
            ? settingsState.settings
            : settingsState is SettingsNotificationError
            ? settingsState.settings
            : Settings.defaults();

    _applySettings(settings, notifySetState: false);
  }

  void _applySettings(Settings settings, {bool notifySetState = true}) {
    void assign() {
      _currentSpeed = settings.teleprompterSpeed.clamp(0.5, 3.0);
      _currentHeight = settings.teleprompterHeight.clamp(0.15, 0.90);
      _currentOpacity = settings.teleprompterOpacity.clamp(0.10, 0.85);
      _currentFontSizeKey = settings.teleprompterFontSize;
      _currentFontSize = settings.fontSizePixels;
      _currentTextColor = _getColorFromString(settings.teleprompterTextColor);
      _autoScrollEnabled = settings.autoScrollEnabled;
      _voiceSyncEnabled = settings.voiceSyncEnabled;
      _mirrorText = settings.teleprompterMirrorText;
      _layoutTemplate = settings.layoutTemplate;
      _countdownSeconds = settings.recordingCountdownSeconds;
      _silenceNotifications = settings.silenceNotificationsDuringRecording;
      _preferredMicDeviceId = settings.preferredMicDeviceId;
      _languagePreference = settings.languagePreference;
      _useFrontCamera = settings.defaultCamera.toLowerCase() != 'back';
    }

    if (notifySetState && mounted) {
      setState(assign);
    } else {
      assign();
    }
  }

  Color _getColorFromString(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'white':
        return const Color(0xFFF7F8F0);
      case 'yellow':
        return const Color(0xFFE5DF7A);
      case 'cyan':
        return const Color(0xFF8CE0A2);
      case 'green':
        return const Color(0xFF75D488);
      case 'pink':
        return const Color(0xFFFF8A8A);
      default:
        return const Color(0xFFF7F8F0);
    }
  }

  Future<void> _initCamera() async {
    try {
      await _recordingService.initialize(useFrontCamera: _useFrontCamera);
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    } catch (e) {
      if (mounted) {
        _showPermissionDialog();
      }
    }
  }

  Future<void> _switchCamera() async {
    if (_isRecording || _isInitializing) return;
    setState(() => _isInitializing = true);
    try {
      await _recordingService.switchCamera();
      _useFrontCamera = !_useFrontCamera;
    } finally {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  Future<void> _changeVideoQuality(ResolutionPreset quality) async {
    if (_isRecording) return;
    setState(() => _isInitializing = true);
    try {
      await _recordingService.setQuality(quality);
    } finally {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  Future<void> _toggleOrientation(bool currentlyLandscape) async {
    if (_isRecording) return;
    if (currentlyLandscape) {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
      ]);
    } else {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  void _cycleLayoutTemplate() {
    if (_isRecording) return;
    final all = RecordingLayoutTemplate.values;
    final next = all[(all.indexOf(_layoutTemplate) + 1) % all.length];
    setState(() {
      _layoutTemplate = next;
      if (!_isScriptVisible && _hasScript) {
        _isScriptVisible = true;
      }
    });
    context.read<SettingsBloc>().add(RecordingLayoutTemplateUpdated(next.key));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Layout: ${next.label}'),
          duration: const Duration(milliseconds: 1100),
        ),
      );
  }

  void _showQuickMicPicker() {
    if (_isRecording || _availableMicrophones.isEmpty) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (ctx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Select Microphone',
                    style: AppTypography.headingMedium(fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.auto_awesome_outlined,
                      color: AppColors.primaryOlive,
                    ),
                    title: Text(
                      'Auto (System Default)',
                      style: AppTypography.bodyStrong(),
                    ),
                    trailing:
                        _preferredMicDeviceId == null
                            ? Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.primaryOlive,
                            )
                            : null,
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _selectMicrophone(null);
                    },
                  ),
                  ..._availableMicrophones.map(
                    (mic) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        mic.isExternal
                            ? Icons.headset_mic_outlined
                            : Icons.mic_none_rounded,
                        color: AppColors.primaryOlive,
                      ),
                      title: Text(mic.name, style: AppTypography.bodyStrong()),
                      subtitle: Text(
                        mic.typeLabel,
                        style: AppTypography.body(fontSize: 12),
                      ),
                      trailing:
                          _preferredMicDeviceId == mic.id
                              ? Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.primaryOlive,
                              )
                              : null,
                      onTap: () async {
                        Navigator.pop(ctx);
                        await _selectMicrophone(mic.id);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _selectMicrophone(int? deviceId) async {
    await _audioService.setPreferredInputDevice(deviceId);
    if (!mounted) return;
    setState(() => _preferredMicDeviceId = deviceId);
    context.read<SettingsBloc>().add(PreferredMicDeviceUpdated(deviceId));
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogCtx) => AlertDialog(
            title: const Text('Permissions Required'),
            content: const Text(
              'Camera and Microphone access are required to record videos. Please enable them in your device settings.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogCtx).pop();
                  widget.onPermissionDenied?.call();
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(dialogCtx).pop();
                  openAppSettings();
                  widget.onPermissionDenied?.call();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _recordingTimer?.cancel();
    _micDevicesSub?.cancel();
    _audioService.endRecordingAudioGuard();
    _recordingService.dispose();
    // Restore default portrait orientation & system bars for the rest of the app
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  void _startCountdown() {
    if (_isInitializing || _isRecording || _showingCountdown) return;

    // Instant recording when countdown is set to 0s (simplified workflow)
    if (_countdownSeconds <= 0) {
      _startRecording();
      return;
    }

    setState(() {
      _countdown = _countdownSeconds;
      _showingCountdown = true;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdown > 1) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
        setState(() => _showingCountdown = false);
        _startRecording();
      }
    });
  }

  void _skipCountdownNow() {
    if (!_showingCountdown) return;
    _countdownTimer?.cancel();
    setState(() => _showingCountdown = false);
    _startRecording();
  }

  Future<void> _startRecording() async {
    // Activate notification sound filtering & preferred mic routing BEFORE
    // MediaRecorder captures its first audio frame.
    await _audioService.beginRecordingAudioGuard(
      silenceNotifications: _silenceNotifications,
    );

    if (!mounted) {
      await _audioService.endRecordingAudioGuard();
      return;
    }

    widget.onRecordingStateChanged?.call(true);
    setState(() {
      _isRecording = true;
      _recordingSeconds = 0;
    });

    widget.onRecordingStarted?.call();
    try {
      await _recordingService.startRecording();
    } catch (_) {
      await _audioService.endRecordingAudioGuard();
      if (mounted) {
        setState(() => _isRecording = false);
        widget.onRecordingStateChanged?.call(false);
      }
      return;
    }

    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _recordingSeconds++);
      if (_recordingSeconds >= widget.maxDurationSeconds) {
        _stopRecording();
      }
    });
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();
    if (!_isRecording) return;

    setState(() => _isRecording = false);
    widget.onRecordingStateChanged?.call(false);

    String? path;
    try {
      path = await _recordingService.stopRecording();
    } finally {
      await _audioService.endRecordingAudioGuard();
    }

    if (path != null && mounted) {
      await widget.onRecordingCompleted(path);
    } else if (mounted && !widget.embedded) {
      widget.onClose?.call();
    }
  }

  void _handleClose() {
    _countdownTimer?.cancel();
    _recordingTimer?.cancel();
    if (_isRecording) {
      _isRecording = false;
      widget.onRecordingStateChanged?.call(false);
      _recordingService.stopRecording();
      _audioService.endRecordingAudioGuard();
    }
    if (widget.onClose != null) {
      widget.onClose!();
    } else if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _adjustSpeed(double delta) {
    setState(() {
      _currentSpeed = (_currentSpeed + delta).clamp(0.5, 3.0);
    });
    context.read<SettingsBloc>().add(TeleprompterSpeedUpdated(_currentSpeed));
  }

  void _toggleVoiceSync(bool enabled) {
    setState(() => _voiceSyncEnabled = enabled);
    context.read<SettingsBloc>().add(VoiceSyncToggled(enabled));
  }

  void _toggleMirrorText(bool enabled) {
    setState(() => _mirrorText = enabled);
    context.read<SettingsBloc>().add(TeleprompterMirrorToggled(enabled));
  }

  Future<void> _showSettingsSheet() async {
    // Refresh connected microphones & DND policy status on open
    final mics = await _audioService.listInputDevices();
    final hasDnd = await _audioService.hasDndPolicyAccess();
    if (!mounted) return;
    setState(() {
      _availableMicrophones = mics;
      _hasDndPolicyAccess = hasDnd;
    });

    final prevSpeed = _currentSpeed;
    final prevHeight = _currentHeight;
    final prevOpacity = _currentOpacity;
    final prevFontSizeKey = _currentFontSizeKey;
    final prevFontSize = _currentFontSize;
    final prevAutoScroll = _autoScrollEnabled;
    final prevVoiceSync = _voiceSyncEnabled;
    final prevMirror = _mirrorText;
    final prevLayout = _layoutTemplate;
    final prevCountdown = _countdownSeconds;
    final prevSilence = _silenceNotifications;
    final prevMicId = _preferredMicDeviceId;
    var saved = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder:
          (_) => TeleprompterSettingsSheet(
            initialSpeed: _currentSpeed,
            initialHeight: _currentHeight,
            initialOpacity: _currentOpacity,
            initialFontSizeKey: _currentFontSizeKey,
            initialAutoScrollEnabled: _autoScrollEnabled,
            initialVoiceSyncEnabled: _voiceSyncEnabled,
            initialMirrorText: _mirrorText,
            initialLayoutTemplate: _layoutTemplate,
            initialCountdownSeconds: _countdownSeconds,
            initialSilenceNotifications: _silenceNotifications,
            availableMicrophones: _availableMicrophones,
            initialPreferredMicDeviceId: _preferredMicDeviceId,
            hasDndPolicyAccess: _hasDndPolicyAccess,
            onOpenDndPolicySettings: () async {
              await _audioService.openDndPolicySettings();
            },
            currentVideoQuality:
                widget.showQualitySelector
                    ? _recordingService.currentQuality
                    : null,
            onVideoQualityChanged:
                widget.showQualitySelector ? _changeVideoQuality : null,
            onSettingsChanged: (preview) {
              if (!mounted) return;
              setState(() {
                _currentSpeed = preview.speed;
                _currentHeight = preview.height;
                _currentOpacity = preview.opacity;
                _currentFontSizeKey = preview.fontSizeKey;
                _currentFontSize = preview.fontSizePixels;
                _autoScrollEnabled = preview.autoScrollEnabled;
                _voiceSyncEnabled = preview.voiceSyncEnabled;
                _mirrorText = preview.mirrorText;
                _layoutTemplate = preview.layoutTemplate;
                _countdownSeconds = preview.countdownSeconds;
                _silenceNotifications = preview.silenceNotifications;
                _preferredMicDeviceId = preview.preferredMicDeviceId;
              });
            },
            onSettingsSaved: (result) {
              saved = true;
              _audioService.setPreferredInputDevice(
                result.preferredMicDeviceId,
              );
              if (!mounted) return;
              setState(() {
                _currentSpeed = result.speed;
                _currentHeight = result.height;
                _currentOpacity = result.opacity;
                _currentFontSizeKey = result.fontSizeKey;
                _currentFontSize = result.fontSizePixels;
                _autoScrollEnabled = result.autoScrollEnabled;
                _voiceSyncEnabled = result.voiceSyncEnabled;
                _mirrorText = result.mirrorText;
                _layoutTemplate = result.layoutTemplate;
                _countdownSeconds = result.countdownSeconds;
                _silenceNotifications = result.silenceNotifications;
                _preferredMicDeviceId = result.preferredMicDeviceId;
              });
            },
          ),
    ).whenComplete(() {
      if (!saved && mounted) {
        setState(() {
          _currentSpeed = prevSpeed;
          _currentHeight = prevHeight;
          _currentOpacity = prevOpacity;
          _currentFontSizeKey = prevFontSizeKey;
          _currentFontSize = prevFontSize;
          _autoScrollEnabled = prevAutoScroll;
          _voiceSyncEnabled = prevVoiceSync;
          _mirrorText = prevMirror;
          _layoutTemplate = prevLayout;
          _countdownSeconds = prevCountdown;
          _silenceNotifications = prevSilence;
          _preferredMicDeviceId = prevMicId;
        });
      }
    });
  }

  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Widget _buildCameraPreview(
    CameraController controller, {
    required bool isLandscape,
  }) {
    final previewSize = controller.value.previewSize;
    if (!controller.value.isInitialized || previewSize == null) {
      return CameraPreview(controller);
    }

    // Sensor previewSize is reported in landscape (width > height); swap only
    // in portrait so both portrait and landscape show the exact native sensor
    // aspect ratio (e.g. 9:16 or 16:9). Using BoxFit.contain on pure black
    // guarantees 100% pre-record == post-record framing with zero hidden crop!
    final previewWidth = isLandscape ? previewSize.width : previewSize.height;
    final previewHeight = isLandscape ? previewSize.height : previewSize.width;

    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: previewWidth,
          height: previewHeight,
          child: CameraPreview(controller),
        ),
      ),
    );
  }

  Widget _buildCameraLayer({required bool isLandscape}) {
    if (!_isInitializing && _recordingService.controller != null) {
      return _buildCameraPreview(
        _recordingService.controller!,
        isLandscape: isLandscape,
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: Color(0xFFF7F8F0)),
          const SizedBox(height: 16),
          Text(
            'Preparing camera...',
            style: AppTypography.body(color: const Color(0xFFF7F8F0)),
          ),
        ],
      ),
    );
  }

  Widget _buildTeleprompter({required bool solidBackground}) {
    return IgnorePointer(
      ignoring: _showingCountdown,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: _showingCountdown ? 0.0 : 1.0,
        child: TeleprompterWidget(
          title: widget.scriptTitle ?? 'Script',
          sections: widget.sections,
          isRecording: _isRecording,
          autoScrollEnabled: _autoScrollEnabled,
          voiceSyncEnabled: _voiceSyncEnabled,
          mirrorText: _mirrorText,
          solidBackground: solidBackground,
          scrollSpeed: _currentSpeed,
          opacity: _currentOpacity,
          fontSize: _currentFontSize,
          textColor: _currentTextColor,
          languagePreference: _languagePreference,
          onSpeedChange: _adjustSpeed,
          onVoiceSyncToggle: _toggleVoiceSync,
          onMirrorToggle: _toggleMirrorText,
        ),
      ),
    );
  }

  Widget _buildGlassIconButton({
    required IconData icon,
    required VoidCallback onTap,
    required String semanticLabel,
    bool active = false,
  }) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color:
                active
                    ? const Color(0xFF6B7344).withValues(alpha: 0.78)
                    : const Color(0xFF121512).withValues(alpha: 0.58),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color:
                  active
                      ? const Color(0xFFD8D478)
                      : Colors.white.withValues(alpha: 0.22),
            ),
          ),
          child: Icon(
            icon,
            color: active ? const Color(0xFFF7F8F0) : const Color(0xFFF7F8F0),
            size: 19,
          ),
        ),
      ),
    );
  }

  /// Compact studio action strip docked BELOW the camera framing (above the
  /// shutter) so zero controls sit between the camera lens and the script text.
  Widget _buildStudioToolsRow({required bool isLandscape}) {
    if (_showingCountdown) return const SizedBox.shrink();

    final buttons = <Widget>[
      if (_hasScript)
        _buildGlassIconButton(
          icon:
              _isScriptVisible
                  ? Icons.subtitles_outlined
                  : Icons.subtitles_off_outlined,
          onTap: () => setState(() => _isScriptVisible = !_isScriptVisible),
          semanticLabel:
              _isScriptVisible ? 'Hide Teleprompter' : 'Show Teleprompter',
        ),
      if (!_isRecording) ...[
        if (_hasScript)
          _buildGlassIconButton(
            icon: Icons.view_agenda_outlined,
            onTap: _cycleLayoutTemplate,
            semanticLabel: 'Switch Recording Layout (${_layoutTemplate.label})',
            active: _layoutTemplate.isSplit,
          ),
        if (_availableMicrophones.length > 1)
          _buildGlassIconButton(
            icon: Icons.settings_voice_outlined,
            onTap: _showQuickMicPicker,
            semanticLabel: 'Select Microphone',
            active: _preferredMicDeviceId != null,
          ),
        _buildGlassIconButton(
          icon: Icons.screen_rotation_outlined,
          onTap: () => _toggleOrientation(isLandscape),
          semanticLabel:
              isLandscape
                  ? 'Switch to Portrait Mode'
                  : 'Switch to Landscape Mode',
          active: isLandscape,
        ),
        _buildGlassIconButton(
          icon: Icons.cameraswitch_outlined,
          onTap: _switchCamera,
          semanticLabel: 'Switch Camera',
        ),
        _buildGlassIconButton(
          icon: Icons.tune_rounded,
          onTap: _showSettingsSheet,
          semanticLabel: 'Teleprompter Settings',
        ),
      ],
    ];

    if (buttons.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < buttons.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            buttons[i],
          ],
        ],
      ),
    );
  }

  /// Bottom shutter dock for Portrait mode: Close / REC badge on the left,
  /// Record Shutter dead-center, Hide Teleprompter on the right while
  /// recording (so tall overlays up to 90% have maximum vertical room), and
  /// studio tools row neatly stacked above when idle.
  Widget _buildPortraitBottomDock({required double bottomInset}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset + 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_isRecording) ...[
            _buildStudioToolsRow(isLandscape: false),
            const SizedBox(height: 10),
          ],
          SizedBox(
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child:
                      _isRecording
                          ? _buildRecordingBadge()
                          : (widget.showCloseButton
                              ? _buildGlassIconButton(
                                icon: Icons.close_rounded,
                                onTap: _handleClose,
                                semanticLabel: 'Close Recording',
                              )
                              : const SizedBox(width: 38)),
                ),
                _buildRecordingControlsWidget(),
                if (_isRecording && _hasScript)
                  Align(
                    alignment: Alignment.centerRight,
                    child: _buildGlassIconButton(
                      icon:
                          _isScriptVisible
                              ? Icons.subtitles_outlined
                              : Icons.subtitles_off_outlined,
                      onTap:
                          () => setState(
                            () => _isScriptVisible = !_isScriptVisible,
                          ),
                      semanticLabel:
                          _isScriptVisible
                              ? 'Hide Teleprompter'
                              : 'Show Teleprompter',
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownOverlay() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _skipCountdownNow,
      child: SizedBox.expand(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 118,
                height: 118,
                decoration: BoxDecoration(
                  color: const Color(0xFF121512).withValues(alpha: 0.76),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFD8D478), width: 3),
                ),
                child: Center(
                  child: Text(
                    '$_countdown',
                    style: AppTypography.displayMetric(
                      fontSize: 54,
                      color: const Color(0xFFF7F8F0),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF121512).withValues(alpha: 0.68),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'Tap anywhere to start now',
                  style: AppTypography.bodyStrong(
                    fontSize: 12,
                    color: const Color(0xFFD8D478),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyScriptBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF121512).withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFFD8D478)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.emptyScriptMessage!,
              style: AppTypography.bodyStrong(
                fontSize: 13.5,
                color: const Color(0xFFF7F8F0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingControlsWidget() {
    return RecordingControls(
      isRecording: _isRecording,
      isInitializing: _isInitializing,
      recordingSeconds: _recordingSeconds,
      progressTargetSeconds: widget.progressTargetSeconds,
      onStartCountdown: _startCountdown,
      onStopRecording: _stopRecording,
    );
  }

  Widget _buildSplitLayout({
    required BoxConstraints constraints,
    required bool isLandscape,
    required EdgeInsets mediaPad,
  }) {
    final scriptFlex = _layoutTemplate.scriptFlex;
    final cameraFlex = _layoutTemplate.cameraFlex;

    final cameraStage = Stack(
      fit: StackFit.expand,
      children: [
        _buildCameraLayer(isLandscape: isLandscape),
        if (_showingCountdown) _buildCountdownOverlay(),
        if (isLandscape) ...[
          // Top-right Close / Live REC pill clear of teleprompter
          Positioned(
            top: mediaPad.top + 10,
            right: mediaPad.right + 14,
            child:
                _isRecording
                    ? _buildRecordingBadge()
                    : (widget.showCloseButton
                        ? _buildGlassIconButton(
                          icon: Icons.close_rounded,
                          onTap: _handleClose,
                          semanticLabel: 'Close Recording',
                        )
                        : const SizedBox.shrink()),
          ),
          // Right-rail shutter
          Positioned(
            right: mediaPad.right + 14,
            top: 0,
            bottom: 0,
            child: Center(child: _buildRecordingControlsWidget()),
          ),
          // Bottom studio tools bar
          Positioned(
            left: 10,
            right: mediaPad.right + 104,
            bottom: mediaPad.bottom + 10,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: _buildStudioToolsRow(isLandscape: true),
            ),
          ),
        ] else
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildPortraitBottomDock(bottomInset: mediaPad.bottom),
          ),
      ],
    );

    if (isLandscape) {
      return Container(
        color: Colors.black,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: scriptFlex,
              child: Container(
                color: const Color(0xFF0E100E),
                padding: EdgeInsets.fromLTRB(
                  mediaPad.left,
                  0,
                  0,
                  mediaPad.bottom,
                ),
                child: _buildTeleprompter(solidBackground: true),
              ),
            ),
            Container(width: 1.2, color: Colors.white.withValues(alpha: 0.16)),
            Expanded(flex: cameraFlex, child: cameraStage),
          ],
        ),
      );
    }

    // Portrait Split: ZERO top padding so script sticks flush at the very top
    // edge next to the front camera lens!
    return Container(
      color: Colors.black,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: scriptFlex,
            child: Container(
              color: const Color(0xFF0E100E),
              child: _buildTeleprompter(solidBackground: true),
            ),
          ),
          Container(height: 1.2, color: Colors.white.withValues(alpha: 0.16)),
          Expanded(flex: cameraFlex, child: cameraStage),
        ],
      ),
    );
  }

  Widget _buildOverlayLayout({
    required BoxConstraints constraints,
    required bool isLandscape,
    required EdgeInsets mediaPad,
  }) {
    // ZERO top margin so the teleprompter text sticks flush at the top edge
    // directly next to the front camera lens!
    const teleprompterTop = 0.0;
    final isLowerOverlay =
        _layoutTemplate == RecordingLayoutTemplate.lowerOverlay;

    final showCoach =
        widget.showCoachTips &&
        !_isRecording &&
        !_showingCountdown &&
        !isLandscape &&
        !isLowerOverlay &&
        _currentHeight <= 0.58;

    final overlayHeight = TeleprompterScrollMath.computeOverlayHeight(
      containerHeight: constraints.maxHeight,
      heightFraction: _currentHeight,
      topInset: teleprompterTop,
      bottomReserve:
          isLandscape
              ? (_isRecording ? (mediaPad.bottom + 8.0) : (mediaPad.bottom + 64.0))
              : (mediaPad.bottom +
                  (_isRecording ? 96.0 : (showCoach ? 204.0 : 146.0))),
    );

    final horizontalLeftInset = isLandscape ? mediaPad.left + 8.0 : 0.0;
    final horizontalRightInset = isLandscape ? mediaPad.right + 108.0 : 0.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        _buildCameraLayer(isLandscape: isLandscape),

        // Teleprompter overlay (pinned right near the lens, or lower third)
        if (_hasScript && _isScriptVisible)
          Positioned(
            top: isLowerOverlay ? null : teleprompterTop,
            bottom:
                isLowerOverlay
                    ? (isLandscape
                        ? (_isRecording
                            ? mediaPad.bottom + 8.0
                            : mediaPad.bottom + 64.0)
                        : (mediaPad.bottom + (_isRecording ? 96.0 : 146.0)))
                    : null,
            left: horizontalLeftInset,
            right: horizontalRightInset,
            height: overlayHeight,
            child: _buildTeleprompter(solidBackground: false),
          ),

        // Empty script banner (e.g. Content Creator with no script selected)
        if (!_hasScript &&
            !_showingCountdown &&
            !_isRecording &&
            widget.emptyScriptMessage != null)
          Positioned(
            top: teleprompterTop + 8,
            left: horizontalLeftInset,
            right: horizontalRightInset,
            child: _buildEmptyScriptBanner(),
          ),

        // Coach tips above bottom studio dock (only when idle & compact overlay)
        if (showCoach)
          Positioned(
            bottom: mediaPad.bottom + 150,
            left: 12,
            right: 12,
            child: const CoachTipsCard(isRecording: false),
          ),

        // Countdown overlay (tap anywhere to skip immediately)
        if (_showingCountdown) _buildCountdownOverlay(),

        // Shutter + studio toolbar docked below
        if (isLandscape) ...[
          Positioned(
            top: mediaPad.top + 10,
            right: mediaPad.right + 14,
            child:
                _isRecording
                    ? _buildRecordingBadge()
                    : (widget.showCloseButton
                        ? _buildGlassIconButton(
                          icon: Icons.close_rounded,
                          onTap: _handleClose,
                          semanticLabel: 'Close Recording',
                        )
                        : const SizedBox.shrink()),
          ),
          Positioned(
            right: mediaPad.right + 14,
            top: 0,
            bottom: 0,
            child: Center(child: _buildRecordingControlsWidget()),
          ),
          Positioned(
            left: horizontalLeftInset,
            right: horizontalRightInset,
            bottom: mediaPad.bottom + 10,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: _buildStudioToolsRow(isLandscape: true),
            ),
          ),
        ] else
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildPortraitBottomDock(bottomInset: mediaPad.bottom),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaPad = MediaQuery.paddingOf(context);
    final content = BlocListener<SettingsBloc, SettingsState>(
      listener: (context, state) {
        if (state is SettingsLoadSuccess) {
          _applySettings(state.settings);
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isLandscape =
              MediaQuery.of(context).orientation == Orientation.landscape ||
              constraints.maxWidth > constraints.maxHeight;
          final useSplit =
              _layoutTemplate.isSplit && _hasScript && _isScriptVisible;

          if (useSplit) {
            return _buildSplitLayout(
              constraints: constraints,
              isLandscape: isLandscape,
              mediaPad: mediaPad,
            );
          }
          return _buildOverlayLayout(
            constraints: constraints,
            isLandscape: isLandscape,
            mediaPad: mediaPad,
          );
        },
      ),
    );

    if (widget.embedded) {
      return ColoredBox(color: Colors.black, child: content);
    }

    return Scaffold(backgroundColor: Colors.black, body: content);
  }

  Widget _buildRecordingBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFFF7F8F0),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            _formatDuration(_recordingSeconds),
            style: AppTypography.bodyStrong(
              color: const Color(0xFFF7F8F0),
              fontSize: 13,
            ),
          ),
          if (_silenceNotifications) ...[
            const SizedBox(width: 6),
            const Icon(
              Icons.notifications_off_rounded,
              color: Color(0xFFF7F8F0),
              size: 13.5,
            ),
          ],
        ],
      ),
    );
  }
}

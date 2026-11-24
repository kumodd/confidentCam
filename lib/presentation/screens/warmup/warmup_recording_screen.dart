import 'dart:async';

import 'package:camera/camera.dart';
import 'package:confident_cam/presentation/bloc/warmup/warmup_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/warmup.dart';
import '../../../services/video_recording_service.dart';
import '../../bloc/settings/settings_bloc.dart';
import '../../bloc/warmup/warmup_bloc.dart';
import '../../bloc/warmup/warmup_event.dart';
import '../../widgets/camera/coach_tips_card.dart';
import 'warmup_playback_screen.dart';
import '../../widgets/camera/recording_controls.dart';
import '../../widgets/camera/teleprompter_settings_sheet.dart';
import '../../widgets/camera/teleprompter_widget.dart';

/// Recording mode to distinguish between warmup and daily challenge.
enum RecordingMode { warmup, dailyChallenge }

/// Unified recording screen for both warmup and daily challenges.
class WarmupRecordingScreen extends StatefulWidget {
  final RecordingMode mode;
  final int warmupIndex;
  final int? dayNumber;
  final String? userId;
  final String? script;
  final String? userName;
  final String? userGoal;
  final String? userLocation;

  const WarmupRecordingScreen({
    super.key,
    this.mode = RecordingMode.warmup,
    this.warmupIndex = 0,
    this.dayNumber,
    this.userId,
    this.script,
    this.userName,
    this.userGoal,
    this.userLocation,
  });

  factory WarmupRecordingScreen.warmup({
    Key? key,
    required int warmupIndex,
    String? userName,
    String? userGoal,
    String? userLocation,
  }) =>
      WarmupRecordingScreen(
        key: key,
        mode: RecordingMode.warmup,
        warmupIndex: warmupIndex,
        userName: userName,
        userGoal: userGoal,
        userLocation: userLocation,
      );

  factory WarmupRecordingScreen.dailyChallenge({
    Key? key,
    required String userId,
    required int dayNumber,
    required String script,
  }) =>
      WarmupRecordingScreen(
        key: key,
        mode: RecordingMode.dailyChallenge,
        userId: userId,
        dayNumber: dayNumber,
        script: script,
      );

  @override
  State<WarmupRecordingScreen> createState() => _WarmupRecordingScreenState();
}

class _WarmupRecordingScreenState extends State<WarmupRecordingScreen> {
  late VideoRecordingService _recordingService;
  bool _isInitializing = true;
  bool _isRecording = false;
  int _countdown = 3;
  bool _showingCountdown = false;
  Timer? _countdownTimer;
  Timer? _recordingTimer;
  int _recordingSeconds = 0;
  Warmup? _warmup;
  String? _cachedCustomScript;

  double _currentSpeed = 1.0;
  double _currentHeight = 0.24;
  double _currentOpacity = 0.35;
  double _currentFontSize = 16.0;
  Color _currentTextColor = const Color(0xFFF7F8F0);
  bool _isScriptVisible = true;

  @override
  void initState() {
    super.initState();
    if (widget.mode == RecordingMode.warmup) {
      _warmup = Warmups.getByIndex(widget.warmupIndex);
    }
    _recordingService = sl<VideoRecordingService>();
    _initCamera();
    _loadSettings();
  }

  void _loadSettings() {
    final settingsState = context.read<SettingsBloc>().state;
    if (settingsState is SettingsLoadSuccess) {
      final settings = settingsState.settings;
      setState(() {
        _currentSpeed = settings.teleprompterSpeed;
        _currentHeight = settings.teleprompterHeight;
        _currentOpacity = settings.teleprompterOpacity;
        _currentFontSize = settings.fontSizePixels;
        _currentTextColor = _getColorFromString(settings.teleprompterTextColor);
      });
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
      await _recordingService.initialize(useFrontCamera: true);
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    } catch (e) {
      if (mounted) {
        EasyLoading.dismiss();
        _showPermissionDialog();
      }
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Permissions Required'),
        content: Text(
          'Camera and Microphone access are required to record videos. Please enable them in your device settings.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
              Navigator.of(context).pop();
            },
            child: Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _recordingTimer?.cancel();
    _recordingService.dispose();
    super.dispose();
  }

  void _startCountdown() {
    setState(() {
      _countdown = 3;
      _showingCountdown = true;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 1) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
        setState(() => _showingCountdown = false);
        _startRecording();
      }
    });
  }

  Future<void> _startRecording() async {
    setState(() {
      _isRecording = true;
      _recordingSeconds = 0;
    });

    if (widget.mode == RecordingMode.warmup) {
      context.read<WarmupBloc>().add(WarmupRecordingStarted());
    }

    await _recordingService.startRecording();

    final maxDuration = widget.mode == RecordingMode.warmup
        ? (_warmup?.durationSeconds ?? 60)
        : 300;

    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _recordingSeconds++);

      if (_recordingSeconds >= maxDuration) {
        _stopRecording();
      }
    });
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();

    if (!_isRecording) return;

    setState(() => _isRecording = false);

    final path = await _recordingService.stopRecording();

    if (path != null && mounted) {
      if (widget.mode == RecordingMode.warmup) {
        context.read<WarmupBloc>().add(WarmupRecordingStopped(path));
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => BlocProvider.value(
              value: context.read<WarmupBloc>(),
              child: WarmupPlaybackScreen(
                warmupIndex: widget.warmupIndex,
                videoPath: path,
              ),
            ),
          ),
        );
      } else {
        Navigator.of(context).pop(path);
      }
    } else if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _handleClose() {
    _countdownTimer?.cancel();
    _recordingTimer?.cancel();
    if (_isRecording) {
      _recordingService.stopRecording();
    }
    Navigator.of(context).pop();
  }

  void _adjustSpeed(double delta) {
    setState(() {
      _currentSpeed = (_currentSpeed + delta).clamp(0.5, 3.0);
    });
    context.read<SettingsBloc>().add(TeleprompterSpeedUpdated(_currentSpeed));
  }

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => TeleprompterSettingsSheet(
        initialSpeed: _currentSpeed,
        initialHeight: _currentHeight,
        initialOpacity: _currentOpacity,
        onSettingsSaved: (speed, height, opacity) {
          setState(() {
            _currentSpeed = speed;
            _currentHeight = height;
            _currentOpacity = opacity;
          });
        },
      ),
    );
  }

  String _getFallbackWarmupScript() {
    final hasName =
        widget.userName != null && widget.userName!.trim().isNotEmpty;
    final name = hasName ? widget.userName!.trim() : '';
    final goal = widget.userGoal ?? 'become more confident on camera';
    final location = widget.userLocation ?? '';
    final locationText = location.isNotEmpty ? ' from $location' : '';

    switch (widget.warmupIndex) {
      case 0:
        final greeting =
            hasName ? "Hi, I'm $name$locationText! 👋" : 'Hi everyone! 👋';
        return '$greeting\n\n'
            'This is my very first step toward my goal to $goal.\n\n'
            "I know this won't be perfect, and that's completely okay.\n\n"
            "What matters is that I'm showing up and taking action.\n\n"
            "Let's begin this journey together!\n\n"
            'Remember to breathe, smile, and speak from the heart.\n\n'
            "You've got this!";
      case 1:
        final greeting =
            hasName ? "Hey, it's $name again! 😊" : "Hey everyone, I'm back! 😊";
        return '$greeting\n\n'
            "I completed my first warmup and I'm back for more.\n\n"
            "Today I'm focusing on bringing positive energy to the camera.\n\n"
            'My goal to $goal is getting closer with every practice.\n\n'
            "I'm learning to relax and be myself.\n\n"
            'Each day gets easier and more natural.\n\n'
            "Let's bring the energy!";
      case 2:
        final greeting =
            hasName ? "What's up! $name here 🔥" : "What's up everyone! 🔥";
        return '$greeting\n\n'
            'This is my final warmup before the 30-day challenge begins!\n\n'
            "I've already grown so much just by showing up these past few days.\n\n"
            "I'm ready to achieve my goal to $goal.\n\n"
            "I've learned that consistency beats perfection.\n\n"
            'Every recording makes me more confident.\n\n'
            "Let's finish strong and crush this challenge!";
      default:
        final greeting =
            hasName ? "Hi, I'm $name$locationText!" : 'Hi everyone!';
        return '$greeting\n\n'
            "I'm working toward my goal to $goal.\n\n"
            'Every time I practice, I get a little better.\n\n'
            "Let's do this!";
    }
  }

  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Widget _buildCameraPreview(CameraController controller) {
    final previewSize = controller.value.previewSize;
    if (!controller.value.isInitialized || previewSize == null) {
      return CameraPreview(controller);
    }

    return ClipRect(
      child: OverflowBox(
        maxWidth: double.infinity,
        maxHeight: double.infinity,
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: previewSize.height,
            height: previewSize.width,
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121512),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final teleprompterHeight = (constraints.maxHeight *
                    _currentHeight.clamp(0.15, 0.50))
                .clamp(115.0, constraints.maxHeight * 0.46);

            return Stack(
              fit: StackFit.expand,
              children: [
                // Aspect-preserving full-bleed camera preview
                if (!_isInitializing && _recordingService.controller != null)
                  _buildCameraPreview(_recordingService.controller!)
                else
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          color: Color(0xFFF7F8F0),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Preparing camera...',
                          style: AppTypography.body(
                            color: const Color(0xFFF7F8F0),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Top bar with smoked-glass pill controls
                Positioned(
                  top: 8,
                  left: 12,
                  right: 12,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: _handleClose,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF121512).withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.22),
                            ),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Color(0xFFF7F8F0),
                            size: 21,
                          ),
                        ),
                      ),
                      if (_isRecording)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
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
                              const SizedBox(width: 8),
                              Text(
                                _formatDuration(_recordingSeconds),
                                style: AppTypography.bodyStrong(
                                  color: const Color(0xFFF7F8F0),
                                  fontSize: 13.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (!_showingCountdown)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: () => setState(
                                () => _isScriptVisible = !_isScriptVisible,
                              ),
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF121512)
                                      .withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.22),
                                  ),
                                ),
                                child: Icon(
                                  _isScriptVisible
                                      ? Icons.subtitles_outlined
                                      : Icons.subtitles_off_outlined,
                                  color: const Color(0xFFF7F8F0),
                                  size: 20,
                                ),
                              ),
                            ),
                            if (!_isRecording) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: _showSettingsSheet,
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF121512)
                                        .withValues(alpha: 0.55),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.22),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.tune_rounded,
                                    color: Color(0xFFF7F8F0),
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        )
                      else
                        const SizedBox(width: 40),
                    ],
                  ),
                ),

                // TELEPROMPTER AT TOP
                if (!_showingCountdown && _isScriptVisible)
                  Positioned(
                    top: 58,
                    left: 12,
                    right: 12,
                    height: teleprompterHeight,
                    child: widget.mode == RecordingMode.warmup
                        ? BlocBuilder<WarmupBloc, WarmupState>(
                            builder: (context, state) {
                              if (state is WarmupInProgress &&
                                  state.customScriptText != null) {
                                _cachedCustomScript = state.customScriptText;
                              } else if (state is WarmupRecording &&
                                  state.customScriptText != null) {
                                _cachedCustomScript = state.customScriptText;
                              }

                              final scriptText = _cachedCustomScript ??
                                  _getFallbackWarmupScript();

                              return TeleprompterWidget(
                                script: scriptText,
                                title: _warmup?.title ?? 'Day ${widget.dayNumber}',
                                isRecording: _isRecording,
                                scrollSpeed: _currentSpeed,
                                opacity: _currentOpacity,
                                fontSize: _currentFontSize,
                                textColor: _currentTextColor,
                                onSpeedChange: _adjustSpeed,
                              );
                            },
                          )
                        : TeleprompterWidget(
                            script: widget.script ?? 'No script found',
                            title: 'Day ${widget.dayNumber}',
                            isRecording: _isRecording,
                            scrollSpeed: _currentSpeed,
                            opacity: _currentOpacity,
                            fontSize: _currentFontSize,
                            textColor: _currentTextColor,
                            onSpeedChange: _adjustSpeed,
                          ),
                  ),

                // COACH TIPS AT BOTTOM
                if (!_isRecording && !_showingCountdown)
                  const Positioned(
                    bottom: 126,
                    left: 12,
                    right: 12,
                    child: CoachTipsCard(isRecording: false),
                  ),

                // Countdown overlay
                if (_showingCountdown)
                  Center(
                    child: Container(
                      width: 118,
                      height: 118,
                      decoration: BoxDecoration(
                        color: const Color(0xFF121512).withValues(alpha: 0.72),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFD8D478),
                          width: 3,
                        ),
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
                  ),

                // Bottom controls
                Positioned(
                  bottom: 24,
                  left: 0,
                  right: 0,
                  child: RecordingControls(
                    isRecording: _isRecording,
                    isInitializing: _isInitializing,
                    recordingSeconds: _recordingSeconds,
                    mode: widget.mode,
                    warmup: _warmup,
                    onStartCountdown: _startCountdown,
                    onStopRecording: _stopRecording,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

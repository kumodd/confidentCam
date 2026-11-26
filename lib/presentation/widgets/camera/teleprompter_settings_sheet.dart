import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/recording_audio_service.dart';
import '../../bloc/settings/settings_bloc.dart';

/// Values committed from [TeleprompterSettingsSheet].
class TeleprompterSettingsResult {
  final double speed;
  final double height;
  final double opacity;
  final String fontSizeKey;
  final double fontSizePixels;
  final bool autoScrollEnabled;
  final bool voiceSyncEnabled;
  final bool mirrorText;
  final RecordingLayoutTemplate layoutTemplate;
  final int countdownSeconds;
  final bool silenceNotifications;
  final int? preferredMicDeviceId;

  const TeleprompterSettingsResult({
    required this.speed,
    required this.height,
    required this.opacity,
    required this.fontSizeKey,
    required this.fontSizePixels,
    required this.autoScrollEnabled,
    required this.voiceSyncEnabled,
    this.mirrorText = false,
    this.layoutTemplate = RecordingLayoutTemplate.classicOverlay,
    this.countdownSeconds = 3,
    this.silenceNotifications = true,
    this.preferredMicDeviceId,
  });
}

/// Shared modal bottom sheet for configuring teleprompter, layout templates,
/// mirror mode, countdown, microphone input, and alert silencing across
/// Warmup, 30-Day Challenge, and Content Creator recording screens.
class TeleprompterSettingsSheet extends StatefulWidget {
  final double initialSpeed;
  final double initialHeight;
  final double initialOpacity;
  final String initialFontSizeKey;
  final bool initialAutoScrollEnabled;
  final bool initialVoiceSyncEnabled;
  final bool initialMirrorText;
  final RecordingLayoutTemplate initialLayoutTemplate;
  final int initialCountdownSeconds;
  final bool initialSilenceNotifications;
  final List<AudioInputDevice> availableMicrophones;
  final int? initialPreferredMicDeviceId;
  final bool hasDndPolicyAccess;
  final VoidCallback? onOpenDndPolicySettings;
  final ResolutionPreset? currentVideoQuality;
  final ValueChanged<ResolutionPreset>? onVideoQualityChanged;
  final ValueChanged<TeleprompterSettingsResult> onSettingsChanged;
  final ValueChanged<TeleprompterSettingsResult> onSettingsSaved;

  const TeleprompterSettingsSheet({
    super.key,
    required this.initialSpeed,
    required this.initialHeight,
    required this.initialOpacity,
    required this.initialFontSizeKey,
    required this.initialAutoScrollEnabled,
    required this.initialVoiceSyncEnabled,
    this.initialMirrorText = false,
    this.initialLayoutTemplate = RecordingLayoutTemplate.classicOverlay,
    this.initialCountdownSeconds = 3,
    this.initialSilenceNotifications = true,
    this.availableMicrophones = const [],
    this.initialPreferredMicDeviceId,
    this.hasDndPolicyAccess = false,
    this.onOpenDndPolicySettings,
    this.currentVideoQuality,
    this.onVideoQualityChanged,
    required this.onSettingsChanged,
    required this.onSettingsSaved,
  });

  @override
  State<TeleprompterSettingsSheet> createState() =>
      _TeleprompterSettingsSheetState();
}

class _TeleprompterSettingsSheetState extends State<TeleprompterSettingsSheet> {
  late double _currentSpeed;
  late double _currentHeight;
  late double _currentOpacity;
  late String _currentFontSizeKey;
  late bool _autoScrollEnabled;
  late bool _voiceSyncEnabled;
  late bool _mirrorText;
  late RecordingLayoutTemplate _layoutTemplate;
  late int _countdownSeconds;
  late bool _silenceNotifications;
  int? _preferredMicDeviceId;

  static const Map<String, String> _fontSizeLabels = {
    'small': 'S',
    'medium': 'M',
    'large': 'L',
    'extra_large': 'XL',
  };

  static const Map<int, String> _countdownOptions = {
    0: 'Instant',
    3: '3s',
    5: '5s',
  };

  @override
  void initState() {
    super.initState();
    _currentSpeed = widget.initialSpeed.clamp(0.5, 3.0);
    _currentHeight = widget.initialHeight.clamp(0.15, 0.55);
    _currentOpacity = widget.initialOpacity.clamp(0.10, 0.85);
    _currentFontSizeKey =
        AppConstants.fontSizeMap.containsKey(widget.initialFontSizeKey)
            ? widget.initialFontSizeKey
            : 'medium';
    _autoScrollEnabled = widget.initialAutoScrollEnabled;
    _voiceSyncEnabled = widget.initialVoiceSyncEnabled;
    _mirrorText = widget.initialMirrorText;
    _layoutTemplate = widget.initialLayoutTemplate;
    _countdownSeconds =
        _countdownOptions.containsKey(widget.initialCountdownSeconds)
            ? widget.initialCountdownSeconds
            : 3;
    _silenceNotifications = widget.initialSilenceNotifications;
    _preferredMicDeviceId = widget.initialPreferredMicDeviceId;
  }

  TeleprompterSettingsResult _snapshot() {
    return TeleprompterSettingsResult(
      speed: _currentSpeed,
      height: _currentHeight,
      opacity: _currentOpacity,
      fontSizeKey: _currentFontSizeKey,
      fontSizePixels: AppConstants.fontSizeMap[_currentFontSizeKey] ?? 16.0,
      autoScrollEnabled: _autoScrollEnabled,
      voiceSyncEnabled: _voiceSyncEnabled,
      mirrorText: _mirrorText,
      layoutTemplate: _layoutTemplate,
      countdownSeconds: _countdownSeconds,
      silenceNotifications: _silenceNotifications,
      preferredMicDeviceId: _preferredMicDeviceId,
    );
  }

  void _emitLivePreview() {
    widget.onSettingsChanged(_snapshot());
  }

  IconData _templateIcon(RecordingLayoutTemplate template) {
    switch (template) {
      case RecordingLayoutTemplate.classicOverlay:
        return Icons.picture_in_picture_alt_rounded;
      case RecordingLayoutTemplate.splitTop40:
        return Icons.view_stream_rounded;
      case RecordingLayoutTemplate.splitEven50:
        return Icons.splitscreen_rounded;
      case RecordingLayoutTemplate.scriptFocus60:
        return Icons.article_outlined;
      case RecordingLayoutTemplate.lowerOverlay:
        return Icons.subtitles_outlined;
    }
  }

  IconData _micIcon(AudioInputDevice device) {
    final label = device.typeLabel.toLowerCase();
    if (label.contains('bluetooth')) return Icons.bluetooth_audio_rounded;
    if (label.contains('usb')) return Icons.usb_rounded;
    if (label.contains('wired')) return Icons.headset_mic_outlined;
    return Icons.mic_none_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final maxSheetHeight = MediaQuery.of(context).size.height * 0.88;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxSheetHeight),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      color: AppColors.primaryOlive,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Recording & Teleprompter',
                        style: AppTypography.headingMedium(fontSize: 19),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.close_rounded,
                        color: AppColors.secondaryText,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // 1. Recording Screen Layout Templates
                SageCard(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'RECORDING LAYOUT TEMPLATE',
                            style: AppTypography.uppercaseLabel(
                              color: AppColors.secondaryText,
                              fontSize: 10.5,
                            ),
                          ),
                          OlivePillBadge(label: _layoutTemplate.shortLabel),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            RecordingLayoutTemplate.values.map((tpl) {
                              final selected = _layoutTemplate == tpl;
                              return GestureDetector(
                                onTap: () {
                                  setState(() => _layoutTemplate = tpl);
                                  _emitLivePreview();
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 11,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        selected
                                            ? AppColors.primaryOlive
                                            : AppColors.background,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color:
                                          selected
                                              ? AppColors.primaryOlive
                                              : AppColors.divider,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _templateIcon(tpl),
                                        size: 15,
                                        color:
                                            selected
                                                ? const Color(0xFFF7F8F0)
                                                : AppColors.primaryOlive,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        tpl.label,
                                        style: AppTypography.bodyStrong(
                                          fontSize: 12,
                                          color:
                                              selected
                                                  ? const Color(0xFFF7F8F0)
                                                  : AppColors.primaryText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _layoutTemplate.description,
                        style: AppTypography.body(fontSize: 11.5),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // 2. Modes: Voice-Following, Fixed-Speed, Mirror Text, Countdown
                SageCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildToggleRow(
                        icon: Icons.mic_none_rounded,
                        title: 'Voice-Following Mode',
                        subtitle:
                            'Auto-detects Hindi/English & scrolls sentence by sentence',
                        value: _voiceSyncEnabled,
                        onChanged: (v) {
                          setState(() => _voiceSyncEnabled = v);
                          _emitLivePreview();
                        },
                      ),
                      const Divider(height: 14),
                      _buildToggleRow(
                        icon: Icons.play_arrow_outlined,
                        title: 'Fixed-Speed Auto-Scroll',
                        subtitle:
                            _voiceSyncEnabled
                                ? 'Automatic fallback if voice recognition is unavailable'
                                : 'Mathematically scaled scroll speed on record',
                        value: _autoScrollEnabled,
                        onChanged: (v) {
                          setState(() => _autoScrollEnabled = v);
                          _emitLivePreview();
                        },
                      ),
                      const Divider(height: 14),
                      _buildToggleRow(
                        icon: Icons.flip_rounded,
                        title: 'Mirror Text',
                        subtitle:
                            'Flip script horizontally for glass mirror teleprompter rigs',
                        value: _mirrorText,
                        onChanged: (v) {
                          setState(() => _mirrorText = v);
                          _emitLivePreview();
                        },
                      ),
                      const Divider(height: 14),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              color: AppColors.primaryOlive,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Start Countdown',
                                    style: AppTypography.bodyStrong(
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Choose Instant for 1-tap recording',
                                    style: AppTypography.body(fontSize: 11.5),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children:
                                  _countdownOptions.entries.map((entry) {
                                    final selected =
                                        _countdownSeconds == entry.key;
                                    return Padding(
                                      padding: const EdgeInsets.only(left: 5),
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(
                                            () => _countdownSeconds = entry.key,
                                          );
                                          _emitLivePreview();
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                selected
                                                    ? AppColors.primaryOlive
                                                    : AppColors.background,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            border: Border.all(
                                              color:
                                                  selected
                                                      ? AppColors.primaryOlive
                                                      : AppColors.divider,
                                            ),
                                          ),
                                          child: Text(
                                            entry.value,
                                            style: AppTypography.bodyStrong(
                                              fontSize: 11.5,
                                              color:
                                                  selected
                                                      ? const Color(0xFFF7F8F0)
                                                      : AppColors.primaryText,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // 3. Audio Input (Microphone Selector) & Notification Sound Filtering
                SageCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.settings_voice_outlined,
                            color: AppColors.primaryOlive,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'MICROPHONE INPUT',
                              style: AppTypography.uppercaseLabel(
                                color: AppColors.secondaryText,
                                fontSize: 10.5,
                              ),
                            ),
                          ),
                          OlivePillBadge(
                            label:
                                widget.availableMicrophones.length > 1
                                    ? '${widget.availableMicrophones.length} detected'
                                    : 'Default',
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (widget.availableMicrophones.isEmpty)
                        Text(
                          'Using system default microphone. Connect a USB-C, wired, or Bluetooth mic to switch inputs.',
                          style: AppTypography.body(fontSize: 12),
                        )
                      else ...[
                        _buildMicOptionTile(
                          icon: Icons.auto_awesome_outlined,
                          title: 'Auto (System Default)',
                          subtitle: 'Automatically uses connected external mic',
                          selected: _preferredMicDeviceId == null,
                          onTap: () {
                            setState(() => _preferredMicDeviceId = null);
                            _emitLivePreview();
                          },
                        ),
                        ...widget.availableMicrophones.map(
                          (mic) => _buildMicOptionTile(
                            icon: _micIcon(mic),
                            title: mic.name,
                            subtitle:
                                mic.isExternal
                                    ? '${mic.typeLabel} • External'
                                    : mic.typeLabel,
                            selected: _preferredMicDeviceId == mic.id,
                            onTap: () {
                              setState(() => _preferredMicDeviceId = mic.id);
                              _emitLivePreview();
                            },
                          ),
                        ),
                      ],
                      const Divider(height: 16),
                      _buildToggleRow(
                        icon: Icons.notifications_off_outlined,
                        title: 'Filter Notification Sounds',
                        subtitle:
                            'Silences alerts, ringtones, and system pings during recording',
                        value: _silenceNotifications,
                        onChanged: (v) {
                          setState(() => _silenceNotifications = v);
                          _emitLivePreview();
                        },
                      ),
                      if (_silenceNotifications &&
                          !widget.hasDndPolicyAccess &&
                          widget.onOpenDndPolicySettings != null) ...[
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: widget.onOpenDndPolicySettings,
                            icon: const Icon(
                              Icons.do_not_disturb_on_outlined,
                              size: 16,
                            ),
                            label: const Text('Enable Deep DND Silence'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // 4. Sliders, Typography & Video Quality
                SageCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSliderRow(
                        label: 'SCROLL SPEED',
                        value: _currentSpeed,
                        min: 0.5,
                        max: 3.0,
                        suffix: 'x',
                        onChanged: (v) {
                          setState(() => _currentSpeed = v);
                          _emitLivePreview();
                        },
                      ),
                      if (!_layoutTemplate.isSplit) ...[
                        const Divider(height: 14),
                        _buildSliderRow(
                          label: 'OVERLAY DISPLAY HEIGHT',
                          value: (_currentHeight * 100).clamp(15.0, 55.0),
                          min: 15,
                          max: 55,
                          suffix: '%',
                          onChanged: (v) {
                            setState(() => _currentHeight = v / 100);
                            _emitLivePreview();
                          },
                        ),
                        const Divider(height: 14),
                        _buildSliderRow(
                          label: 'BACKGROUND OPACITY',
                          value: (_currentOpacity * 100).clamp(10.0, 85.0),
                          min: 10,
                          max: 85,
                          suffix: '%',
                          onChanged: (v) {
                            setState(() => _currentOpacity = v / 100);
                            _emitLivePreview();
                          },
                        ),
                      ],
                      const Divider(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              'BASE FONT SIZE',
                              style: AppTypography.uppercaseLabel(
                                color: AppColors.secondaryText,
                                fontSize: 10.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OlivePillBadge(
                            label:
                                '${(AppConstants.fontSizeMap[_currentFontSizeKey] ?? 16.0).toStringAsFixed(0)}pt',
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children:
                            _fontSizeLabels.entries.map((entry) {
                              final selected = _currentFontSizeKey == entry.key;
                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(
                                        () => _currentFontSizeKey = entry.key,
                                      );
                                      _emitLivePreview();
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 160,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            selected
                                                ? AppColors.primaryOlive
                                                : AppColors.background,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color:
                                              selected
                                                  ? AppColors.primaryOlive
                                                  : AppColors.divider,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          entry.value,
                                          style: AppTypography.bodyStrong(
                                            fontSize: 13,
                                            color:
                                                selected
                                                    ? const Color(0xFFF7F8F0)
                                                    : AppColors.primaryText,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                      if (widget.currentVideoQuality != null &&
                          widget.onVideoQualityChanged != null) ...[
                        const Divider(height: 20),
                        Row(
                          children: [
                            Icon(
                              Icons.high_quality_outlined,
                              color: AppColors.primaryOlive,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Video Quality',
                                style: AppTypography.bodyStrong(),
                              ),
                            ),
                            DropdownButtonHideUnderline(
                              child: DropdownButton<ResolutionPreset>(
                                value: widget.currentVideoQuality,
                                dropdownColor: AppColors.background,
                                icon: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: AppColors.secondaryText,
                                  size: 20,
                                ),
                                style: AppTypography.bodyStrong(),
                                items: const [
                                  DropdownMenuItem(
                                    value: ResolutionPreset.low,
                                    child: Text('480p (Low)'),
                                  ),
                                  DropdownMenuItem(
                                    value: ResolutionPreset.medium,
                                    child: Text('720p (Medium)'),
                                  ),
                                  DropdownMenuItem(
                                    value: ResolutionPreset.high,
                                    child: Text('1080p (High)'),
                                  ),
                                  DropdownMenuItem(
                                    value: ResolutionPreset.veryHigh,
                                    child: Text('1440p (Very High)'),
                                  ),
                                  DropdownMenuItem(
                                    value: ResolutionPreset.ultraHigh,
                                    child: Text('4K (Ultra)'),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    Navigator.pop(context);
                                    widget.onVideoQualityChanged!(value);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final result = _snapshot();
                      final bloc = context.read<SettingsBloc>();
                      bloc.add(TeleprompterSpeedUpdated(result.speed));
                      bloc.add(TeleprompterHeightUpdated(result.height));
                      bloc.add(TeleprompterOpacityUpdated(result.opacity));
                      bloc.add(TeleprompterFontSizeUpdated(result.fontSizeKey));
                      bloc.add(AutoScrollToggled(result.autoScrollEnabled));
                      bloc.add(VoiceSyncToggled(result.voiceSyncEnabled));
                      bloc.add(TeleprompterMirrorToggled(result.mirrorText));
                      bloc.add(
                        RecordingLayoutTemplateUpdated(
                          result.layoutTemplate.key,
                        ),
                      );
                      bloc.add(
                        RecordingCountdownUpdated(result.countdownSeconds),
                      );
                      bloc.add(
                        SilenceNotificationsToggled(
                          result.silenceNotifications,
                        ),
                      );
                      bloc.add(
                        PreferredMicDeviceUpdated(result.preferredMicDeviceId),
                      );
                      widget.onSettingsSaved(result);
                      Navigator.pop(context);
                    },
                    child: const Text('Save Settings'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMicOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppColors.olivePillFill : AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.primaryOlive : AppColors.divider,
              width: selected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color:
                    selected ? AppColors.primaryOlive : AppColors.secondaryText,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.bodyStrong(
                        fontSize: 13,
                        color:
                            selected
                                ? AppColors.primaryOlive
                                : AppColors.primaryText,
                      ),
                    ),
                    Text(subtitle, style: AppTypography.body(fontSize: 11)),
                  ],
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: AppColors.primaryOlive,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryOlive, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.bodyStrong(fontSize: 13.5)),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTypography.body(fontSize: 11.5)),
              ],
            ),
          ),
        ),
        Switch(
          value: value,
          activeThumbColor: AppColors.secondaryGreen,
          activeTrackColor: AppColors.navPill,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildSliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required String suffix,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                label,
                style: AppTypography.uppercaseLabel(
                  color: AppColors.secondaryText,
                  fontSize: 10.5,
                ),
              ),
            ),
            const SizedBox(width: 8),
            OlivePillBadge(label: '${value.toStringAsFixed(1)}$suffix'),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          activeColor: AppColors.primaryOlive,
          inactiveColor: AppColors.divider,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

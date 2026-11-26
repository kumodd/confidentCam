import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';

/// Recording screen layout templates combining the teleprompter script panel
/// and live camera preview in different proportions.
enum RecordingLayoutTemplate {
  classicOverlay(
    key: 'classic_overlay',
    label: 'Floating Overlay',
    shortLabel: 'Overlay',
    description: 'Full-screen camera with translucent top teleprompter',
    isSplit: false,
    scriptFlex: 0,
    cameraFlex: 100,
  ),
  splitTop40(
    key: 'split_top_40',
    label: 'Split 40 / 60',
    shortLabel: '40/60',
    description: 'Script panel top 40%, live video preview bottom 60%',
    isSplit: true,
    scriptFlex: 40,
    cameraFlex: 60,
  ),
  splitEven50(
    key: 'split_even_50',
    label: 'Split 50 / 50',
    shortLabel: '50/50',
    description: 'Equal 50% script panel and 50% live video preview',
    isSplit: true,
    scriptFlex: 50,
    cameraFlex: 50,
  ),
  scriptFocus60(
    key: 'script_focus_60',
    label: 'Script Focus 60 / 40',
    shortLabel: '60/40',
    description: 'Large 60% script reading area with 40% self-view monitor',
    isSplit: true,
    scriptFlex: 60,
    cameraFlex: 40,
  ),
  lowerOverlay(
    key: 'lower_overlay',
    label: 'Lower Overlay',
    shortLabel: 'Lower',
    description: 'Full-screen camera with compact script near the bottom',
    isSplit: false,
    scriptFlex: 0,
    cameraFlex: 100,
  );

  final String key;
  final String label;
  final String shortLabel;
  final String description;
  final bool isSplit;
  final int scriptFlex;
  final int cameraFlex;

  const RecordingLayoutTemplate({
    required this.key,
    required this.label,
    required this.shortLabel,
    required this.description,
    required this.isSplit,
    required this.scriptFlex,
    required this.cameraFlex,
  });

  static RecordingLayoutTemplate fromKey(String? raw) {
    for (final template in RecordingLayoutTemplate.values) {
      if (template.key == raw) return template;
    }
    return RecordingLayoutTemplate.classicOverlay;
  }
}

/// User settings entity.
class Settings extends Equatable {
  final TimeOfDay reminderTime;
  final double teleprompterSpeed;
  final String teleprompterFontSize;
  final String teleprompterTextColor;
  final double teleprompterHeight;
  final double teleprompterOpacity;
  final bool autoScrollEnabled;
  final bool voiceSyncEnabled;
  final bool teleprompterMirrorText;
  final String recordingLayoutTemplate;
  final int recordingCountdownSeconds;
  final bool silenceNotificationsDuringRecording;
  final int? preferredMicDeviceId;
  final String defaultCamera;
  final String videoQuality;
  final String languagePreference;

  const Settings({
    required this.reminderTime,
    required this.teleprompterSpeed,
    required this.teleprompterFontSize,
    required this.teleprompterTextColor,
    required this.teleprompterHeight,
    required this.teleprompterOpacity,
    required this.autoScrollEnabled,
    this.voiceSyncEnabled = false,
    this.teleprompterMirrorText = false,
    this.recordingLayoutTemplate = 'classic_overlay',
    this.recordingCountdownSeconds = 3,
    this.silenceNotificationsDuringRecording = true,
    this.preferredMicDeviceId,
    required this.defaultCamera,
    required this.videoQuality,
    required this.languagePreference,
  });

  factory Settings.defaults() => const Settings(
    reminderTime: TimeOfDay(hour: 9, minute: 0),
    teleprompterSpeed: 1.0,
    teleprompterFontSize: 'medium',
    teleprompterTextColor: 'white',
    teleprompterHeight: 0.24,
    teleprompterOpacity: 0.35,
    autoScrollEnabled: true,
    voiceSyncEnabled: false,
    teleprompterMirrorText: false,
    recordingLayoutTemplate: 'classic_overlay',
    recordingCountdownSeconds: 3,
    silenceNotificationsDuringRecording: true,
    preferredMicDeviceId: null,
    defaultCamera: 'front',
    videoQuality: '1080p',
    languagePreference: 'en',
  );

  /// Parsed recording layout template enum.
  RecordingLayoutTemplate get layoutTemplate =>
      RecordingLayoutTemplate.fromKey(recordingLayoutTemplate);

  /// Create a copy with specific fields updated
  Settings copyWith({
    TimeOfDay? reminderTime,
    double? teleprompterSpeed,
    String? teleprompterFontSize,
    String? teleprompterTextColor,
    double? teleprompterHeight,
    double? teleprompterOpacity,
    bool? autoScrollEnabled,
    bool? voiceSyncEnabled,
    bool? teleprompterMirrorText,
    String? recordingLayoutTemplate,
    int? recordingCountdownSeconds,
    bool? silenceNotificationsDuringRecording,
    int? preferredMicDeviceId,
    bool clearPreferredMicDevice = false,
    String? defaultCamera,
    String? videoQuality,
    String? languagePreference,
  }) {
    return Settings(
      reminderTime: reminderTime ?? this.reminderTime,
      teleprompterSpeed: teleprompterSpeed ?? this.teleprompterSpeed,
      teleprompterFontSize: teleprompterFontSize ?? this.teleprompterFontSize,
      teleprompterTextColor:
          teleprompterTextColor ?? this.teleprompterTextColor,
      teleprompterHeight: teleprompterHeight ?? this.teleprompterHeight,
      teleprompterOpacity: teleprompterOpacity ?? this.teleprompterOpacity,
      autoScrollEnabled: autoScrollEnabled ?? this.autoScrollEnabled,
      voiceSyncEnabled: voiceSyncEnabled ?? this.voiceSyncEnabled,
      teleprompterMirrorText:
          teleprompterMirrorText ?? this.teleprompterMirrorText,
      recordingLayoutTemplate:
          recordingLayoutTemplate ?? this.recordingLayoutTemplate,
      recordingCountdownSeconds:
          recordingCountdownSeconds ?? this.recordingCountdownSeconds,
      silenceNotificationsDuringRecording:
          silenceNotificationsDuringRecording ??
          this.silenceNotificationsDuringRecording,
      preferredMicDeviceId:
          clearPreferredMicDevice
              ? null
              : preferredMicDeviceId ?? this.preferredMicDeviceId,
      defaultCamera: defaultCamera ?? this.defaultCamera,
      videoQuality: videoQuality ?? this.videoQuality,
      languagePreference: languagePreference ?? this.languagePreference,
    );
  }

  /// Get font size in pixels
  double get fontSizePixels =>
      AppConstants.fontSizeMap[teleprompterFontSize] ??
      double.tryParse(teleprompterFontSize) ??
      16.0;

  /// Maps a numeric font size in logical pixels to the nearest named preset key.
  static String fontSizeKeyForPixels(double pixels) {
    if (pixels <= 14.5) return 'small';
    if (pixels <= 17.0) return 'medium';
    if (pixels <= 20.0) return 'large';
    return 'extra_large';
  }

  @override
  List<Object?> get props => [
    reminderTime,
    teleprompterSpeed,
    teleprompterFontSize,
    teleprompterTextColor,
    teleprompterHeight,
    teleprompterOpacity,
    autoScrollEnabled,
    voiceSyncEnabled,
    teleprompterMirrorText,
    recordingLayoutTemplate,
    recordingCountdownSeconds,
    silenceNotificationsDuringRecording,
    preferredMicDeviceId,
    defaultCamera,
    videoQuality,
    languagePreference,
  ];
}

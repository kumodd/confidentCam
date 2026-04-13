import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';

/// User settings entity.
class Settings extends Equatable {
  final TimeOfDay reminderTime;
  final double teleprompterSpeed;
  final String teleprompterFontSize;
  final String teleprompterTextColor;
  final double teleprompterHeight;
  final double teleprompterOpacity;
  final bool autoScrollEnabled;
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
    required this.defaultCamera,
    required this.videoQuality,
    required this.languagePreference,
  });

  factory Settings.defaults() => const Settings(
    reminderTime: TimeOfDay(hour: 9, minute: 0),
    teleprompterSpeed: 1.0,
    teleprompterFontSize: 'medium',
    teleprompterTextColor: 'white',
    teleprompterHeight: 0.25,
    teleprompterOpacity: 0.85,
    autoScrollEnabled: true,
    defaultCamera: 'front',
    videoQuality: '1080p',
    languagePreference: 'en',
  );

  /// Create a copy with specific fields updated
  Settings copyWith({
    TimeOfDay? reminderTime,
    double? teleprompterSpeed,
    String? teleprompterFontSize,
    String? teleprompterTextColor,
    double? teleprompterHeight,
    double? teleprompterOpacity,
    bool? autoScrollEnabled,
    String? defaultCamera,
    String? videoQuality,
    String? languagePreference,
  }) {
    return Settings(
      reminderTime: reminderTime ?? this.reminderTime,
      teleprompterSpeed: teleprompterSpeed ?? this.teleprompterSpeed,
      teleprompterFontSize: teleprompterFontSize ?? this.teleprompterFontSize,
      teleprompterTextColor: teleprompterTextColor ?? this.teleprompterTextColor,
      teleprompterHeight: teleprompterHeight ?? this.teleprompterHeight,
      teleprompterOpacity: teleprompterOpacity ?? this.teleprompterOpacity,
      autoScrollEnabled: autoScrollEnabled ?? this.autoScrollEnabled,
      defaultCamera: defaultCamera ?? this.defaultCamera,
      videoQuality: videoQuality ?? this.videoQuality,
      languagePreference: languagePreference ?? this.languagePreference,
    );
  }

  /// Get font size in pixels
  double get fontSizePixels =>
      AppConstants.fontSizeMap[teleprompterFontSize] ?? 16.0;

  @override
  List<Object?> get props => [
    reminderTime,
    teleprompterSpeed,
    teleprompterFontSize,
    teleprompterTextColor,
    teleprompterHeight,
    teleprompterOpacity,
    autoScrollEnabled,
    defaultCamera,
    videoQuality,
    languagePreference,
  ];
}

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Settings BLoC Events
abstract class SettingsEvent extends Equatable {
  const SettingsEvent();
  @override
  List<Object?> get props => [];
}

class SettingsLoaded extends SettingsEvent {
  const SettingsLoaded();
}

class ReminderTimeUpdated extends SettingsEvent {
  final TimeOfDay time;
  const ReminderTimeUpdated(this.time);
  @override
  List<Object?> get props => [time];
}

class TeleprompterSpeedUpdated extends SettingsEvent {
  final double speed;
  const TeleprompterSpeedUpdated(this.speed);
  @override
  List<Object?> get props => [speed];
}

class TeleprompterFontSizeUpdated extends SettingsEvent {
  final String fontSize;
  const TeleprompterFontSizeUpdated(this.fontSize);
  @override
  List<Object?> get props => [fontSize];
}

class TeleprompterTextColorUpdated extends SettingsEvent {
  final String color;
  const TeleprompterTextColorUpdated(this.color);
  @override
  List<Object?> get props => [color];
}

class TeleprompterHeightUpdated extends SettingsEvent {
  final double height;
  const TeleprompterHeightUpdated(this.height);
  @override
  List<Object?> get props => [height];
}

class TeleprompterOpacityUpdated extends SettingsEvent {
  final double opacity;
  const TeleprompterOpacityUpdated(this.opacity);
  @override
  List<Object?> get props => [opacity];
}

class AutoScrollToggled extends SettingsEvent {
  final bool enabled;
  const AutoScrollToggled(this.enabled);
  @override
  List<Object?> get props => [enabled];
}

class DefaultCameraUpdated extends SettingsEvent {
  final String camera;
  const DefaultCameraUpdated(this.camera);
  @override
  List<Object?> get props => [camera];
}

class LanguagePreferenceUpdated extends SettingsEvent {
  final String language;
  const LanguagePreferenceUpdated(this.language);
  @override
  List<Object?> get props => [language];
}

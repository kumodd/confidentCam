import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/datasources/local/hive_settings_datasource.dart';
import '../../../core/constants/app_constants.dart';

// Settings entity
class Settings extends Equatable {
  final TimeOfDay reminderTime;
  final double teleprompterSpeed;
  final String teleprompterFontSize;
  final String teleprompterTextColor;
  final double teleprompterHeight;
  final double teleprompterOpacity;
  final String defaultCamera;
  final String videoQuality;

  const Settings({
    required this.reminderTime,
    required this.teleprompterSpeed,
    required this.teleprompterFontSize,
    required this.teleprompterTextColor,
    required this.teleprompterHeight,
    required this.teleprompterOpacity,
    required this.defaultCamera,
    required this.videoQuality,
  });

  factory Settings.defaults() => const Settings(
    reminderTime: TimeOfDay(hour: 9, minute: 0),
    teleprompterSpeed: 1.0,
    teleprompterFontSize: 'medium',
    teleprompterTextColor: 'white',
    teleprompterHeight: 0.25,
    teleprompterOpacity: 0.85,
    defaultCamera: 'front',
    videoQuality: '1080p',
  );

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
    defaultCamera,
    videoQuality,
  ];
}

// Events
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

class DefaultCameraUpdated extends SettingsEvent {
  final String camera;
  const DefaultCameraUpdated(this.camera);
  @override
  List<Object?> get props => [camera];
}

// States
abstract class SettingsState extends Equatable {
  const SettingsState();
  @override
  List<Object?> get props => [];
}

class SettingsInitial extends SettingsState {
  const SettingsInitial();
}

class SettingsLoadSuccess extends SettingsState {
  final Settings settings;
  const SettingsLoadSuccess(this.settings);
  @override
  List<Object?> get props => [settings];
}

class SettingsUpdating extends SettingsState {
  const SettingsUpdating();
}

class SettingsError extends SettingsState {
  final String message;
  const SettingsError(this.message);
  @override
  List<Object?> get props => [message];
}

// BLoC
class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final HiveSettingsDataSource settingsDataSource;

  SettingsBloc({required this.settingsDataSource})
    : super(const SettingsInitial()) {
    on<SettingsLoaded>(_onLoaded);
    on<ReminderTimeUpdated>(_onReminderTimeUpdated);
    on<TeleprompterSpeedUpdated>(_onSpeedUpdated);
    on<TeleprompterFontSizeUpdated>(_onFontSizeUpdated);
    on<TeleprompterHeightUpdated>(_onHeightUpdated);
    on<TeleprompterOpacityUpdated>(_onOpacityUpdated);
    on<DefaultCameraUpdated>(_onCameraUpdated);
  }

  Future<void> _onLoaded(
    SettingsLoaded event,
    Emitter<SettingsState> emit,
  ) async {
    final data = await settingsDataSource.getSettings();

    final timeStr = data[AppConstants.reminderTimeKey] as String? ?? '09:00';
    final parts = timeStr.split(':');
    final time = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 9,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );

    emit(
      SettingsLoadSuccess(
        Settings(
          reminderTime: time,
          teleprompterSpeed:
              (data[AppConstants.teleprompterSpeedKey] as num?)?.toDouble() ??
              AppConstants.defaultScrollSpeed,
          teleprompterFontSize:
              data[AppConstants.teleprompterFontSizeKey] as String? ??
              AppConstants.defaultFontSize,
          teleprompterTextColor:
              data[AppConstants.teleprompterTextColorKey] as String? ??
              AppConstants.defaultTextColor,
          teleprompterHeight:
              (data[AppConstants.teleprompterHeightKey] as num?)?.toDouble() ??
              AppConstants.defaultTeleprompterHeight,
          teleprompterOpacity:
              (data[AppConstants.teleprompterOpacityKey] as num?)?.toDouble() ??
              AppConstants.defaultTeleprompterOpacity,
          defaultCamera:
              data[AppConstants.defaultCameraKey] as String? ?? 'front',
          videoQuality:
              data[AppConstants.videoQualityKey] as String? ?? '1080p',
        ),
      ),
    );
  }

  Future<void> _onReminderTimeUpdated(
    ReminderTimeUpdated event,
    Emitter<SettingsState> emit,
  ) async {
    final timeStr =
        '${event.time.hour.toString().padLeft(2, '0')}:${event.time.minute.toString().padLeft(2, '0')}';
    await settingsDataSource.saveSetting(AppConstants.reminderTimeKey, timeStr);
    add(const SettingsLoaded());
  }

  Future<void> _onSpeedUpdated(
    TeleprompterSpeedUpdated event,
    Emitter<SettingsState> emit,
  ) async {
    await settingsDataSource.saveSetting(
      AppConstants.teleprompterSpeedKey,
      event.speed,
    );
    add(const SettingsLoaded());
  }

  Future<void> _onFontSizeUpdated(
    TeleprompterFontSizeUpdated event,
    Emitter<SettingsState> emit,
  ) async {
    await settingsDataSource.saveSetting(
      AppConstants.teleprompterFontSizeKey,
      event.fontSize,
    );
    add(const SettingsLoaded());
  }

  Future<void> _onHeightUpdated(
    TeleprompterHeightUpdated event,
    Emitter<SettingsState> emit,
  ) async {
    await settingsDataSource.saveSetting(
      AppConstants.teleprompterHeightKey,
      event.height,
    );
    add(const SettingsLoaded());
  }

  Future<void> _onOpacityUpdated(
    TeleprompterOpacityUpdated event,
    Emitter<SettingsState> emit,
  ) async {
    await settingsDataSource.saveSetting(
      AppConstants.teleprompterOpacityKey,
      event.opacity,
    );
    add(const SettingsLoaded());
  }

  Future<void> _onCameraUpdated(
    DefaultCameraUpdated event,
    Emitter<SettingsState> emit,
  ) async {
    await settingsDataSource.saveSetting(
      AppConstants.defaultCameraKey,
      event.camera,
    );
    add(const SettingsLoaded());
  }
}

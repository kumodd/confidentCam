import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/di/injection_container.dart';
import '../../../data/datasources/local/hive_settings_datasource.dart';
import '../../../domain/entities/settings.dart';
import '../../../services/notification_service.dart';
import 'settings_event.dart';
import 'settings_state.dart';

// Re-export for consumers that import settings_bloc.dart
export '../../../domain/entities/settings.dart';
export 'settings_event.dart';
export 'settings_state.dart';

/// BLoC for managing user settings.
///
/// Uses [Settings.copyWith] to emit updated state directly
/// instead of re-reading all values from Hive on every change.
class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final HiveSettingsDataSource settingsDataSource;

  SettingsBloc({required this.settingsDataSource})
    : super(const SettingsInitial()) {
    on<SettingsLoaded>(_onLoaded);
    on<ReminderTimeUpdated>(_onReminderTimeUpdated);
    on<TeleprompterSpeedUpdated>(_onSpeedUpdated);
    on<TeleprompterFontSizeUpdated>(_onFontSizeUpdated);
    on<TeleprompterTextColorUpdated>(_onTextColorUpdated);
    on<TeleprompterHeightUpdated>(_onHeightUpdated);
    on<TeleprompterOpacityUpdated>(_onOpacityUpdated);
    on<AutoScrollToggled>(_onAutoScrollToggled);
    on<DefaultCameraUpdated>(_onCameraUpdated);
    on<LanguagePreferenceUpdated>(_onLanguageUpdated);
  }

  /// Helper: get current settings or defaults
  Settings get _currentSettings {
    if (state is SettingsLoadSuccess) {
      return (state as SettingsLoadSuccess).settings;
    }
    return Settings.defaults();
  }

  /// Helper: save a setting and emit updated state without re-reading Hive
  Future<void> _updateAndEmit(
    String key,
    dynamic value,
    Settings Function(Settings current) updater,
    Emitter<SettingsState> emit,
  ) async {
    await settingsDataSource.saveSetting(key, value);
    emit(SettingsLoadSuccess(updater(_currentSettings)));
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
          autoScrollEnabled: data['auto_scroll_enabled'] as bool? ?? true,
          defaultCamera:
              data[AppConstants.defaultCameraKey] as String? ?? 'front',
          videoQuality:
              data[AppConstants.videoQualityKey] as String? ?? '1080p',
          languagePreference:
              data[AppConstants.languagePreferenceKey] as String? ?? 'en',
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
    
    // Schedule the daily notification
    try {
      final notificationService = sl<NotificationService>();
      final hasPermission = await notificationService.requestPermissions();
      if (!hasPermission) {
        emit(SettingsNotificationError(_currentSettings.copyWith(reminderTime: event.time)));
      } else {
        await notificationService.scheduleDailyReminder(event.time);
      }
    } catch (e) {
      emit(SettingsNotificationError(_currentSettings.copyWith(reminderTime: event.time)));
    }
    
    emit(SettingsLoadSuccess(_currentSettings.copyWith(reminderTime: event.time)));
  }

  Future<void> _onSpeedUpdated(
    TeleprompterSpeedUpdated event,
    Emitter<SettingsState> emit,
  ) async {
    await _updateAndEmit(
      AppConstants.teleprompterSpeedKey,
      event.speed,
      (s) => s.copyWith(teleprompterSpeed: event.speed),
      emit,
    );
  }

  Future<void> _onFontSizeUpdated(
    TeleprompterFontSizeUpdated event,
    Emitter<SettingsState> emit,
  ) async {
    await _updateAndEmit(
      AppConstants.teleprompterFontSizeKey,
      event.fontSize,
      (s) => s.copyWith(teleprompterFontSize: event.fontSize),
      emit,
    );
  }

  Future<void> _onTextColorUpdated(
    TeleprompterTextColorUpdated event,
    Emitter<SettingsState> emit,
  ) async {
    await _updateAndEmit(
      AppConstants.teleprompterTextColorKey,
      event.color,
      (s) => s.copyWith(teleprompterTextColor: event.color),
      emit,
    );
  }

  Future<void> _onHeightUpdated(
    TeleprompterHeightUpdated event,
    Emitter<SettingsState> emit,
  ) async {
    await _updateAndEmit(
      AppConstants.teleprompterHeightKey,
      event.height,
      (s) => s.copyWith(teleprompterHeight: event.height),
      emit,
    );
  }

  Future<void> _onOpacityUpdated(
    TeleprompterOpacityUpdated event,
    Emitter<SettingsState> emit,
  ) async {
    await _updateAndEmit(
      AppConstants.teleprompterOpacityKey,
      event.opacity,
      (s) => s.copyWith(teleprompterOpacity: event.opacity),
      emit,
    );
  }

  Future<void> _onAutoScrollToggled(
    AutoScrollToggled event,
    Emitter<SettingsState> emit,
  ) async {
    await _updateAndEmit(
      'auto_scroll_enabled',
      event.enabled,
      (s) => s.copyWith(autoScrollEnabled: event.enabled),
      emit,
    );
  }

  Future<void> _onCameraUpdated(
    DefaultCameraUpdated event,
    Emitter<SettingsState> emit,
  ) async {
    await _updateAndEmit(
      AppConstants.defaultCameraKey,
      event.camera,
      (s) => s.copyWith(defaultCamera: event.camera),
      emit,
    );
  }

  Future<void> _onLanguageUpdated(
    LanguagePreferenceUpdated event,
    Emitter<SettingsState> emit,
  ) async {
    await _updateAndEmit(
      AppConstants.languagePreferenceKey,
      event.language,
      (s) => s.copyWith(languagePreference: event.language),
      emit,
    );
  }
}

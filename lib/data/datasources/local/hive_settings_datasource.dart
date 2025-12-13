import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/error/exceptions.dart';
import '../../../core/utils/logger.dart';

/// Local data source for settings using Hive.
abstract class HiveSettingsDataSource {
  /// Get all settings.
  Future<Map<String, dynamic>> getSettings();

  /// Get a specific setting.
  T? getSetting<T>(String key);

  /// Save a setting.
  Future<void> saveSetting(String key, dynamic value);

  /// Save multiple settings.
  Future<void> saveSettings(Map<String, dynamic> settings);

  /// Clear all settings.
  Future<void> clearSettings();
}

class HiveSettingsDataSourceImpl implements HiveSettingsDataSource {
  final Box settingsBox;

  HiveSettingsDataSourceImpl({required this.settingsBox});

  @override
  Future<Map<String, dynamic>> getSettings() async {
    try {
      return {
        AppConstants.reminderTimeKey: settingsBox.get(
          AppConstants.reminderTimeKey,
          defaultValue: '09:00',
        ),
        AppConstants.teleprompterSpeedKey: settingsBox.get(
          AppConstants.teleprompterSpeedKey,
          defaultValue: AppConstants.defaultScrollSpeed,
        ),
        AppConstants.teleprompterFontSizeKey: settingsBox.get(
          AppConstants.teleprompterFontSizeKey,
          defaultValue: AppConstants.defaultFontSize,
        ),
        AppConstants.teleprompterTextColorKey: settingsBox.get(
          AppConstants.teleprompterTextColorKey,
          defaultValue: AppConstants.defaultTextColor,
        ),
        AppConstants.teleprompterHeightKey: settingsBox.get(
          AppConstants.teleprompterHeightKey,
          defaultValue: AppConstants.defaultTeleprompterHeight,
        ),
        AppConstants.teleprompterOpacityKey: settingsBox.get(
          AppConstants.teleprompterOpacityKey,
          defaultValue: AppConstants.defaultTeleprompterOpacity,
        ),
        'auto_scroll_enabled': settingsBox.get(
          'auto_scroll_enabled',
          defaultValue: true,
        ),
        AppConstants.defaultCameraKey: settingsBox.get(
          AppConstants.defaultCameraKey,
          defaultValue: 'front',
        ),
        AppConstants.videoQualityKey: settingsBox.get(
          AppConstants.videoQualityKey,
          defaultValue: '1080p',
        ),
        AppConstants.languagePreferenceKey: settingsBox.get(
          AppConstants.languagePreferenceKey,
          defaultValue: 'en',
        ),
      };
    } catch (e) {
      logger.e('Error getting settings', e);
      return _defaultSettings;
    }
  }

  Map<String, dynamic> get _defaultSettings => {
    AppConstants.reminderTimeKey: '09:00',
    AppConstants.teleprompterSpeedKey: AppConstants.defaultScrollSpeed,
    AppConstants.teleprompterFontSizeKey: AppConstants.defaultFontSize,
    AppConstants.teleprompterTextColorKey: AppConstants.defaultTextColor,
    AppConstants.teleprompterHeightKey: AppConstants.defaultTeleprompterHeight,
    AppConstants.teleprompterOpacityKey:
        AppConstants.defaultTeleprompterOpacity,
    'auto_scroll_enabled': true,
    AppConstants.defaultCameraKey: 'front',
    AppConstants.videoQualityKey: '1080p',
    AppConstants.languagePreferenceKey: 'en',
  };

  @override
  T? getSetting<T>(String key) {
    try {
      return settingsBox.get(key) as T?;
    } catch (e) {
      logger.e('Error getting setting $key', e);
      return null;
    }
  }

  @override
  Future<void> saveSetting(String key, dynamic value) async {
    try {
      await settingsBox.put(key, value);
    } catch (e) {
      logger.e('Error saving setting $key', e);
      throw CacheException(message: 'Failed to save setting', originalError: e);
    }
  }

  @override
  Future<void> saveSettings(Map<String, dynamic> settings) async {
    try {
      for (final entry in settings.entries) {
        await settingsBox.put(entry.key, entry.value);
      }
    } catch (e) {
      logger.e('Error saving settings', e);
      throw CacheException(
        message: 'Failed to save settings',
        originalError: e,
      );
    }
  }

  @override
  Future<void> clearSettings() async {
    try {
      await settingsBox.clear();
    } catch (e) {
      logger.e('Error clearing settings', e);
    }
  }
}

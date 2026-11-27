import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/logger.dart';
import 'app_config.dart';

/// Runtime remote configuration backed by Supabase `public.app_config`
/// and `public.feature_flags`, with Hive offline caching and safe
/// compile-time [AppConfig] fallbacks.
class RemoteConfigService extends ChangeNotifier {
  static const String _configCacheKey = 'app_config_map';
  static const String _flagsCacheKey = 'feature_flags_map';
  static const String _lastFetchedAtKey = 'last_fetched_at';
  static const Duration _fetchTimeout = Duration(seconds: 4);
  static const Duration _minRefreshInterval = Duration(minutes: 5);

  final SupabaseClient? _client;
  final Box? _cacheBox;

  Map<String, String> _config = {};
  Map<String, bool> _flags = {};
  DateTime? _lastFetchedAt;
  bool _isRefreshing = false;

  RemoteConfigService({
    SupabaseClient? client,
    Box? cacheBox,
  })  : _client = client,
        _cacheBox = cacheBox {
    _loadFromCache();
  }

  /// Test/preview constructor allowing direct in-memory injection.
  @visibleForTesting
  RemoteConfigService.fromValues({
    Map<String, String> config = const {},
    Map<String, bool> flags = const {},
  })  : _client = null,
        _cacheBox = null,
        _config = Map<String, String>.from(config),
        _flags = Map<String, bool>.from(flags);

  bool get hasLoadedRemote => _lastFetchedAt != null;
  DateTime? get lastFetchedAt => _lastFetchedAt;

  void _loadFromCache() {
    final box = _cacheBox;
    if (box == null) return;
    try {
      final rawConfig = box.get(_configCacheKey);
      if (rawConfig is Map) {
        _config = rawConfig.map(
          (k, v) => MapEntry(k.toString(), v.toString()),
        );
      }
      final rawFlags = box.get(_flagsCacheKey);
      if (rawFlags is Map) {
        _flags = rawFlags.map(
          (k, v) => MapEntry(k.toString(), v == true || v.toString() == 'true'),
        );
      }
      final rawTime = box.get(_lastFetchedAtKey);
      if (rawTime is String) {
        _lastFetchedAt = DateTime.tryParse(rawTime);
      }
    } catch (e) {
      logger.w('RemoteConfigService cache read notice: $e');
    }
  }

  Future<void> _saveToCache() async {
    final box = _cacheBox;
    if (box == null) return;
    try {
      await box.put(_configCacheKey, _config);
      await box.put(_flagsCacheKey, _flags);
      if (_lastFetchedAt != null) {
        await box.put(_lastFetchedAtKey, _lastFetchedAt!.toIso8601String());
      }
    } catch (e) {
      logger.w('RemoteConfigService cache write notice: $e');
    }
  }

  /// Fetch active non-secret rows from `public.app_config` and all rows from
  /// `public.feature_flags`. Fails silently to cache/defaults when offline.
  Future<bool> refresh({bool force = false}) async {
    if (_client == null) return false;
    if (_isRefreshing) return false;

    if (!force &&
        _lastFetchedAt != null &&
        DateTime.now().difference(_lastFetchedAt!) < _minRefreshInterval) {
      return true;
    }

    _isRefreshing = true;
    try {
      final results = await Future.wait<dynamic>([
        _client
            .from('app_config')
            .select('key, value, is_active')
            .eq('is_active', true)
            .timeout(_fetchTimeout),
        _client
            .from('feature_flags')
            .select('flag_key, is_enabled')
            .timeout(_fetchTimeout),
      ]);

      final configRows = results[0] as List<dynamic>;
      final flagRows = results[1] as List<dynamic>;

      final nextConfig = <String, String>{};
      for (final row in configRows) {
        if (row is! Map) continue;
        final key = row['key']?.toString().trim();
        final value = row['value']?.toString();
        final isActive = row['is_active'];
        if (key == null || key.isEmpty || value == null) continue;
        if (isActive == false) continue;
        // Belt-and-suspenders client guard: ignore any secret-like keys.
        if (_isSecretKey(key)) continue;
        nextConfig[key] = value;
      }

      final nextFlags = <String, bool>{};
      for (final row in flagRows) {
        if (row is! Map) continue;
        final key = row['flag_key']?.toString().trim();
        final enabled = row['is_enabled'];
        if (key == null || key.isEmpty) continue;
        nextFlags[key] = enabled == true || enabled.toString().toLowerCase() == 'true';
      }

      final changed = !mapEquals(_config, nextConfig) || !mapEquals(_flags, nextFlags);
      _config = nextConfig;
      _flags = nextFlags;
      _lastFetchedAt = DateTime.now();

      await _saveToCache();
      logger.i(
        'RemoteConfigService refreshed (${_config.length} config keys, ${_flags.length} flags)',
      );

      if (changed) {
        notifyListeners();
      }
      return true;
    } catch (e) {
      logger.w('RemoteConfigService refresh skipped (using cache/defaults): $e');
      return false;
    } finally {
      _isRefreshing = false;
    }
  }

  static bool _isSecretKey(String key) {
    final lower = key.toLowerCase();
    return lower == 'openai_api_key' ||
        lower.contains('api_key') ||
        lower.contains('secret') ||
        lower.contains('password') ||
        lower.contains('private_key');
  }

  // ---------------------------------------------------------------------------
  // Typed Parsers
  // ---------------------------------------------------------------------------
  bool _getBool(String key, bool fallback) {
    final raw = _config[key]?.trim().toLowerCase();
    if (raw == null || raw.isEmpty) return fallback;
    if (raw == 'true' || raw == '1' || raw == 'yes') return true;
    if (raw == 'false' || raw == '0' || raw == 'no') return false;
    return fallback;
  }

  int _getInt(String key, int fallback, {int? min, int? max}) {
    final raw = _config[key]?.trim();
    if (raw == null || raw.isEmpty) return fallback;
    final parsed = int.tryParse(raw);
    if (parsed == null) return fallback;
    var clamped = parsed;
    if (min != null && clamped < min) clamped = min;
    if (max != null && clamped > max) clamped = max;
    return clamped;
  }

  String _getString(String key, String fallback) {
    final raw = _config[key]?.trim();
    if (raw == null || raw.isEmpty) return fallback;
    return raw;
  }

  bool isFeatureEnabled(String flagKey, {required bool fallback}) {
    return _flags[flagKey] ?? fallback;
  }

  // ---------------------------------------------------------------------------
  // Auth Settings
  // ---------------------------------------------------------------------------
  bool get enablePhoneAuth => _getBool('enable_phone_auth', AppConfig.enablePhoneAuth);

  /// Guarantees at least one auth method stays enabled so users cannot be
  /// locked out of the login screen if both remote flags are turned off.
  bool get enableEmailAuth {
    final emailEnabled = _getBool('enable_email_auth', AppConfig.enableEmailAuth);
    if (!emailEnabled && !enablePhoneAuth) {
      return true;
    }
    return emailEnabled;
  }

  bool get enableGoogleAuth => _getBool('enable_google_auth', false);

  int get otpLength => _getInt('otp_length', AppConfig.otpLength, min: 4, max: 8);

  int get otpResendDelaySeconds => _getInt(
        'otp_resend_delay_seconds',
        AppConfig.otpResendDelaySeconds,
        min: 15,
        max: 300,
      );

  int get maxOtpAttempts => _getInt(
        'max_otp_attempts',
        AppConfig.maxOtpAttempts,
        min: 3,
        max: 10,
      );

  int get otpLockoutMinutes => _getInt(
        'otp_lockout_minutes',
        AppConfig.otpLockoutMinutes,
        min: 1,
        max: 60,
      );

  // ---------------------------------------------------------------------------
  // App Info & Force Update
  // ---------------------------------------------------------------------------
  String get appName => _getString('app_name', AppConfig.appName);
  String get remoteAppVersion => _getString('app_version', AppConfig.appVersion);
  String get minSupportedVersion => _getString('min_supported_version', '1.0.0');
  bool get forceUpdateRequired => _getBool('force_update_required', false);
  String get forceUpdateMessage => _getString(
        'force_update_message',
        'A new version is available. Please update to continue using the app.',
      );
  String get playStoreUrl => _getString(
        'play_store_url',
        'https://play.google.com/store/apps/details?id=com.confidentcam.confident_cam',
      );
  String get appStoreUrl => _config['app_store_url']?.trim() ?? '';

  /// Returns true if [currentVersion] must update before continuing:
  /// - Always true when [currentVersion] < [minSupportedVersion].
  /// - Also true when [forceUpdateRequired] is enabled and [currentVersion] < [remoteAppVersion].
  bool needsForceUpdate(String currentVersion) {
    if (compareVersions(currentVersion, minSupportedVersion) < 0) {
      return true;
    }
    if (forceUpdateRequired &&
        compareVersions(currentVersion, remoteAppVersion) < 0) {
      return true;
    }
    return false;
  }

  /// Compares semantic versions (`1.2.2` vs `1.2.3`). Strips build metadata (`+41`).
  static int compareVersions(String a, String b) {
    List<int> parse(String v) {
      final clean = v.split('+').first.split('-').first.trim();
      return clean
          .split('.')
          .map((part) => int.tryParse(part.trim()) ?? 0)
          .toList();
    }

    final pa = parse(a);
    final pb = parse(b);
    final len = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < len; i++) {
      final va = i < pa.length ? pa[i] : 0;
      final vb = i < pb.length ? pb[i] : 0;
      if (va != vb) return va.compareTo(vb);
    }
    return 0;
  }

  // ---------------------------------------------------------------------------
  // Challenge, Developer, Video & Network Settings
  // ---------------------------------------------------------------------------
  bool get devMode => _getBool('dev_mode', AppConfig.devMode);
  bool get isPremiumUser => _getBool('is_premium_user', AppConfig.isPremiumUser);

  int get totalDays => _getInt('total_days', AppConfig.totalDays, min: 1, max: 90);
  int get totalWarmups => _getInt('total_warmups', AppConfig.totalWarmups, min: 1, max: 5);
  int get segmentedDaysEnd =>
      _getInt('segmented_days_end', AppConfig.segmentedDaysEnd, min: 1, max: 30);
  int get extensionDaysCount =>
      _getInt('extension_days_count', AppConfig.extensionDaysCount, min: 1, max: 60);
  int get maxExtensions =>
      _getInt('max_extensions', AppConfig.maxExtensions, min: 0, max: 12);

  int get maxRecordingDurationSeconds => _getInt(
        'max_recording_duration_seconds',
        AppConfig.maxRecordingDurationSeconds,
        min: 30,
        max: 600,
      );
  int get minRecordingDurationSeconds => _getInt(
        'min_recording_duration_seconds',
        AppConfig.minRecordingDurationSeconds,
        min: 1,
        max: 30,
      );
  int get warmupMaxDurationSeconds => _getInt(
        'warmup_max_duration_seconds',
        AppConfig.warmupMaxDurationSeconds,
        min: 10,
        max: 120,
      );

  Duration get apiTimeout => Duration(
        seconds: _getInt(
          'api_timeout_seconds',
          AppConfig.apiTimeout.inSeconds,
          min: 5,
          max: 120,
        ),
      );
  Duration get uploadTimeout => Duration(
        minutes: _getInt(
          'upload_timeout_minutes',
          AppConfig.uploadTimeout.inMinutes,
          min: 1,
          max: 30,
        ),
      );
  Duration get scriptsRefreshInterval => Duration(
        hours: _getInt(
          'scripts_refresh_interval_hours',
          AppConfig.scriptsRefreshInterval.inHours,
          min: 1,
          max: 168,
        ),
      );
  Duration get progressSyncInterval => Duration(
        minutes: _getInt(
          'progress_sync_interval_minutes',
          AppConfig.progressSyncInterval.inMinutes,
          min: 1,
          max: 120,
        ),
      );

  // ---------------------------------------------------------------------------
  // Feature Flags (`public.feature_flags`)
  // ---------------------------------------------------------------------------
  bool get maintenanceMode => isFeatureEnabled('maintenance_mode', fallback: false);
  bool get qrLoginEnabled => isFeatureEnabled('qr_login_enabled', fallback: true);
  bool get contentCreatorEnabled =>
      isFeatureEnabled('content_creator_enabled', fallback: true);
  bool get extensionsEnabled =>
      isFeatureEnabled('extensions_enabled', fallback: true);
  bool get aiFeedbackEnabled =>
      isFeatureEnabled('ai_feedback_enabled', fallback: false);
}

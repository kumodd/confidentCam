/// Application configuration for ConfidentCam
///
/// Contains environment-specific settings like Supabase credentials.
/// For production, use environment variables or secure key storage.
///
/// ─────────────────────────────────────────────────────────────────
/// SECRET KEYS — HOW TO RUN LOCALLY OR BUILD
/// ─────────────────────────────────────────────────────────────────
/// Never commit real keys to source control.
/// Pass secrets at build/run time via --dart-define:
///
///   flutter run \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=sb_publishable_... \
///     --dart-define=OPENAI_API_KEY=sk-proj-...
///
/// For CI/CD (Play Store/App Store builds), inject via the same
/// --dart-define mechanism.
/// ─────────────────────────────────────────────────────────────────
class AppConfig {
  // ---------------------------------------------------------------------------
  // Supabase Configuration (read from compile-time env vars)
  // ---------------------------------------------------------------------------
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  // App Settings
  static const String appName = 'Confident Creator';
  static const String appVersion = '1.0.1';

  // Developer Settings
  /// When true, bypasses day unlock restrictions (all days accessible)
  /// Set to false for production
  static const bool devMode = true;

  /// Premium users can access next challenge without waiting
  static const bool isPremiumUser = false;

  // Video Recording Settings
  static const int maxRecordingDurationSeconds = 180; // 3 minutes
  static const int minRecordingDurationSeconds = 5;
  static const int warmupMaxDurationSeconds = 30;

  // OTP Settings
  static const int otpLength = 6;
  static const int otpResendDelaySeconds = 60;
  static const int maxOtpAttempts = 5;
  static const int otpLockoutMinutes = 15;

  // Auth Methods (enable/disable)
  static const bool enablePhoneAuth = true;
  static const bool enableEmailAuth = true;

  // Challenge Settings
  static const int totalDays = 3;
  static const int totalWarmups = 1;
  static const int segmentedDaysEnd = 5; // Days 1-5 are segmented

  // Cache Settings
  static const Duration scriptsRefreshInterval = Duration(hours: 24);
  static const Duration progressSyncInterval = Duration(minutes: 5);

  // API Timeouts
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration uploadTimeout = Duration(minutes: 5);

  // ---------------------------------------------------------------------------
  // OpenAI Configuration (read from compile-time env vars)
  // ---------------------------------------------------------------------------
  static const String openAiApiKey = String.fromEnvironment(
    'OPENAI_API_KEY',
    defaultValue: '',
  );
  static const String openAiModel = 'gpt-4o-mini'; // Cost-effective model
  static const String openAiBaseUrl = 'https://api.openai.com/v1';
  static const int maxScriptTokens = 16300;

  // Extension Settings
  static const int extensionDaysCount = 15; // Days per extension
  static const int maxExtensions = 4; // Maximum 4 extensions (60 more days)
}

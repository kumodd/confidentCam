/// Application configuration for ConfidentCam.
///
/// ─────────────────────────────────────────────────────────────────
/// SECRET KEYS — HOW TO RUN LOCALLY
/// ─────────────────────────────────────────────────────────────────
/// Never commit real keys to source control.
/// Pass secrets at build/run time via --dart-define:
///
///   flutter run \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=sb_publishable_... \
///     --dart-define=OPENAI_API_KEY=sk-proj-...
///
/// For CI/CD, store them as encrypted secrets (GitHub Actions, Codemagic, etc.)
/// and inject via the same --dart-define mechanism.
/// ─────────────────────────────────────────────────────────────────
class AppConfig {
  // ---------------------------------------------------------------------------
  // Supabase Configuration (read from compile-time env vars)
  // ---------------------------------------------------------------------------
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '', // Empty string → app will fail fast with a clear error
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  // ---------------------------------------------------------------------------
  // OpenAI Configuration (read from compile-time env vars)
  // ---------------------------------------------------------------------------
  static const String openAiApiKey = String.fromEnvironment(
    'OPENAI_API_KEY',
    defaultValue: '',
  );
  static const String openAiModel = 'gpt-4o-mini';
  static const String openAiBaseUrl = 'https://api.openai.com/v1';
  static const int maxScriptTokens = 16300;

  // ---------------------------------------------------------------------------
  // App Settings
  // ---------------------------------------------------------------------------
  static const String appName = 'Confident Creator';
  static const String appVersion = '1.0.1';

  // ---------------------------------------------------------------------------
  // Developer Settings
  // ---------------------------------------------------------------------------
  /// When true, bypasses day unlock restrictions (all days accessible).
  /// MUST be false in every production / TestFlight / Play Store build.
  /// CI should assert: `dart define devMode=false` for release flavors.
  static const bool devMode = false; // ← FIXED: was true

  /// Premium users can access next challenge without waiting.
  static const bool isPremiumUser = false;

  // ---------------------------------------------------------------------------
  // Video Recording
  // ---------------------------------------------------------------------------
  static const int maxRecordingDurationSeconds = 180; // 3 minutes
  static const int minRecordingDurationSeconds = 5;
  static const int warmupMaxDurationSeconds = 30;

  // ---------------------------------------------------------------------------
  // OTP Settings
  // ---------------------------------------------------------------------------
  static const int otpLength = 6;
  static const int otpResendDelaySeconds = 60;
  static const int maxOtpAttempts = 5;
  static const int otpLockoutMinutes = 15;

  // ---------------------------------------------------------------------------
  // Auth Methods
  // ---------------------------------------------------------------------------
  static const bool enablePhoneAuth = true;
  static const bool enableEmailAuth = true;

  // ---------------------------------------------------------------------------
  // Challenge Settings
  // ---------------------------------------------------------------------------
  static const int totalDays = 3;
  static const int totalWarmups = 1;
  static const int segmentedDaysEnd = 5;

  // ---------------------------------------------------------------------------
  // Cache / Sync
  // ---------------------------------------------------------------------------
  static const Duration scriptsRefreshInterval = Duration(hours: 24);
  static const Duration progressSyncInterval = Duration(minutes: 5);

  // ---------------------------------------------------------------------------
  // API Timeouts
  // ---------------------------------------------------------------------------
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration uploadTimeout = Duration(minutes: 5);

  // ---------------------------------------------------------------------------
  // Extension Settings
  // ---------------------------------------------------------------------------
  static const int extensionDaysCount = 15;
  static const int maxExtensions = 4;
}

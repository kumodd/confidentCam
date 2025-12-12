/// Application configuration for ConfidentCam
///
/// Contains environment-specific settings like Supabase credentials.
/// For production, use environment variables or secure key storage.
class AppConfig {
  // Supabase Configuration
  // TODO: Replace with your Supabase project credentials
  static const String supabaseUrl = 'https://govbpayonsbfwrfxzbgq.supabase.co';
  static const String supabaseAnonKey =
      'sb_publishable_Bg4FZF-KFlpRfX4Oqt9V4A_oWtvysow';

  // App Settings
  static const String appName = 'ConfidentCam';
  static const String appVersion = '1.0.0';

  // Video Recording Settings
  static const int maxRecordingDurationSeconds = 180; // 3 minutes
  static const int minRecordingDurationSeconds = 5;
  static const int warmupMaxDurationSeconds = 30;

  // OTP Settings
  static const int otpLength = 6;
  static const int otpResendDelaySeconds = 60;
  static const int maxOtpAttempts = 5;
  static const int otpLockoutMinutes = 15;

  // Challenge Settings
  static const int totalDays = 30;
  static const int totalWarmups = 3;
  static const int segmentedDaysEnd = 5; // Days 1-5 are segmented

  // Cache Settings
  static const Duration scriptsRefreshInterval = Duration(hours: 24);
  static const Duration progressSyncInterval = Duration(minutes: 5);

  // API Timeouts
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration uploadTimeout = Duration(minutes: 5);

  // OpenAI Configuration
  // TODO: Replace with your OpenAI API key
  static const String openAiApiKey = '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';
  static const String openAiModel = 'gpt-4o-mini'; // Cost-effective model
  static const String openAiBaseUrl = 'https://api.openai.com/v1';
  static const int maxScriptTokens = 40000;

  // Extension Settings
  static const int extensionDaysCount = 15; // Days per extension
  static const int maxExtensions = 4; // Maximum 4 extensions (60 more days)
}

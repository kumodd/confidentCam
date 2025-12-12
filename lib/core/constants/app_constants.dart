/// Application-wide constants for ConfidentCam
class AppConstants {
  // Hive Box Names
  static const String authBox = 'auth_box';
  static const String progressBox = 'progress_box';
  static const String scriptsBox = 'scripts_box';
  static const String settingsBox = 'settings_box';
  static const String offlineQueueBox = 'offline_queue_box';

  // Hive Keys
  static const String sessionTokenKey = 'session_token';
  static const String userIdKey = 'user_id';
  static const String phoneKey = 'phone';
  static const String displayNameKey = 'display_name';

  // Progress Keys
  static const String warmup0Key = 'warmup_0_complete';
  static const String warmup1Key = 'warmup_1_complete';
  static const String warmup2Key = 'warmup_2_complete';
  static const String currentDayKey = 'current_day';
  static const String streakKey = 'streak';
  static const String longestStreakKey = 'longest_streak';
  static const String lastCompletedDateKey = 'last_completed_date';

  // Settings Keys
  static const String reminderTimeKey = 'reminder_time';
  static const String teleprompterSpeedKey = 'teleprompter_speed';
  static const String teleprompterFontSizeKey = 'teleprompter_font_size';
  static const String teleprompterTextColorKey = 'teleprompter_text_color';
  static const String teleprompterHeightKey = 'teleprompter_height';
  static const String teleprompterOpacityKey = 'teleprompter_opacity';
  static const String defaultCameraKey = 'default_camera';
  static const String videoQualityKey = 'video_quality';

  // Video Storage Paths
  static const String warmupsFolderName = 'warmups';
  static const String dailyFolderName = 'daily';
  static const String exportsFolderName = 'exports';

  // Teleprompter Defaults
  static const double defaultScrollSpeed = 1.0;
  static const String defaultFontSize = 'medium';
  static const String defaultTextColor = 'white';
  static const double defaultTeleprompterHeight = 0.25; // 25% of screen
  static const double defaultTeleprompterOpacity = 0.85;

  // Font Size Mapping (points)
  static const Map<String, double> fontSizeMap = {
    'small': 14.0,
    'medium': 16.0,
    'large': 18.0,
    'extra_large': 22.0,
  };

  // Speed Options
  static const List<double> speedOptions = [
    0.5,
    0.75,
    1.0,
    1.25,
    1.5,
    2.0,
    2.5,
    3.0,
  ];

  // Height Options (as percentage of screen)
  static const List<double> heightOptions = [
    0.15,
    0.20,
    0.25,
    0.30,
    0.35,
    0.40,
  ];

  // Opacity Options
  static const List<double> opacityOptions = [0.6, 0.7, 0.8, 0.85, 0.9, 0.95];

  // Supabase Tables
  static const String usersTable = 'users';
  static const String userProfilesTable = 'user_profiles';
  static const String userProgressTable = 'user_progress';
  static const String dailyScriptsTable = 'daily_scripts';
  static const String dailyCompletionsTable = 'daily_completions';
  static const String aiFeedbackTable = 'ai_feedback';
  static const String achievementsTable = 'achievements';
  static const String premiumStatusTable = 'premium_status';
  static const String notificationSettingsTable = 'notification_settings';

  // Achievement Keys
  static const String achievementFirstStep = 'first_step';
  static const String achievementWarmedUp = 'warmed_up';
  static const String achievementDayOneDone = 'day_one_done';
  static const String achievementFirstWeek = 'first_week';
  static const String achievementHalfway = 'halfway';
  static const String achievementAlmostThere = 'almost_there';
  static const String achievementChampion = 'champion';
  static const String achievementPerfectWeek = 'perfect_week';
  static const String achievementUnstoppable = 'unstoppable';
  static const String achievementLegend = 'legend';
  static const String achievementNightOwl = 'night_owl';
  static const String achievementEarlyBird = 'early_bird';
  static const String achievementRetakeMaster = 'retake_master';

  // Checklist Keys
  static const String checklistEyeContact = 'eye_contact';
  static const String checklistClearVoice = 'clear_voice';
  static const String checklistNaturalExpression = 'natural_expression';
  static const String checklistComfortablePacing = 'comfortable_pacing';
  static const String checklistPresentFocused = 'present_focused';
  static const String checklistFullScript = 'full_script';
  static const String checklistSatisfied = 'satisfied';
}

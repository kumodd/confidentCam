import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../constants/app_constants.dart';
import '../network/network_info.dart';
import '../../data/datasources/local/hive_auth_datasource.dart';
import '../../data/datasources/local/hive_content_scripts_datasource.dart';
import '../../data/datasources/local/hive_progress_datasource.dart';
import '../../data/datasources/local/hive_scripts_datasource.dart';
import '../../data/datasources/local/hive_settings_datasource.dart';
import '../../data/datasources/remote/supabase_auth_datasource.dart';
import '../../data/datasources/remote/supabase_content_scripts_datasource.dart';
import '../../data/datasources/remote/supabase_language_datasource.dart';
import '../../data/datasources/remote/supabase_onboarding_datasource.dart';
import '../../data/datasources/remote/supabase_progress_datasource.dart';
import '../../data/datasources/remote/supabase_script_datasource.dart';
import '../../data/datasources/remote/supabase_user_datasource.dart';
import '../../services/openai_service.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/repositories/content_creator_repository_impl.dart';
import '../../data/repositories/progress_repository_impl.dart';
import '../../data/repositories/script_repository_impl.dart';
import '../../data/repositories/user_repository_impl.dart';
import '../../data/repositories/video_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/content_creator_repository.dart';
import '../../domain/repositories/progress_repository.dart';
import '../../domain/repositories/script_repository.dart';
import '../../domain/repositories/user_repository.dart';
import '../../domain/repositories/video_repository.dart';
import '../../presentation/bloc/auth/auth_bloc.dart';
import '../../presentation/bloc/content_creator/content_creator_bloc.dart';
import '../../presentation/bloc/daily_challenge/daily_challenge_bloc.dart';
import '../../presentation/bloc/network/network_bloc.dart';
import '../../presentation/bloc/onboarding/onboarding_bloc.dart';
import '../../presentation/bloc/progress/progress_bloc.dart';
import '../../presentation/bloc/settings/settings_bloc.dart';
import '../../presentation/bloc/warmup/warmup_bloc.dart';
import '../../services/video_recording_service.dart';
import '../../services/video_storage_service.dart';
import '../../services/notification_service.dart';

final sl = GetIt.instance;

/// Initialize all dependencies for the application.
///
/// Call this in main() before runApp().
Future<void> initDependencies() async {
  // External
  await _initExternal();

  // Core
  _initCore();

  // Data Sources
  _initDataSources();

  // Repositories
  _initRepositories();

  // Services
  _initServices();

  // BLoCs
  _initBlocs();
}

Future<void> _initExternal() async {
  // Initialize Supabase
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );
  sl.registerLazySingleton<SupabaseClient>(() => Supabase.instance.client);

  // Initialize Hive
  await Hive.initFlutter();

  // Open Hive boxes
  final authBox = await Hive.openBox(AppConstants.authBox);
  final progressBox = await Hive.openBox(AppConstants.progressBox);
  final scriptsBox = await Hive.openBox(AppConstants.scriptsBox);
  final settingsBox = await Hive.openBox(AppConstants.settingsBox);
  final offlineQueueBox = await Hive.openBox(AppConstants.offlineQueueBox);

  sl.registerLazySingleton<Box>(
    () => authBox,
    instanceName: AppConstants.authBox,
  );
  sl.registerLazySingleton<Box>(
    () => progressBox,
    instanceName: AppConstants.progressBox,
  );
  sl.registerLazySingleton<Box>(
    () => scriptsBox,
    instanceName: AppConstants.scriptsBox,
  );
  sl.registerLazySingleton<Box>(
    () => settingsBox,
    instanceName: AppConstants.settingsBox,
  );
  sl.registerLazySingleton<Box>(
    () => offlineQueueBox,
    instanceName: AppConstants.offlineQueueBox,
  );

  // Content Scripts Box (standalone for Content Creator)
  final contentScriptsBox = await Hive.openBox(AppConstants.contentScriptsBox);
  sl.registerLazySingleton<Box>(
    () => contentScriptsBox,
    instanceName: AppConstants.contentScriptsBox,
  );

  // Internet connection checker
  sl.registerLazySingleton(() => InternetConnectionChecker());
}

void _initCore() {
  // Network Info
  sl.registerLazySingleton<NetworkInfo>(
    () => NetworkInfoImpl(connectionChecker: sl()),
  );
}

void _initDataSources() {
  // Remote Data Sources
  sl.registerLazySingleton<SupabaseAuthDataSource>(
    () => SupabaseAuthDataSourceImpl(client: sl()),
  );
  sl.registerLazySingleton<SupabaseUserDataSource>(
    () => SupabaseUserDataSourceImpl(client: sl()),
  );
  sl.registerLazySingleton<SupabaseProgressDataSource>(
    () => SupabaseProgressDataSourceImpl(client: sl()),
  );
  sl.registerLazySingleton<SupabaseScriptDataSource>(
    () => SupabaseScriptDataSourceImpl(client: sl()),
  );
  sl.registerLazySingleton<SupabaseOnboardingDataSource>(
    () => SupabaseOnboardingDataSourceImpl(client: sl()),
  );
  sl.registerLazySingleton<SupabaseLanguageDataSource>(
    () => SupabaseLanguageDataSource(client: sl()),
  );
  sl.registerLazySingleton<SupabaseContentScriptsDataSource>(
    () => SupabaseContentScriptsDataSource(client: sl()),
  );

  // Local Data Sources
  sl.registerLazySingleton<HiveAuthDataSource>(
    () =>
        HiveAuthDataSourceImpl(authBox: sl(instanceName: AppConstants.authBox)),
  );
  sl.registerLazySingleton<HiveProgressDataSource>(
    () => HiveProgressDataSourceImpl(
      progressBox: sl(instanceName: AppConstants.progressBox),
    ),
  );
  sl.registerLazySingleton<HiveScriptsDataSource>(
    () => HiveScriptsDataSourceImpl(
      scriptsBox: sl(instanceName: AppConstants.scriptsBox),
    ),
  );
  sl.registerLazySingleton<HiveSettingsDataSource>(
    () => HiveSettingsDataSourceImpl(
      settingsBox: sl(instanceName: AppConstants.settingsBox),
    ),
  );

  // Content Creator Local Data Source (standalone)
  sl.registerLazySingleton<HiveContentScriptsDataSource>(
    () => HiveContentScriptsDataSourceImpl(
      contentScriptsBox: sl(instanceName: AppConstants.contentScriptsBox),
    ),
  );
}

void _initRepositories() {
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
      networkInfo: sl(),
    ),
  );
  sl.registerLazySingleton<UserRepository>(
    () => UserRepositoryImpl(remoteDataSource: sl(), networkInfo: sl()),
  );
  sl.registerLazySingleton<ProgressRepository>(
    () => ProgressRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
      networkInfo: sl(),
    ),
  );
  sl.registerLazySingleton<ScriptRepository>(
    () => ScriptRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
      networkInfo: sl(),
    ),
  );
  sl.registerLazySingleton<VideoRepository>(
    () => VideoRepositoryImpl(videoStorageService: sl()),
  );

  // Content Creator Repository (standalone - uses Supabase for storage and OpenAI for generation)
  sl.registerLazySingleton<ContentCreatorRepository>(
    () => ContentCreatorRepositoryImpl(remoteDataSource: sl()),
  );
}

void _initServices() {
  sl.registerLazySingleton<VideoStorageService>(
    () => VideoStorageServiceImpl(),
  );
  sl.registerLazySingleton<VideoRecordingService>(
    () => VideoRecordingServiceImpl(),
  );
  sl.registerLazySingleton<OpenAiService>(() => OpenAiService());
  sl.registerLazySingleton<NotificationService>(() => NotificationService());
}

void _initBlocs() {
  // Network BLoC (singleton - monitors connectivity app-wide)
  sl.registerLazySingleton<NetworkBloc>(() => NetworkBloc(networkInfo: sl()));

  // Auth BLoC (singleton - shared app-wide for consistent auth state)
  sl.registerLazySingleton<AuthBloc>(() => AuthBloc(authRepository: sl()));

  // Onboarding BLoC
  sl.registerFactory<OnboardingBloc>(
    () => OnboardingBloc(
      onboardingDataSource: sl(),
      languageDataSource: sl(),
      scriptRepository: sl(),
      openAiService: sl(),
    ),
  );

  // Warmup BLoC
  sl.registerFactory<WarmupBloc>(
    () => WarmupBloc(progressRepository: sl(), videoRepository: sl()),
  );

  // Daily Challenge BLoC
  sl.registerFactory<DailyChallengeBloc>(
    () => DailyChallengeBloc(
      scriptRepository: sl(),
      progressRepository: sl(),
      videoRepository: sl(),
      openAiService: sl(),
      onboardingDataSource: sl(),
    ),
  );

  // Progress BLoC (singleton - shared across dashboard tabs)
  sl.registerLazySingleton<ProgressBloc>(
    () => ProgressBloc(
      progressRepository: sl(),
      scriptRepository: sl(),
    ),
  );

  // Settings BLoC (singleton - settings shared app-wide)
  sl.registerLazySingleton<SettingsBloc>(
    () => SettingsBloc(settingsDataSource: sl()),
  );

  // Content Creator BLoC (standalone)
  sl.registerFactory<ContentCreatorBloc>(
    () => ContentCreatorBloc(repository: sl(), videoStorageService: sl()),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

import 'core/di/injection_container.dart';
import 'services/notification_service.dart';
import 'data/datasources/local/hive_settings_datasource.dart';
import 'core/constants/app_constants.dart';
import 'presentation/bloc/auth/auth_bloc.dart';
import 'presentation/bloc/auth/auth_event.dart';
import 'presentation/bloc/daily_challenge/daily_challenge_bloc.dart';
import 'presentation/bloc/network/network_bloc.dart';
import 'presentation/bloc/progress/progress_bloc.dart';
import 'presentation/bloc/settings/settings_bloc.dart';
import 'presentation/bloc/warmup/warmup_bloc.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize dependencies
  await initDependencies();

  // Initialize and configure notifications
  await _initializeNotifications();

  // Configure EasyLoading
  _configureEasyLoading();

  runApp(const ConfidentCamApp());
}

/// Initialize notification service and schedule saved reminder.
Future<void> _initializeNotifications() async {
  try {
    final notificationService = sl<NotificationService>();
    await notificationService.initialize();
    await notificationService.requestPermissions();
    
    // Schedule reminder from saved settings
    final settingsDataSource = sl<HiveSettingsDataSource>();
    final settings = await settingsDataSource.getSettings();
    final timeStr = settings[AppConstants.reminderTimeKey] as String? ?? '09:00';
    final parts = timeStr.split(':');
    final hour = int.tryParse(parts[0]) ?? 9;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    
    await notificationService.scheduleDailyReminder(
      TimeOfDay(hour: hour, minute: minute),
    );
  } catch (e) {
    // Notification initialization failed, but app should continue
  }
}

void _configureEasyLoading() {
  EasyLoading.instance
    ..displayDuration = const Duration(milliseconds: 2000)
    ..indicatorType = EasyLoadingIndicatorType.fadingCircle
    ..loadingStyle = EasyLoadingStyle.dark
    ..indicatorSize = 45.0
    ..radius = 10.0
    ..progressColor = Colors.white
    ..backgroundColor = Colors.black87
    ..indicatorColor = Colors.white
    ..textColor = Colors.white
    ..maskType = EasyLoadingMaskType.black
    ..userInteractions = false
    ..dismissOnTap = false;
}

class ConfidentCamApp extends StatelessWidget {
  const ConfidentCamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // Core BLoCs available app-wide
        BlocProvider<NetworkBloc>(create: (_) => sl<NetworkBloc>()),
        BlocProvider<AuthBloc>(
          create: (_) => sl<AuthBloc>()..add(const SessionCheckRequested()),
        ),
        // Feature BLoCs - lazy created but available everywhere
        BlocProvider<WarmupBloc>(create: (_) => sl<WarmupBloc>()),
        BlocProvider<ProgressBloc>(create: (_) => sl<ProgressBloc>()),
        BlocProvider<SettingsBloc>(create: (_) => sl<SettingsBloc>()),
      ],
      child: const App(),
    );
  }
}

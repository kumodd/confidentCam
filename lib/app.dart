import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

import 'core/constants/app_constants.dart';
import 'core/di/injection_container.dart';
import 'core/theme/app_theme.dart';
import 'data/datasources/local/hive_settings_datasource.dart';
import 'presentation/bloc/auth/auth_bloc.dart';
import 'presentation/bloc/auth/auth_state.dart';
import 'presentation/bloc/network/network_bloc.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/onboarding/app_intro_onboarding_screen.dart';
import 'presentation/screens/splash/splash_screen.dart';
import 'presentation/screens/progress/dashboard_screen.dart';
import 'presentation/widgets/common/network_status_banner.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncPlatformBrightness();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    setState(_syncPlatformBrightness);
  }

  void _syncPlatformBrightness() {
    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final isDark = brightness == Brightness.dark;
    AppColors.setDark(isDark);
    SystemChrome.setSystemUIOverlayStyle(AppTheme.systemOverlayStyle);
    EasyLoading.instance
      ..progressColor = AppColors.primaryOlive
      ..backgroundColor = AppColors.cardSurface
      ..indicatorColor = AppColors.primaryOlive
      ..textColor = AppColors.primaryText;
  }

  @override
  Widget build(BuildContext context) {
    final platformBrightness = MediaQuery.platformBrightnessOf(context);
    final isDark = platformBrightness == Brightness.dark;
    if (AppColors.isDark != isDark) {
      AppColors.setDark(isDark);
      SystemChrome.setSystemUIOverlayStyle(AppTheme.systemOverlayStyle);
    }
    final easyLoadingInit = EasyLoading.init();
    return MaterialApp(
      title: 'ConfidentCam',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      builder: (context, child) {
        return easyLoadingInit(context, child);
      },
      home: _AuthWrapper(key: ValueKey('auth_wrapper_$isDark')),
    );
  }
}

/// Wrapper widget to handle first-time 5-screen onboarding tour, auth state, and network status.
class _AuthWrapper extends StatefulWidget {
  const _AuthWrapper({super.key});

  @override
  State<_AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<_AuthWrapper> {
  bool _checkingIntro = true;
  bool _hasSeenIntro = false;

  @override
  void initState() {
    super.initState();
    _checkIntroStatus();
  }

  Future<void> _checkIntroStatus() async {
    try {
      final settingsDataSource = sl<HiveSettingsDataSource>();
      final seen = settingsDataSource.getSetting<bool>(
            AppConstants.hasSeenIntroOnboardingKey,
          ) ??
          false;
      if (mounted) {
        setState(() {
          _hasSeenIntro = seen;
          _checkingIntro = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _hasSeenIntro = true;
          _checkingIntro = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        BlocBuilder<AuthBloc, AuthState>(
          buildWhen: (previous, current) {
            return current is AuthInitial ||
                current is AuthSuccess ||
                current is AuthLoggedOut;
          },
          builder: (context, state) {
            if (_checkingIntro || state is AuthInitial) {
              return const SplashScreen();
            }

            if (!_hasSeenIntro) {
              return AppIntroOnboardingScreen(
                onFinished: () {
                  setState(() => _hasSeenIntro = true);
                },
              );
            }

            if (state is AuthSuccess) {
              return DashboardScreen(
                key: ValueKey('${state.user.id}_${AppColors.isDark}'),
                user: state.user,
                isNewUser: state.isNewUser,
              );
            }

            return const LoginScreen();
          },
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: BlocBuilder<NetworkBloc, NetworkState>(
            builder: (context, state) {
              if (state is NetworkDisconnected) {
                return const SafeArea(
                  bottom: false,
                  child: NetworkStatusBanner(),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ],
    );
  }
}

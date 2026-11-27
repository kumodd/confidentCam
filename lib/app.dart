import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:url_launcher/url_launcher.dart';

import 'core/config/app_config.dart';
import 'core/config/remote_config_service.dart';
import 'core/constants/app_constants.dart';
import 'core/di/injection_container.dart';
import 'core/theme/app_theme.dart';
import 'data/datasources/local/hive_settings_datasource.dart';
import 'presentation/bloc/auth/auth_bloc.dart';
import 'presentation/bloc/auth/auth_state.dart';
import 'presentation/bloc/network/network_bloc.dart';
import 'presentation/bloc/progress/progress_bloc.dart';
import 'presentation/bloc/settings/settings_bloc.dart';
import 'presentation/bloc/warmup/warmup_bloc.dart';
import 'presentation/bloc/warmup/warmup_event.dart';
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed &&
        sl.isRegistered<RemoteConfigService>()) {
      sl<RemoteConfigService>().refresh();
    }
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
    final remoteConfig =
        sl.isRegistered<RemoteConfigService>()
            ? sl<RemoteConfigService>()
            : null;

    Widget buildMainContent() {
      if (remoteConfig != null) {
        if (remoteConfig.maintenanceMode) {
          return _MaintenanceScreen(
            onRetry: () => remoteConfig.refresh(force: true),
          );
        }
        if (remoteConfig.needsForceUpdate(AppConfig.appVersion)) {
          final storeUrl =
              Platform.isIOS && remoteConfig.appStoreUrl.isNotEmpty
                  ? remoteConfig.appStoreUrl
                  : remoteConfig.playStoreUrl;
          return _ForceUpdateScreen(
            message: remoteConfig.forceUpdateMessage,
            storeUrl: storeUrl,
          );
        }
      }

      return BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthLoggedOut) {
            // Reset all app-wide user-scoped BLoCs so stale data never bleeds
            // into the next user session on the same device.
            context.read<ProgressBloc>().add(const ProgressReset());
            context.read<SettingsBloc>().add(const SettingsReset());
            context.read<WarmupBloc>().add(const WarmupReset());
          }
        },
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
      );
    }

    return Stack(
      children: [
        if (remoteConfig != null)
          ListenableBuilder(
            listenable: remoteConfig,
            builder: (_, __) => buildMainContent(),
          )
        else
          buildMainContent(),
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

class _MaintenanceScreen extends StatelessWidget {
  final Future<bool> Function() onRetry;

  const _MaintenanceScreen({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SageCard(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.olivePillFill,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.olivePillBorder),
                    ),
                    child: Icon(
                      Icons.construction_rounded,
                      color: AppColors.primaryOlive,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Under Maintenance',
                    style: AppTypography.headingLarge(fontSize: 22),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'We are making improvements to ConfidentCam. Please check back in a few minutes.',
                    style: AppTypography.body(),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        onRetry();
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 19),
                      label: const Text('Check Again'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ForceUpdateScreen extends StatelessWidget {
  final String message;
  final String storeUrl;

  const _ForceUpdateScreen({
    required this.message,
    required this.storeUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SageCard(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.olivePillFill,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.olivePillBorder),
                    ),
                    child: Icon(
                      Icons.system_update_rounded,
                      color: AppColors.primaryOlive,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Update Required',
                    style: AppTypography.headingLarge(fontSize: 22),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    style: AppTypography.body(),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        if (storeUrl.isEmpty) return;
                        final uri = Uri.tryParse(storeUrl);
                        if (uri != null && await canLaunchUrl(uri)) {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                      icon: const Icon(Icons.open_in_new_rounded, size: 19),
                      label: const Text('Update Now'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

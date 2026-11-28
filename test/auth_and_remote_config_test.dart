import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:confident_cam/core/config/app_config.dart';
import 'package:confident_cam/core/config/remote_config_service.dart';
import 'package:confident_cam/core/constants/app_constants.dart';
import 'package:confident_cam/core/error/failures.dart' as failures;
import 'package:confident_cam/core/network/network_info.dart';
import 'package:confident_cam/data/datasources/local/hive_auth_datasource.dart';
import 'package:confident_cam/data/datasources/remote/supabase_auth_datasource.dart';
import 'package:confident_cam/data/repositories/auth_repository_impl.dart';
import 'package:confident_cam/domain/entities/user.dart';
import 'package:confident_cam/domain/repositories/auth_repository.dart';
import 'package:confident_cam/presentation/bloc/auth/auth_bloc.dart';
import 'package:confident_cam/presentation/bloc/auth/auth_event.dart';
import 'package:confident_cam/presentation/bloc/auth/auth_state.dart';
import 'package:confident_cam/presentation/screens/auth/otp_verification_screen.dart';

class _FakeNetworkInfo implements NetworkInfo {
  bool connected;
  _FakeNetworkInfo({required this.connected});

  @override
  Future<bool> get isConnected async => connected;

  @override
  Stream<bool> get onConnectivityChanged => Stream.value(connected);

  @override
  void dispose() {}
}

class _FakeRemoteAuthDataSource implements SupabaseAuthDataSource {
  Map<String, dynamic>? currentUserResponse;
  String? liveUserId;

  @override
  String? get currentUserId => liveUserId;

  @override
  Future<Map<String, dynamic>?> getCurrentUser() async => currentUserResponse;

  @override
  Future<void> deleteAccount() async {}

  @override
  Future<void> logout() async {
    liveUserId = null;
    currentUserResponse = null;
  }

  @override
  Future<void> sendEmailOtp(String email) async {}

  @override
  Future<void> sendOtp(String phone) async {}

  @override
  Future<(Map<String, dynamic>, bool)> signInWithEmail(
    String email,
    String password,
  ) =>
      throw UnimplementedError();

  @override
  Future<(Map<String, dynamic>, bool)> signUpWithEmail(
    String email,
    String password, {
    String? phone,
  }) =>
      throw UnimplementedError();

  @override
  Future<(Map<String, dynamic>, bool)> verifyEmailOtp(
    String email,
    String otp,
  ) =>
      throw UnimplementedError();

  @override
  Future<(Map<String, dynamic>, bool)> verifyOtp(String phone, String otp) =>
      throw UnimplementedError();
}

class _InMemoryHiveAuthDataSource implements HiveAuthDataSource {
  Map<String, dynamic>? session;
  bool clearedSession = false;
  final Map<String, int> attempts = {};
  final Map<String, DateTime> lockouts = {};

  @override
  Future<void> saveSession({
    required String userId,
    required String phone,
    String? displayName,
    String? email,
    DateTime? createdAt,
  }) async {
    session = {
      'user_id': userId,
      'phone': phone,
      'display_name': displayName,
      'email': email,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  @override
  Future<Map<String, dynamic>?> getSession() async => session;

  @override
  Future<void> clearSession() async {
    clearedSession = true;
    session = null;
  }

  @override
  String? get userId => session?['user_id'] as String?;

  @override
  int getOtpAttempts(String identifier) => attempts[identifier] ?? 0;

  @override
  DateTime? getOtpLockoutUntil(String identifier) => lockouts[identifier];

  @override
  Future<void> saveOtpAttemptState(
    String identifier, {
    required int attempts,
    DateTime? lockoutUntil,
  }) async {
    this.attempts[identifier] = attempts;
    if (lockoutUntil != null) {
      lockouts[identifier] = lockoutUntil;
    } else {
      lockouts.remove(identifier);
    }
  }

  @override
  Future<void> clearOtpAttemptState(String identifier) async {
    attempts.remove(identifier);
    lockouts.remove(identifier);
  }
}

class _FakeAuthRepository implements AuthRepository {
  Either<failures.Failure, void> deleteResult = const Right(null);
  bool logoutCalled = false;

  @override
  Future<Either<failures.Failure, void>> deleteAccount() async => deleteResult;

  @override
  Future<Either<failures.Failure, void>> logout() async {
    logoutCalled = true;
    return const Right(null);
  }

  @override
  Future<Either<failures.Failure, User>> checkSession() async =>
      Left(failures.AuthFailure.sessionExpired());

  @override
  String? get currentUserId => null;

  @override
  Future<Either<failures.Failure, void>> sendEmailOtp(String email) async =>
      const Right(null);

  @override
  Future<Either<failures.Failure, void>> sendOtp(String phone) async =>
      const Right(null);

  @override
  Future<Either<failures.Failure, (User, bool)>> signInWithEmail(
    String email,
    String password,
  ) =>
      throw UnimplementedError();

  @override
  Future<Either<failures.Failure, (User, bool)>> signUpWithEmail(
    String email,
    String password, {
    String? phone,
  }) =>
      throw UnimplementedError();

  @override
  Future<Either<failures.Failure, (User, bool)>> verifyEmailOtp(
    String email,
    String otp,
  ) =>
      throw UnimplementedError();

  @override
  Future<Either<failures.Failure, (User, bool)>> verifyOtp(
    String phone,
    String otp,
  ) =>
      throw UnimplementedError();
}

void main() {
  group('RemoteConfigService', () {
    test('falls back to AppConfig defaults when empty', () {
      final rc = RemoteConfigService.fromValues();
      expect(rc.enableEmailAuth, AppConfig.enableEmailAuth);
      expect(rc.enablePhoneAuth, AppConfig.enablePhoneAuth);
      expect(rc.otpLength, AppConfig.otpLength);
      expect(rc.maxOtpAttempts, AppConfig.maxOtpAttempts);
      expect(rc.otpLockoutMinutes, AppConfig.otpLockoutMinutes);
      expect(rc.otpResendDelaySeconds, AppConfig.otpResendDelaySeconds);
      expect(rc.totalDays, AppConfig.totalDays);
      expect(rc.totalWarmups, AppConfig.totalWarmups);
      expect(rc.maxRecordingDurationSeconds, AppConfig.maxRecordingDurationSeconds);
      expect(rc.maintenanceMode, false);
      expect(rc.qrLoginEnabled, true);
      expect(rc.contentCreatorEnabled, true);
    });

    test('parses remote values, clamps bounds, and guards against zero auth methods', () {
      final rc = RemoteConfigService.fromValues(
        config: {
          'enable_email_auth': 'false',
          'enable_phone_auth': 'false',
          'otp_length': '99',
          'max_otp_attempts': '1',
          'otp_lockout_minutes': '0',
          'max_recording_duration_seconds': '240',
          'api_timeout_seconds': '45',
          'dev_mode': 'true',
        },
        flags: {
          'maintenance_mode': true,
          'qr_login_enabled': false,
          'content_creator_enabled': false,
        },
      );

      // Guardrail keeps email auth enabled when both are false
      expect(rc.enablePhoneAuth, false);
      expect(rc.enableEmailAuth, true);
      expect(rc.otpLength, 8);
      expect(rc.maxOtpAttempts, 3);
      expect(rc.otpLockoutMinutes, 1);
      expect(rc.maxRecordingDurationSeconds, 240);
      expect(rc.apiTimeout, const Duration(seconds: 45));
      expect(rc.devMode, true);
      expect(rc.maintenanceMode, true);
      expect(rc.qrLoginEnabled, false);
      expect(rc.contentCreatorEnabled, false);
    });

    test('treats inactive (is_active=false) auth flags as disabled even when default is true', () {
      // Admin toggles inline ACTIVE switch OFF on enable_email_auth while
      // enable_phone_auth is active & true -> phone-only login!
      final phoneOnly = RemoteConfigService.fromValues(
        config: {'enable_phone_auth': 'true'},
        inactiveKeys: {'enable_email_auth'},
      );
      expect(phoneOnly.enablePhoneAuth, true);
      expect(phoneOnly.enableEmailAuth, false);

      // Admin toggles inline ACTIVE switch OFF on both -> safety guardrail
      // keeps email auth enabled so users are never locked out.
      final bothInactive = RemoteConfigService.fromValues(
        inactiveKeys: {'enable_email_auth', 'enable_phone_auth'},
      );
      expect(bothInactive.enablePhoneAuth, false);
      expect(bothInactive.enableEmailAuth, true);
    });

    test('evaluates semver comparison and force-update gates accurately', () {
      expect(RemoteConfigService.compareVersions('1.2.2+41', '1.2.2'), 0);
      expect(RemoteConfigService.compareVersions('1.2.2', '1.2.3'), lessThan(0));
      expect(RemoteConfigService.compareVersions('1.10.0', '1.2.9'), greaterThan(0));

      final upToDate = RemoteConfigService.fromValues(
        config: {
          'min_supported_version': '1.0.0',
          'app_version': '1.2.2',
          'force_update_required': 'true',
        },
      );
      expect(upToDate.needsForceUpdate('1.2.2'), false);

      final forcedOnNewRelease = RemoteConfigService.fromValues(
        config: {
          'min_supported_version': '1.0.0',
          'app_version': '1.2.3',
          'force_update_required': 'true',
        },
      );
      expect(forcedOnNewRelease.needsForceUpdate('1.2.2'), true);

      final belowMinimum = RemoteConfigService.fromValues(
        config: {
          'min_supported_version': '1.3.0',
          'app_version': '1.3.0',
          'force_update_required': 'false',
        },
      );
      expect(belowMinimum.needsForceUpdate('1.2.2'), true);
    });
  });

  group('SupabaseAuthDataSourceImpl.detectIsNewUser', () {
    final now = DateTime.utc(2026, 11, 27, 12, 0, 0);

    test('returns true when existingUser row is missing', () {
      expect(
        SupabaseAuthDataSourceImpl.detectIsNewUser(
          authCreatedAt: now.toIso8601String(),
          existingUser: null,
          now: now,
        ),
        true,
      );
    });

    test('returns true when trigger created user row seconds ago without display_name', () {
      expect(
        SupabaseAuthDataSourceImpl.detectIsNewUser(
          authCreatedAt: now.subtract(const Duration(seconds: 45)).toIso8601String(),
          existingUser: {'id': 'u1', 'email': 'new@example.com', 'display_name': null},
          now: now,
        ),
        true,
      );
    });

    test('returns false when user already has a display_name', () {
      expect(
        SupabaseAuthDataSourceImpl.detectIsNewUser(
          authCreatedAt: now.subtract(const Duration(seconds: 30)).toIso8601String(),
          existingUser: {'id': 'u1', 'display_name': 'Alex'},
          now: now,
        ),
        false,
      );
    });

    test('returns false for older returning user without display_name', () {
      expect(
        SupabaseAuthDataSourceImpl.detectIsNewUser(
          authCreatedAt: now.subtract(const Duration(days: 5)).toIso8601String(),
          existingUser: {'id': 'u1', 'display_name': null},
          now: now,
        ),
        false,
      );
    });
  });

  group('AuthRepositoryImpl.checkSession', () {
    test('does not resurrect Hive cache when online with expired/missing Supabase session', () async {
      final remote = _FakeRemoteAuthDataSource()
        ..liveUserId = null
        ..currentUserResponse = null;
      final local = _InMemoryHiveAuthDataSource()
        ..session = {
          'user_id': 'stale-user',
          'email': 'stale@example.com',
          'phone': '',
          'created_at': '2026-01-01T00:00:00Z',
        };
      final repo = AuthRepositoryImpl(
        remoteDataSource: remote,
        localDataSource: local,
        networkInfo: _FakeNetworkInfo(connected: true),
      );

      final result = await repo.checkSession();
      expect(result.isLeft(), true);
      expect(local.clearedSession, true);
      expect(local.session, isNull);
    });

    test('falls back to matching Hive cache if online JWT is live but DB fetch fails transiently', () async {
      final remote = _FakeRemoteAuthDataSource()
        ..liveUserId = 'live-user'
        ..currentUserResponse = null;
      final local = _InMemoryHiveAuthDataSource()
        ..session = {
          'user_id': 'live-user',
          'email': 'live@example.com',
          'phone': '',
          'created_at': '2026-01-01T00:00:00Z',
        };
      final repo = AuthRepositoryImpl(
        remoteDataSource: remote,
        localDataSource: local,
        networkInfo: _FakeNetworkInfo(connected: true),
      );

      final result = await repo.checkSession();
      expect(result.isRight(), true);
      result.fold((_) => fail('Expected cached user'), (user) {
        expect(user.id, 'live-user');
      });
    });

    test('restores cached Hive session when offline', () async {
      final remote = _FakeRemoteAuthDataSource();
      final local = _InMemoryHiveAuthDataSource()
        ..session = {
          'user_id': 'offline-user',
          'email': 'offline@example.com',
          'phone': '',
          'created_at': '2026-01-01T00:00:00Z',
        };
      final repo = AuthRepositoryImpl(
        remoteDataSource: remote,
        localDataSource: local,
        networkInfo: _FakeNetworkInfo(connected: false),
      );

      final result = await repo.checkSession();
      expect(result.isRight(), true);
      expect(local.clearedSession, false);
    });
  });

  group('AuthBloc logout, deleteAccount & Hive cleanup', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('cc_auth_test_');
      Hive.init(tempDir.path);
      await Hive.openBox(AppConstants.authBox);
      await Hive.openBox(AppConstants.progressBox);
      await Hive.openBox(AppConstants.scriptsBox);
      await Hive.openBox(AppConstants.settingsBox);
      await Hive.openBox(AppConstants.offlineQueueBox);
      await Hive.openBox(AppConstants.contentScriptsBox);
      await Hive.openBox(AppConstants.remoteConfigBox);
    });

    tearDown(() async {
      await Hive.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('AccountDeletionRequested awaits cleanup and emits AuthLoggedOut cleanly', () async {
      await Hive.box(AppConstants.contentScriptsBox).put('s1', 'script');
      await Hive.box(AppConstants.offlineQueueBox).put('q1', 'pending');
      await Hive.box(AppConstants.settingsBox)
          .put(AppConstants.hasSeenIntroOnboardingKey, true);
      await Hive.box(AppConstants.settingsBox).put('reminder_time', '08:00');
      await Hive.box(AppConstants.remoteConfigBox).put('cached', 'keep');

      final repo = _FakeAuthRepository();
      final bloc = AuthBloc(authRepository: repo);

      final emitted = <AuthState>[];
      final sub = bloc.stream.listen(emitted.add);

      bloc.add(const AccountDeletionRequested());
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(emitted, [const AuthDeletingAccount(), const AuthLoggedOut()]);
      expect(Hive.box(AppConstants.contentScriptsBox).isEmpty, true);
      expect(Hive.box(AppConstants.offlineQueueBox).isEmpty, true);
      expect(
        Hive.box(AppConstants.settingsBox)
            .get(AppConstants.hasSeenIntroOnboardingKey),
        true,
      );
      expect(Hive.box(AppConstants.settingsBox).get('reminder_time'), isNull);
      expect(Hive.box(AppConstants.remoteConfigBox).get('cached'), 'keep');

      await sub.cancel();
      await bloc.close();
    });

    test('HiveAuthDataSourceImpl persists OTP lockout across normalized identifiers and preserves it across clearSession', () async {
      final authBox = Hive.box(AppConstants.authBox);
      final ds = HiveAuthDataSourceImpl(authBox: authBox);

      final lockoutUntil = DateTime.now().add(const Duration(minutes: 15));
      await ds.saveOtpAttemptState(
        'User@Example.COM',
        attempts: 5,
        lockoutUntil: lockoutUntil,
      );
      await ds.saveSession(userId: 'u1', phone: '', email: 'user@example.com');
      await ds.clearSession();

      expect(ds.userId, isNull);
      expect(ds.getOtpAttempts('user@example.com'), 5);
      expect(ds.getOtpLockoutUntil('user@example.com'), isNotNull);

      await ds.clearOtpAttemptState('user@example.com');
      expect(ds.getOtpAttempts('user@example.com'), 0);
      expect(ds.getOtpLockoutUntil('user@example.com'), isNull);
    });
  });

  testWidgets('OtpVerificationScreen has no RenderFlex overflow when keyboard shrinks viewport', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    tester.view.viewInsets = const FakeViewPadding(bottom: 340);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewInsets();
    });

    final authBloc = AuthBloc(authRepository: _FakeAuthRepository());
    addTearDown(authBloc.close);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<AuthBloc>.value(
          value: authBloc,
          child: const OtpVerificationScreen(
            phone: 'kumod353@gmail.com',
            isEmail: true,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Verify & Continue'), findsOneWidget);
  });
}

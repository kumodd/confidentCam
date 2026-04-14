import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/logger.dart';
import '../../../domain/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

/// BLoC for handling authentication flow.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;

  AuthBloc({required this.authRepository}) : super(const AuthInitial()) {
    on<SessionCheckRequested>(_onSessionCheck);
    on<PhoneSubmitted>(_onPhoneSubmitted);
    on<OtpSubmitted>(_onOtpSubmitted);
    on<ResendOtpRequested>(_onResendOtp);
    on<LogoutRequested>(_onLogout);
    on<AccountDeletionRequested>(_onDeleteAccount);
    on<EmailSignUpRequested>(_onEmailSignUp);
    on<EmailSignInRequested>(_onEmailSignIn);
  }

  Future<void> _onSessionCheck(
    SessionCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    final result = await authRepository.checkSession();

    result.fold(
      (failure) {
        logger.d('No active session');
        emit(const AuthLoggedOut());
      },
      (user) {
        logger.i('Session restored for user ${user.id}');
        emit(AuthSuccess(user: user, isNewUser: false));
      },
    );
  }

  Future<void> _onPhoneSubmitted(
    PhoneSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    final result = await authRepository.sendOtp(event.phone);

    result.fold(
      (failure) {
        logger.e('Failed to send OTP: ${failure.message}');
        emit(AuthFailure(message: failure.message));
      },
      (_) {
        logger.i('OTP sent to ${event.phone}');
        emit(AuthCodeSent(phone: event.phone));
      },
    );
  }

  Future<void> _onOtpSubmitted(
    OtpSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthVerifying());

    final result = await authRepository.verifyOtp(event.phone, event.otp);

    result.fold(
      (failure) {
        logger.e('OTP verification failed: ${failure.message}');
        emit(AuthFailure(message: failure.message, previousPhone: event.phone));
      },
      (data) {
        final (user, isNewUser) = data;
        logger.i('OTP verified. New user: $isNewUser');
        emit(AuthSuccess(user: user, isNewUser: isNewUser));
      },
    );
  }

  Future<void> _onResendOtp(
    ResendOtpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    final result = await authRepository.sendOtp(event.phone);

    result.fold(
      (failure) {
        logger.e('Failed to resend OTP: ${failure.message}');
        emit(AuthFailure(message: failure.message, previousPhone: event.phone));
      },
      (_) {
        logger.i('OTP resent to ${event.phone}');
        emit(AuthCodeSent(phone: event.phone));
      },
    );
  }

  Future<void> _onLogout(LogoutRequested event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());

    await authRepository.logout();

    // Clear ALL local data to prevent stale data for next user
    await _clearAllLocalData();

    logger.i('User logged out, local data cleared');
    emit(const AuthLoggedOut());
  }

  Future<void> _onDeleteAccount(
    AccountDeletionRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthDeletingAccount());

    final result = await authRepository.deleteAccount();

    result.fold(
      (failure) {
        logger.e('Account deletion failed: ${failure.message}');
        emit(AuthFailure(message: failure.message));
      },
      (_) async {
        await _clearAllLocalData();
        logger.i('Account deleted, local data cleared');
        emit(const AuthLoggedOut());
      },
    );
  }

  Future<void> _onEmailSignUp(
    EmailSignUpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    final result = await authRepository.signUpWithEmail(
      event.email,
      event.password,
      phone: event.phone,
    );

    result.fold(
      (failure) {
        logger.e('Email sign up failed: ${failure.message}');
        emit(AuthFailure(message: failure.message));
      },
      (data) {
        final (user, isNewUser) = data;
        logger.i('Email sign up result. New user: $isNewUser, id: ${user.id}');

        // If the user entity has a valid createdAt that isn't just DateTime.now()
        // and we got a proper user id, it means Supabase gave us a live session
        // (email confirmation is disabled in Supabase project settings).
        // In that case, skip the confirmation screen and go straight to the app.
        final hasLiveSession = user.id.isNotEmpty && user.email != null;

        if (hasLiveSession && !isNewUser) {
          // Returning user or session without confirmation requirement
          logger.i('Live session after signup — going to dashboard');
          emit(AuthSuccess(user: user, isNewUser: isNewUser));
        } else if (hasLiveSession && isNewUser) {
          // New user with live session (confirmation disabled)
          logger.i('Email confirmation not required — going to dashboard as new user');
          emit(AuthSuccess(user: user, isNewUser: true));
        } else {
          // Needs email confirmation
          logger.i('Email confirmation required for: ${event.email}');
          emit(EmailConfirmationRequired(email: event.email));
        }
      },
    );
  }

  Future<void> _onEmailSignIn(
    EmailSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    final result = await authRepository.signInWithEmail(
      event.email,
      event.password,
    );

    result.fold(
      (failure) {
        logger.e('Email sign in failed: ${failure.message}');
        emit(AuthFailure(message: failure.message));
      },
      (data) {
        final (user, isNewUser) = data;
        logger.i('Email sign in successful. New user: $isNewUser');
        emit(AuthSuccess(user: user, isNewUser: isNewUser));
      },
    );
  }

  /// Clear all local Hive data to ensure no stale data persists
  /// between different user sessions.
  ///
  /// NOTE: Recorded videos are intentionally NOT deleted here.
  /// Videos are stored in the device filesystem (getApplicationDocumentsDirectory)
  /// and belong to the user's device — they are preserved across logouts and
  /// account switches by design.
  Future<void> _clearAllLocalData() async {
    try {
      final progressBox = Hive.box(AppConstants.progressBox);
      final scriptsBox = Hive.box(AppConstants.scriptsBox);
      final settingsBox = Hive.box(AppConstants.settingsBox);

      await progressBox.clear();
      await scriptsBox.clear();
      await settingsBox.clear();

      logger.i('All local Hive boxes cleared');
    } catch (e) {
      logger.e('Error clearing local data: $e');
      // Non-fatal: auth session is already cleared by repository
    }
  }
}

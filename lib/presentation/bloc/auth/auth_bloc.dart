import 'package:flutter_bloc/flutter_bloc.dart';

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

    logger.i('User logged out');
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
      (_) {
        logger.i('Account deleted');
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
        logger.i('Email sign up successful. New user: $isNewUser');

        // Always show confirmation screen for email signup
        // Supabase requires email confirmation by default
        logger.i('Email confirmation required for: ${event.email}');
        emit(EmailConfirmationRequired(email: event.email));
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
}

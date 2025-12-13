import 'package:equatable/equatable.dart';

import '../../../domain/entities/user.dart';

/// Auth BLoC States
abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any auth action
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// Loading state during auth operations
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// OTP has been sent to phone
class AuthCodeSent extends AuthState {
  final String phone;

  const AuthCodeSent({required this.phone});

  @override
  List<Object?> get props => [phone];
}

/// Verifying OTP code
class AuthVerifying extends AuthState {
  const AuthVerifying();
}

/// Authentication successful
class AuthSuccess extends AuthState {
  final User user;
  final bool isNewUser;

  const AuthSuccess({required this.user, required this.isNewUser});

  @override
  List<Object?> get props => [user, isNewUser];
}

/// Authentication failed
class AuthFailure extends AuthState {
  final String message;
  final int? attemptsRemaining;
  final String? previousPhone;

  const AuthFailure({
    required this.message,
    this.attemptsRemaining,
    this.previousPhone,
  });

  @override
  List<Object?> get props => [message, attemptsRemaining, previousPhone];
}

/// User logged out
class AuthLoggedOut extends AuthState {
  const AuthLoggedOut();
}

/// Account deletion in progress
class AuthDeletingAccount extends AuthState {
  const AuthDeletingAccount();
}

/// User needs to confirm their email before proceeding
class EmailConfirmationRequired extends AuthState {
  final String email;

  const EmailConfirmationRequired({required this.email});

  @override
  List<Object?> get props => [email];
}

import 'package:equatable/equatable.dart';

/// Auth BLoC Events
abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Submit phone number for OTP
class PhoneSubmitted extends AuthEvent {
  final String phone;

  const PhoneSubmitted(this.phone);

  @override
  List<Object?> get props => [phone];
}

/// Submit OTP code for verification
class OtpSubmitted extends AuthEvent {
  final String phone;
  final String otp;

  const OtpSubmitted({required this.phone, required this.otp});

  @override
  List<Object?> get props => [phone, otp];
}

/// Request to resend OTP
class ResendOtpRequested extends AuthEvent {
  final String phone;

  const ResendOtpRequested(this.phone);

  @override
  List<Object?> get props => [phone];
}

/// Check existing session on app start
class SessionCheckRequested extends AuthEvent {
  const SessionCheckRequested();
}

/// Request logout
class LogoutRequested extends AuthEvent {
  const LogoutRequested();
}

/// Request account deletion
class AccountDeletionRequested extends AuthEvent {
  const AccountDeletionRequested();
}

/// Sign up with email and password
class EmailSignUpRequested extends AuthEvent {
  final String email;
  final String password;
  final String? phone;

  const EmailSignUpRequested({
    required this.email,
    required this.password,
    this.phone,
  });

  @override
  List<Object?> get props => [email, password, phone];
}

/// Sign in with email and password
class EmailSignInRequested extends AuthEvent {
  final String email;
  final String password;

  const EmailSignInRequested({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

/// Request OTP code sent to email
class EmailOtpRequested extends AuthEvent {
  final String email;

  const EmailOtpRequested(this.email);

  @override
  List<Object?> get props => [email];
}

/// Submit email OTP code for verification
class EmailOtpSubmitted extends AuthEvent {
  final String email;
  final String otp;

  const EmailOtpSubmitted({required this.email, required this.otp});

  @override
  List<Object?> get props => [email, otp];
}

/// Request to resend email OTP
class ResendEmailOtpRequested extends AuthEvent {
  final String email;

  const ResendEmailOtpRequested(this.email);

  @override
  List<Object?> get props => [email];
}

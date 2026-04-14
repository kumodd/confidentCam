import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:pinput/pinput.dart';

import '../../../core/config/app_config.dart';
import '../../../core/di/injection_container.dart';
import '../../../domain/repositories/user_repository.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import '../../bloc/auth/auth_state.dart';

/// OTP verification screen.
class OtpVerificationScreen extends StatefulWidget {
  final String phone;

  const OtpVerificationScreen({super.key, required this.phone});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otpController = TextEditingController();
  final _focusNode = FocusNode();
  int _resendTimer = AppConfig.otpResendDelaySeconds;
  Timer? _timer;
  int _attemptCount = 0;
  bool _isLocked = false;
  int _lockoutTimer = AppConfig.otpLockoutMinutes * 60;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    // Auto focus OTP input
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _timer?.cancel();
    setState(() => _resendTimer = AppConfig.otpResendDelaySeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimer > 0) {
        setState(() => _resendTimer--);
      } else {
        timer.cancel();
      }
    });
  }

  void _verifyOtp(String otp) {
    if (_isLocked) return;
    if (otp.length == AppConfig.otpLength) {
      context.read<AuthBloc>().add(OtpSubmitted(phone: widget.phone, otp: otp));
    }
  }

  void _startLockout() {
    setState(() {
      _isLocked = true;
      _lockoutTimer = AppConfig.otpLockoutMinutes * 60;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_lockoutTimer > 0) {
        setState(() => _lockoutTimer--);
      } else {
        t.cancel();
        setState(() {
          _isLocked = false;
          _attemptCount = 0;
        });
      }
    });
  }

  /// Shows a bottom sheet to collect the user's display name after OTP success.
  /// Runs for new users only. The user can skip by tapping "Skip".
  void _showNameCollectionSheet(BuildContext context, String userId) {
    final nameController = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Greeting
              Text(
                '👋  Welcome! What should we call you?',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your name will appear on your dashboard. You can change it later in Settings.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white54,
                ),
              ),
              const SizedBox(height: 24),

              // Name field
              TextField(
                controller: nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Your first name',
                  labelStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.person_outline, color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF252538),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Save button
              ElevatedButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  Navigator.of(sheetCtx).pop();
                  if (name.isNotEmpty) {
                    try {
                      await sl<UserRepository>().updateDisplayName(userId, name);
                    } catch (_) {
                      // Non-blocking: name update failure should not block login
                    }
                  }
                  // Route to app regardless of whether name was saved
                  if (context.mounted) {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Save & Continue', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 10),

              // Skip option
              TextButton(
                onPressed: () {
                  Navigator.of(sheetCtx).pop();
                  if (context.mounted) {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                },
                child: const Text('Skip for now', style: TextStyle(color: Colors.white38)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _resendOtp() {
    if (_resendTimer == 0) {
      context.read<AuthBloc>().add(ResendOtpRequested(widget.phone));
      _startResendTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 56,
      height: 60,
      textStyle: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary,
          width: 2,
        ),
      ),
    );

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthVerifying) {
          EasyLoading.show(status: 'Verifying...');
        } else {
          EasyLoading.dismiss();
        }

        if (state is AuthSuccess) {
          if (state.isNewUser) {
            // New user: collect their name before routing to the app
            _showNameCollectionSheet(context, state.user.id);
          } else {
            // Returning user: go straight to dashboard
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        } else if (state is AuthFailure) {
          _otpController.clear();
          _attemptCount++;
          final remaining = AppConfig.maxOtpAttempts - _attemptCount;
          if (remaining <= 0) {
            _startLockout();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Too many failed attempts. Locked for ${AppConfig.otpLockoutMinutes} minutes.',
                ),
                backgroundColor: Theme.of(context).colorScheme.error,
                duration: const Duration(seconds: 5),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${state.message} ($remaining attempts left)'),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0F0F1A), Color(0xFF1E1E2E)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),

                  // Header
                  Text(
                    'Verify your number',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ).animate().fadeIn(duration: 400.ms),

                  const SizedBox(height: 12),

                  Text(
                    'Enter the 6-digit code sent to',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: Colors.white54),
                  ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

                  const SizedBox(height: 4),

                  Text(
                    widget.phone,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ).animate().fadeIn(delay: 150.ms, duration: 400.ms),

                  const SizedBox(height: 48),

                  // OTP input
                  Center(
                    child: Pinput(
                      controller: _otpController,
                      focusNode: _focusNode,
                      length: AppConfig.otpLength,
                      defaultPinTheme: defaultPinTheme,
                      focusedPinTheme: focusedPinTheme,
                      submittedPinTheme: defaultPinTheme,
                      onCompleted: _verifyOtp,
                      cursor: Container(
                        width: 2,
                        height: 24,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      showCursor: true,
                    ),
                  ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

                  const SizedBox(height: 32),

                  // Resend button
                  Center(
                    child: _resendTimer > 0
                        ? Text(
                            'Resend code in $_resendTimer seconds',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.white54),
                          )
                        : TextButton(
                            onPressed: _resendOtp,
                            child: const Text('Resend Code'),
                          ),
                  ).animate().fadeIn(delay: 300.ms, duration: 400.ms),

                  const Spacer(),

                  // Lockout warning
                  if (_isLocked)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lock_clock, color: Colors.red, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Too many attempts. Try again in ${_lockoutTimer ~/ 60}:${(_lockoutTimer % 60).toString().padLeft(2, '0')}',
                              style: const TextStyle(color: Colors.red, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Verify button
                  ElevatedButton(
                    onPressed: _isLocked ? null : () => _verifyOtp(_otpController.text),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Verify', style: TextStyle(fontSize: 18)),
                  ).animate().fadeIn(delay: 400.ms, duration: 400.ms),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

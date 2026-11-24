import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinput/pinput.dart';

import '../../../core/config/app_config.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/repositories/user_repository.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import '../../bloc/auth/auth_state.dart';

/// OTP verification screen in the minimalist sage & olive design system.
class OtpVerificationScreen extends StatefulWidget {
  final String phone;
  final bool isEmail;

  const OtpVerificationScreen({
    super.key,
    required this.phone,
    this.isEmail = false,
  });

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
      if (widget.isEmail) {
        context
            .read<AuthBloc>()
            .add(EmailOtpSubmitted(email: widget.phone, otp: otp));
      } else {
        context
            .read<AuthBloc>()
            .add(OtpSubmitted(phone: widget.phone, otp: otp));
      }
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

  void _showNameCollectionSheet(BuildContext context, String userId) {
    final nameController = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetCtx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
            left: 24,
            right: 24,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Welcome! What should we call you?',
                style: AppTypography.headingMedium(fontSize: 20),
              ),
              const SizedBox(height: 8),
              Text(
                'Your name will appear on your dashboard. You can change it later in Settings.',
                style: AppTypography.body(),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                style: AppTypography.bodyStrong(),
                decoration: InputDecoration(
                  labelText: 'Your first name',
                  prefixIcon: Icon(
                    Icons.person_outline_rounded,
                    color: AppColors.secondaryText,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  Navigator.of(sheetCtx).pop();
                  if (name.isNotEmpty) {
                    try {
                      await sl<UserRepository>()
                          .updateDisplayName(userId, name);
                    } catch (_) {}
                  }
                  if (context.mounted) {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                },
                child: Text('Save & Continue'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.of(sheetCtx).pop();
                  if (context.mounted) {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                },
                child: Text(
                  'Skip for now',
                  style: AppTypography.body(color: AppColors.secondaryText),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _resendOtp() {
    if (_resendTimer == 0) {
      if (widget.isEmail) {
        context.read<AuthBloc>().add(ResendEmailOtpRequested(widget.phone));
      } else {
        context.read<AuthBloc>().add(ResendOtpRequested(widget.phone));
      }
      _startResendTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 50,
      height: 58,
      textStyle: GoogleFonts.manrope(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: AppColors.primaryText,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider, width: 1.4),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: BoxDecoration(
        color: AppColors.olivePillFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryOlive,
          width: 2.0,
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
            _showNameCollectionSheet(context, state.user.id);
          } else {
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
                backgroundColor: AppColors.error,
                duration: const Duration(seconds: 5),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${state.message} ($remaining attempts left)'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text('Verification'),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SageCard(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            color: AppColors.secondaryGreen,
                            size: 20,
                          ),
                          Text(
                            'ONE-TIME PASSCODE',
                            style: AppTypography.uppercaseLabel(
                              fontSize: 11,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(height: 1.2, color: AppColors.divider),
                      const SizedBox(height: 18),
                      Text(
                        widget.isEmail
                            ? 'Verify your email'
                            : 'Verify your number',
                        style: AppTypography.headingLarge(fontSize: 24),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enter the 6-digit code sent to',
                        style: AppTypography.body(),
                      ),
                      const SizedBox(height: 8),
                      OlivePillBadge(
                        label: widget.phone,
                        icon: widget.isEmail
                            ? Icons.email_outlined
                            : Icons.phone_outlined,
                      ),
                      const SizedBox(height: 28),
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
                            height: 22,
                            color: AppColors.primaryOlive,
                          ),
                          showCursor: true,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: _resendTimer > 0
                            ? Text(
                                'Resend code in $_resendTimer seconds',
                                style: AppTypography.body(
                                  fontSize: 13.5,
                                  color: AppColors.secondaryText,
                                ),
                              )
                            : TextButton(
                                onPressed: _resendOtp,
                                child: Text('Resend Code'),
                              ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (_isLocked)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.errorTint,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lock_clock_outlined,
                          color: AppColors.error,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Too many attempts. Try again in ${_lockoutTimer ~/ 60}:${(_lockoutTimer % 60).toString().padLeft(2, '0')}',
                            style: AppTypography.body(
                              color: AppColors.error,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ElevatedButton(
                  onPressed:
                      _isLocked ? null : () => _verifyOtp(_otpController.text),
                  child: Text('Verify & Continue'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

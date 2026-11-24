import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import '../../bloc/auth/auth_state.dart' as app_auth;

/// Screen shown after email signup to prompt user to verify their email.
class EmailConfirmationScreen extends StatefulWidget {
  final String email;

  const EmailConfirmationScreen({super.key, required this.email});

  @override
  State<EmailConfirmationScreen> createState() =>
      _EmailConfirmationScreenState();
}

class _EmailConfirmationScreenState extends State<EmailConfirmationScreen> {
  Timer? _pollTimer;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkConfirmation();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkConfirmation() async {
    if (_isChecking || !mounted) return;
    setState(() => _isChecking = true);

    try {
      final response = await Supabase.instance.client.auth.refreshSession();
      final user = response.session?.user;

      if (user != null && user.emailConfirmedAt != null && mounted) {
        _pollTimer?.cancel();
        context.read<AuthBloc>().add(SessionCheckRequested());
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _resendEmail() async {
    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: widget.email,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Confirmation email resent!'),
            backgroundColor: AppColors.secondaryGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not resend. Please try again later.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, app_auth.AuthState>(
      listener: (context, state) {
        if (state is app_auth.AuthSuccess) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text('Confirm Email'),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SageCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: AppColors.olivePillFill,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.olivePillBorder,
                            width: 1.3,
                          ),
                        ),
                        child: Icon(
                          Icons.mark_email_unread_outlined,
                          color: AppColors.primaryOlive,
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Check Your Email',
                        style: AppTypography.headingLarge(fontSize: 24),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'We sent a confirmation link to:',
                        style: AppTypography.body(),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      OlivePillBadge(
                        label: widget.email,
                        icon: Icons.email_outlined,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _isChecking
                            ? 'Checking confirmation status...'
                            : 'Checking automatically every 5 seconds...',
                        style: AppTypography.body(
                          fontSize: 12.5,
                          color: AppColors.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SageCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildStep(
                        Icons.inbox_outlined,
                        'Open your email inbox',
                        1,
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(),
                      ),
                      _buildStep(
                        Icons.link_rounded,
                        'Click the confirmation link',
                        2,
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(),
                      ),
                      _buildStep(
                        Icons.check_circle_outline_rounded,
                        'You will be signed in automatically',
                        3,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                ElevatedButton.icon(
                  onPressed: _checkConfirmation,
                  icon: Icon(Icons.refresh_rounded, size: 19),
                  label: Text("I've already verified — Sign In"),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Didn't receive the email?",
                      style: AppTypography.body(),
                    ),
                    TextButton(
                      onPressed: _resendEmail,
                      child: Text('Resend'),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () async {
                    await Supabase.instance.client.auth.signOut();
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  child: Text(
                    'Back to Login',
                    style: AppTypography.body(color: AppColors.secondaryText),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep(IconData icon, String text, int number) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.olivePillFill,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.olivePillBorder),
          ),
          child: Center(
            child: Text(
              number.toString(),
              style: AppTypography.bodyStrong(color: AppColors.primaryOlive),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Icon(icon, color: AppColors.secondaryGreen, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodyStrong(fontSize: 14.5),
          ),
        ),
      ],
    );
  }
}

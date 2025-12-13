import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Screen shown after email signup to prompt user to verify their email
class EmailConfirmationScreen extends StatelessWidget {
  final String email;

  const EmailConfirmationScreen({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A0A14), Color(0xFF1A1A2E), Color(0xFF16162A)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Email icon
                Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(context).colorScheme.secondary,
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.email_outlined,
                        color: Colors.white,
                        size: 50,
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 500.ms)
                    .scale(begin: const Offset(0.8, 0.8)),

                const SizedBox(height: 32),

                Text(
                  'Check Your Email',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

                const SizedBox(height: 16),

                Text(
                  'We sent a confirmation link to:',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: Colors.white70),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 300.ms, duration: 400.ms),

                const SizedBox(height: 8),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    email,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ).animate().fadeIn(delay: 400.ms, duration: 400.ms),

                const SizedBox(height: 32),

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildStep(
                        context,
                        Icons.inbox_rounded,
                        'Open your email inbox',
                        1,
                      ),
                      const SizedBox(height: 16),
                      _buildStep(
                        context,
                        Icons.link_rounded,
                        'Click the confirmation link',
                        2,
                      ),
                      const SizedBox(height: 16),
                      _buildStep(
                        context,
                        Icons.check_circle_outline,
                        'Your account will be activated',
                        3,
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 500.ms, duration: 400.ms),

                const SizedBox(height: 32),

                Text(
                  "Didn't receive the email?",
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.white54),
                ).animate().fadeIn(delay: 600.ms, duration: 400.ms),

                const SizedBox(height: 12),

                TextButton(
                  onPressed: () {
                    // TODO: Implement resend confirmation email
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Confirmation email resent!'),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                      ),
                    );
                  },
                  child: Text(
                    'Resend Confirmation Email',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ).animate().fadeIn(delay: 700.ms, duration: 400.ms),

                const SizedBox(height: 24),

                OutlinedButton(
                  onPressed: () async {
                    // Sign out to clear session before going back
                    await Supabase.instance.client.auth.signOut();
                    if (context.mounted) {
                      // Pop back to login screen
                      Navigator.of(context).pop();
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Back to Login',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ).animate().fadeIn(delay: 800.ms, duration: 400.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep(
    BuildContext context,
    IconData icon,
    String text,
    int number,
  ) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.secondary,
              ],
            ),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Icon(icon, color: Colors.white70, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
        ),
      ],
    );
  }
}

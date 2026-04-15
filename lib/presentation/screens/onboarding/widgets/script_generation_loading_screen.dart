import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Animated loading screen with rotating motivational quotes
class ScriptGenerationLoadingScreen extends StatefulWidget {
  const ScriptGenerationLoadingScreen();

  @override
  State<ScriptGenerationLoadingScreen> createState() =>
      ScriptGenerationLoadingScreenState();
}

class ScriptGenerationLoadingScreenState
    extends State<ScriptGenerationLoadingScreen> {
  int _currentQuoteIndex = 0;
  Timer? _quoteTimer;

  static const _motivationalQuotes = [
    "Your voice matters. The world needs to hear it.",
    "Every expert was once a beginner.",
    "Confidence is a skill. You're building it now.",
    "The camera is your friend, not your critic.",
    "Small steps lead to big transformations.",
    "You're braver than you believe.",
    "Progress over perfection, always.",
    "Your unique perspective is your superpower.",
    "Today's discomfort is tomorrow's strength.",
    "You're not just recording. You're growing.",
    "Authenticity beats perfection every time.",
    "One video at a time, you'll get there.",
    "The only way out is through. Keep going.",
    "Your future self will thank you for starting.",
    "Embrace the awkward. It's part of the journey.",
  ];

  @override
  void initState() {
    super.initState();
    _quoteTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) {
        setState(() {
          _currentQuoteIndex =
              (_currentQuoteIndex + 1) % _motivationalQuotes.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _quoteTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated loading indicator
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      const Color(0xFF6366F1).withValues(alpha: 0.8),
                    ),
                  ),
                ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2000.ms),
                const SizedBox(height: 48),
                // Main message
                const Text(
                  'Preparing Your First Week\'s Journey',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(duration: 600.ms),
                const SizedBox(height: 12),
                Text(
                  'Crafting personalized scripts just for you...',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 300.ms),
                
                const SizedBox(height: 64),
                // Motivational quote with animation
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.format_quote,
                        color: const Color(0xFF6366F1).withValues(alpha: 0.5),
                        size: 32,
                      ),
                      const SizedBox(height: 16),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 500),
                        child: Text(
                          _motivationalQuotes[_currentQuoteIndex],
                          key: ValueKey<int>(_currentQuoteIndex),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontStyle: FontStyle.italic,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.2, end: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

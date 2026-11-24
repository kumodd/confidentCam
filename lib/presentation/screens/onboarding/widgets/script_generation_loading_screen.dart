import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Animated loading screen with rotating motivational quotes
class ScriptGenerationLoadingScreen extends StatefulWidget {
  const ScriptGenerationLoadingScreen({super.key});

  @override
  State<ScriptGenerationLoadingScreen> createState() =>
      ScriptGenerationLoadingScreenState();
}

class ScriptGenerationLoadingScreenState
    extends State<ScriptGenerationLoadingScreen> {
  int _currentQuoteIndex = 0;
  Timer? _quoteTimer;

  static const _motivationalQuotes = [
    'Your voice matters. The world needs to hear it.',
    'Every expert was once a beginner.',
    "Confidence is a skill. You're building it now.",
    'The camera is your friend, not your critic.',
    'Small steps lead to big transformations.',
    "You're braver than you believe.",
    'Progress over perfection, always.',
    'Your unique perspective is your superpower.',
    "Today's discomfort is tomorrow's strength.",
    "You're not just recording. You're growing.",
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
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 68,
                height: 68,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.primaryOlive,
                  ),
                ),
              ),
              const SizedBox(height: 36),
              Text(
                "Preparing Your First Week's Journey",
                style: AppTypography.headingLarge(fontSize: 23),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Crafting personalized scripts just for you...',
                style: AppTypography.body(fontSize: 15),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 44),
              SageCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      Icons.format_quote_rounded,
                      color: AppColors.primaryOlive,
                      size: 30,
                    ),
                    const SizedBox(height: 12),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 450),
                      child: Text(
                        _motivationalQuotes[_currentQuoteIndex],
                        key: ValueKey<int>(_currentQuoteIndex),
                        style: AppTypography.bodyStrong(
                          fontSize: 16.5,
                          color: AppColors.primaryText,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

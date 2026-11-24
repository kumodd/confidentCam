import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_theme.dart';

/// Splash screen shown during app initialization.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Minimalist sage/olive logo badge
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: AppColors.divider,
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.olivePillFill,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: AppColors.olivePillBorder,
                      width: 1.2,
                    ),
                  ),
                  child: Icon(
                    Icons.videocam_outlined,
                    size: 38,
                    color: AppColors.primaryOlive,
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 500.ms).scale(
                  begin: const Offset(0.85, 0.85),
                  end: const Offset(1, 1),
                ),

            const SizedBox(height: 28),

            // App name
            Text(
              'ConfidentCam',
              style: AppTypography.headingLarge(fontSize: 30),
            ).animate().fadeIn(delay: 200.ms, duration: 500.ms),

            const SizedBox(height: 8),

            // Tagline
            Text(
              '30 DAYS TO CAMERA CONFIDENCE',
              style: AppTypography.uppercaseLabel(
                fontSize: 11.5,
                color: AppColors.secondaryText,
                letterSpacing: 2.0,
              ),
            ).animate().fadeIn(delay: 350.ms, duration: 500.ms),

            const SizedBox(height: 44),

            // Loading indicator
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2.8,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.primaryOlive,
                ),
              ),
            ).animate().fadeIn(delay: 500.ms, duration: 400.ms),
          ],
        ),
      ),
    );
  }
}

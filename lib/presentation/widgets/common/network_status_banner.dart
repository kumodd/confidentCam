import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Network status banner shown when offline.
class NetworkStatusBanner extends StatelessWidget {
  const NetworkStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.error,
      child: SafeArea(
        bottom: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.wifi_off_rounded,
                color: AppColors.background,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'No internet connection',
                style: AppTypography.bodyStrong(
                  color: AppColors.background,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

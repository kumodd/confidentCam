import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Reusable option card widget in the sage & olive design system.
class OptionCard extends StatelessWidget {
  final String text;
  final String? subtitle;
  final bool isSelected;
  final bool showCheckbox;
  final VoidCallback onTap;

  const OptionCard({
    super.key,
    required this.text,
    this.subtitle,
    required this.isSelected,
    this.showCheckbox = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.olivePillFill : AppColors.cardSurface,
          borderRadius: AppRadii.cardBorder,
          border: Border.all(
            color:
                isSelected ? AppColors.primaryOlive : AppColors.divider,
            width: isSelected ? 1.8 : 1.2,
          ),
        ),
        child: Row(
          children: [
            if (showCheckbox) ...[
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primaryOlive
                      : AppColors.background,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primaryOlive
                        : AppColors.secondaryText,
                    width: 1.6,
                  ),
                ),
                child: isSelected
                    ? Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: AppColors.background,
                      )
                    : null,
              ),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: AppTypography.bodyStrong(
                      fontSize: 15.5,
                      color: AppColors.primaryText,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: AppTypography.body(
                        fontSize: 13,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!showCheckbox && isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: AppColors.primaryOlive,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}

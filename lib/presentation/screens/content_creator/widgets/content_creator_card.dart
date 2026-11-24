import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../content_creator_screen.dart';

/// Dashboard metric card for the Content Creator module.
class ContentCreatorCard extends StatelessWidget {
  final String userId;

  const ContentCreatorCard({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return SageMetricCard(
      icon: Icons.movie_creation_outlined,
      iconColor: AppColors.secondaryGreen,
      label: 'STUDIO',
      value: 'AI Scripts',
      subtitle: 'Content Creator',
      onTap: () => _openContentCreator(context),
    );
  }

  void _openContentCreator(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ContentCreatorScreen(userId: userId)),
    );
  }
}

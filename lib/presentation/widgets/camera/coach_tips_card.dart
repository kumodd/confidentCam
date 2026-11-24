import 'dart:math';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Coaching tips widget that shows rotating tips on the recording screen.
class CoachTipsCard extends StatefulWidget {
  final bool isRecording;

  const CoachTipsCard({super.key, this.isRecording = false});

  @override
  State<CoachTipsCard> createState() => _CoachTipsCardState();
}

class _CoachTipsCardState extends State<CoachTipsCard> {
  int _currentTipIndex = 0;

  static const List<CoachTip> _recordingTips = [
    CoachTip(
      icon: Icons.visibility_outlined,
      text: "Look at the camera lens like it's your best friend",
      category: 'EYE CONTACT',
    ),
    CoachTip(
      icon: Icons.volume_up_outlined,
      text: 'Project your voice - speak 20% louder than usual',
      category: 'VOICE',
    ),
    CoachTip(
      icon: Icons.sentiment_satisfied_outlined,
      text: 'Smile gently - it relaxes your face and voice',
      category: 'EXPRESSION',
    ),
    CoachTip(
      icon: Icons.speed_outlined,
      text: 'Slow down - we all speak faster when nervous',
      category: 'PACING',
    ),
    CoachTip(
      icon: Icons.air_rounded,
      text: 'Take a breath before starting - it calms the nerves',
      category: 'BREATHING',
    ),
    CoachTip(
      icon: Icons.emoji_emotions_outlined,
      text: "Imagine you're talking to a close friend",
      category: 'CONNECTION',
    ),
    CoachTip(
      icon: Icons.gesture_rounded,
      text: 'Use hand gestures naturally - they add energy',
      category: 'BODY LANGUAGE',
    ),
    CoachTip(
      icon: Icons.self_improvement_outlined,
      text: 'Imperfect is perfect - authenticity wins',
      category: 'MINDSET',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _currentTipIndex = Random().nextInt(_recordingTips.length);
  }

  void _nextTip() {
    setState(() {
      _currentTipIndex = (_currentTipIndex + 1) % _recordingTips.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tip = _recordingTips[_currentTipIndex];

    return GestureDetector(
      onTap: _nextTip,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.background.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                widget.isRecording ? AppColors.error : AppColors.divider,
            width: 1.3,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: widget.isRecording
                    ? AppColors.errorTint
                    : AppColors.olivePillFill,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: widget.isRecording
                      ? AppColors.error.withValues(alpha: 0.4)
                      : AppColors.olivePillBorder,
                ),
              ),
              child: Icon(
                tip.icon,
                color: widget.isRecording
                    ? AppColors.error
                    : AppColors.primaryOlive,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tip.category,
                    style: AppTypography.uppercaseLabel(
                      color: widget.isRecording
                          ? AppColors.error
                          : AppColors.secondaryGreen,
                      fontSize: 10.5,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tip.text,
                    style: AppTypography.bodyStrong(
                      color: AppColors.primaryText,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.touch_app_outlined,
              color: AppColors.mutedText,
              size: 17,
            ),
          ],
        ),
      ),
    );
  }
}

class CoachTip {
  final IconData icon;
  final String text;
  final String category;

  const CoachTip({
    required this.icon,
    required this.text,
    required this.category,
  });
}

/// Sample script prompts when user has blank thoughts.
class SampleScriptCard extends StatelessWidget {
  final String? userName;
  final String? userGoal;
  final int warmupIndex;

  const SampleScriptCard({
    super.key,
    this.userName,
    this.userGoal,
    required this.warmupIndex,
  });

  String _getSampleScript() {
    final name = userName ?? 'there';
    final goal = userGoal ?? 'build my confidence on camera';

    final scripts = [
      "Hi, I'm $name and this is my first step toward becoming confident on camera. "
          "My goal is to $goal. I know it won't be perfect, but I'm proud of myself for starting. "
          "Let's do this!",
      "Hey everyone! $name here again. Today I'm working on bringing more energy and positivity. "
          "I'm one step closer to $goal. Each day I show up, I'm proving to myself that I can do this!",
      "What's up! It's $name and I'm on my final warmup before the 30-day challenge begins. "
          "I've already grown so much just by practicing these warmups. "
          "My goal of $goal feels more achievable every day. Let's crush this!",
    ];

    return scripts[warmupIndex.clamp(0, 2)];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider, width: 1.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                color: AppColors.primaryOlive,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'NEED INSPIRATION? TRY THIS:',
                style: AppTypography.uppercaseLabel(
                  color: AppColors.primaryOlive,
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '"${_getSampleScript()}"',
            style: AppTypography.body(
              color: AppColors.primaryText,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

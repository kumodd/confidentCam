import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
      icon: Icons.visibility,
      text: "Look at the camera lens like it's your best friend",
      category: "Eye Contact",
    ),
    CoachTip(
      icon: Icons.volume_up,
      text: "Project your voice - speak 20% louder than usual",
      category: "Voice",
    ),
    CoachTip(
      icon: Icons.sentiment_satisfied,
      text: "Smile gently - it relaxes your face and voice",
      category: "Expression",
    ),
    CoachTip(
      icon: Icons.speed,
      text: "Slow down - we all speak faster when nervous",
      category: "Pacing",
    ),
    CoachTip(
      icon: Icons.air,
      text: "Take a breath before starting - it calms the nerves",
      category: "Breathing",
    ),
    CoachTip(
      icon: Icons.emoji_emotions,
      text: "Imagine you're talking to a close friend",
      category: "Connection",
    ),
    CoachTip(
      icon: Icons.gesture,
      text: "Use hand gestures naturally - they add energy",
      category: "Body Language",
    ),
    CoachTip(
      icon: Icons.self_improvement,
      text: "Imperfect is perfect - authenticity wins",
      category: "Mindset",
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
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                widget.isRecording
                    ? Colors.red.withValues(alpha: 0.5)
                    : const Color(0xFF22D3EE).withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color:
                    widget.isRecording
                        ? Colors.red.withValues(alpha: 0.2)
                        : const Color(0xFF22D3EE).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                tip.icon,
                color:
                    widget.isRecording ? Colors.red : const Color(0xFF22D3EE),
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
                    style: TextStyle(
                      color:
                          widget.isRecording
                              ? Colors.red
                              : const Color(0xFF22D3EE),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tip.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.touch_app,
              color: Colors.white.withValues(alpha: 0.3),
              size: 16,
            ),
          ],
        ),
      ).animate(key: ValueKey(_currentTipIndex)).fadeIn(duration: 300.ms),
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
      // Warmup 0 - Breathing/Introduction
      "Hi, I'm $name and this is my first step toward becoming confident on camera. "
          "My goal is to $goal. I know it won't be perfect, but I'm proud of myself for starting. "
          "Let's do this!",

      // Warmup 1 - Smile/Energy
      "Hey everyone! $name here again. Today I'm working on bringing more energy and positivity. "
          "I'm one step closer to $goal. Each day I show up, I'm proving to myself that I can do this!",

      // Warmup 2 - Full warmup
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
        color: const Color(0xFF6366F1).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF6366F1).withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.lightbulb_outline,
                color: Color(0xFFFBBF24),
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                'Need inspiration? Try this:',
                style: TextStyle(
                  color: Color(0xFFFBBF24),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '"${_getSampleScript()}"',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

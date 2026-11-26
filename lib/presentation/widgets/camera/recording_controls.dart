import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Unified bottom camera capture controls shared by Warmup, 30-Day Challenge,
/// and Content Creator recording flows.
class RecordingControls extends StatelessWidget {
  final bool isRecording;
  final bool isInitializing;
  final int recordingSeconds;

  /// When provided, displays a countdown progress bar during recording
  /// (e.g., for timed warmup sessions).
  final int? progressTargetSeconds;

  final VoidCallback onStartCountdown;
  final VoidCallback onStopRecording;

  const RecordingControls({
    super.key,
    required this.isRecording,
    required this.isInitializing,
    required this.recordingSeconds,
    this.progressTargetSeconds,
    required this.onStartCountdown,
    required this.onStopRecording,
  });

  @override
  Widget build(BuildContext context) {
    final targetSeconds = progressTargetSeconds;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isRecording && targetSeconds != null && targetSeconds > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: (recordingSeconds / targetSeconds).clamp(0.0, 1.0),
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.error),
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 8),
                Text(
                  '${math.max(0, targetSeconds - recordingSeconds)}s remaining',
                  style: AppTypography.bodyStrong(
                    color: const Color(0xFFF7F8F0),
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        if (isRecording && targetSeconds != null && targetSeconds > 0)
          const SizedBox(height: 14),
        Center(
          child:
              isRecording
                  ? Semantics(
                    label: 'Stop Recording',
                    button: true,
                    child: GestureDetector(
                      onTap: onStopRecording,
                      child: Container(
                        width: 78,
                        height: 78,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F8F0),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.error, width: 4),
                        ),
                        child: Center(
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                  : Semantics(
                    label: 'Start Recording',
                    button: true,
                    child: GestureDetector(
                      onTap: isInitializing ? null : onStartCountdown,
                      child: Container(
                        width: 78,
                        height: 78,
                        decoration: BoxDecoration(
                          color:
                              isInitializing
                                  ? AppColors.mutedText
                                  : AppColors.primaryOlive,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFF7F8F0),
                            width: 3.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.videocam_rounded,
                          color: Color(0xFFF7F8F0),
                          size: 34,
                        ),
                      ),
                    ),
                  ),
        ),
      ],
    );
  }
}

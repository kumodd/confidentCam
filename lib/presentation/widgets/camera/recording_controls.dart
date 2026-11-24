import 'package:confident_cam/presentation/screens/warmup/warmup_recording_screen.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../../domain/entities/warmup.dart';

class RecordingControls extends StatelessWidget {
  final bool isRecording;
  final bool isInitializing;
  final int recordingSeconds;
  final RecordingMode mode;
  final Warmup? warmup;
  final VoidCallback onStartCountdown;
  final VoidCallback onStopRecording;

  const RecordingControls({
    super.key,
    required this.isRecording,
    required this.isInitializing,
    required this.recordingSeconds,
    required this.mode,
    this.warmup,
    required this.onStartCountdown,
    required this.onStopRecording,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (isRecording && mode == RecordingMode.warmup && warmup != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: recordingSeconds / warmup!.durationSeconds,
                  backgroundColor: AppColors.cardSurface.withValues(alpha: 0.4),
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.error),
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 8),
                Text(
                  '${max(0, warmup!.durationSeconds - recordingSeconds)}s remaining',
                  style: AppTypography.bodyStrong(
                    color: AppColors.background,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        Center(
          child: isRecording
              ? GestureDetector(
                  onTap: onStopRecording,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.background,
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
                )
              : GestureDetector(
                  onTap: isInitializing ? null : onStartCountdown,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: isInitializing
                          ? AppColors.mutedText
                          : AppColors.primaryOlive,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.background,
                        width: 3.5,
                      ),
                    ),
                    child: Icon(
                      Icons.videocam_rounded,
                      color: AppColors.background,
                      size: 36,
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  int max(int a, int b) => a > b ? a : b;
}

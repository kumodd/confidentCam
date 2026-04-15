import 'package:confident_cam/presentation/screens/warmup/warmup_recording_screen.dart';
import 'package:flutter/material.dart';

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
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 8),
                Text(
                  '${max(0, warmup!.durationSeconds - recordingSeconds)}s remaining',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        Center(
          child:
              isRecording
                  ? GestureDetector(
                    onTap: onStopRecording,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.red, width: 4),
                      ),
                      child: Center(
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(6),
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
                        color:
                            isInitializing
                                ? Colors.grey
                                : const Color(0xFF22D3EE),
                        shape: BoxShape.circle,
                        boxShadow:
                            isInitializing
                                ? null
                                : [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF22D3EE,
                                    ).withValues(alpha: 0.4),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ],
                      ),
                      child: const Icon(
                        Icons.videocam_rounded,
                        color: Colors.white,
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

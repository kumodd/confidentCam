import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

import '../../../core/di/injection_container.dart';
import '../../../domain/entities/daily_completion.dart';
import '../../../domain/entities/user_progress.dart';
import '../../../domain/repositories/video_repository.dart';
import '../../bloc/daily_challenge/daily_challenge_bloc.dart';
import '../../bloc/daily_challenge/daily_challenge_event.dart';
import 'day_challenge_overview_screen.dart';

/// Screen showing details of a completed day.
class DayDetailsScreen extends StatefulWidget {
  final String userId;
  final int dayNumber;
  final DailyCompletion completion;
  final UserProgress progress;

  const DayDetailsScreen({
    super.key,
    required this.userId,
    required this.dayNumber,
    required this.completion,
    required this.progress,
  });

  @override
  State<DayDetailsScreen> createState() => _DayDetailsScreenState();
}

class _DayDetailsScreenState extends State<DayDetailsScreen> {
  VideoPlayerController? _controller;
  bool _isVideoLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  Future<void> _loadVideo() async {
    final videoRepo = sl<VideoRepository>();
    final result = await videoRepo.getFinalVideo(widget.dayNumber);

    result.fold(
      (failure) => debugPrint('Failed to load video: ${failure.message}'),
      (file) async {
        if (file != null && mounted) {
          _controller = VideoPlayerController.file(file);
          await _controller!.initialize();
          await _controller!.setLooping(true);
          if (mounted) {
            setState(() => _isVideoLoaded = true);
          }
        }
      },
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F0F1A), Color(0xFF1E1E2E)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // App bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios,
                        color: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(
                      'Day ${widget.dayNumber}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check, color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'Completed',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms),

              // Video preview
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child:
                        _isVideoLoaded && _controller != null
                            ? GestureDetector(
                              onTap: () {
                                if (_controller!.value.isPlaying) {
                                  _controller!.pause();
                                } else {
                                  _controller!.play();
                                }
                                setState(() {});
                              },
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  AspectRatio(
                                    aspectRatio: _controller!.value.aspectRatio,
                                    child: VideoPlayer(_controller!),
                                  ),
                                  if (!_controller!.value.isPlaying)
                                    Container(
                                      width: 72,
                                      height: 72,
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.5,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.play_arrow,
                                        color: Colors.white,
                                        size: 48,
                                      ),
                                    ),
                                ],
                              ),
                            )
                            : Container(
                              color: Colors.black26,
                              child: const Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(
                                      color: Colors.white,
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'Loading video...',
                                      style: TextStyle(color: Colors.white54),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                  ),
                ),
              ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

              // Details section
              Expanded(
                flex: 2,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Completion date
                      _buildDetailRow(
                        icon: Icons.calendar_today,
                        label: 'Completed on',
                        value: DateFormat(
                          'MMMM d, yyyy',
                        ).format(widget.completion.completedAt),
                      ),
                      const SizedBox(height: 16),

                      // Duration
                      if (widget.completion.durationSeconds != null)
                        _buildDetailRow(
                          icon: Icons.timer,
                          label: 'Duration',
                          value: _formatDuration(
                            widget.completion.durationSeconds!,
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Checklist summary
                      if (widget.completion.checklistResponses.isNotEmpty)
                        _buildDetailRow(
                          icon: Icons.check_box,
                          label: 'Self-reflection',
                          value:
                              '${widget.completion.checklistResponses.length} items checked',
                        ),
                      const SizedBox(height: 32),

                      // Re-record button (only if this is current day and can record)
                      if (_canReRecord())
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _reRecordDay,
                            icon: const Icon(Icons.replay),
                            label: const Text('Re-record This Day'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ).animate().fadeIn(delay: 400.ms, duration: 400.ms),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white54, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    if (mins > 0) {
      return '${mins}m ${secs}s';
    }
    return '${secs}s';
  }

  bool _canReRecord() {
    // Can only re-record if this day was completed today
    final now = DateTime.now();
    final completedDate = widget.completion.completedAt;
    final isSameDay =
        now.year == completedDate.year &&
        now.month == completedDate.month &&
        now.day == completedDate.day;
    return isSameDay;
  }

  void _reRecordDay() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder:
            (_) => BlocProvider(
              create:
                  (_) =>
                      sl<DailyChallengeBloc>()..add(
                        DayLoaded(
                          userId: widget.userId,
                          dayNumber: widget.dayNumber,
                        ),
                      ),
              child: DayChallengeOverviewScreen(
                userId: widget.userId,
                dayNumber: widget.dayNumber,
              ),
            ),
      ),
    );
  }
}

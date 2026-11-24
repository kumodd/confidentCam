import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/theme/app_theme.dart';
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
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  Future<void> _loadVideo() async {
    final videoRepo = sl<VideoRepository>();
    final result = await videoRepo.getFinalVideo(widget.dayNumber);

    if (_isDisposed) return;

    result.fold(
      (failure) => debugPrint('Failed to load video: ${failure.message}'),
      (file) async {
        if (file != null) {
          final controller = VideoPlayerController.file(file);
          await controller.initialize();

          if (_isDisposed) {
            controller.dispose();
            return;
          }

          await controller.setLooping(true);

          setState(() {
            _controller = controller;
            _isVideoLoaded = true;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Day ${widget.dayNumber}'),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(
              child: OlivePillBadge(
                label: 'Completed',
                icon: Icons.check_rounded,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardSurface,
                    borderRadius: AppRadii.cardLargeBorder,
                    border: Border.all(color: AppColors.divider, width: 1.5),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _isVideoLoaded && _controller != null
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
                                  width: 68,
                                  height: 68,
                                  decoration: BoxDecoration(
                                    color: AppColors.background.withValues(
                                      alpha: 0.9,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.play_arrow_rounded,
                                    color: AppColors.primaryOlive,
                                    size: 42,
                                  ),
                                ),
                            ],
                          ),
                        )
                      : Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(
                                color: AppColors.primaryOlive,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Loading video...',
                                style: AppTypography.body(),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: SageMetricCard(
                            icon: Icons.calendar_today_outlined,
                            iconColor: AppColors.secondaryGreen,
                            label: 'COMPLETED',
                            value: DateFormat('MMM d').format(
                              widget.completion.completedAt,
                            ),
                            subtitle: DateFormat('yyyy').format(
                              widget.completion.completedAt,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SageMetricCard(
                            icon: Icons.timer_outlined,
                            iconColor: AppColors.primaryOlive,
                            label: 'DURATION',
                            value: widget.completion.durationSeconds != null
                                ? _formatDuration(
                                    widget.completion.durationSeconds!,
                                  )
                                : 'Recorded',
                            subtitle:
                                '${widget.completion.checklistResponses.length} reflections',
                          ),
                        ),
                      ],
                    ),
                    if (_canReRecord()) ...[
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _reRecordDay,
                          icon: Icon(Icons.replay_rounded),
                          label: Text('Re-record This Day'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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
    final now = DateTime.now();
    final completedDate = widget.completion.completedAt;
    return now.year == completedDate.year &&
        now.month == completedDate.month &&
        now.day == completedDate.day;
  }

  void _reRecordDay() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<DailyChallengeBloc>()
            ..add(
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

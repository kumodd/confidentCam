import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_theme.dart';
import '../../bloc/daily_challenge/daily_challenge_bloc.dart';
import '../../bloc/daily_challenge/daily_challenge_event.dart';
import '../../bloc/daily_challenge/daily_challenge_state.dart';
import '../warmup/warmup_recording_screen.dart';
import 'day_review_screen.dart';

/// Day challenge overview screen - shows script and tips before recording.
class DayChallengeOverviewScreen extends StatefulWidget {
  final String userId;
  final int dayNumber;

  const DayChallengeOverviewScreen({
    super.key,
    required this.userId,
    required this.dayNumber,
  });

  @override
  State<DayChallengeOverviewScreen> createState() =>
      _DayChallengeOverviewScreenState();
}

class _DayChallengeOverviewScreenState
    extends State<DayChallengeOverviewScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<DailyChallengeBloc>().add(
              DayLoaded(userId: widget.userId, dayNumber: widget.dayNumber),
            );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Day ${widget.dayNumber}'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: BlocBuilder<DailyChallengeBloc, DailyChallengeState>(
          builder: (context, state) {
            if (state is DayChallengeLoading) {
              return Center(
                child: CircularProgressIndicator(
                  color: AppColors.primaryOlive,
                ),
              );
            }

            if (state is DayChallengeReady) {
              return _buildContent(state);
            }

            if (state is DayChallengeError) {
              return _buildError(state.message);
            }

            return Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryOlive,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent(DayChallengeReady state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Day ${widget.dayNumber} Challenge',
                      style: AppTypography.headingLarge(fontSize: 25),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Review your script and tips, then start recording!',
                      style: AppTypography.body(),
                    ),
                  ],
                ),
              ),
              OlivePillBadge(label: 'Day ${widget.dayNumber}/30'),
            ],
          ),
          const SizedBox(height: 16),

          // Primary 1-tap Start Recording CTA surfaced immediately at top
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _startRecording(state),
              icon: const Icon(Icons.videocam_rounded, size: 21),
              label: Text(
                state.takes.isNotEmpty
                    ? 'Record New Take (${state.takes.length} saved)'
                    : 'Start Recording Now',
              ),
            ),
          ),

          if (state.takes.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _previewExistingTakes(state),
                icon: Icon(
                  Icons.play_circle_outline_rounded,
                  color: AppColors.secondaryGreen,
                ),
                label: Text(
                  'Preview ${state.takes.length} Take${state.takes.length > 1 ? 's' : ''}',
                ),
              ),
            ),
          ],

          const SizedBox(height: 18),

          // Script Card
          _buildScriptCard(state.script.fullText),

          const SizedBox(height: 20),

          // Tips Section
          _buildTipsSection(),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _showFullScript(state.script.fullText),
              child: const Text('View Full Script'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildScriptCard(String script) {
    final preview =
        script.length > 220 ? '${script.substring(0, 220)}...' : script;

    return SageCard(
      padding: EdgeInsets.zero,
      onTap: () => _showFullScript(script),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  Icons.description_outlined,
                  color: AppColors.primaryOlive,
                  size: 20,
                ),
                Text(
                  'TELEPROMPTER SCRIPT',
                  style: AppTypography.uppercaseLabel(
                    fontSize: 11,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1.3, color: AppColors.divider),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  preview,
                  style: AppTypography.body(
                    color: AppColors.primaryText,
                    fontSize: 14.5,
                  ),
                ),
                if (script.length > 220) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Tap to view full script',
                    style: AppTypography.bodyStrong(
                      color: AppColors.secondaryGreen,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SageSectionHeader(title: 'QUICK COACHING TIPS'),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: SageMetricCard(
                icon: Icons.visibility_outlined,
                iconColor: AppColors.secondaryGreen,
                label: 'FOCUS',
                value: 'Eye Contact',
                subtitle: 'Look at the lens',
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: SageMetricCard(
                icon: Icons.speed_outlined,
                iconColor: AppColors.primaryOlive,
                label: 'PACING',
                value: 'Natural',
                subtitle: 'Pause & breathe',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SageMetricCard(
                icon: Icons.sentiment_satisfied_outlined,
                iconColor: AppColors.primaryOlive,
                label: 'ENERGY',
                value: 'Expressive',
                subtitle: 'Show personality',
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: SageMetricCard(
                icon: Icons.replay_rounded,
                iconColor: AppColors.secondaryGreen,
                label: 'PRACTICE',
                value: 'Multi-Take',
                subtitle: 'Retry anytime',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SageCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
                size: 52,
              ),
              const SizedBox(height: 16),
              Text(
                'Failed to load challenge',
                style: AppTypography.headingMedium(),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: AppTypography.body(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  context.read<DailyChallengeBloc>().add(
                        DayLoaded(
                          userId: widget.userId,
                          dayNumber: widget.dayNumber,
                        ),
                      );
                },
                child: Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startRecording(DayChallengeReady state) {
    // Simplified recording workflow: launch camera immediately without a
    // redundant re-record confirmation dialog (previous takes stay preserved).
    _navigateToRecording(state);
  }

  void _navigateToRecording(DayChallengeReady state) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<DailyChallengeBloc>(),
          child: WarmupRecordingScreen.dailyChallenge(
            userId: widget.userId,
            dayNumber: widget.dayNumber,
            script: state.script.fullText,
          ),
        ),
      ),
    ).then((videoPath) {
      if (videoPath != null && videoPath is String && mounted) {
        context.read<DailyChallengeBloc>().add(RecordingStopped(videoPath));

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => BlocProvider.value(
              value: context.read<DailyChallengeBloc>(),
              child: DayReviewScreen(
                dayNumber: widget.dayNumber,
                userId: widget.userId,
              ),
            ),
          ),
        );
      }
    });
  }

  void _previewExistingTakes(DayChallengeReady state) {
    context.read<DailyChallengeBloc>().add(PreviewTakesRequested());
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<DailyChallengeBloc>(),
          child: DayReviewScreen(
            dayNumber: widget.dayNumber,
            userId: widget.userId,
          ),
        ),
      ),
    );
  }

  void _showFullScript(String script) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                children: [
                  Icon(
                    Icons.description_outlined,
                    color: AppColors.primaryOlive,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Day ${widget.dayNumber} Script',
                    style: AppTypography.headingMedium(fontSize: 19),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: Icon(
                      Icons.close_rounded,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: SageCard(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    script,
                    style: AppTypography.body(
                      color: AppColors.primaryText,
                      fontSize: 15.5,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Close'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

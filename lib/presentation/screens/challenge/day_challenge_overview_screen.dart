import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection_container.dart';
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
  Widget build(BuildContext context) {
    return BlocProvider<DailyChallengeBloc>(
      create: (context) => sl<DailyChallengeBloc>()..add(
        DayLoaded(userId: widget.userId, dayNumber: widget.dayNumber),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text('Day ${widget.dayNumber}'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0F0F1A), Color(0xFF1E1E2E)],
            ),
          ),
          child: SafeArea(
            child: BlocBuilder<DailyChallengeBloc, DailyChallengeState>(
              builder: (context, state) {
                if (state is DayChallengeLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state is DayChallengeReady) {
                  return _buildContent(state);
                }

                if (state is DayChallengeError) {
                  return _buildError(state.message);
                }

                // Show loading for initial state
                return const Center(child: CircularProgressIndicator());
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(DayChallengeReady state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            '🎬 Day ${widget.dayNumber} Challenge',
            style: Theme.of(context).textTheme.displayMedium,
          ).animate().fadeIn(duration: 400.ms),
          const SizedBox(height: 8),
          Text(
            'Review your script and tips, then start recording!',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: Colors.white54),
          ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
          const SizedBox(height: 32),

          // Script Card
          _buildScriptCard(state.script.fullText),

          const SizedBox(height: 24),

          // Tips Section
          _buildTipsSection(),

          const SizedBox(height: 32),

          // Start Recording Button
          ElevatedButton(
            onPressed: () => _startRecording(state),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.videocam_rounded),
                SizedBox(width: 12),
                Text('Start Recording', style: TextStyle(fontSize: 18)),
              ],
            ),
          ).animate().fadeIn(delay: 500.ms, duration: 400.ms),

          const SizedBox(height: 16),

          // Preview Existing Takes (if available)
          if (state.takes.isNotEmpty)
            OutlinedButton(
              onPressed: () => _previewExistingTakes(state),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.secondary,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.play_circle_outline,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Preview ${state.takes.length} Take${state.takes.length > 1 ? 's' : ''}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 550.ms, duration: 400.ms),

          if (state.takes.isNotEmpty) const SizedBox(height: 16),

          // View Full Script Button
          OutlinedButton(
            onPressed: () => _showFullScript(state.script.fullText),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text('View Full Script'),
          ).animate().fadeIn(delay: 600.ms, duration: 400.ms),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildScriptCard(String script) {
    final preview =
        script.length > 200 ? '${script.substring(0, 200)}...' : script;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
            Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.description_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Your Script',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            preview,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white70,
              height: 1.6,
            ),
          ),
          if (script.length > 200)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Tap "View Full Script" to see more',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white38,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 400.ms);
  }

  Widget _buildTipsSection() {
    const tips = [
      {
        'icon': Icons.visibility,
        'title': 'Look at the camera',
        'desc': 'Maintain eye contact with the lens',
      },
      {
        'icon': Icons.speed,
        'title': 'Speak naturally',
        'desc': 'Don\'t rush - pause when needed',
      },
      {
        'icon': Icons.emoji_emotions,
        'title': 'Show emotion',
        'desc': 'Let your personality shine through',
      },
      {
        'icon': Icons.replay,
        'title': 'It\'s okay to retry',
        'desc': 'You can re-record if needed',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '💡 Quick Tips',
          style: Theme.of(context).textTheme.titleLarge,
        ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
        const SizedBox(height: 16),
        ...tips.asMap().entries.map((entry) {
          final index = entry.key;
          final tip = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.secondary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      tip['icon'] as IconData,
                      color: Theme.of(context).colorScheme.secondary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tip['title'] as String,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tip['desc'] as String,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(
              delay: Duration(milliseconds: 350 + (index * 50)),
              duration: 300.ms,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(
              'Failed to load challenge',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(color: Colors.white54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                context.read<DailyChallengeBloc>().add(
                  DayLoaded(userId: widget.userId, dayNumber: widget.dayNumber),
                );
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  void _startRecording(DayChallengeReady state) {
    // Show warning if user already has recordings for this day
    if (state.takes.isNotEmpty) {
      _showReRecordWarning(state);
      return;
    }

    _navigateToRecording(state);
  }

  void _showReRecordWarning(DayChallengeReady state) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E2E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFFBBF24),
                  size: 28,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Re-record Day?',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
              ],
            ),
            content: Text(
              'You have already completed Day ${widget.dayNumber}!\n\n'
              'Recording again will add another take. Your previous recordings will still be saved.\n\n'
              'Do you want to continue?',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _navigateToRecording(state);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                ),
                child: const Text('Record Anyway'),
              ),
            ],
          ),
    );
  }

  void _navigateToRecording(DayChallengeReady state) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => BlocProvider.value(
              value: context.read<DailyChallengeBloc>(),
              child: WarmupRecordingScreen.dailyChallenge(
                userId: widget.userId,
                dayNumber: widget.dayNumber,
                script: state.script.fullText,
              ),
            ),
      ),
    ).then((videoPath) {
      // Handle returned video path from recording
      if (videoPath != null && videoPath is String && mounted) {
        context.read<DailyChallengeBloc>().add(RecordingStopped(videoPath));

        // Navigate to DayReviewScreen after recording
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (_) => BlocProvider.value(
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
    // Add event to transition to playback state
    context.read<DailyChallengeBloc>().add(const PreviewTakesRequested());
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => BlocProvider.value(
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
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => Container(
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: const BoxDecoration(
              color: Color(0xFF1E1E2E),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      const Icon(Icons.description, color: Colors.white54),
                      const SizedBox(width: 12),
                      Text(
                        'Day ${widget.dayNumber} Script',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close, color: Colors.white54),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12),
                // Script content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      script,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white70,
                        height: 1.8,
                      ),
                    ),
                  ),
                ),
                // Copy button
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                    ),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
    );
  }
}

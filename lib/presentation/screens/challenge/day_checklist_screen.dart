import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import '../../bloc/daily_challenge/daily_challenge_bloc.dart';
import '../../bloc/daily_challenge/daily_challenge_event.dart';
import '../../bloc/daily_challenge/daily_challenge_state.dart';

/// Day checklist screen to complete the day.
class DayChecklistScreen extends StatefulWidget {
  final int dayNumber;

  const DayChecklistScreen({super.key, required this.dayNumber});

  @override
  State<DayChecklistScreen> createState() => _DayChecklistScreenState();
}

class _DayChecklistScreenState extends State<DayChecklistScreen> {
  final Set<String> _checkedItems = {};

  static const _checklistItems = [
    'I looked at the camera lens',
    'I spoke clearly and at a good pace',
    'I felt more confident than yesterday',
    'I completed my script',
    'I showed genuine emotion',
    'I would share this with a friend',
  ];

  void _submit() {
    if (_checkedItems.length < 3) {
      EasyLoading.showInfo('Check at least 3 items to continue');
      return;
    }

    context
        .read<DailyChallengeBloc>()
        .add(ChecklistSubmitted(_checkedItems.toList()));

    // Delay to allow bloc to process, then finalize
    final bloc = context.read<DailyChallengeBloc>();
    Future.delayed(const Duration(milliseconds: 100), () {
      bloc.add(const DayFinalized());
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<DailyChallengeBloc, DailyChallengeState>(
      listener: (context, state) {
        if (state is DayChallengeLoading) {
          EasyLoading.show(status: 'Saving your progress...');
        } else if (state is DayChallengeComplete) {
          EasyLoading.dismiss();
          _showCompletionDialog(state);
        } else if (state is DayChallengeError) {
          EasyLoading.dismiss();
          EasyLoading.showError(state.message);
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Reflection'),
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
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Great work on Day ${widget.dayNumber}! 🎉',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ).animate().fadeIn(duration: 400.ms),
                    const SizedBox(height: 8),
                    Text(
                      'Take a moment to reflect on your recording. Check off what applies:',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.white54,
                          ),
                    ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
                    const SizedBox(height: 32),

                    // Checklist
                    Expanded(
                      child: ListView.builder(
                        itemCount: _checklistItems.length,
                        itemBuilder: (context, index) {
                          final item = _checklistItems[index];
                          final isChecked = _checkedItems.contains(item);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  if (isChecked) {
                                    _checkedItems.remove(item);
                                  } else {
                                    _checkedItems.add(item);
                                  }
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isChecked
                                      ? const Color(0xFF22C55E).withValues(alpha: 0.15)
                                      : const Color(0xFF1E1E2E),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isChecked
                                        ? const Color(0xFF22C55E)
                                        : Colors.white12,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: isChecked
                                            ? const Color(0xFF22C55E)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isChecked
                                              ? const Color(0xFF22C55E)
                                              : Colors.white38,
                                          width: 2,
                                        ),
                                      ),
                                      child: isChecked
                                          ? const Icon(
                                              Icons.check,
                                              color: Colors.white,
                                              size: 16,
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        item,
                                        style: TextStyle(
                                          color: isChecked
                                              ? Colors.white
                                              : Colors.white70,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ).animate().fadeIn(
                                  delay: (100 * index).ms,
                                  duration: 300.ms,
                                ),
                          );
                        },
                      ),
                    ),

                    // Progress indicator
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: LinearProgressIndicator(
                              value: _checkedItems.length / 3,
                              backgroundColor: Colors.white12,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _checkedItems.length >= 3
                                    ? const Color(0xFF22C55E)
                                    : Theme.of(context).colorScheme.primary,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${_checkedItems.length}/3 minimum',
                            style: TextStyle(
                              color: _checkedItems.length >= 3
                                  ? const Color(0xFF22C55E)
                                  : Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Complete button
                    ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _checkedItems.length >= 3
                            ? const Color(0xFF22C55E)
                            : Colors.grey,
                        minimumSize: const Size(double.infinity, 56),
                      ),
                      child: Text(
                        'Complete Day ${widget.dayNumber}',
                        style: const TextStyle(fontSize: 18),
                      ),
                    ).animate().fadeIn(delay: 400.ms, duration: 400.ms),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showCompletionDialog(DayChallengeComplete state) {
    final isMilestone = widget.dayNumber == 7 ||
        widget.dayNumber == 14 ||
        widget.dayNumber == 21 ||
        widget.dayNumber == 30;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: state.isChallengeComplete
                  ? const Icon(
                      Icons.emoji_events_rounded,
                      color: Color(0xFFFBBF24),
                      size: 48,
                    )
                  : const Icon(
                      Icons.check_circle,
                      color: Color(0xFF22C55E),
                      size: 48,
                    ),
            ),
            const SizedBox(height: 20),
            Text(
              state.isChallengeComplete
                  ? '🎉 Challenge Complete! 🎉'
                  : 'Day ${widget.dayNumber} Done!',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            if (state.newStreak > 1)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBBF24).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 24)),
                    const SizedBox(width: 8),
                    Text(
                      '${state.newStreak} day streak!',
                      style: const TextStyle(
                        color: Color(0xFFFBBF24),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Text(
              state.isChallengeComplete
                  ? "You've completed all 30 days! You are now camera confident! 🚀"
                  : isMilestone
                      ? 'Amazing milestone! Only ${30 - widget.dayNumber} days to go!'
                      : 'Keep going! You\'re building great habits.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white54,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                minimumSize: const Size(200, 48),
              ),
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}

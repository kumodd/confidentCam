import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

import '../../../core/theme/app_theme.dart';
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

    final bloc = context.read<DailyChallengeBloc>();
    Future.delayed(const Duration(milliseconds: 100), () {
      bloc.add(DayFinalized());
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
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text('Reflection'),
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Great work on Day ${widget.dayNumber}!',
                    style: AppTypography.headingLarge(fontSize: 25),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Take a moment to reflect on your recording. Check off what applies:',
                    style: AppTypography.body(),
                  ),
                  const SizedBox(height: 22),
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
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: isChecked
                                    ? AppColors.olivePillFill
                                    : AppColors.cardSurface,
                                borderRadius: AppRadii.cardBorder,
                                border: Border.all(
                                  color: isChecked
                                      ? AppColors.primaryOlive
                                      : AppColors.divider,
                                  width: isChecked ? 1.8 : 1.2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: isChecked
                                          ? AppColors.secondaryGreen
                                          : AppColors.background,
                                      borderRadius: BorderRadius.circular(7),
                                      border: Border.all(
                                        color: isChecked
                                            ? AppColors.secondaryGreen
                                            : AppColors.secondaryText,
                                        width: 1.6,
                                      ),
                                    ),
                                    child: isChecked
                                        ? Icon(
                                            Icons.check_rounded,
                                            color: AppColors.background,
                                            size: 16,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      item,
                                      style: AppTypography.bodyStrong(
                                        fontSize: 15,
                                        color: AppColors.primaryText,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              minHeight: 7,
                              value: (_checkedItems.length / 3).clamp(0.0, 1.0),
                              backgroundColor: AppColors.divider,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _checkedItems.length >= 3
                                    ? AppColors.secondaryGreen
                                    : AppColors.primaryOlive,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OlivePillBadge(
                          label: '${_checkedItems.length}/3 minimum',
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submit,
                      child: Text('Complete Day ${widget.dayNumber}'),
                    ),
                  ),
                ],
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.navPill,
                shape: BoxShape.circle,
              ),
              child: Icon(
                state.isChallengeComplete
                    ? Icons.emoji_events_outlined
                    : Icons.check_circle_outline_rounded,
                color: AppColors.secondaryGreen,
                size: 42,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              state.isChallengeComplete
                  ? 'Challenge Complete!'
                  : 'Day ${widget.dayNumber} Done!',
              style: AppTypography.headingMedium(fontSize: 21),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            if (state.newStreak > 1)
              OlivePillBadge(
                label: '${state.newStreak} day streak!',
                icon: Icons.local_fire_department_outlined,
              ),
            const SizedBox(height: 12),
            Text(
              state.isChallengeComplete
                  ? "You've completed all 30 days! You are now camera confident!"
                  : isMilestone
                      ? 'Amazing milestone! Only ${30 - widget.dayNumber} days to go!'
                      : "Keep going! You're building great habits.",
              style: AppTypography.body(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

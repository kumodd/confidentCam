import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/warmup.dart';
import '../../bloc/warmup/warmup_bloc.dart';
import '../../bloc/warmup/warmup_event.dart';
import '../../bloc/warmup/warmup_state.dart';

/// Warmup checklist screen to complete warmup.
class WarmupChecklistScreen extends StatefulWidget {
  final int warmupIndex;
  final String videoPath;

  const WarmupChecklistScreen({
    super.key,
    required this.warmupIndex,
    required this.videoPath,
  });

  @override
  State<WarmupChecklistScreen> createState() => _WarmupChecklistScreenState();
}

class _WarmupChecklistScreenState extends State<WarmupChecklistScreen> {
  late Warmup _warmup;
  final Set<int> _checkedItems = {};

  @override
  void initState() {
    super.initState();
    _warmup = Warmups.getByIndex(widget.warmupIndex)!;
  }

  void _submit() {
    if (_checkedItems.length < 2) {
      EasyLoading.showError('Please check at least 2 items');
      return;
    }

    final checkedStrings =
        _checkedItems.map((i) => _warmup.checklistItems[i]).toList();

    context.read<WarmupBloc>().add(
          WarmupChecklistSubmitted(
            warmupIndex: widget.warmupIndex,
            checkedItems: checkedStrings,
            videoPath: widget.videoPath,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<WarmupBloc, WarmupState>(
      listener: (context, state) {
        if (state is WarmupLoading) {
          EasyLoading.show(status: 'Saving...');
        } else if (state is WarmupDayComplete) {
          EasyLoading.dismiss();
          _showCompletionDialog(state);
        } else if (state is WarmupError) {
          EasyLoading.dismiss();
          EasyLoading.showError(state.message);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text('Quick Checklist'),
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
                  'How did it go?',
                  style: AppTypography.headingLarge(fontSize: 25),
                ),
                const SizedBox(height: 6),
                Text(
                  'Check off what you noticed about your warmup. No wrong answers!',
                  style: AppTypography.body(),
                ),
                const SizedBox(height: 22),
                Expanded(
                  child: ListView.builder(
                    itemCount: _warmup.checklistItems.length,
                    itemBuilder: (context, index) {
                      final item = _warmup.checklistItems[index];
                      final isChecked = _checkedItems.contains(index);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isChecked) {
                                _checkedItems.remove(index);
                              } else {
                                _checkedItems.add(index);
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
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submit,
                    child: Text('Complete Warmup ${widget.warmupIndex + 1}'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCompletionDialog(WarmupDayComplete state) {
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
                Icons.check_circle_outline_rounded,
                color: AppColors.secondaryGreen,
                size: 44,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              state.isLastWarmup ? 'All Warmups Complete!' : 'Great Job!',
              style: AppTypography.headingMedium(fontSize: 21),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              state.isLastWarmup
                  ? "You're ready to start your 30-day challenge!"
                  : 'Warmup ${widget.warmupIndex + 1} complete. Keep going!',
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
                child: Text(state.isLastWarmup ? 'Start Day 1' : 'Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

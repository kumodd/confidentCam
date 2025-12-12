import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

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

    final checkedStrings = _checkedItems.map((i) => _warmup.checklistItems[i]).toList();

    context.read<WarmupBloc>().add(WarmupChecklistSubmitted(
          warmupIndex: widget.warmupIndex,
          checkedItems: checkedStrings,
          videoPath: widget.videoPath,
        ));
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
        appBar: AppBar(
          title: const Text('Quick Checklist'),
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
                    'How did it go?',
                    style: Theme.of(context).textTheme.displayMedium,
                  ).animate().fadeIn(duration: 400.ms),
                  const SizedBox(height: 8),
                  Text(
                    'Check off what you noticed about your warmup. No wrong answers!',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white54,
                        ),
                  ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
                  const SizedBox(height: 32),

                  // Checklist items
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
                                        color:
                                            isChecked ? Colors.white : Colors.white70,
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

                  // Submit button
                  ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF22C55E),
                      minimumSize: const Size(double.infinity, 56),
                    ),
                    child: Text(
                      'Complete Warmup ${widget.warmupIndex + 1}',
                      style: const TextStyle(fontSize: 18),
                    ),
                  ).animate().fadeIn(delay: 400.ms, duration: 400.ms),
                ],
              ),
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
              child: const Icon(
                Icons.check_circle,
                color: Color(0xFF22C55E),
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              state.isLastWarmup ? 'All Warmups Complete!' : 'Great Job!',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              state.isLastWarmup
                  ? "You're ready to start your 30-day challenge!"
                  : 'Warmup ${widget.warmupIndex + 1} complete. Keep going!',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white54,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                // Pop back to warmup overview or dashboard
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                minimumSize: const Size(200, 48),
              ),
              child: Text(state.isLastWarmup ? 'Start Day 1' : 'Continue'),
            ),
          ],
        ),
      ),
    );
  }
}

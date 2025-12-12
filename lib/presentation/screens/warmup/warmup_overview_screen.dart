import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/warmup.dart';
import '../../bloc/warmup/warmup_bloc.dart';
import '../../bloc/warmup/warmup_event.dart';
import '../../bloc/warmup/warmup_state.dart';
import 'warmup_recording_screen.dart';

/// Warmup overview screen showing all 3 warmups.
class WarmupOverviewScreen extends StatefulWidget {
  final String? userName;
  final String? userGoal;
  final String? userLocation;

  const WarmupOverviewScreen({
    super.key,
    this.userName,
    this.userGoal,
    this.userLocation,
  });

  @override
  State<WarmupOverviewScreen> createState() => _WarmupOverviewScreenState();
}

class _WarmupOverviewScreenState extends State<WarmupOverviewScreen> {
  @override
  void initState() {
    super.initState();
    // Reload warmup status when screen appears
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reloadStatus();
    });
  }

  void _reloadStatus() {
    final bloc = context.read<WarmupBloc>();
    // Use the reload event which uses stored userId
    bloc.add(const WarmupReloadRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Get Ready'),
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
          child: BlocConsumer<WarmupBloc, WarmupState>(
            listener: (context, state) {
              if (state is WarmupDayComplete && state.isLastWarmup) {
                Navigator.of(context).pop();
              }
            },
            builder: (context, state) {
              if (state is WarmupLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (state is WarmupOverview) {
                return _WarmupList(
                  state: state,
                  userName: widget.userName,
                  userGoal: widget.userGoal,
                  userLocation: widget.userLocation,
                  onReload: _reloadStatus,
                );
              }

              if (state is AllWarmupsComplete) {
                return _AllComplete();
              }

              // For any intermediate state, trigger a reload and show shimmer
              if (state is WarmupInProgress ||
                  state is WarmupRecording ||
                  state is WarmupPlayback ||
                  state is WarmupDayComplete) {
                // Trigger reload
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _reloadStatus();
                });

                return const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Refreshing...',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                );
              }

              // Default fallback
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.refresh, color: Colors.white54, size: 48),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _reloadStatus,
                      child: const Text('Reload'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _WarmupList extends StatelessWidget {
  final WarmupOverview state;
  final String? userName;
  final String? userGoal;
  final String? userLocation;
  final VoidCallback onReload;

  const _WarmupList({
    required this.state,
    this.userName,
    this.userGoal,
    this.userLocation,
    required this.onReload,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Personalized header
          Text(
            userName != null ? 'Hey $userName! 👋' : 'Before You Start',
            style: Theme.of(context).textTheme.displayMedium,
          ).animate().fadeIn(duration: 400.ms),
          const SizedBox(height: 8),
          Text(
            'Complete these 3 warmups to unlock your 30-day challenge.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: Colors.white54, height: 1.5),
          ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
          const SizedBox(height: 32),

          // Warmup cards
          _WarmupCard(
            warmup: Warmups.breathing,
            index: 0,
            isComplete: state.warmup0Done,
            isUnlocked: true,
            userName: userName,
            userGoal: userGoal,
            userLocation: userLocation,
            onReload: onReload,
          ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
          const SizedBox(height: 16),

          _WarmupCard(
            warmup: Warmups.smile,
            index: 1,
            isComplete: state.warmup1Done,
            isUnlocked: state.warmup0Done,
            userName: userName,
            userGoal: userGoal,
            userLocation: userLocation,
            onReload: onReload,
          ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
          const SizedBox(height: 16),

          _WarmupCard(
            warmup: Warmups.energy,
            index: 2,
            isComplete: state.warmup2Done,
            isUnlocked: state.warmup1Done,
            userName: userName,
            userGoal: userGoal,
            userLocation: userLocation,
            onReload: onReload,
          ).animate().fadeIn(delay: 400.ms, duration: 400.ms),
        ],
      ),
    );
  }
}

class _WarmupCard extends StatelessWidget {
  final Warmup warmup;
  final int index;
  final bool isComplete;
  final bool isUnlocked;
  final String? userName;
  final String? userGoal;
  final String? userLocation;
  final VoidCallback onReload;

  const _WarmupCard({
    required this.warmup,
    required this.index,
    required this.isComplete,
    required this.isUnlocked,
    this.userName,
    this.userGoal,
    this.userLocation,
    required this.onReload,
  });

  @override
  Widget build(BuildContext context) {
    final canStart = isUnlocked && !isComplete;

    return GestureDetector(
      onTap:
          canStart
              ? () async {
                context.read<WarmupBloc>().add(WarmupStarted(index));

                // Navigate and wait for result
                await Navigator.of(context).push(
                  MaterialPageRoute(
                builder: (_) => BlocProvider.value(
                  value: context.read<WarmupBloc>(),
                  child: WarmupRecordingScreen(
                    warmupIndex: index,
                    userName: userName,
                    userGoal: userGoal,
                    userLocation: userLocation,
                  ),
                ),
                  ),
                );

                // Reload status when returning
                onReload();
              }
              : null,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                isComplete
                    ? const Color(0xFF22C55E)
                    : isUnlocked
                    ? const Color(0xFF22D3EE).withValues(alpha: 0.5)
                    : Colors.white12,
            width: isComplete ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color:
                    isComplete
                        ? const Color(0xFF22C55E).withValues(alpha: 0.2)
                        : isUnlocked
                        ? const Color(0xFF22D3EE).withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child:
                    isComplete
                        ? const Icon(
                          Icons.check,
                          color: Color(0xFF22C55E),
                          size: 28,
                        )
                        : isUnlocked
                        ? Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Color(0xFF22D3EE),
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                        : const Icon(
                          Icons.lock,
                          color: Colors.white24,
                          size: 24,
                        ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    warmup.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: isUnlocked ? Colors.white : Colors.white54,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    warmup.description,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.white38),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '~${warmup.durationSeconds ~/ 60} min',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (canStart)
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF22D3EE).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.arrow_forward,
                  color: Color(0xFF22D3EE),
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AllComplete extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.celebration_rounded,
                color: Color(0xFF22C55E),
                size: 48,
              ),
            ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
            const SizedBox(height: 24),
            Text(
              'All Warmups Complete!',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 12),
            Text(
              "You're ready to start your 30-day journey!",
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Colors.white54),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 300.ms),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
              child: const Text('Start Day 1'),
            ).animate().fadeIn(delay: 400.ms),
          ],
        ),
      ),
    );
  }
}

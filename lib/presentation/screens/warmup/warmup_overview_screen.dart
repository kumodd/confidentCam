import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reloadStatus();
    });
  }

  void _reloadStatus() {
    context.read<WarmupBloc>().add(WarmupReloadRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Get Ready'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: BlocConsumer<WarmupBloc, WarmupState>(
          listener: (context, state) {
            if (state is WarmupDayComplete && state.isLastWarmup) {
              Navigator.of(context).pop();
            }
          },
          builder: (context, state) {
            if (state is WarmupLoading) {
              return Center(
                child: CircularProgressIndicator(
                  color: AppColors.primaryOlive,
                ),
              );
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

            if (state is WarmupInProgress ||
                state is WarmupRecording ||
                state is WarmupPlayback ||
                state is WarmupDayComplete) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _reloadStatus();
              });

              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: AppColors.primaryOlive,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Refreshing...',
                      style: AppTypography.body(),
                    ),
                  ],
                ),
              );
            }

            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.refresh_rounded,
                    color: AppColors.secondaryText,
                    size: 44,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _reloadStatus,
                    child: Text('Reload'),
                  ),
                ],
              ),
            );
          },
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

  int get _doneCount {
    int c = 0;
    if (state.warmup0Done) c++;
    if (state.warmup1Done) c++;
    if (state.warmup2Done) c++;
    return c;
  }

  int get _nextWarmupIndex {
    if (!state.warmup0Done) return 0;
    if (!state.warmup1Done) return 1;
    return 2;
  }

  Future<void> _launchWarmup(BuildContext context, int index) async {
    context.read<WarmupBloc>().add(WarmupStarted(index));
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
    onReload();
  }

  @override
  Widget build(BuildContext context) {
    final done = _doneCount;
    final nextIdx = _nextWarmupIndex;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: OliveArcGauge(
              progress: done == 0 ? 0.33 : done / 3.0,
              primaryValue: '$done',
              primaryUnit: '/3',
              statusLabel: 'WARMUP SESSIONS',
              pillText: '${3 - done} Remaining',
              size: 256,
            ),
          ),
          const SizedBox(height: 12),
          SageStatusCard(
            title: userName != null ? 'Hey $userName!' : 'Before You Start',
            subtitle:
                'Tap Record to jump straight into Warmup 0${nextIdx + 1} ($done/3 complete).',
            actionLabel: done < 3 ? 'Record 0${nextIdx + 1}' : '3/3 Done',
            onActionTap: done < 3 ? () => _launchWarmup(context, nextIdx) : null,
          ),
          const SizedBox(height: 18),
          _WarmupCard(
            warmup: Warmups.breathing,
            index: 0,
            isComplete: state.warmup0Done,
            isUnlocked: true,
            userName: userName,
            userGoal: userGoal,
            userLocation: userLocation,
            onReload: onReload,
          ),
          const SizedBox(height: 14),
          _WarmupCard(
            warmup: Warmups.smile,
            index: 1,
            isComplete: state.warmup1Done,
            isUnlocked: state.warmup0Done,
            userName: userName,
            userGoal: userGoal,
            userLocation: userLocation,
            onReload: onReload,
          ),
          const SizedBox(height: 14),
          _WarmupCard(
            warmup: Warmups.energy,
            index: 2,
            isComplete: state.warmup2Done,
            isUnlocked: state.warmup1Done,
            userName: userName,
            userGoal: userGoal,
            userLocation: userLocation,
            onReload: onReload,
          ),
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

    return SageCard(
      padding: EdgeInsets.zero,
      borderColor: isComplete
          ? AppColors.secondaryGreen
          : canStart
              ? AppColors.olivePillBorder
              : null,
      onTap: canStart
          ? () async {
              context.read<WarmupBloc>().add(WarmupStarted(index));

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

              onReload();
            }
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isComplete
                          ? Icons.check_circle_rounded
                          : isUnlocked
                              ? Icons.play_circle_outline_rounded
                              : Icons.lock_outline_rounded,
                      size: 19,
                      color: isComplete
                          ? AppColors.secondaryGreen
                          : isUnlocked
                              ? AppColors.primaryOlive
                              : AppColors.mutedText,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'WARMUP 0${index + 1}',
                      style: AppTypography.uppercaseLabel(
                        fontSize: 11,
                        color: isComplete
                            ? AppColors.secondaryGreen
                            : AppColors.secondaryText,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                OlivePillBadge(
                  label: isComplete
                      ? 'Completed'
                      : '~${warmup.durationSeconds ~/ 60} min',
                ),
              ],
            ),
          ),
          Container(height: 1.3, color: AppColors.divider),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isComplete
                        ? AppColors.navPill
                        : isUnlocked
                            ? AppColors.olivePillFill
                            : AppColors.background,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: isComplete
                          ? AppColors.secondaryGreen
                          : isUnlocked
                              ? AppColors.olivePillBorder
                              : AppColors.divider,
                    ),
                  ),
                  child: Center(
                    child: isComplete
                        ? Icon(
                            Icons.check_rounded,
                            color: AppColors.secondaryGreen,
                            size: 24,
                          )
                        : isUnlocked
                            ? Text(
                                '${index + 1}',
                                style: GoogleFonts.manrope(
                                  color: AppColors.primaryOlive,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              )
                            : Icon(
                                Icons.lock_outline_rounded,
                                color: AppColors.mutedText,
                                size: 22,
                              ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        warmup.title,
                        style: AppTypography.sectionTitle(
                          fontSize: 17,
                          color: isUnlocked
                              ? AppColors.primaryText
                              : AppColors.mutedText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        warmup.description,
                        style: AppTypography.body(
                          fontSize: 13.5,
                          color: AppColors.secondaryText,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (canStart) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.secondaryText,
                    size: 24,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AllComplete extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SageCard(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: AppColors.navPill,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.celebration_outlined,
                  color: AppColors.secondaryGreen,
                  size: 42,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'All Warmups Complete!',
                style: AppTypography.headingLarge(fontSize: 24),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "You're ready to start your 30-day journey!",
                style: AppTypography.body(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Start Day 1'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

import '../../../core/utils/script_sentence_matcher.dart';
import '../../../domain/entities/warmup.dart';
import '../../bloc/warmup/warmup_bloc.dart';
import '../../bloc/warmup/warmup_event.dart';
import '../../bloc/warmup/warmup_state.dart';
import '../../widgets/camera/unified_recording_view.dart';
import 'warmup_playback_screen.dart';

/// Recording mode to distinguish between warmup and daily challenge.
enum RecordingMode { warmup, dailyChallenge }

/// Full-screen recording route for both Warmup sessions and the 30-Day
/// Challenge, powered by the shared [UnifiedRecordingView].
class WarmupRecordingScreen extends StatefulWidget {
  final RecordingMode mode;
  final int warmupIndex;
  final int? dayNumber;
  final String? userId;
  final String? script;
  final String? userName;
  final String? userGoal;
  final String? userLocation;

  const WarmupRecordingScreen({
    super.key,
    this.mode = RecordingMode.warmup,
    this.warmupIndex = 0,
    this.dayNumber,
    this.userId,
    this.script,
    this.userName,
    this.userGoal,
    this.userLocation,
  });

  factory WarmupRecordingScreen.warmup({
    Key? key,
    required int warmupIndex,
    String? userName,
    String? userGoal,
    String? userLocation,
  }) => WarmupRecordingScreen(
    key: key,
    mode: RecordingMode.warmup,
    warmupIndex: warmupIndex,
    userName: userName,
    userGoal: userGoal,
    userLocation: userLocation,
  );

  factory WarmupRecordingScreen.dailyChallenge({
    Key? key,
    required String userId,
    required int dayNumber,
    required String script,
  }) => WarmupRecordingScreen(
    key: key,
    mode: RecordingMode.dailyChallenge,
    userId: userId,
    dayNumber: dayNumber,
    script: script,
  );

  @override
  State<WarmupRecordingScreen> createState() => _WarmupRecordingScreenState();
}

class _WarmupRecordingScreenState extends State<WarmupRecordingScreen> {
  Warmup? _warmup;
  String? _cachedCustomScript;

  @override
  void initState() {
    super.initState();
    if (widget.mode == RecordingMode.warmup) {
      _warmup = Warmups.getByIndex(widget.warmupIndex);
    }
  }

  String _getFallbackWarmupScript() {
    final hasName =
        widget.userName != null && widget.userName!.trim().isNotEmpty;
    final name = hasName ? widget.userName!.trim() : '';
    final goal = widget.userGoal ?? 'become more confident on camera';
    final location = widget.userLocation ?? '';
    final locationText = location.isNotEmpty ? ' from $location' : '';

    switch (widget.warmupIndex) {
      case 0:
        final greeting =
            hasName ? "Hi, I'm $name$locationText! 👋" : 'Hi everyone! 👋';
        return '$greeting\n\n'
            'This is my very first step toward my goal to $goal.\n\n'
            "I know this won't be perfect, and that's completely okay.\n\n"
            "What matters is that I'm showing up and taking action.\n\n"
            "Let's begin this journey together!\n\n"
            'Remember to breathe, smile, and speak from the heart.\n\n'
            "You've got this!";
      case 1:
        final greeting =
            hasName
                ? "Hey, it's $name again! 😊"
                : "Hey everyone, I'm back! 😊";
        return '$greeting\n\n'
            "I completed my first warmup and I'm back for more.\n\n"
            "Today I'm focusing on bringing positive energy to the camera.\n\n"
            'My goal to $goal is getting closer with every practice.\n\n'
            "I'm learning to relax and be myself.\n\n"
            'Each day gets easier and more natural.\n\n'
            "Let's bring the energy!";
      case 2:
        final greeting =
            hasName ? "What's up! $name here 🔥" : "What's up everyone! 🔥";
        return '$greeting\n\n'
            'This is my final warmup before the 30-day challenge begins!\n\n'
            "I've already grown so much just by showing up these past few days.\n\n"
            "I'm ready to achieve my goal to $goal.\n\n"
            "I've learned that consistency beats perfection.\n\n"
            'Every recording makes me more confident.\n\n'
            "Let's finish strong and crush this challenge!";
      default:
        final greeting =
            hasName ? "Hi, I'm $name$locationText!" : 'Hi everyone!';
        return '$greeting\n\n'
            "I'm working toward my goal to $goal.\n\n"
            'Every time I practice, I get a little better.\n\n'
            "Let's do this!";
    }
  }

  Future<void> _handleRecordingCompleted(String videoPath) async {
    if (!mounted) return;
    if (widget.mode == RecordingMode.warmup) {
      context.read<WarmupBloc>().add(WarmupRecordingStopped(videoPath));
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder:
              (_) => BlocProvider.value(
                value: context.read<WarmupBloc>(),
                child: WarmupPlaybackScreen(
                  warmupIndex: widget.warmupIndex,
                  videoPath: videoPath,
                ),
              ),
        ),
      );
    } else {
      Navigator.of(context).pop(videoPath);
    }
  }

  Widget _buildRecordingView(String scriptText) {
    final isWarmup = widget.mode == RecordingMode.warmup;
    final maxDuration = isWarmup ? (_warmup?.durationSeconds ?? 60) : 300;
    final title =
        isWarmup
            ? (_warmup?.title ?? 'Warmup ${widget.warmupIndex + 1}')
            : 'Day ${widget.dayNumber}';

    return UnifiedRecordingView(
      scriptTitle: title,
      sections: [TeleprompterSection(body: scriptText)],
      embedded: false,
      showCloseButton: true,
      showCoachTips: true,
      showQualitySelector: true,
      maxDurationSeconds: maxDuration,
      progressTargetSeconds: isWarmup ? _warmup?.durationSeconds : null,
      onRecordingStarted: () {
        if (isWarmup) {
          context.read<WarmupBloc>().add(WarmupRecordingStarted());
        }
      },
      onRecordingCompleted: _handleRecordingCompleted,
      onPermissionDenied: () {
        EasyLoading.dismiss();
        if (mounted) Navigator.of(context).pop();
      },
      onClose: () {
        if (mounted) Navigator.of(context).pop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mode == RecordingMode.warmup) {
      return BlocBuilder<WarmupBloc, WarmupState>(
        builder: (context, state) {
          if (state is WarmupInProgress && state.customScriptText != null) {
            _cachedCustomScript = state.customScriptText;
          } else if (state is WarmupRecording &&
              state.customScriptText != null) {
            _cachedCustomScript = state.customScriptText;
          }
          final scriptText = _cachedCustomScript ?? _getFallbackWarmupScript();
          return _buildRecordingView(scriptText);
        },
      );
    }

    return _buildRecordingView(widget.script ?? 'No script found');
  }
}

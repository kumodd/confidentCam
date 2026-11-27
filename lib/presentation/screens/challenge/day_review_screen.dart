import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/repositories/video_repository.dart';
import '../../bloc/daily_challenge/daily_challenge_bloc.dart';
import '../../bloc/daily_challenge/daily_challenge_event.dart';
import '../../bloc/daily_challenge/daily_challenge_state.dart';
import 'day_checklist_screen.dart';
import '../warmup/warmup_recording_screen.dart';

/// Review screen for selecting the best take.
class DayReviewScreen extends StatefulWidget {
  final int dayNumber;
  final String userId;

  const DayReviewScreen({
    super.key,
    required this.dayNumber,
    required this.userId,
  });

  @override
  State<DayReviewScreen> createState() => _DayReviewScreenState();
}

class _DayReviewScreenState extends State<DayReviewScreen> {
  VideoPlayerController? _controller;
  int _selectedTakeIndex = 0;
  List<VideoTake> _takes = [];
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadInitialState();
  }

  void _loadInitialState() {
    final state = context.read<DailyChallengeBloc>().state;
    if (state is DayChallengePlayback) {
      _takes = state.takes;
      _selectedTakeIndex = state.selectedTakeIndex;
      if (_takes.isNotEmpty) {
        _initVideo(_takes[_selectedTakeIndex].path);
      }
    }
  }

  Future<void> _initVideo(String path) async {
    setState(() => _isInitialized = false);

    try {
      await _controller?.dispose();
      _controller = null;

      final file = File(path);
      if (!await file.exists()) {
        throw Exception('Video file not found');
      }

      _controller = VideoPlayerController.file(file);
      await _controller!.initialize();
      await _controller!.setLooping(true);
      await _controller!.play();

      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      if (mounted) {
        EasyLoading.showError('Failed to load video preview');
        setState(() => _isInitialized = false);
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _selectTake(int index) {
    if (index == _selectedTakeIndex) return;

    setState(() {
      _selectedTakeIndex = index;
      _isInitialized = false;
    });

    context.read<DailyChallengeBloc>().add(TakeSelected(index));
    _initVideo(_takes[index].path);
  }

  void _deleteTake(int index) {
    if (_takes.length <= 1) {
      EasyLoading.showInfo('You need at least one take!');
      return;
    }

    if (index == _selectedTakeIndex && _controller != null) {
      _controller!.pause();
      setState(() {});
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Take?'),
        content: Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (index == _selectedTakeIndex && _controller != null) {
                _controller!.play();
                setState(() {});
              }
            },
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (index == _selectedTakeIndex) {
                _controller?.dispose();
                _controller = null;
                _isInitialized = false;
              }
              context.read<DailyChallengeBloc>().add(
                    TakeDeleted(_takes[index].path),
                  );
            },
            child: Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  void _continueToChecklist() {
    if (_takes.isEmpty) {
      EasyLoading.showError('No takes available');
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<DailyChallengeBloc>(),
          child: DayChecklistScreen(dayNumber: widget.dayNumber),
        ),
      ),
    );
  }

  void _handleBack() {
    context.read<DailyChallengeBloc>().add(
          DayLoaded(userId: widget.userId, dayNumber: widget.dayNumber),
        );
    Navigator.of(context).pop();
  }

  Future<void> _recordAnotherTake() async {
    if (_controller?.value.isPlaying == true) {
      await _controller?.pause();
    }
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: AppColors.primaryOlive,
              size: 26,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Record New Take?',
                style: AppTypography.headingMedium(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(
          'You already have ${_takes.length} take(s) for Day ${widget.dayNumber}.\n\n'
          'Recording another take will add to your collection. Do you want to continue?',
          style: AppTypography.body(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Record New Take'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final state = context.read<DailyChallengeBloc>().state;
    String script = '';
    if (state is DayChallengeReady) {
      script = state.script.fullText;
    } else if (state is DayChallengePlayback) {
      script = state.script.fullText;
    }

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<DailyChallengeBloc>(),
          child: WarmupRecordingScreen.dailyChallenge(
            userId: widget.userId,
            dayNumber: widget.dayNumber,
            script: script,
          ),
        ),
      ),
    );

    if (result != null && result is String && mounted) {
      context.read<DailyChallengeBloc>().add(RecordingStopped(result));
    }

    if (mounted) {
      context.read<DailyChallengeBloc>().add(PreviewTakesRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<DailyChallengeBloc, DailyChallengeState>(
      listener: (context, state) {
        if (state is DayChallengePlayback) {
          setState(() {
            _takes = state.takes;
            _selectedTakeIndex = state.selectedTakeIndex;
          });
          if (_takes.isNotEmpty && _selectedTakeIndex >= 0) {
            _initVideo(_takes[_selectedTakeIndex].path);
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text('Day ${widget.dayNumber} • Review'),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded),
            onPressed: _handleBack,
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _isInitialized && _controller != null
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
                                Center(
                                  child: AspectRatio(
                                    aspectRatio: _controller!.value.aspectRatio,
                                    child: VideoPlayer(_controller!),
                                  ),
                                ),
                                if (!_controller!.value.isPlaying)
                                  Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      color: AppColors.background.withValues(
                                        alpha: 0.9,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.play_arrow_rounded,
                                      color: AppColors.primaryOlive,
                                      size: 38,
                                    ),
                                  ),
                              ],
                            ),
                          )
                        : Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primaryOlive,
                            ),
                          ),
                  ),
                ),
              ),
              if (_takes.length > 1)
                SizedBox(
                  height: 92,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    itemCount: _takes.length,
                    itemBuilder: (context, index) {
                      final take = _takes[index];
                      final isSelected = index == _selectedTakeIndex;

                      return GestureDetector(
                        onTap: () => _selectTake(index),
                        onLongPress: () => _deleteTake(index),
                        child: Container(
                          width: 82,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.olivePillFill
                                : AppColors.cardSurface,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primaryOlive
                                  : AppColors.divider,
                              width: isSelected ? 1.8 : 1.2,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.videocam_outlined,
                                color: isSelected
                                    ? AppColors.primaryOlive
                                    : AppColors.secondaryText,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Take ${take.takeNumber}',
                                style: AppTypography.bodyStrong(
                                  color: isSelected
                                      ? AppColors.primaryOlive
                                      : AppColors.secondaryText,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
                child: SageCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        'Happy with this take?',
                        style: AppTypography.headingMedium(fontSize: 19),
                      ),
                      if (_takes.length > 1) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Long-press a take to delete it',
                          style: AppTypography.body(fontSize: 12.5),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _recordAnotherTake,
                              icon: Icon(Icons.add_rounded, size: 19),
                              label: Text('New Take'),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _continueToChecklist,
                              icon: Icon(
                                Icons.arrow_forward_rounded,
                                size: 19,
                              ),
                              label: Text('Use This'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

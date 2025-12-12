import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:video_player/video_player.dart';

import '../../../domain/repositories/video_repository.dart';
import '../../bloc/daily_challenge/daily_challenge_bloc.dart';
import '../../bloc/daily_challenge/daily_challenge_event.dart';
import '../../bloc/daily_challenge/daily_challenge_state.dart';
import 'day_checklist_screen.dart';
import 'day_recording_screen.dart';

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
      debugPrint('Error initializing video: $e');
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

    // Pause the video if deleting the currently playing take
    if (index == _selectedTakeIndex && _controller != null) {
      _controller!.pause();
      setState(() {});
    }

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete Take?'),
            content: const Text('This cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  // Resume playing if user cancelled and it was paused
                  if (index == _selectedTakeIndex && _controller != null) {
                    _controller!.play();
                    setState(() {});
                  }
                },
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  // Dispose controller if deleting current take to prevent resource issues
                  if (index == _selectedTakeIndex) {
                    _controller?.dispose();
                    _controller = null;
                    _isInitialized = false;
                  }
                  context.read<DailyChallengeBloc>().add(
                    TakeDeleted(_takes[index].path),
                  );
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
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
        builder:
            (_) => BlocProvider.value(
              value: context.read<DailyChallengeBloc>(),
              child: DayChecklistScreen(dayNumber: widget.dayNumber),
            ),
      ),
    );
  }

  void _handleBack() {
    // Reload day data to restore Ready state before popping
    context.read<DailyChallengeBloc>().add(
      DayLoaded(userId: widget.userId, dayNumber: widget.dayNumber),
    );
    Navigator.of(context).pop();
  }

  Future<void> _recordAnotherTake() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => BlocProvider.value(
              value: context.read<DailyChallengeBloc>(),
              child: DayRecordingScreen(
                userId: widget.userId,
                dayNumber: widget.dayNumber,
              ),
            ),
      ),
    );

    // Reload takes when returning from recording
    if (mounted) {
      context.read<DailyChallengeBloc>().add(const PreviewTakesRequested());
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
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text('Day ${widget.dayNumber} - Review'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: _handleBack,
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Video preview
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child:
                        _isInitialized && _controller != null
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
                                  AspectRatio(
                                    aspectRatio: _controller!.value.aspectRatio,
                                    child: VideoPlayer(_controller!),
                                  ),
                                  if (!_controller!.value.isPlaying)
                                    Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.5,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.play_arrow,
                                        color: Colors.white,
                                        size: 40,
                                      ),
                                    ),
                                ],
                              ),
                            )
                            : const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            ),
                  ),
                ),
              ),

              // Takes list
              if (_takes.length > 1)
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _takes.length,
                    itemBuilder: (context, index) {
                      final take = _takes[index];
                      final isSelected = index == _selectedTakeIndex;

                      return GestureDetector(
                        onTap: () => _selectTake(index),
                        onLongPress: () => _deleteTake(index),
                        child: Container(
                          width: 80,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E2E),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.white12,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.videocam,
                                color:
                                    isSelected ? Colors.white : Colors.white54,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Take ${take.takeNumber}',
                                style: TextStyle(
                                  color:
                                      isSelected
                                          ? Colors.white
                                          : Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: (50 * index).ms),
                      );
                    },
                  ),
                ),

              // Actions
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      'Happy with this take?',
                      style: Theme.of(context).textTheme.titleLarge,
                    ).animate().fadeIn(duration: 400.ms),
                    const SizedBox(height: 8),
                    if (_takes.length > 1)
                      Text(
                        'Long-press a take to delete it',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.white38),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _recordAnotherTake,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add),
                                SizedBox(width: 8),
                                Text('New Take'),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _continueToChecklist,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF22C55E),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Use This'),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

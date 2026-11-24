import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/warmup.dart';
import '../../bloc/warmup/warmup_bloc.dart';
import 'warmup_checklist_screen.dart';

/// Warmup playback screen to review recording.
class WarmupPlaybackScreen extends StatefulWidget {
  final int warmupIndex;
  final String videoPath;

  const WarmupPlaybackScreen({
    super.key,
    required this.warmupIndex,
    required this.videoPath,
  });

  @override
  State<WarmupPlaybackScreen> createState() => _WarmupPlaybackScreenState();
}

class _WarmupPlaybackScreenState extends State<WarmupPlaybackScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  late Warmup _warmup;

  @override
  void initState() {
    super.initState();
    _warmup = Warmups.getByIndex(widget.warmupIndex)!;
    _initVideo();
  }

  Future<void> _initVideo() async {
    _controller = VideoPlayerController.file(File(widget.videoPath));
    await _controller.initialize();
    await _controller.setLooping(true);
    await _controller.play();

    if (mounted) {
      setState(() => _isInitialized = true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _retryRecording() {
    Navigator.of(context).pop();
  }

  void _continueToChecklist() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<WarmupBloc>(),
          child: WarmupChecklistScreen(
            warmupIndex: widget.warmupIndex,
            videoPath: widget.videoPath,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_warmup.title),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardSurface,
                    borderRadius: AppRadii.cardLargeBorder,
                    border: Border.all(color: AppColors.divider, width: 1.5),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _isInitialized
                      ? GestureDetector(
                          onTap: () {
                            if (_controller.value.isPlaying) {
                              _controller.pause();
                            } else {
                              _controller.play();
                            }
                            setState(() {});
                          },
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              AspectRatio(
                                aspectRatio: _controller.value.aspectRatio,
                                child: VideoPlayer(_controller),
                              ),
                              if (!_controller.value.isPlaying)
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
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
              child: SageCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      'Happy with your warmup?',
                      style: AppTypography.headingMedium(fontSize: 19),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Don't worry about being perfect! This is just practice.",
                      style: AppTypography.body(),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _retryRecording,
                            icon: Icon(Icons.refresh_rounded, size: 19),
                            label: Text('Try Again'),
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
                            label: Text('Continue'),
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
    );
  }
}

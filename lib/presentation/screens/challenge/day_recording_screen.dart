import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

import '../../../core/di/injection_container.dart';
import '../../../domain/entities/daily_script.dart';
import '../../../services/video_recording_service.dart';
import '../../bloc/daily_challenge/daily_challenge_bloc.dart';
import '../../bloc/daily_challenge/daily_challenge_event.dart';
import '../../bloc/daily_challenge/daily_challenge_state.dart';
import '../../bloc/settings/settings_bloc.dart';
import '../../widgets/camera/coach_tips_card.dart';
import 'day_review_screen.dart';

/// Daily challenge recording screen with teleprompter.
class DayRecordingScreen extends StatefulWidget {
  final String userId;
  final int dayNumber;

  const DayRecordingScreen({
    super.key,
    required this.userId,
    required this.dayNumber,
  });

  @override
  State<DayRecordingScreen> createState() => _DayRecordingScreenState();
}

class _DayRecordingScreenState extends State<DayRecordingScreen> {
  late VideoRecordingService _recordingService;
  bool _isInitializing = true;
  bool _isRecording = false;
  int _countdown = 0;
  bool _showingCountdown = false;
  Timer? _countdownTimer;
  Timer? _recordingTimer;
  int _recordingSeconds = 0;
  bool _showTeleprompter = true;

  // Teleprompter settings
  double _scrollSpeed = 1.0;
  double _teleprompterHeight = 0.3;
  double _teleprompterOpacity = 0.85;

  @override
  void initState() {
    super.initState();
    _recordingService = sl<VideoRecordingService>();
    _initCamera();
    _loadSettings();
  }

  void _loadSettings() {
    final settingsState = context.read<SettingsBloc>().state;
    if (settingsState is SettingsLoadSuccess) {
      setState(() {
        _scrollSpeed = settingsState.settings.teleprompterSpeed;
        _teleprompterHeight = settingsState.settings.teleprompterHeight;
        _teleprompterOpacity = settingsState.settings.teleprompterOpacity;
      });
    }
  }

  Future<void> _initCamera() async {
    try {
      await _recordingService.initialize(useFrontCamera: true);
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    } catch (e) {
      EasyLoading.showError('Failed to initialize camera');
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _recordingTimer?.cancel();
    _recordingService.dispose();
    super.dispose();
  }

  void _startCountdown() {
    setState(() {
      _countdown = 3;
      _showingCountdown = true;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 1) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
        setState(() {
          _showingCountdown = false;
          _countdown = 0;
        });
        _startRecording();
      }
    });
  }

  Future<void> _startRecording() async {
    setState(() {
      _isRecording = true;
      _recordingSeconds = 0;
    });

    context.read<DailyChallengeBloc>().add(const RecordingStarted());
    await _recordingService.startRecording();

    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _recordingSeconds++);
    });
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();

    if (!_isRecording) return;

    setState(() => _isRecording = false);

    final path = await _recordingService.stopRecording();

    if (path != null && mounted) {
      // Show loading while video is being saved
      EasyLoading.show(status: 'Saving video...');
      context.read<DailyChallengeBloc>().add(RecordingStopped(path));
    } else if (mounted) {
      EasyLoading.showError('Recording failed');
      Navigator.of(context).pop();
    }
  }

  void _handleClose() {
    _countdownTimer?.cancel();
    _recordingTimer?.cancel();
    if (_isRecording) {
      _recordingService.stopRecording();
    }
    Navigator.of(context).pop();
  }

  void _adjustSpeed(double delta) {
    setState(() {
      _scrollSpeed = (_scrollSpeed + delta).clamp(0.5, 3.0);
    });
    context.read<SettingsBloc>().add(TeleprompterSpeedUpdated(_scrollSpeed));
  }

  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final teleprompterHeightPx = screenHeight * _teleprompterHeight;

    return BlocConsumer<DailyChallengeBloc, DailyChallengeState>(
      listener: (context, state) {
        if (state is DayChallengePlayback) {
          EasyLoading.dismiss();
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder:
                  (_) => BlocProvider.value(
                    value: context.read<DailyChallengeBloc>(),
                    child: DayReviewScreen(
                      dayNumber: widget.dayNumber,
                      userId: widget.userId,
                    ),
                  ),
            ),
          );
        } else if (state is DayChallengeError) {
          EasyLoading.dismiss();
          EasyLoading.showError(state.message);
        }
      },
      builder: (context, state) {
        // Get script from state
        DailyScript? script;
        if (state is DayChallengeReady) {
          script = state.script;
        } else if (state is DayChallengeRecording) {
          script = state.script;
        }

        final scriptText = script?.fullText ?? '';

        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Camera preview
                if (!_isInitializing && _recordingService.controller != null)
                  CameraPreview(_recordingService.controller!)
                else
                  const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 16),
                        Text(
                          'Preparing camera...',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
                  ),

                // Top bar
                Positioned(
                  top: 8,
                  left: 8,
                  right: 8,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 28,
                        ),
                        onPressed: _handleClose,
                      ),
                      if (_isRecording)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                  )
                                  .animate(
                                    onComplete: (c) => c.repeat(reverse: true),
                                  )
                                  .fade(duration: 500.ms),
                              const SizedBox(width: 8),
                              Text(
                                _formatDuration(_recordingSeconds),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Text(
                          'Day ${widget.dayNumber}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      // Toggle teleprompter button
                      IconButton(
                        icon: Icon(
                          _showTeleprompter
                              ? Icons.text_fields
                              : Icons.text_fields_outlined,
                          color:
                              _showTeleprompter ? Colors.white : Colors.white38,
                        ),
                        onPressed:
                            () => setState(
                              () => _showTeleprompter = !_showTeleprompter,
                            ),
                      ),
                    ],
                  ),
                ),

                // TELEPROMPTER at top (always visible when enabled, not just recording)
                if (_showTeleprompter &&
                    scriptText.isNotEmpty &&
                    !_showingCountdown)
                  Positioned(
                    top: 56,
                    left: 12,
                    right: 12,
                    height: teleprompterHeightPx,
                    child: _DayTeleprompter(
                      scriptText: scriptText,
                      isRecording: _isRecording,
                      scrollSpeed: _scrollSpeed,
                      opacity: _teleprompterOpacity,
                      onSpeedChange: _adjustSpeed,
                    ),
                  ),

                // Countdown overlay
                if (_showingCountdown) _buildCountdownOverlay(),

                // Coach tips above bottom controls
                if (!_showingCountdown)
                  Positioned(
                    bottom: 150,
                    left: 16,
                    right: 16,
                    child: CoachTipsCard(isRecording: _isRecording),
                  ),

                // Bottom controls
                _buildBottomControls(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCountdownOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child:
            Text(
              '$_countdown',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 120,
                fontWeight: FontWeight.bold,
              ),
            ).animate().scale(duration: 200.ms).fadeIn(),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: 32,
      left: 0,
      right: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Record/Stop button
          GestureDetector(
            onTap: () {
              if (_isRecording) {
                _stopRecording();
              } else if (!_showingCountdown) {
                _startCountdown();
              }
            },
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
              ),
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: _isRecording ? 32 : 60,
                  height: _isRecording ? 32 : 60,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(_isRecording ? 8 : 30),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _isRecording ? 'Tap to stop' : 'Tap to record',
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

/// Teleprompter widget for daily challenge with auto-scroll.
class _DayTeleprompter extends StatefulWidget {
  final String scriptText;
  final bool isRecording;
  final double scrollSpeed;
  final double opacity;
  final Function(double) onSpeedChange;

  const _DayTeleprompter({
    required this.scriptText,
    required this.isRecording,
    required this.scrollSpeed,
    required this.opacity,
    required this.onSpeedChange,
  });

  @override
  State<_DayTeleprompter> createState() => _DayTeleprompterState();
}

class _DayTeleprompterState extends State<_DayTeleprompter> {
  final ScrollController _scrollController = ScrollController();
  Timer? _scrollTimer;
  bool _isScrolling = false;

  @override
  void didUpdateWidget(_DayTeleprompter oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Start scrolling when recording begins
    if (widget.isRecording && !oldWidget.isRecording) {
      _startAutoScroll();
    }

    // Stop scrolling when recording ends
    if (!widget.isRecording && oldWidget.isRecording) {
      _stopAutoScroll();
    }

    // Restart scroll if speed changed during recording
    if (widget.isRecording && widget.scrollSpeed != oldWidget.scrollSpeed) {
      _stopAutoScroll();
      _startAutoScroll();
    }
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    if (_isScrolling) return;
    _isScrolling = true;

    final pixelsPerTick = 0.5 * widget.scrollSpeed;
    const tickDuration = Duration(milliseconds: 16);

    _scrollTimer = Timer.periodic(tickDuration, (timer) {
      if (!_scrollController.hasClients) return;

      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.offset;

      if (currentScroll < maxScroll) {
        _scrollController.jumpTo(currentScroll + pixelsPerTick);
      } else {
        timer.cancel();
        _isScrolling = false;
      }
    });
  }

  void _stopAutoScroll() {
    _scrollTimer?.cancel();
    _isScrolling = false;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: widget.opacity * 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          // Speed controls
          if (!widget.isRecording)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.speed, color: Colors.white54, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Speed: ${widget.scrollSpeed.toStringAsFixed(1)}x',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(
                      Icons.remove,
                      color: Colors.white70,
                      size: 16,
                    ),
                    onPressed: () => widget.onSpeedChange(-0.25),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.add,
                      color: Colors.white70,
                      size: 16,
                    ),
                    onPressed: () => widget.onSpeedChange(0.25),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),
            ),
          // Script text
          Expanded(
            child: ShaderMask(
              shaderCallback: (bounds) {
                return LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.white,
                    Colors.white,
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.1, 0.9, 1.0],
                ).createShader(bounds);
              },
              blendMode: BlendMode.dstIn,
              child: SingleChildScrollView(
                controller: _scrollController,
                physics:
                    widget.isRecording
                        ? const NeverScrollableScrollPhysics()
                        : const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Text(
                  widget.scriptText,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: widget.opacity),
                    fontSize: 18,
                    height: 1.6,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

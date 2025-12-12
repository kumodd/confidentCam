import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

import '../../../core/di/injection_container.dart';
import '../../../domain/entities/warmup.dart';
import '../../../services/video_recording_service.dart';
import '../../bloc/settings/settings_bloc.dart';
import '../../bloc/warmup/warmup_bloc.dart';
import '../../bloc/warmup/warmup_event.dart';
import '../../widgets/camera/coach_tips_card.dart';
import 'warmup_playback_screen.dart';

/// Warmup recording screen with configurable teleprompter.
class WarmupRecordingScreen extends StatefulWidget {
  final int warmupIndex;
  final String? userName;
  final String? userGoal;
  final String? userLocation;

  const WarmupRecordingScreen({
    super.key,
    required this.warmupIndex,
    this.userName,
    this.userGoal,
    this.userLocation,
  });

  @override
  State<WarmupRecordingScreen> createState() => _WarmupRecordingScreenState();
}

class _WarmupRecordingScreenState extends State<WarmupRecordingScreen> {
  late VideoRecordingService _recordingService;
  bool _isInitializing = true;
  bool _isRecording = false;
  int _countdown = 3;
  bool _showingCountdown = false;
  Timer? _countdownTimer;
  Timer? _recordingTimer;
  int _recordingSeconds = 0;
  late Warmup _warmup;

  // Teleprompter settings (can be adjusted in real-time)
  double _currentSpeed = 1.0;
  double _currentHeight = 0.25;
  double _currentOpacity = 0.85;

  @override
  void initState() {
    super.initState();
    _warmup = Warmups.getByIndex(widget.warmupIndex)!;
    _recordingService = sl<VideoRecordingService>();
    _initCamera();
    _loadSettings();
  }

  void _loadSettings() {
    // Load settings from bloc if available
    final settingsState = context.read<SettingsBloc>().state;
    if (settingsState is SettingsLoadSuccess) {
      setState(() {
        _currentSpeed = settingsState.settings.teleprompterSpeed;
        _currentHeight = settingsState.settings.teleprompterHeight;
        _currentOpacity = settingsState.settings.teleprompterOpacity;
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
        setState(() => _showingCountdown = false);
        _startRecording();
      }
    });
  }

  Future<void> _startRecording() async {
    setState(() {
      _isRecording = true;
      _recordingSeconds = 0;
    });

    // Ensure bloc state is WarmupInProgress (handles retake scenario)
    context.read<WarmupBloc>().add(WarmupStarted(widget.warmupIndex));

    await _recordingService.startRecording();

    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _recordingSeconds++);

      if (_recordingSeconds >= _warmup.durationSeconds) {
        _stopRecording();
      }
    });
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();

    if (!_isRecording) return;

    setState(() => _isRecording = false);

    final path = await _recordingService.stopRecording();

    if (path != null && mounted) {
      context.read<WarmupBloc>().add(WarmupRecordingStopped(path));

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder:
              (_) => BlocProvider.value(
                value: context.read<WarmupBloc>(),
                child: WarmupPlaybackScreen(
                  warmupIndex: widget.warmupIndex,
                  videoPath: path,
                ),
              ),
        ),
      );
    } else if (mounted) {
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
      _currentSpeed = (_currentSpeed + delta).clamp(0.5, 3.0);
    });
    // Save to settings
    context.read<SettingsBloc>().add(TeleprompterSpeedUpdated(_currentSpeed));
  }

  // Height and opacity adjusted via settings sheet
  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final teleprompterHeight = screenHeight * _currentHeight;

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
                    ),
                  // Settings button (before recording)
                  if (!_isRecording && !_showingCountdown)
                    IconButton(
                      icon: const Icon(Icons.tune, color: Colors.white70),
                      onPressed: _showSettingsSheet,
                    )
                  else
                    const SizedBox(width: 48),
                ],
              ),
            ),

            // TELEPROMPTER AT TOP
            if (!_showingCountdown)
              Positioned(
                top: 56,
                left: 12,
                right: 12,
                height: teleprompterHeight,
                child: TeleprompterWidget(
                  userName: widget.userName,
                  userGoal: widget.userGoal,
                  userLocation: widget.userLocation,
                  warmupIndex: widget.warmupIndex,
                  warmupTitle: _warmup.title,
                  isRecording: _isRecording,
                  scrollSpeed: _currentSpeed,
                  opacity: _currentOpacity,
                  onSpeedChange: _adjustSpeed,
                ),
              ),

            // COACH TIPS AT BOTTOM
            if (!_isRecording && !_showingCountdown)
              Positioned(
                bottom: 140,
                left: 12,
                right: 12,
                child: CoachTipsCard(isRecording: false),
              ),

            // Countdown overlay
            if (_showingCountdown)
              Center(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$_countdown',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 64,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ).animate().scale(
                  begin: const Offset(1.2, 1.2),
                  end: const Offset(1, 1),
                  duration: 800.ms,
                ),
              ),

            // Bottom controls
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  if (_isRecording)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 48),
                      child: Column(
                        children: [
                          LinearProgressIndicator(
                            value: _recordingSeconds / _warmup.durationSeconds,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.red,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${_warmup.durationSeconds - _recordingSeconds}s remaining',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  Center(
                    child:
                        _isRecording
                            ? GestureDetector(
                              onTap: _stopRecording,
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.red,
                                    width: 4,
                                  ),
                                ),
                                child: Center(
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                ),
                              ),
                            )
                            : GestureDetector(
                              onTap: _isInitializing ? null : _startCountdown,
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color:
                                      _isInitializing
                                          ? Colors.grey
                                          : const Color(0xFF22D3EE),
                                  shape: BoxShape.circle,
                                  boxShadow:
                                      _isInitializing
                                          ? null
                                          : [
                                            BoxShadow(
                                              color: const Color(
                                                0xFF22D3EE,
                                              ).withValues(alpha: 0.4),
                                              blurRadius: 20,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                ),
                                child: const Icon(
                                  Icons.videocam_rounded,
                                  color: Colors.white,
                                  size: 36,
                                ),
                              ),
                            ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setSheetState) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Teleprompter Settings',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Speed slider
                      _buildSliderRow(
                        label: 'Scroll Speed',
                        value: _currentSpeed,
                        min: 0.5,
                        max: 3.0,
                        suffix: 'x',
                        onChanged: (v) {
                          setSheetState(() => _currentSpeed = v);
                          setState(() {});
                        },
                      ),
                      const SizedBox(height: 16),

                      // Height slider
                      _buildSliderRow(
                        label: 'Height',
                        value: _currentHeight * 100,
                        min: 15,
                        max: 50,
                        suffix: '%',
                        onChanged: (v) {
                          setSheetState(() => _currentHeight = v / 100);
                          setState(() {});
                        },
                      ),
                      const SizedBox(height: 16),

                      // Opacity slider
                      _buildSliderRow(
                        label: 'Opacity',
                        value: _currentOpacity * 100,
                        min: 50,
                        max: 100,
                        suffix: '%',
                        onChanged: (v) {
                          setSheetState(() => _currentOpacity = v / 100);
                          setState(() {});
                        },
                      ),
                      const SizedBox(height: 24),

                      // Save button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            // Save settings
                            context.read<SettingsBloc>().add(
                              TeleprompterSpeedUpdated(_currentSpeed),
                            );
                            context.read<SettingsBloc>().add(
                              TeleprompterHeightUpdated(_currentHeight),
                            );
                            context.read<SettingsBloc>().add(
                              TeleprompterOpacityUpdated(_currentOpacity),
                            );
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF22D3EE),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Save Settings'),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
          ),
    );
  }

  Widget _buildSliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required String suffix,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70)),
            Text(
              '${value.toStringAsFixed(1)}$suffix',
              style: const TextStyle(
                color: Color(0xFF22D3EE),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          activeColor: const Color(0xFF22D3EE),
          inactiveColor: Colors.white24,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// Teleprompter widget with auto-scroll during recording.
class TeleprompterWidget extends StatefulWidget {
  final String? userName;
  final String? userGoal;
  final String? userLocation;
  final int warmupIndex;
  final String warmupTitle;
  final bool isRecording;
  final double scrollSpeed;
  final double opacity;
  final Function(double) onSpeedChange;

  const TeleprompterWidget({
    super.key,
    this.userName,
    this.userGoal,
    this.userLocation,
    required this.warmupIndex,
    required this.warmupTitle,
    required this.isRecording,
    required this.scrollSpeed,
    required this.opacity,
    required this.onSpeedChange,
  });

  @override
  State<TeleprompterWidget> createState() => _TeleprompterWidgetState();
}

class _TeleprompterWidgetState extends State<TeleprompterWidget> {
  final ScrollController _scrollController = ScrollController();
  Timer? _scrollTimer;
  bool _isScrolling = false;

  @override
  void didUpdateWidget(TeleprompterWidget oldWidget) {
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

    // Speed: 1.0 = ~30 pixels per second, scales with speed setting
    final pixelsPerTick = 0.5 * widget.scrollSpeed;
    final tickDuration = const Duration(milliseconds: 16); // ~60fps

    _scrollTimer = Timer.periodic(tickDuration, (timer) {
      if (!_scrollController.hasClients) return;

      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.offset;

      if (currentScroll < maxScroll) {
        _scrollController.jumpTo(currentScroll + pixelsPerTick);
      } else {
        // Reached end, stop scrolling
        timer.cancel();
        _isScrolling = false;
      }
    });
  }

  void _stopAutoScroll() {
    _scrollTimer?.cancel();
    _isScrolling = false;
  }

  String _getPersonalizedScript() {
    final name = widget.userName ?? 'everyone';
    final goal = widget.userGoal ?? 'become more confident on camera';
    final location = widget.userLocation ?? '';
    final locationText = location.isNotEmpty ? ' from $location' : '';

    switch (widget.warmupIndex) {
      case 0:
        return "Hi, I'm $name$locationText! 👋\n\n"
            "This is my very first step toward my goal to $goal.\n\n"
            "I know this won't be perfect, and that's completely okay.\n\n"
            "What matters is that I'm showing up and taking action.\n\n"
            "Let's begin this journey together!\n\n"
            "Remember to breathe, smile, and speak from the heart.\n\n"
            "You've got this!";
      case 1:
        return "Hey, it's $name again! 😊\n\n"
            "I completed my first warmup and I'm back for more.\n\n"
            "Today I'm focusing on bringing positive energy to the camera.\n\n"
            "My goal to $goal is getting closer with every practice.\n\n"
            "I'm learning to relax and be myself.\n\n"
            "Each day gets easier and more natural.\n\n"
            "Let's bring the energy!";
      case 2:
        return "What's up! $name here 🔥\n\n"
            "This is my final warmup before the 30-day challenge begins!\n\n"
            "I've already grown so much just by showing up these past few days.\n\n"
            "I'm ready to achieve my goal to $goal.\n\n"
            "I've learned that consistency beats perfection.\n\n"
            "Every recording makes me more confident.\n\n"
            "Let's finish strong and crush this challenge!";
      default:
        return "Hi, I'm $name$locationText!\n\n"
            "I'm working toward my goal to $goal.\n\n"
            "Every time I practice, I get a little better.\n\n"
            "Let's do this!";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: widget.opacity),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              widget.isRecording
                  ? Colors.red.withValues(alpha: 0.6)
                  : const Color(0xFF6366F1).withValues(alpha: 0.6),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color:
                  widget.isRecording
                      ? Colors.red.withValues(alpha: 0.2)
                      : const Color(0xFF6366F1).withValues(alpha: 0.2),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color:
                        widget.isRecording
                            ? Colors.red
                            : const Color(0xFF6366F1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    widget.warmupTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (widget.isRecording) ...[
                  // Speed controls during recording
                  GestureDetector(
                    onTap: () => widget.onSpeedChange(-0.25),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.remove,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      '${widget.scrollSpeed.toStringAsFixed(1)}x',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => widget.onSpeedChange(0.25),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  widget.isRecording ? '📖 Reading...' : '📖 Your Script',
                  style: TextStyle(
                    color:
                        widget.isRecording
                            ? Colors.white
                            : const Color(0xFFFBBF24),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Scrollable script
          Expanded(
            child: ShaderMask(
              shaderCallback: (Rect bounds) {
                return LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white,
                    Colors.white,
                    Colors.white.withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.75, 1.0],
                ).createShader(bounds);
              },
              blendMode: BlendMode.dstIn,
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 40),
                physics:
                    widget.isRecording
                        ? const NeverScrollableScrollPhysics()
                        : const BouncingScrollPhysics(),
                child: Text(
                  _getPersonalizedScript(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.6,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

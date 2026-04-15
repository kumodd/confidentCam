import 'dart:async';

import 'package:camera/camera.dart';
import 'package:confident_cam/presentation/bloc/warmup/warmup_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/di/injection_container.dart';
import '../../../domain/entities/warmup.dart';
import '../../../services/video_recording_service.dart';
import '../../bloc/settings/settings_bloc.dart';
import '../../bloc/warmup/warmup_bloc.dart';
import '../../bloc/warmup/warmup_event.dart';
import '../../widgets/camera/coach_tips_card.dart';
import 'warmup_playback_screen.dart';
import '../../widgets/camera/recording_controls.dart';
import '../../widgets/camera/teleprompter_settings_sheet.dart';
import '../../widgets/camera/teleprompter_widget.dart';


/// Recording mode to distinguish between warmup and daily challenge.
enum RecordingMode { warmup, dailyChallenge }

/// Unified recording screen for both warmup and daily challenges.
class WarmupRecordingScreen extends StatefulWidget {
  final RecordingMode mode;
  final int warmupIndex; // For warmup mode
  final int? dayNumber; // For daily challenge mode
  final String? userId; // For daily challenge mode
  final String? script; // Pre-loaded script for daily challenge
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

  /// Factory constructor for warmup mode
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

  /// Factory constructor for daily challenge mode
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
  late VideoRecordingService _recordingService;
  bool _isInitializing = true;
  bool _isRecording = false;
  int _countdown = 3;
  bool _showingCountdown = false;
  Timer? _countdownTimer;
  Timer? _recordingTimer;
  int _recordingSeconds = 0;
  Warmup? _warmup; // Nullable for daily challenge mode
  String? _cachedCustomScript; // Caches AI script to prevent UI flickering

  // Teleprompter settings (can be adjusted in real-time)
  double _currentSpeed = 1.0;
  double _currentHeight = 0.25;
  double _currentOpacity = 0.85;
  double _currentFontSize = 16.0;
  Color _currentTextColor = Colors.white;

  @override
  void initState() {
    super.initState();
    // Only load warmup data in warmup mode
    if (widget.mode == RecordingMode.warmup) {
      _warmup = Warmups.getByIndex(widget.warmupIndex);
    }
    _recordingService = sl<VideoRecordingService>();
    _initCamera();
    _loadSettings();
  }

  void _loadSettings() {
    // Load settings from bloc if available
    final settingsState = context.read<SettingsBloc>().state;
    if (settingsState is SettingsLoadSuccess) {
      final settings = settingsState.settings;
      setState(() {
        _currentSpeed = settings.teleprompterSpeed;
        _currentHeight = settings.teleprompterHeight;
        _currentOpacity = settings.teleprompterOpacity;
        _currentFontSize = settings.fontSizePixels;
        _currentTextColor = _getColorFromString(settings.teleprompterTextColor);
      });
    }
  }

  Color _getColorFromString(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'white':
        return Colors.white;
      case 'yellow':
        return const Color(0xFFFBBF24);
      case 'cyan':
        return const Color(0xFF22D3EE);
      case 'green':
        return const Color(0xFF22C55E);
      case 'pink':
        return const Color(0xFFF472B6);
      default:
        return Colors.white;
    }
  }

  Future<void> _initCamera() async {
    try {
      await _recordingService.initialize(useFrontCamera: true);
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    } catch (e) {
      if (mounted) {
        EasyLoading.dismiss();
        _showPermissionDialog();
      }
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Permissions Required'),
        content: const Text(
          'Camera and Microphone access are required to record videos. Please enable them in your device settings.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // close dialog
              Navigator.of(context).pop(); // close screen
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
              Navigator.of(context).pop();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
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

    // Notify appropriate bloc based on mode
    if (widget.mode == RecordingMode.warmup) {
      context.read<WarmupBloc>().add(const WarmupRecordingStarted());
    }

    await _recordingService.startRecording();

    // For warmup mode, auto-stop at duration; for daily challenge, manual stop
    final maxDuration =
        widget.mode == RecordingMode.warmup
            ? (_warmup?.durationSeconds ?? 60)
            : 300; // 5 min max for daily challenge

    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _recordingSeconds++);

      if (_recordingSeconds >= maxDuration) {
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
      if (widget.mode == RecordingMode.warmup) {
        // Warmup mode: notify WarmupBloc and go to playback
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
      } else {
        // Daily challenge mode: return path to caller
        Navigator.of(context).pop(path);
      }
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

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => TeleprompterSettingsSheet(
        initialSpeed: _currentSpeed,
        initialHeight: _currentHeight,
        initialOpacity: _currentOpacity,
        onSettingsSaved: (speed, height, opacity) {
          setState(() {
            _currentSpeed = speed;
            _currentHeight = height;
            _currentOpacity = opacity;
          });
        },
      ),
    );
  }

  String _getFallbackWarmupScript() {
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
                child: widget.mode == RecordingMode.warmup
                    ? BlocBuilder<WarmupBloc, WarmupState>(
                        builder: (context, state) {
                          // Update cache if we have a valid custom script
                          if (state is WarmupInProgress && state.customScriptText != null) {
                            _cachedCustomScript = state.customScriptText;
                          } else if (state is WarmupRecording && state.customScriptText != null) {
                            _cachedCustomScript = state.customScriptText;
                          }

                          // Use cached script if available, otherwise fallback
                          String scriptText = _cachedCustomScript ?? _getFallbackWarmupScript();

                          return TeleprompterWidget(
                            script: scriptText,
                            title: _warmup?.title ?? 'Day ${widget.dayNumber}',
                            isRecording: _isRecording,
                            scrollSpeed: _currentSpeed,
                            opacity: _currentOpacity,
                            fontSize: _currentFontSize,
                            textColor: _currentTextColor,
                            onSpeedChange: _adjustSpeed,
                          );
                        },
                      )
                    : TeleprompterWidget(
                        script: widget.script ?? 'No script found',
                        title: 'Day ${widget.dayNumber}',
                        isRecording: _isRecording,
                        scrollSpeed: _currentSpeed,
                        opacity: _currentOpacity,
                        fontSize: _currentFontSize,
                        textColor: _currentTextColor,
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
              child: RecordingControls(
                isRecording: _isRecording,
                isInitializing: _isInitializing,
                recordingSeconds: _recordingSeconds,
                mode: widget.mode,
                warmup: _warmup,
                onStartCountdown: _startCountdown,
                onStopRecording: _stopRecording,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

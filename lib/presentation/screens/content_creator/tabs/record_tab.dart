import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../domain/entities/content_script.dart';
import '../../../../services/video_recording_service.dart';
import '../../../../services/video_storage_service.dart';
import '../../../bloc/content_creator/content_creator_bloc.dart';
import '../../../bloc/content_creator/content_creator_event.dart';
import '../../../bloc/content_creator/content_creator_state.dart';
import '../../../bloc/settings/settings_bloc.dart';

/// Tab for recording content videos with teleprompter and controls.
class RecordTab extends StatefulWidget {
  final String userId;

  const RecordTab({super.key, required this.userId});

  @override
  State<RecordTab> createState() => _RecordTabState();
}

class _RecordTabState extends State<RecordTab> {
  late VideoRecordingService _recordingService;
  bool _isInitializing = true;
  bool _isRecording = false;
  int _countdown = 3;
  bool _showingCountdown = false;
  Timer? _countdownTimer;
  Timer? _recordingTimer;
  int _recordingSeconds = 0;

  // Teleprompter settings
  double _currentSpeed = 1.0;
  double _currentHeight = 0.30;
  double _currentOpacity = 0.85;
  double _currentFontSize = 16.0;
  Color _currentTextColor = Colors.white;

  // Teleprompter scroll
  final ScrollController _scrollController = ScrollController();
  Timer? _scrollTimer;
  bool _isScrolling = false;

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
      case 'white': return Colors.white;
      case 'yellow': return const Color(0xFFFBBF24);
      case 'cyan': return const Color(0xFF22D3EE);
      case 'green': return const Color(0xFF22C55E);
      case 'pink': return const Color(0xFFF472B6);
      default: return Colors.white;
    }
  }

  Future<void> _initCamera() async {
    try {
      await _recordingService.initialize(useFrontCamera: true);
      if (mounted) setState(() => _isInitializing = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to initialize camera'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _recordingTimer?.cancel();
    _scrollTimer?.cancel();
    _scrollController.dispose();
    _recordingService.dispose();
    super.dispose();
  }

  void _startCountdown() {
    setState(() { _countdown = 3; _showingCountdown = true; });
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
    setState(() { _isRecording = true; _recordingSeconds = 0; });
    await _recordingService.startRecording();
    _startAutoScroll();
    
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _recordingSeconds++);
      if (_recordingSeconds >= 300) _stopRecording();
    });
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();
    _stopAutoScroll();
    if (!_isRecording) return;
    setState(() => _isRecording = false);

    final path = await _recordingService.stopRecording();
    if (path != null && mounted) {
      final storageService = sl<VideoStorageService>();
      
      // Get script title for video naming
      String? scriptTitle;
      final state = context.read<ContentCreatorBloc>().state;
      if (state is ContentCreatorLoaded && state.selectedScript != null) {
        scriptTitle = state.selectedScript!.title;
      }
      
      final savedPath = await storageService.saveVideo(
        tempPath: path,
        type: 'content',
        dayOrWarmupIndex: DateTime.now().millisecondsSinceEpoch,
        takeNumber: 1,
        title: scriptTitle ?? 'Content Video',
      );

      if (savedPath.isNotEmpty) {
        if (state is ContentCreatorLoaded && state.selectedScript != null) {
          context.read<ContentCreatorBloc>().add(MarkScriptRecorded(state.selectedScript!.id));
        }
        context.read<ContentCreatorBloc>().add(LoadContentVideos(widget.userId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(scriptTitle != null ? '"$scriptTitle" saved!' : 'Video saved!'),
            backgroundColor: const Color(0xFF22C55E),
          ),
        );
      }
    }
  }

  void _startAutoScroll() {
    if (_isScrolling) return;
    _isScrolling = true;

    final pixelsPerTick = 0.5 * _currentSpeed;
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

  void _adjustSpeed(double delta) {
    setState(() {
      _currentSpeed = (_currentSpeed + delta).clamp(0.5, 3.0);
    });
    if (_isRecording && _isScrolling) {
      _stopAutoScroll();
      _startAutoScroll();
    }
  }

  String _formatDuration(int s) => '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final teleprompterHeight = MediaQuery.of(context).size.height * _currentHeight;

    return BlocBuilder<ContentCreatorBloc, ContentCreatorState>(
      builder: (context, state) {
        ContentScript? selectedScript;
        if (state is ContentCreatorLoaded) selectedScript = state.selectedScript;

        return Stack(
          fit: StackFit.expand,
          children: [
            // Camera preview
            if (!_isInitializing && _recordingService.controller != null)
              ClipRRect(borderRadius: BorderRadius.circular(16), child: CameraPreview(_recordingService.controller!))
            else
              const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(color: Colors.white), SizedBox(height: 16),
                Text('Preparing camera...', style: TextStyle(color: Colors.white54)),
              ])),

            // Settings button (top right)
            if (!_showingCountdown && !_isRecording)
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.tune, color: Colors.white, size: 20),
                  ),
                  onPressed: () => _showSettingsSheet(context),
                ),
              ),

            // Teleprompter overlay
            if (!_showingCountdown && selectedScript != null)
              Positioned(
                top: 56,
                left: 12,
                right: 12,
                height: teleprompterHeight,
                child: _buildTeleprompter(selectedScript),
              ),

            // No script selected message
            if (!_showingCountdown && selectedScript == null && !_isRecording)
              Positioned(
                top: 56,
                left: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(children: [
                    Icon(Icons.info_outline, color: Colors.white54), SizedBox(width: 12),
                    Expanded(child: Text('No script selected. Go to My Scripts tab to select one.', style: TextStyle(color: Colors.white70, fontSize: 13))),
                  ]),
                ),
              ),

            // Recording indicator + duration
            if (_isRecording)
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle))
                        .animate(onComplete: (c) => c.repeat(reverse: true)).fade(duration: 500.ms),
                    const SizedBox(width: 8),
                    Text(_formatDuration(_recordingSeconds), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ]),
                ),
              ),

            // Speed controls (visible during recording)
            if (_isRecording && selectedScript != null)
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      icon: const Icon(Icons.remove, color: Colors.white, size: 20),
                      onPressed: () => _adjustSpeed(-0.25),
                    ),
                    Text('${_currentSpeed.toStringAsFixed(1)}x', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.add, color: Colors.white, size: 20),
                      onPressed: () => _adjustSpeed(0.25),
                    ),
                  ]),
                ),
              ),

            // Countdown overlay
            if (_showingCountdown)
              Center(child: Container(
                width: 120, height: 120,
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), shape: BoxShape.circle),
                child: Center(child: Text('$_countdown', style: const TextStyle(color: Colors.white, fontSize: 64, fontWeight: FontWeight.bold))),
              ).animate().scale(begin: const Offset(1.2, 1.2), end: const Offset(1, 1), duration: 800.ms)),

            // Record/Stop button
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: Center(child: _isRecording
                  ? GestureDetector(onTap: _stopRecording, child: Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.red, width: 4)),
                      child: Center(child: Container(width: 32, height: 32, decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)))),
                    ))
                  : GestureDetector(onTap: _isInitializing ? null : _startCountdown, child: Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)]),
                        shape: BoxShape.circle,
                        boxShadow: _isInitializing ? null : [BoxShadow(color: const Color(0xFFEC4899).withOpacity(0.4), blurRadius: 20, spreadRadius: 2)],
                      ),
                      child: const Icon(Icons.videocam_rounded, color: Colors.white, size: 36),
                    )),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTeleprompter(ContentScript script) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(_currentOpacity),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (_isRecording ? Colors.red : const Color(0xFFEC4899)).withOpacity(0.6),
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
              color: (_isRecording ? Colors.red : const Color(0xFFEC4899)).withOpacity(0.2),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    script.title,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _isRecording ? '${_currentSpeed.toStringAsFixed(1)}x' : '📖',
                  style: TextStyle(
                    color: _isRecording ? Colors.white : const Color(0xFFFBBF24),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // Script content with sections
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              physics: _isRecording ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hook Section
                  _buildScriptSection(
                    icon: '🎯',
                    title: 'HOOK',
                    content: script.part1,
                    color: const Color(0xFFEC4899),
                  ),
                  const SizedBox(height: 20),

                  // Content Section
                  _buildScriptSection(
                    icon: '💡',
                    title: 'CONTENT',
                    content: script.part2,
                    color: const Color(0xFF8B5CF6),
                  ),
                  const SizedBox(height: 20),

                  // Ending Section
                  _buildScriptSection(
                    icon: '🎬',
                    title: 'ENDING',
                    content: script.part3,
                    color: const Color(0xFF22C55E),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScriptSection({
    required String icon,
    required String title,
    required String content,
    required Color color,
  }) {
    if (content.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withOpacity(0.25),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Section content with markdown rendering
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: RichText(
            text: TextSpan(
              children: _parseMarkdown(content),
              style: TextStyle(
                color: _currentTextColor,
                fontSize: _currentFontSize,
                height: 1.7,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Parse simple markdown (bold, line breaks, bullets) into TextSpans
  List<TextSpan> _parseMarkdown(String text) {
    final spans = <TextSpan>[];
    
    // Split by line breaks first
    final lines = text.split(RegExp(r'\\n|[\n]'));
    
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      
      if (line.isEmpty) {
        spans.add(const TextSpan(text: '\n'));
        continue;
      }
      
      // Check if line starts with bullet
      String processedLine = line;
      if (line.trim().startsWith('•') || line.trim().startsWith('-')) {
        // Already has bullet, keep it
      } else if (line.trim().startsWith('* ')) {
        // Convert asterisk bullet to nicer bullet
        processedLine = line.replaceFirst('* ', '• ');
      }
      
      // Parse bold text (**text**)
      final boldPattern = RegExp(r'\*\*(.+?)\*\*');
      var lastEnd = 0;
      
      for (final match in boldPattern.allMatches(processedLine)) {
        // Text before the match
        if (match.start > lastEnd) {
          spans.add(TextSpan(text: processedLine.substring(lastEnd, match.start)));
        }
        // Bold text
        spans.add(TextSpan(
          text: match.group(1),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: const Color(0xFFFBBF24), // Yellow highlight for bold
            fontSize: _currentFontSize,
          ),
        ));
        lastEnd = match.end;
      }
      
      // Remaining text after last match
      if (lastEnd < processedLine.length) {
        spans.add(TextSpan(text: processedLine.substring(lastEnd)));
      }
      
      // Add line break after each line (except the last)
      if (i < lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }
    
    return spans;
  }

  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E2E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.tune, color: Color(0xFFEC4899)),
                  const SizedBox(width: 12),
                  const Text('Teleprompter Settings', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 24),

              // Speed slider
              _buildSliderRow(
                label: 'Scroll Speed', value: _currentSpeed, min: 0.5, max: 3.0, suffix: 'x',
                onChanged: (v) { setSheetState(() => _currentSpeed = v); setState(() {}); },
              ),
              const SizedBox(height: 16),

              // Height slider
              _buildSliderRow(
                label: 'Height', value: _currentHeight * 100, min: 15, max: 60, suffix: '%',
                onChanged: (v) { setSheetState(() => _currentHeight = v / 100); setState(() {}); },
              ),
              const SizedBox(height: 16),

              // Opacity slider
              _buildSliderRow(
                label: 'Opacity', value: _currentOpacity * 100, min: 50, max: 100, suffix: '%',
                onChanged: (v) { setSheetState(() => _currentOpacity = v / 100); setState(() {}); },
              ),
              const SizedBox(height: 16),

              // Font size slider
              _buildSliderRow(
                label: 'Font Size', value: _currentFontSize, min: 12, max: 24, suffix: 'pt',
                onChanged: (v) { setSheetState(() => _currentFontSize = v); setState(() {}); },
              ),
              const SizedBox(height: 24),
              
              // Video Quality selector
              Row(
                children: [
                  const Icon(Icons.high_quality, color: Color(0xFF8B5CF6), size: 20),
                  const SizedBox(width: 8),
                  const Text('Video Quality', style: TextStyle(color: Colors.white, fontSize: 14)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D2D3D),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<ResolutionPreset>(
                        value: _recordingService.currentQuality,
                        dropdownColor: const Color(0xFF2D2D3D),
                        icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF8B5CF6), size: 20),
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        items: const [
                          DropdownMenuItem(
                            value: ResolutionPreset.low,
                            child: Text('480p (Low)'),
                          ),
                          DropdownMenuItem(
                            value: ResolutionPreset.medium,
                            child: Text('720p (Medium)'),
                          ),
                          DropdownMenuItem(
                            value: ResolutionPreset.high,
                            child: Text('1080p (High)'),
                          ),
                          DropdownMenuItem(
                            value: ResolutionPreset.veryHigh,
                            child: Text('1440p (Very High)'),
                          ),
                          DropdownMenuItem(
                            value: ResolutionPreset.ultraHigh,
                            child: Text('4K (Ultra)'),
                          ),
                        ],
                        onChanged: (value) async {
                          if (value != null) {
                            Navigator.pop(ctx);
                            setState(() => _isInitializing = true);
                            await _recordingService.setQuality(value);
                            if (mounted) setState(() => _isInitializing = false);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    context.read<SettingsBloc>().add(TeleprompterSpeedUpdated(_currentSpeed));
                    context.read<SettingsBloc>().add(TeleprompterHeightUpdated(_currentHeight));
                    context.read<SettingsBloc>().add(TeleprompterOpacityUpdated(_currentOpacity));
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEC4899),
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
            Text('${value.toStringAsFixed(1)}$suffix', style: const TextStyle(color: Color(0xFFEC4899), fontWeight: FontWeight.bold)),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          activeColor: const Color(0xFFEC4899),
          inactiveColor: Colors.white24,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

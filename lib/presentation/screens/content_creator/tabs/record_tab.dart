import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/content_script.dart';
import '../../../../services/video_recording_service.dart';
import '../../../../services/video_storage_service.dart';
import '../../../bloc/content_creator/content_creator_bloc.dart';
import '../../../bloc/content_creator/content_creator_event.dart';
import '../../../bloc/content_creator/content_creator_state.dart';
import '../../../bloc/settings/settings_bloc.dart';
import '../content_creator_screen.dart';

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

  double _currentSpeed = 0.6;
  double _currentHeight = 0.25;
  double _currentOpacity = 0.35;
  double _currentFontSize = 16.0;
  Color _currentTextColor = const Color(0xFFF7F8F0);
  bool _isScriptVisible = true;

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
      case 'white':
        return const Color(0xFFF7F8F0);
      case 'yellow':
        return const Color(0xFFE5DF7A);
      case 'cyan':
        return const Color(0xFF8CE0A2);
      case 'green':
        return const Color(0xFF75D488);
      case 'pink':
        return const Color(0xFFFF8A8A);
      default:
        return const Color(0xFFF7F8F0);
    }
  }

  Future<void> _initCamera() async {
    try {
      await _recordingService.initialize(useFrontCamera: true);
      if (mounted) setState(() => _isInitializing = false);
    } catch (e) {
      if (mounted) {
        _showPermissionDialog();
      }
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Permissions Required'),
        content: Text(
          'Camera and Microphone access are required to record videos. Please enable them in your device settings.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: Text('Open Settings'),
          ),
        ],
      ),
    );
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
    ContentCreatorTabController.of(context)?.setRecording(true);

    setState(() {
      _isRecording = true;
      _recordingSeconds = 0;
    });
    await _recordingService.startRecording();

    Future.delayed(const Duration(seconds: 20), () {
      if (_isRecording && mounted) {
        _startAutoScroll();
      }
    });

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

    ContentCreatorTabController.of(context)?.setRecording(false);

    final path = await _recordingService.stopRecording();
    if (path != null && mounted) {
      final storageService = sl<VideoStorageService>();

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

      if (savedPath.isNotEmpty && mounted) {
        if (state is ContentCreatorLoaded && state.selectedScript != null) {
          context.read<ContentCreatorBloc>().add(
                MarkScriptRecorded(state.selectedScript!.id),
              );
        }
        context.read<ContentCreatorBloc>().add(
              LoadContentVideos(widget.userId),
            );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              scriptTitle != null ? '"$scriptTitle" saved!' : 'Video saved!',
            ),
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

  String _formatDuration(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  Widget _buildCameraPreview(CameraController controller) {
    final previewSize = controller.value.previewSize;
    if (!controller.value.isInitialized || previewSize == null) {
      return CameraPreview(controller);
    }

    return ClipRect(
      child: OverflowBox(
        maxWidth: double.infinity,
        maxHeight: double.infinity,
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: previewSize.height,
            height: previewSize.width,
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ContentCreatorBloc, ContentCreatorState>(
      builder: (context, state) {
        ContentScript? selectedScript;
        if (state is ContentCreatorLoaded) {
          selectedScript = state.selectedScript;
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF121512),
              borderRadius: AppRadii.cardLargeBorder,
              border: Border.all(color: AppColors.divider, width: 1.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final teleprompterHeight = (constraints.maxHeight *
                        _currentHeight.clamp(0.15, 0.52))
                    .clamp(110.0, constraints.maxHeight * 0.46);

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    if (!_isInitializing &&
                        _recordingService.controller != null)
                      _buildCameraPreview(_recordingService.controller!)
                    else
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(
                              color: Color(0xFFF7F8F0),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Preparing camera...',
                              style: AppTypography.body(
                                color: const Color(0xFFF7F8F0),
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (!_showingCountdown && !_isRecording)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (selectedScript != null) ...[
                              GestureDetector(
                                onTap: () => setState(
                                  () => _isScriptVisible = !_isScriptVisible,
                                ),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF121512)
                                        .withValues(alpha: 0.55),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.22),
                                    ),
                                  ),
                                  child: Icon(
                                    _isScriptVisible
                                        ? Icons.subtitles_outlined
                                        : Icons.subtitles_off_outlined,
                                    color: const Color(0xFFF7F8F0),
                                    size: 20,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            GestureDetector(
                              onTap: () => _showSettingsSheet(context),
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF121512)
                                      .withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.22),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.tune_rounded,
                                  color: Color(0xFFF7F8F0),
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (!_showingCountdown &&
                        selectedScript != null &&
                        _isScriptVisible)
                      Positioned(
                        top: 62,
                        left: 12,
                        right: 12,
                        height: teleprompterHeight,
                        child: _buildTeleprompter(selectedScript),
                      ),

                    if (!_showingCountdown &&
                        selectedScript == null &&
                        !_isRecording)
                      Positioned(
                        top: 62,
                        left: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF121512)
                                .withValues(alpha: 0.52),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.20),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                color: Color(0xFFD8D478),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'No script selected. Go to Scripts tab to select one.',
                                  style: AppTypography.bodyStrong(
                                    fontSize: 13.5,
                                    color: const Color(0xFFF7F8F0),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    if (_isRecording)
                      Positioned(
                        top: 14,
                        left: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF7F8F0),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatDuration(_recordingSeconds),
                                style: AppTypography.bodyStrong(
                                  color: const Color(0xFFF7F8F0),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    if (_isRecording && selectedScript != null)
                      Positioned(
                        top: 14,
                        right: 14,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: () => setState(
                                () => _isScriptVisible = !_isScriptVisible,
                              ),
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF121512)
                                      .withValues(alpha: 0.58),
                                  borderRadius: BorderRadius.circular(13),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.22),
                                  ),
                                ),
                                child: Icon(
                                  _isScriptVisible
                                      ? Icons.subtitles_outlined
                                      : Icons.subtitles_off_outlined,
                                  color: const Color(0xFFF7F8F0),
                                  size: 18,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF121512)
                                    .withValues(alpha: 0.58),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.22),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  GestureDetector(
                                    onTap: () => _adjustSpeed(-0.25),
                                    child: const Padding(
                                      padding: EdgeInsets.all(4),
                                      child: Icon(
                                        Icons.remove,
                                        color: Color(0xFFF7F8F0),
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                    ),
                                    child: Text(
                                      '${_currentSpeed.toStringAsFixed(1)}x',
                                      style: AppTypography.bodyStrong(
                                        fontSize: 13,
                                        color: const Color(0xFFF7F8F0),
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => _adjustSpeed(0.25),
                                    child: const Padding(
                                      padding: EdgeInsets.all(4),
                                      child: Icon(
                                        Icons.add,
                                        color: Color(0xFFF7F8F0),
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (_showingCountdown)
                      Center(
                        child: Container(
                          width: 116,
                          height: 116,
                          decoration: BoxDecoration(
                            color: const Color(0xFF121512)
                                .withValues(alpha: 0.72),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFD8D478),
                              width: 3,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '$_countdown',
                              style: AppTypography.displayMetric(
                                fontSize: 52,
                                color: const Color(0xFFF7F8F0),
                              ),
                            ),
                          ),
                        ),
                      ),

                    Positioned(
                      bottom: 26,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: _isRecording
                            ? GestureDetector(
                                onTap: _stopRecording,
                                child: Container(
                                  width: 78,
                                  height: 78,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF7F8F0),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.error,
                                      width: 4,
                                    ),
                                  ),
                                  child: Center(
                                    child: Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        color: AppColors.error,
                                        borderRadius: BorderRadius.circular(7),
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : GestureDetector(
                                onTap: _isInitializing ? null : _startCountdown,
                                child: Container(
                                  width: 78,
                                  height: 78,
                                  decoration: BoxDecoration(
                                    color: _isInitializing
                                        ? AppColors.mutedText
                                        : AppColors.primaryOlive,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFFF7F8F0),
                                      width: 3.5,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.videocam_rounded,
                                    color: Color(0xFFF7F8F0),
                                    size: 34,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildTeleprompter(ContentScript script) {
    final bgAlpha = (_currentOpacity * 0.65).clamp(0.06, 0.62);
    final headerAlpha = (bgAlpha + 0.12).clamp(0.14, 0.68);
    const onGlassText = Color(0xFFF7F8F0);
    const glassShadows = [
      Shadow(color: Color(0xCC000000), blurRadius: 6, offset: Offset(0, 1)),
    ];
    final resolvedTextColor = _currentTextColor == AppColors.primaryText
        ? onGlassText
        : _currentTextColor;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF121512).withValues(alpha: bgAlpha),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _isRecording
              ? AppColors.error.withValues(alpha: 0.85)
              : Colors.white.withValues(alpha: 0.22),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF121512).withValues(alpha: headerAlpha),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    script.title,
                    style: AppTypography.bodyStrong(
                      fontSize: 13,
                      color: onGlassText,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _isRecording
                        ? AppColors.error
                        : Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _isRecording
                          ? AppColors.error
                          : const Color(0xFFD8D478).withValues(alpha: 0.55),
                    ),
                  ),
                  child: Text(
                    _isRecording
                        ? '${_currentSpeed.toStringAsFixed(1)}x'
                        : 'Script',
                    style: GoogleFonts.manrope(
                      color:
                          _isRecording ? onGlassText : const Color(0xFFD8D478),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1.0, color: Colors.white.withValues(alpha: 0.12)),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildScriptSection(
                    title: 'HOOK',
                    content: script.part1,
                    color: const Color(0xFFE5DF7A),
                    textColor: resolvedTextColor,
                    shadows: glassShadows,
                  ),
                  const SizedBox(height: 14),
                  _buildScriptSection(
                    title: 'CONTENT',
                    content: script.part2,
                    color: const Color(0xFF8CE0A2),
                    textColor: resolvedTextColor,
                    shadows: glassShadows,
                  ),
                  const SizedBox(height: 14),
                  _buildScriptSection(
                    title: 'ENDING',
                    content: script.part3,
                    color: const Color(0xFFE5DF7A),
                    textColor: resolvedTextColor,
                    shadows: glassShadows,
                  ),
                  const SizedBox(height: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScriptSection({
    required String title,
    required String content,
    required Color color,
    required Color textColor,
    required List<Shadow> shadows,
  }) {
    if (content.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.50)),
          ),
          child: Text(
            title,
            style: AppTypography.uppercaseLabel(
              color: color,
              fontSize: 10,
              letterSpacing: 1.3,
            ),
          ),
        ),
        const SizedBox(height: 6),
        RichText(
          text: TextSpan(
            children: _parseMarkdown(content),
            style: GoogleFonts.inter(
              color: textColor,
              fontSize: _currentFontSize,
              height: 1.65,
              fontWeight: FontWeight.w500,
              shadows: shadows,
            ),
          ),
        ),
      ],
    );
  }

  List<TextSpan> _parseMarkdown(String text) {
    final spans = <TextSpan>[];
    final lines = text.split(RegExp(r'\\n|[\n]'));

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];

      if (line.isEmpty) {
        spans.add(const TextSpan(text: '\n'));
        continue;
      }

      String processedLine = line;
      if (line.trim().startsWith('* ')) {
        processedLine = line.replaceFirst('* ', '• ');
      }

      final boldPattern = RegExp(r'\*\*(.+?)\*\*');
      var lastEnd = 0;

      for (final match in boldPattern.allMatches(processedLine)) {
        if (match.start > lastEnd) {
          spans.add(
            TextSpan(text: processedLine.substring(lastEnd, match.start)),
          );
        }
        spans.add(
          TextSpan(
            text: match.group(1),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: const Color(0xFFE5DF7A),
              fontSize: _currentFontSize,
            ),
          ),
        );
        lastEnd = match.end;
      }

      if (lastEnd < processedLine.length) {
        spans.add(TextSpan(text: processedLine.substring(lastEnd)));
      }

      if (i < lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }

    return spans;
  }

  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      isDismissible: true,
      context: context,
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.all(22),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      color: AppColors.primaryOlive,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Teleprompter Settings',
                      style: AppTypography.headingMedium(fontSize: 19),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: AppColors.secondaryText,
                      ),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SageCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      _buildSliderRow(
                        label: 'SCROLL SPEED',
                        value: _currentSpeed,
                        min: 0.1,
                        max: 3.0,
                        suffix: 'x',
                        onChanged: (v) {
                          setSheetState(() => _currentSpeed = v);
                          setState(() {});
                        },
                      ),
                      const Divider(height: 20),
                      _buildSliderRow(
                        label: 'HEIGHT',
                        value: (_currentHeight * 100).clamp(15.0, 55.0),
                        min: 15,
                        max: 55,
                        suffix: '%',
                        onChanged: (v) {
                          setSheetState(() => _currentHeight = v / 100);
                          setState(() {});
                        },
                      ),
                      const Divider(height: 20),
                      _buildSliderRow(
                        label: 'OPACITY',
                        value: (_currentOpacity * 100).clamp(10.0, 85.0),
                        min: 10,
                        max: 85,
                        suffix: '%',
                        onChanged: (v) {
                          setSheetState(() => _currentOpacity = v / 100);
                          setState(() {});
                        },
                      ),
                      const Divider(height: 20),
                      _buildSliderRow(
                        label: 'FONT SIZE',
                        value: _currentFontSize,
                        min: 12,
                        max: 24,
                        suffix: 'pt',
                        onChanged: (v) {
                          setSheetState(() => _currentFontSize = v);
                          setState(() {});
                        },
                      ),
                      const Divider(height: 20),
                      Row(
                        children: [
                          Icon(
                            Icons.high_quality_outlined,
                            color: AppColors.primaryOlive,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Video Quality',
                            style: AppTypography.bodyStrong(),
                          ),
                          const Spacer(),
                          DropdownButtonHideUnderline(
                            child: DropdownButton<ResolutionPreset>(
                              value: _recordingService.currentQuality,
                              dropdownColor: AppColors.background,
                              icon: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: AppColors.secondaryText,
                                size: 20,
                              ),
                              style: AppTypography.bodyStrong(),
                              items: [
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
                                  if (mounted) {
                                    setState(() => _isInitializing = false);
                                  }
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      context.read<SettingsBloc>().add(
                            TeleprompterSpeedUpdated(_currentSpeed),
                          );
                      context.read<SettingsBloc>().add(
                            TeleprompterHeightUpdated(_currentHeight),
                          );
                      context.read<SettingsBloc>().add(
                            TeleprompterOpacityUpdated(_currentOpacity),
                          );
                      Navigator.pop(ctx);
                    },
                    child: Text('Save Settings'),
                  ),
                ),
              ],
            ),
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
            Text(
              label,
              style: AppTypography.uppercaseLabel(
                color: AppColors.secondaryText,
                fontSize: 10.5,
              ),
            ),
            OlivePillBadge(label: '${value.toStringAsFixed(1)}$suffix'),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          activeColor: AppColors.primaryOlive,
          inactiveColor: AppColors.divider,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

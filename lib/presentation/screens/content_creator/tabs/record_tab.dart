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
  double _currentHeight = 0.30;
  double _currentOpacity = 0.85;
  double _currentFontSize = 16.0;
  Color _currentTextColor = AppColors.primaryText;

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
        return AppColors.primaryText;
      case 'yellow':
        return AppColors.primaryOlive;
      case 'cyan':
        return AppColors.secondaryGreen;
      case 'green':
        return AppColors.success;
      case 'pink':
        return AppColors.error;
      default:
        return AppColors.primaryText;
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

  @override
  Widget build(BuildContext context) {
    final teleprompterHeight =
        MediaQuery.of(context).size.height * _currentHeight;

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
              color: AppColors.primaryText,
              borderRadius: AppRadii.cardLargeBorder,
              border: Border.all(color: AppColors.divider, width: 1.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (!_isInitializing && _recordingService.controller != null)
                  CameraPreview(_recordingService.controller!)
                else
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: AppColors.background,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Preparing camera...',
                          style: AppTypography.body(color: AppColors.background),
                        ),
                      ],
                    ),
                  ),

                if (!_showingCountdown && !_isRecording)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: () => _showSettingsSheet(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.background.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Icon(
                          Icons.tune_rounded,
                          color: AppColors.primaryText,
                          size: 20,
                        ),
                      ),
                    ),
                  ),

                if (!_showingCountdown && selectedScript != null)
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
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.background.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: AppColors.primaryOlive,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'No script selected. Go to Scripts tab to select one.',
                              style: AppTypography.bodyStrong(fontSize: 13.5),
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
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatDuration(_recordingSeconds),
                            style: AppTypography.bodyStrong(
                              color: AppColors.background,
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
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.background.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () => _adjustSpeed(-0.25),
                            child: Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                Icons.remove,
                                color: AppColors.primaryText,
                                size: 18,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                              '${_currentSpeed.toStringAsFixed(1)}x',
                              style: AppTypography.bodyStrong(fontSize: 13),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _adjustSpeed(0.25),
                            child: Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                Icons.add,
                                color: AppColors.primaryText,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                if (_showingCountdown)
                  Center(
                    child: Container(
                      width: 116,
                      height: 116,
                      decoration: BoxDecoration(
                        color: AppColors.background.withValues(alpha: 0.94),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primaryOlive,
                          width: 3,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$_countdown',
                          style: AppTypography.displayMetric(
                            fontSize: 52,
                            color: AppColors.primaryOlive,
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
                                color: AppColors.background,
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
                                  color: AppColors.background,
                                  width: 3.5,
                                ),
                              ),
                              child: Icon(
                                Icons.videocam_rounded,
                                color: AppColors.background,
                                size: 34,
                              ),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTeleprompter(ContentScript script) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background.withValues(
          alpha: _currentOpacity.clamp(0.75, 0.96),
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _isRecording ? AppColors.error : AppColors.divider,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    script.title,
                    style: AppTypography.bodyStrong(fontSize: 13.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                OlivePillBadge(
                  label: _isRecording
                      ? '${_currentSpeed.toStringAsFixed(1)}x'
                      : 'Script',
                ),
              ],
            ),
          ),
          Container(height: 1.2, color: AppColors.divider),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildScriptSection(
                    title: 'HOOK',
                    content: script.part1,
                    color: AppColors.primaryOlive,
                  ),
                  const SizedBox(height: 16),
                  _buildScriptSection(
                    title: 'CONTENT',
                    content: script.part2,
                    color: AppColors.secondaryGreen,
                  ),
                  const SizedBox(height: 16),
                  _buildScriptSection(
                    title: 'ENDING',
                    content: script.part3,
                    color: AppColors.primaryOlive,
                  ),
                  const SizedBox(height: 20),
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
  }) {
    if (content.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OlivePillBadge(
          label: title,
          textColor: color,
        ),
        const SizedBox(height: 8),
        RichText(
          text: TextSpan(
            children: _parseMarkdown(content),
            style: GoogleFonts.inter(
              color: _currentTextColor,
              fontSize: _currentFontSize,
              height: 1.65,
              fontWeight: FontWeight.w500,
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
              color: AppColors.primaryOlive,
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
                        value: _currentHeight * 100,
                        min: 15,
                        max: 80,
                        suffix: '%',
                        onChanged: (v) {
                          setSheetState(() => _currentHeight = v / 100);
                          setState(() {});
                        },
                      ),
                      const Divider(height: 20),
                      _buildSliderRow(
                        label: 'OPACITY',
                        value: _currentOpacity * 100,
                        min: 20,
                        max: 100,
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

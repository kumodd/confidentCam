import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/script_sentence_matcher.dart';
import '../../../../domain/entities/content_script.dart';
import '../../../../services/video_storage_service.dart';
import '../../../bloc/content_creator/content_creator_bloc.dart';
import '../../../bloc/content_creator/content_creator_event.dart';
import '../../../bloc/content_creator/content_creator_state.dart';
import '../../../widgets/camera/unified_recording_view.dart';
import '../content_creator_screen.dart';

/// Full-screen camera recording tab for AI-generated & custom Content Creator
/// scripts, powered by the shared [UnifiedRecordingView] and [TeleprompterWidget].
class RecordTab extends StatelessWidget {
  final String userId;

  const RecordTab({super.key, required this.userId});

  List<TeleprompterSection> _buildSections(ContentScript? script) {
    if (script == null) return const [];
    // Single-body custom scripts (Title + Script) render cleanly without a
    // redundant HOOK pill so lines sit right near the lens.
    if (script.part2.trim().isEmpty && script.part3.trim().isEmpty) {
      if (script.part1.trim().isEmpty) return const [];
      return [TeleprompterSection(body: script.part1)];
    }

    return [
      if (script.part1.trim().isNotEmpty)
        TeleprompterSection(
          badgeTitle: 'HOOK',
          badgeColor: const Color(0xFFE5DF7A),
          body: script.part1,
        ),
      if (script.part2.trim().isNotEmpty)
        TeleprompterSection(
          badgeTitle: 'CONTENT',
          badgeColor: const Color(0xFF8CE0A2),
          body: script.part2,
        ),
      if (script.part3.trim().isNotEmpty)
        TeleprompterSection(
          badgeTitle: 'ENDING',
          badgeColor: const Color(0xFFE5DF7A),
          body: script.part3,
        ),
    ];
  }

  Future<void> _handleRecordingCompleted(
    BuildContext context,
    String videoPath,
  ) async {
    final bloc = context.read<ContentCreatorBloc>();
    final state = bloc.state;

    ContentScript? selectedScript;
    if (state is ContentCreatorLoaded) {
      selectedScript = state.selectedScript;
    }

    if (!context.mounted) return;

    // Show full-screen post-record preview with exact same uncropped framing
    // as pre-record so the creator can inspect their capture before saving.
    final shouldSave = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder:
            (_) => _ContentPostRecordReviewScreen(
              videoPath: videoPath,
              title: selectedScript?.title ?? 'Content Video',
            ),
      ),
    );

    if (shouldSave != true) {
      try {
        final tempFile = File(videoPath);
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {}
      return;
    }

    final storageService = sl<VideoStorageService>();
    final savedPath = await storageService.saveVideo(
      tempPath: videoPath,
      type: 'content',
      dayOrWarmupIndex: DateTime.now().millisecondsSinceEpoch,
      takeNumber: 1,
      title: selectedScript?.title ?? 'Content Video',
    );

    if (savedPath.isNotEmpty && context.mounted) {
      if (selectedScript != null) {
        bloc.add(MarkScriptRecorded(selectedScript.id));
      }
      bloc.add(LoadContentVideos(userId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            selectedScript != null
                ? '"${selectedScript.title}" saved!'
                : 'Video saved!',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ContentCreatorBloc, ContentCreatorState>(
      builder: (context, state) {
        final selectedScript =
            state is ContentCreatorLoaded ? state.selectedScript : null;

        return UnifiedRecordingView(
          scriptTitle: selectedScript?.title ?? 'Script',
          sections: _buildSections(selectedScript),
          emptyScriptMessage:
              'No script selected. Tap back to pick or write a script.',
          embedded: true,
          showCloseButton: true,
          showCoachTips: false,
          showQualitySelector: true,
          maxDurationSeconds: 300,
          onClose: () {
            ContentCreatorTabController.of(context)?.switchToTab(1);
          },
          onRecordingStateChanged: (isRecording) {
            ContentCreatorTabController.of(context)?.setRecording(isRecording);
          },
          onRecordingCompleted:
              (path) => _handleRecordingCompleted(context, path),
        );
      },
    );
  }
}

/// Full-screen post-record preview matching the exact `#000000` uncropped
/// camera framing of [UnifiedRecordingView] so pre-record and post-record
/// views are 100% consistent.
class _ContentPostRecordReviewScreen extends StatefulWidget {
  final String videoPath;
  final String title;

  const _ContentPostRecordReviewScreen({
    required this.videoPath,
    required this.title,
  });

  @override
  State<_ContentPostRecordReviewScreen> createState() =>
      _ContentPostRecordReviewScreenState();
}

class _ContentPostRecordReviewScreenState
    extends State<_ContentPostRecordReviewScreen> {
  VideoPlayerController? _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final file = File(widget.videoPath);
    if (!await file.exists()) {
      if (mounted) Navigator.of(context).pop(false);
      return;
    }
    final ctrl = VideoPlayerController.file(file);
    _controller = ctrl;
    await ctrl.initialize();
    await ctrl.setLooping(true);
    await ctrl.play();
    if (mounted) {
      setState(() => _initialized = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaPad = MediaQuery.paddingOf(context);
    final ctrl = _controller;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_initialized && ctrl != null)
            GestureDetector(
              onTap: () {
                if (ctrl.value.isPlaying) {
                  ctrl.pause();
                } else {
                  ctrl.play();
                }
                setState(() {});
              },
              child: Container(
                color: Colors.black,
                alignment: Alignment.center,
                child: AspectRatio(
                  aspectRatio: ctrl.value.aspectRatio,
                  child: VideoPlayer(ctrl),
                ),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Color(0xFFF7F8F0)),
            ),

          if (_initialized && ctrl != null && !ctrl.value.isPlaying)
            IgnorePointer(
              child: Center(
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Color(0xFFF7F8F0),
                    size: 40,
                  ),
                ),
              ),
            ),

          // Top title pill
          Positioned(
            top: mediaPad.top + 10,
            left: 16,
            right: 16,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(false),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.56),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFFF7F8F0),
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.52),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyStrong(
                        color: const Color(0xFFF7F8F0),
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Retake / Save actions
          Positioned(
            left: 18,
            right: 18,
            bottom: mediaPad.bottom + 18,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFF7F8F0),
                      backgroundColor: Colors.black.withValues(alpha: 0.62),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 19),
                    label: const Text('Retake'),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryOlive,
                      foregroundColor: const Color(0xFFF7F8F0),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 19),
                    label: const Text('Save Video'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

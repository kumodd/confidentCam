import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/utils/script_sentence_matcher.dart';
import '../../../../domain/entities/content_script.dart';
import '../../../../services/video_storage_service.dart';
import '../../../bloc/content_creator/content_creator_bloc.dart';
import '../../../bloc/content_creator/content_creator_event.dart';
import '../../../bloc/content_creator/content_creator_state.dart';
import '../../../widgets/camera/unified_recording_view.dart';
import '../content_creator_screen.dart';

/// Tab for recording AI-generated Content Creator scripts, powered by the
/// shared [UnifiedRecordingView] and [TeleprompterWidget].
class RecordTab extends StatelessWidget {
  final String userId;

  const RecordTab({super.key, required this.userId});

  List<TeleprompterSection> _buildSections(ContentScript? script) {
    if (script == null) return const [];
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
    final storageService = sl<VideoStorageService>();
    final bloc = context.read<ContentCreatorBloc>();
    final state = bloc.state;

    ContentScript? selectedScript;
    if (state is ContentCreatorLoaded) {
      selectedScript = state.selectedScript;
    }

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
              'No script selected. Go to Scripts tab to select one.',
          embedded: true,
          showCloseButton: false,
          showCoachTips: false,
          showQualitySelector: true,
          maxDurationSeconds: 300,
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

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/content_script.dart';
import '../../../bloc/content_creator/content_creator_bloc.dart';
import '../../../bloc/content_creator/content_creator_event.dart';
import '../../../bloc/content_creator/content_creator_state.dart';
import '../content_creator_screen.dart';

/// Tab showing user's saved scripts with management options.
class MyScriptsTab extends StatelessWidget {
  final String userId;

  const MyScriptsTab({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ContentCreatorBloc, ContentCreatorState>(
      builder: (context, state) {
        if (state is ContentCreatorLoading ||
            state is IdeaEnhancing ||
            state is IdeaEnhanced ||
            state is ScriptGenerating ||
            state is ScriptRefining ||
            state is ScriptGenerated ||
            state is ScriptRefined) {
          return Center(
            child: CircularProgressIndicator(color: AppColors.primaryOlive),
          );
        }

        if (state is ContentCreatorLoaded) {
          if (state.scripts.isEmpty) {
            return _buildEmptyState(context);
          }
          return _buildScriptsList(context, state.scripts);
        }

        if (state is ContentCreatorError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SageCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.error,
                      size: 46,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      state.message,
                      style: AppTypography.body(),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        context.read<ContentCreatorBloc>().add(
                          LoadScripts(userId),
                        );
                      },
                      child: Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SageCard(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.olivePillFill,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.olivePillBorder),
                ),
                child: Icon(
                  Icons.description_outlined,
                  size: 36,
                  color: AppColors.primaryOlive,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'No Scripts Yet',
                style: AppTypography.headingMedium(fontSize: 20),
              ),
              const SizedBox(height: 6),
              Text(
                'Generate your first script in the Generate tab to get started.',
                textAlign: TextAlign.center,
                style: AppTypography.body(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScriptsList(BuildContext context, List<ContentScript> scripts) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      itemCount: scripts.length,
      itemBuilder: (context, index) {
        final script = scripts[index];
        return _ScriptCard(
          script: script,
          onTap: () => _showScriptDetails(context, script),
          onDelete: () => _confirmDelete(context, script),
          onRecord: () => _recordWithScript(context, script),
        );
      },
    );
  }

  void _showScriptDetails(BuildContext context, ContentScript script) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder:
          (ctx) => DraggableScrollableSheet(
            initialChildSize: 0.78,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder:
                (_, scrollController) => Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.divider,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  script.title,
                                  style: AppTypography.headingMedium(
                                    fontSize: 20,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    if (script.promptTemplate != null)
                                      OlivePillBadge(
                                        label: script.promptTemplate!,
                                      ),
                                    if (script.isRecorded)
                                      OlivePillBadge(
                                        label: 'Recorded',
                                        icon:
                                            Icons.check_circle_outline_rounded,
                                        backgroundColor: AppColors.navPill,
                                        borderColor: AppColors.secondaryGreen,
                                        textColor: AppColors.secondaryGreen,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              color: AppColors.secondaryText,
                            ),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Divider(),
                      const SizedBox(height: 14),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children:
                                script.part2.trim().isEmpty &&
                                        script.part3.trim().isEmpty
                                    ? [
                                      _buildScriptSection(
                                        'SCRIPT',
                                        script.part1,
                                      ),
                                    ]
                                    : [
                                      _buildScriptSection(
                                        'HOOK / OPENING',
                                        script.part1,
                                      ),
                                      const SizedBox(height: 14),
                                      _buildScriptSection(
                                        'CONTENT / BODY',
                                        script.part2,
                                      ),
                                      const SizedBox(height: 14),
                                      _buildScriptSection(
                                        'CLOSE / ENDING',
                                        script.part3,
                                      ),
                                    ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _confirmDelete(context, script);
                              },
                              icon: Icon(
                                Icons.delete_outline_rounded,
                                color: AppColors.error,
                              ),
                              label: Text(
                                'Delete',
                                style: TextStyle(color: AppColors.error),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: AppColors.error),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _recordWithScript(context, script);
                              },
                              icon: Icon(Icons.videocam_outlined),
                              label: Text('Record'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  Widget _buildScriptSection(String title, String content) {
    return SageCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  Icons.segment_rounded,
                  size: 18,
                  color: AppColors.primaryOlive,
                ),
                Text(
                  title,
                  style: AppTypography.uppercaseLabel(
                    fontSize: 10.5,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1.2, color: AppColors.divider),
          Padding(
            padding: const EdgeInsets.all(16),
            child:
                content.isEmpty
                    ? Text('(No content)', style: AppTypography.body())
                    : RichText(
                      text: TextSpan(
                        style: GoogleFonts.inter(
                          color: AppColors.primaryText,
                          fontSize: 14.5,
                          height: 1.6,
                        ),
                        children: _parseMarkdownSpans(content),
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  List<TextSpan> _parseMarkdownSpans(String text) {
    final normalized = text.replaceAll(r'\n', '\n');
    final boldPattern = RegExp(r'\*\*(.+?)\*\*');
    final spans = <TextSpan>[];
    var lastEnd = 0;

    for (final match in boldPattern.allMatches(normalized)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: normalized.substring(lastEnd, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: TextStyle(
            color: AppColors.primaryOlive,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
      lastEnd = match.end;
    }

    if (lastEnd < normalized.length) {
      spans.add(TextSpan(text: normalized.substring(lastEnd)));
    }
    return spans;
  }

  void _confirmDelete(BuildContext context, ContentScript script) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text('Delete Script'),
            content: Text('Delete "${script.title}"? This cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.read<ContentCreatorBloc>().add(
                    DeleteScript(script.id),
                  );
                },
                child: Text('Delete', style: TextStyle(color: AppColors.error)),
              ),
            ],
          ),
    );
  }

  void _recordWithScript(BuildContext context, ContentScript script) {
    context.read<ContentCreatorBloc>().add(SelectScript(script));

    final tabController = ContentCreatorTabController.of(context);
    if (tabController != null) {
      tabController.switchToTab(2);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Recording "${script.title}"'),
          duration: const Duration(seconds: 1),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Selected "${script.title}" - go to Record tab'),
        ),
      );
    }
  }
}

class _ScriptCard extends StatelessWidget {
  final ContentScript script;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onRecord;

  const _ScriptCard({
    required this.script,
    required this.onTap,
    required this.onDelete,
    required this.onRecord,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SageCard(
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 15, 18, 11),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        script.isRecorded
                            ? Icons.check_circle_rounded
                            : Icons.description_outlined,
                        size: 18,
                        color:
                            script.isRecorded
                                ? AppColors.secondaryGreen
                                : AppColors.primaryOlive,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        (script.promptTemplate ?? 'SCRIPT').toUpperCase(),
                        style: AppTypography.uppercaseLabel(
                          fontSize: 11,
                          color: AppColors.secondaryText,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    _formatDate(script.createdAt),
                    style: AppTypography.body(
                      fontSize: 12,
                      color: AppColors.mutedText,
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 1.3, color: AppColors.divider),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          script.title,
                          style: AppTypography.sectionTitle(fontSize: 16.5),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          script.part1
                              .replaceAll('**', '')
                              .replaceAll(r'\n', ' '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body(fontSize: 13.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Semantics(
                    label: 'Quick Record ${script.title}',
                    button: true,
                    child: GestureDetector(
                      onTap: onRecord,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.olivePillFill,
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(color: AppColors.olivePillBorder),
                        ),
                        child: Icon(
                          Icons.videocam_rounded,
                          color: AppColors.primaryOlive,
                          size: 20,
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

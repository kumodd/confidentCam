import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../domain/entities/content_script.dart';
import '../../../bloc/content_creator/content_creator_bloc.dart';
import '../../../bloc/content_creator/content_creator_event.dart';
import '../../../bloc/content_creator/content_creator_state.dart';

/// Tab showing user's saved scripts with management options.
class MyScriptsTab extends StatelessWidget {
  final String userId;

  const MyScriptsTab({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ContentCreatorBloc, ContentCreatorState>(
      builder: (context, state) {
        if (state is ContentCreatorLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is ContentCreatorLoaded) {
          if (state.scripts.isEmpty) {
            return _buildEmptyState(context);
          }
          return _buildScriptsList(context, state.scripts);
        }

        if (state is ContentCreatorError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  state.message,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    context.read<ContentCreatorBloc>().add(LoadScripts(userId));
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.description_outlined,
            size: 80,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No Scripts Yet',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            'Generate your first script in the\nGenerate tab to get started.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white38),
          ),
        ],
      ),
    );
  }

  Widget _buildScriptsList(BuildContext context, List<ContentScript> scripts) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: scripts.length,
      itemBuilder: (context, index) {
        final script = scripts[index];
        return _ScriptCard(
              script: script,
              onTap: () => _showScriptDetails(context, script),
              onDelete: () => _confirmDelete(context, script),
              onRecord: () => _recordWithScript(context, script),
            )
            .animate(delay: Duration(milliseconds: index * 50))
            .fadeIn()
            .slideX(begin: 0.1);
      },
    );
  }

  void _showScriptDetails(BuildContext context, ContentScript script) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (ctx) => DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder:
                (_, scrollController) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  script.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    if (script.promptTemplate != null) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFFEC4899,
                                          ).withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          script.promptTemplate!,
                                          style: const TextStyle(
                                            color: Color(0xFFEC4899),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    if (script.isRecorded)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFF22C55E,
                                          ).withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.check_circle,
                                              color: Color(0xFF22C55E),
                                              size: 12,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Recorded',
                                              style: TextStyle(
                                                color: Color(0xFF22C55E),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white54,
                            ),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Divider(color: Colors.white12),
                      const SizedBox(height: 16),

                      // Script content
                      Expanded(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildScriptSection('Hook/Opening', script.part1),
                              const SizedBox(height: 16),
                              _buildScriptSection('Content/Body', script.part2),
                              const SizedBox(height: 16),
                              _buildScriptSection('Close/Ending', script.part3),
                            ],
                          ),
                        ),
                      ),

                      // Actions
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _confirmDelete(context, script);
                              },
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              label: const Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.red),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
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
                              icon: const Icon(Icons.videocam_rounded),
                              label: const Text('Record'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFEC4899),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFFEC4899),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF2D2D3D),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            content.isEmpty ? '(No content)' : content,
            style: const TextStyle(color: Colors.white70, height: 1.6),
          ),
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, ContentScript script) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E2E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Delete Script',
              style: TextStyle(color: Colors.white),
            ),
            content: Text(
              'Delete "${script.title}"? This cannot be undone.',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.read<ContentCreatorBloc>().add(
                    DeleteScript(script.id),
                  );
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }

  void _recordWithScript(BuildContext context, ContentScript script) {
    // Select script and switch to record tab
    context.read<ContentCreatorBloc>().add(SelectScript(script));

    // Navigate to record tab - for now show snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Selected "${script.title}" for recording'),
        backgroundColor: const Color(0xFF22C55E),
        action: SnackBarAction(
          label: 'Go to Record',
          textColor: Colors.white,
          onPressed: () {
            // In practice, this would switch tabs
          },
        ),
      ),
    );
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                script.isRecorded
                    ? const Color(0xFF22C55E).withOpacity(0.3)
                    : const Color(0xFFEC4899).withOpacity(0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    script.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (script.isRecorded)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Color(0xFF22C55E),
                      size: 14,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Preview
            Text(
              script.part1,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 12),

            // Footer
            Row(
              children: [
                if (script.promptTemplate != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEC4899).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      script.promptTemplate!,
                      style: const TextStyle(
                        color: Color(0xFFEC4899),
                        fontSize: 11,
                      ),
                    ),
                  ),
                const Spacer(),
                Text(
                  _formatDate(script.createdAt),
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
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
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

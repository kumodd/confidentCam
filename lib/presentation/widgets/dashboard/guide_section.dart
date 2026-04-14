import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../domain/entities/guide_chapter.dart';
import '../../bloc/guide/guide_bloc.dart';
import '../../bloc/guide/guide_event.dart';
import '../../bloc/guide/guide_state.dart';
import '../../screens/warmup/warmup_overview_screen.dart';
import '../../bloc/warmup/warmup_bloc.dart';

/// Guide section widget for dashboard
class GuideSection extends StatefulWidget {
  const GuideSection({super.key});

  @override
  State<GuideSection> createState() => _GuideSectionState();
}

class _GuideSectionState extends State<GuideSection> {
  @override
  void initState() {
    super.initState();
    context.read<GuideBloc>().add(LoadGuides());
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.menu_book, color: Color(0xFFFBBF24)),
              const SizedBox(width: 8),
              Text(
                'Creator\'s Guide',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Tips to overcome fear and grow on social media',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white54),
          ),
          const SizedBox(height: 16),
          BlocBuilder<GuideBloc, GuideState>(
            builder: (context, state) {
              if (state is GuideLoading) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(color: Color(0xFFFBBF24)),
                  ),
                );
              } else if (state is GuideLoaded) {
                return Column(
                  children: state.chapters.asMap().entries.map((entry) {
                    final index = entry.key;
                    final chapter = entry.value;
                    return _ChapterCard(chapter: chapter, index: index + 1)
                        .animate(delay: Duration(milliseconds: index * 100))
                        .fadeIn()
                        .slideX(begin: 0.1, end: 0);
                  }).toList(),
                );
              } else if (state is GuideError) {
                return Center(
                  child: Text(
                    'Failed to load guides.',
                    style: TextStyle(color: Colors.red[300]),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }
}

class _ChapterCard extends StatefulWidget {
  final GuideChapter chapter;
  final int index;

  const _ChapterCard({required this.chapter, required this.index});

  @override
  State<_ChapterCard> createState() => _ChapterCardState();
}

class _ChapterCardState extends State<_ChapterCard> {
  bool _isExpanded = false;

  void _handleActionRoute(String route) {
    if (route == '/warmup') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BlocProvider.value(
            value: context.read<WarmupBloc>(),
            child: const WarmupOverviewScreen(),
          ),
        ),
      );
    } else if (route == '/challenge') {
      // Challenge deep link via Dashboard or direct route routing
      // If we are already on Dashboard, ideally we should switch tabs or push day list.
      // For simplicity, we can pop until dashboard or dispatch an event, but here a simple snackbar or basic routing can serve as demo.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Navigating to Challenges...'),
          backgroundColor: Color(0xFF6366F1),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              _isExpanded
                  ? const Color(0xFFFBBF24).withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBBF24).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        widget.chapter.emoji,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chapter ${widget.index}: ${widget.chapter.title}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.chapter.summary,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState:
                _isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 8),
                  ...widget.chapter.content.map(
                    (point) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '• ',
                            style: TextStyle(color: Color(0xFFFBBF24)),
                          ),
                          Expanded(
                            child: Text(
                              point,
                              style: const TextStyle(
                                color: Colors.white70,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Action buttons container
                  if (widget.chapter.youtubeUrl != null || widget.chapter.actionRoute != null)
                    Row(
                      children: [
                        if (widget.chapter.youtubeUrl != null)
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _openYouTube(widget.chapter.youtubeUrl!),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.red.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.play_circle_fill,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        'Watch Video',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        if (widget.chapter.youtubeUrl != null && widget.chapter.actionRoute != null)
                          const SizedBox(width: 12),
                        if (widget.chapter.actionRoute != null)
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _handleActionRoute(widget.chapter.actionRoute!),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFF6366F1).withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.flash_on_rounded,
                                      color: Color(0xFF818CF8),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        widget.chapter.actionTitle ?? 'Take Action',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
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
        ],
      ),
    );
  }

  Future<void> _openYouTube(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

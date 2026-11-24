import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/guide_chapter.dart';
import '../../bloc/guide/guide_bloc.dart';
import '../../bloc/guide/guide_event.dart';
import '../../bloc/guide/guide_state.dart';
import '../../screens/warmup/warmup_overview_screen.dart';
import '../../bloc/warmup/warmup_bloc.dart';
import '../../screens/progress/guide_video_player_screen.dart';

/// Guide section widget for dashboard in the sage & olive design language.
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
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.menu_book_outlined,
                    color: AppColors.primaryOlive,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "CREATOR'S GUIDE",
                    style: AppTypography.uppercaseLabel(
                      fontSize: 12,
                      color: AppColors.secondaryText,
                      letterSpacing: 1.6,
                    ),
                  ),
                ],
              ),
              OlivePillBadge(label: 'Chapters'),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Tips to overcome fear and grow on social media',
            style: AppTypography.body(fontSize: 13.5),
          ),
          const SizedBox(height: 14),
          BlocBuilder<GuideBloc, GuideState>(
            builder: (context, state) {
              if (state is GuideLoading) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(
                      color: AppColors.primaryOlive,
                    ),
                  ),
                );
              } else if (state is GuideLoaded) {
                return Column(
                  children: state.chapters.asMap().entries.map((entry) {
                    final index = entry.key;
                    final chapter = entry.value;
                    return _ChapterCard(chapter: chapter, index: index + 1);
                  }).toList(),
                );
              } else if (state is GuideError) {
                return Center(
                  child: Text(
                    'Failed to load guides.',
                    style: AppTypography.body(color: AppColors.error),
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
            child: WarmupOverviewScreen(),
          ),
        ),
      );
    } else if (route == '/challenge') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Navigating to Challenges...'),
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
        color: AppColors.cardSurface,
        borderRadius: AppRadii.cardBorder,
        border: _isExpanded
            ? Border.all(color: AppColors.olivePillBorder, width: 1.4)
            : null,
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: AppRadii.cardBorder,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.olivePillFill,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.olivePillBorder),
                    ),
                    child: Center(
                      child: Text(
                        widget.chapter.emoji,
                        style: TextStyle(fontSize: 19),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CHAPTER ${widget.index}',
                          style: AppTypography.uppercaseLabel(
                            fontSize: 10.5,
                            color: AppColors.primaryOlive,
                            letterSpacing: 1.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.chapter.title,
                          style: AppTypography.sectionTitle(fontSize: 16),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.chapter.summary,
                          style: AppTypography.body(fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  const SizedBox(height: 12),
                  ...widget.chapter.content.map(
                    (point) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(top: 3),
                            child: Icon(
                              Icons.circle,
                              size: 7,
                              color: AppColors.primaryOlive,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              point,
                              style: AppTypography.body(
                                color: AppColors.primaryText,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (widget.chapter.youtubeUrl != null ||
                      widget.chapter.actionRoute != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (widget.chapter.youtubeUrl != null)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => GuideVideoPlayerScreen(
                                      chapter: widget.chapter,
                                    ),
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                backgroundColor: AppColors.background,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 10,
                                ),
                              ),
                              icon: Icon(
                                Icons.play_circle_outline_rounded,
                                color: AppColors.error,
                                size: 18,
                              ),
                              label: Text(
                                'Watch Video',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        if (widget.chapter.youtubeUrl != null &&
                            widget.chapter.actionRoute != null)
                          const SizedBox(width: 10),
                        if (widget.chapter.actionRoute != null)
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _handleActionRoute(
                                widget.chapter.actionRoute!,
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.secondaryGreen,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 10,
                                ),
                              ),
                              icon: Icon(
                                Icons.arrow_forward_rounded,
                                size: 16,
                              ),
                              label: Text(
                                widget.chapter.actionTitle ?? 'Take Action',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

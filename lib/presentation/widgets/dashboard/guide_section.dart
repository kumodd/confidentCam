import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

/// Guide chapters for motivation and social media tips.
class GuideChapter {
  final String title;
  final String emoji;
  final String summary;
  final List<String> content;
  final String? youtubeUrl;
  final String? youtubeTitle;

  const GuideChapter({
    required this.title,
    required this.emoji,
    required this.summary,
    required this.content,
    this.youtubeUrl,
    this.youtubeTitle,
  });
}

/// Predefined guide chapters
const guideChapters = [
  GuideChapter(
    title: 'Overcoming Fear',
    emoji: '💪',
    summary: 'Why you feel afraid and how to push through',
    content: [
      'Fear of judgment is completely normal. Every successful creator has felt this.',
      'Your first 10 videos will feel awkward - that\'s the learning curve, not failure.',
      'Focus on progress, not perfection. Each video makes you 1% better.',
      'Remember: Most people are too busy with their own lives to judge yours.',
      'The discomfort you feel means you\'re growing. Embrace it!',
    ],
    youtubeUrl: 'https://www.youtube.com/watch?v=ZQUxL4Jm1Lo',
    youtubeTitle: 'How to Overcome Fear of Recording',
  ),
  GuideChapter(
    title: 'No One Is Watching',
    emoji: '👀',
    summary: 'The truth about engagement and visibility',
    content: [
      'Statistically, only 10% of your followers see your posts.',
      'Your first videos will get minimal views - this is normal and good!',
      'Low initial engagement = safe space to practice without pressure.',
      'The algorithm shows your content to strangers first, not friends.',
      'By the time people notice you, you\'ll already be confident!',
    ],
    youtubeUrl: 'https://www.youtube.com/watch?v=Ks-_Mh1QhMc',
    youtubeTitle: 'Why No One Sees Your First Posts',
  ),
  GuideChapter(
    title: 'Block The Haters',
    emoji: '🛡️',
    summary: 'How to protect yourself online',
    content: [
      'You can hide your content from specific people before posting.',
      'On Instagram: Settings → Close Friends (reverse it - add people to NOT show).',
      'Consider creating a separate account for content creation.',
      'Block anyone who makes you uncomfortable - it\'s your space.',
      'Pro tip: Most "haters" are just projecting their own insecurities.',
      'The loudest critics are usually those who never try anything themselves.',
    ],
    youtubeUrl: 'https://www.youtube.com/watch?v=qzR62JJCMBQ',
    youtubeTitle: 'How to Handle Negative Comments',
  ),
  GuideChapter(
    title: 'Consistency > Perfection',
    emoji: '📅',
    summary: 'Why showing up daily beats being perfect',
    content: [
      'Posting consistently builds trust with the algorithm and audience.',
      'A "good enough" video today beats a "perfect" video never posted.',
      '30 days of daily practice = more growth than 1 year of occasional perfection.',
      'Your audience connects with authenticity, not polish.',
      'Set a specific time each day for recording - make it a habit.',
      'Track your streak and celebrate small wins!',
    ],
    youtubeUrl: 'https://www.youtube.com/watch?v=sYMqVwsewSg',
    youtubeTitle: 'The Power of Consistency',
  ),
  GuideChapter(
    title: 'Social Media Tips',
    emoji: '📱',
    summary: 'Practical tips for posting and growing',
    content: [
      '🕐 Best times to post: 7-9 AM, 12-1 PM, 7-9 PM (local time)',
      '📝 Hook viewers in 3 seconds or they scroll away',
      '#️⃣ Use 5-10 relevant hashtags, not 30 random ones',
      '🎵 Trending audio boosts visibility',
      '💬 Reply to every comment in the first hour',
      '📊 Study your analytics weekly - double down on what works',
      '🤝 Engage with others in your niche before posting',
      '📍 Tag your location for local discoverability',
    ],
    youtubeUrl: 'https://www.youtube.com/watch?v=UF8uR6Z6KLc',
    youtubeTitle: 'Instagram Algorithm Tips 2024',
  ),
];

/// Guide section widget for dashboard
class GuideSection extends StatelessWidget {
  const GuideSection({super.key});

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
          ...guideChapters.asMap().entries.map((entry) {
            final index = entry.key;
            final chapter = entry.value;
            return _ChapterCard(chapter: chapter, index: index + 1)
                .animate(delay: Duration(milliseconds: index * 100))
                .fadeIn()
                .slideX(begin: 0.1, end: 0);
          }),
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
                  if (widget.chapter.youtubeUrl != null) ...[
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => _openYouTube(widget.chapter.youtubeUrl!),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.play_circle_fill,
                              color: Colors.red,
                              size: 32,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Watch Video',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                  ),
                                  Text(
                                    widget.chapter.youtubeTitle ??
                                        'YouTube Video',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.open_in_new,
                              color: Colors.white54,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
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

  Future<void> _openYouTube(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

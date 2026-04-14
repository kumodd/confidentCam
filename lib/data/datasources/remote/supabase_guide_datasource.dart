import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../domain/entities/guide_chapter.dart';
import '../../../../presentation/widgets/dashboard/guide_section.dart' as guide_fallback; // Assuming we keep the fallback here for now

class SupabaseGuideDatasource {
  final SupabaseClient _supabaseClient;
  bool _useFallback = false;

  SupabaseGuideDatasource(this._supabaseClient);

  Future<List<GuideChapter>> getGuideChapters() async {
    if (_useFallback) return _getFallbackGuides();

    try {
      final response = await _supabaseClient
          .from('guides')
          .select()
          .eq('is_active', true)
          .order('order_index', ascending: true);
      
      final List<dynamic> data = response as List<dynamic>;
      if (data.isEmpty) {
        return _getFallbackGuides();
      }
      return data.map((json) => GuideChapter.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      // If table doesn't exist or offline, fallback to local data
      _useFallback = true;
      return _getFallbackGuides();
    }
  }

  List<GuideChapter> _getFallbackGuides() {
    return const [
      GuideChapter(
        id: 'overcoming_fear',
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
        actionRoute: '/warmup',
        actionTitle: 'Practice a Warmup'
      ),
      GuideChapter(
        id: 'consistency',
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
        actionRoute: '/challenge',
        actionTitle: 'Start Today\'s Challenge'
      ),
      GuideChapter(
        id: 'no_one_is_watching',
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
        id: 'social_media_tips',
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
  }
}

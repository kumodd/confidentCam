class GuideChapter {
  final String id;
  final String title;
  final String emoji;
  final String summary;
  final List<String> content;
  final String? youtubeUrl;
  final String? youtubeTitle;
  final String? actionRoute;
  final String? actionTitle;

  const GuideChapter({
    this.id = '',
    required this.title,
    required this.emoji,
    required this.summary,
    required this.content,
    this.youtubeUrl,
    this.youtubeTitle,
    this.actionRoute,
    this.actionTitle,
  });

  factory GuideChapter.fromJson(Map<String, dynamic> json) {
    return GuideChapter(
      id: json['guide_key']?.toString() ?? json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      emoji: json['emoji'] ?? '',
      summary: json['summary'] ?? '',
      content: List<String>.from(json['content'] ?? []),
      youtubeUrl: json['youtube_url'],
      youtubeTitle: json['youtube_title'],
      actionRoute: json['action_route'],
      actionTitle: json['action_title'],
    );
  }
}

import '../entities/guide_chapter.dart';

abstract class GuideRepository {
  Future<List<GuideChapter>> getGuideChapters();
}

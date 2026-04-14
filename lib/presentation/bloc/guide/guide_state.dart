import '../../../domain/entities/guide_chapter.dart';

abstract class GuideState {
  const GuideState();
}

class GuideInitial extends GuideState {}

class GuideLoading extends GuideState {}

class GuideLoaded extends GuideState {
  final List<GuideChapter> chapters;
  const GuideLoaded(this.chapters);
}

class GuideError extends GuideState {
  final String message;
  const GuideError(this.message);
}

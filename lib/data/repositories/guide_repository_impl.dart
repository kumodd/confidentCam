import '../../domain/entities/guide_chapter.dart';
import '../../domain/repositories/guide_repository.dart';
import '../datasources/remote/supabase_guide_datasource.dart';

class GuideRepositoryImpl implements GuideRepository {
  final SupabaseGuideDatasource _remoteDataSource;

  GuideRepositoryImpl(this._remoteDataSource);

  @override
  Future<List<GuideChapter>> getGuideChapters() async {
    return await _remoteDataSource.getGuideChapters();
  }
}

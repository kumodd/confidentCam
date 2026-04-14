import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/repositories/guide_repository.dart';
import 'guide_event.dart';
import 'guide_state.dart';

class GuideBloc extends Bloc<GuideEvent, GuideState> {
  final GuideRepository _repository;

  GuideBloc({required GuideRepository repository})
      : _repository = repository,
        super(GuideInitial()) {
    on<LoadGuides>(_onLoadGuides);
  }

  Future<void> _onLoadGuides(LoadGuides event, Emitter<GuideState> emit) async {
    emit(GuideLoading());
    try {
      final chapters = await _repository.getGuideChapters();
      emit(GuideLoaded(chapters));
    } catch (e) {
      emit(GuideError(e.toString()));
    }
  }
}

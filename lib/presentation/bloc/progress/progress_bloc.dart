import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/user_progress.dart';
import '../../../domain/repositories/progress_repository.dart';

// Events
abstract class ProgressEvent extends Equatable {
  const ProgressEvent();
  @override
  List<Object?> get props => [];
}

class ProgressLoaded extends ProgressEvent {
  final String userId;
  const ProgressLoaded(this.userId);
  @override
  List<Object?> get props => [userId];
}

class ProgressRefreshed extends ProgressEvent {
  const ProgressRefreshed();
}

// States
abstract class ProgressState extends Equatable {
  const ProgressState();
  @override
  List<Object?> get props => [];
}

class ProgressInitial extends ProgressState {
  const ProgressInitial();
}

class ProgressLoadInProgress extends ProgressState {
  const ProgressLoadInProgress();
}

class ProgressLoadSuccess extends ProgressState {
  final UserProgress progress;
  const ProgressLoadSuccess(this.progress);
  @override
  List<Object?> get props => [progress];
}

class ProgressLoadFailure extends ProgressState {
  final String message;
  const ProgressLoadFailure(this.message);
  @override
  List<Object?> get props => [message];
}

// BLoC
class ProgressBloc extends Bloc<ProgressEvent, ProgressState> {
  final ProgressRepository progressRepository;
  String? _userId;

  ProgressBloc({required this.progressRepository})
    : super(const ProgressInitial()) {
    on<ProgressLoaded>(_onLoaded);
    on<ProgressRefreshed>(_onRefreshed);
  }

  Future<void> _onLoaded(
    ProgressLoaded event,
    Emitter<ProgressState> emit,
  ) async {
    emit(const ProgressLoadInProgress());
    _userId = event.userId;

    final result = await progressRepository.getProgress(event.userId);

    result.fold(
      (failure) => emit(ProgressLoadFailure(failure.message)),
      (progress) => emit(ProgressLoadSuccess(progress)),
    );
  }

  Future<void> _onRefreshed(
    ProgressRefreshed event,
    Emitter<ProgressState> emit,
  ) async {
    if (_userId == null) return;

    final result = await progressRepository.getProgress(_userId!);

    result.fold(
      (failure) => emit(ProgressLoadFailure(failure.message)),
      (progress) => emit(ProgressLoadSuccess(progress)),
    );
  }
}

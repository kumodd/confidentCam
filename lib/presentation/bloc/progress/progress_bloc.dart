import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/user_progress.dart';
import '../../../domain/repositories/progress_repository.dart';
import '../../../domain/repositories/script_repository.dart';

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
  final bool hasScripts;
  const ProgressLoadSuccess(this.progress, {this.hasScripts = false});
  @override
  List<Object?> get props => [progress, hasScripts];
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
  final ScriptRepository scriptRepository;
  String? _userId;

  ProgressBloc({
    required this.progressRepository,
    required this.scriptRepository,
  }) : super(const ProgressInitial()) {
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

    // Check if scripts exist (moved from dashboard UI layer)
    final hasScripts = await _checkScriptsExist(event.userId);

    result.fold(
      (failure) => emit(ProgressLoadFailure(failure.message)),
      (progress) => emit(ProgressLoadSuccess(progress, hasScripts: hasScripts)),
    );
  }

  Future<void> _onRefreshed(
    ProgressRefreshed event,
    Emitter<ProgressState> emit,
  ) async {
    if (_userId == null) return;

    final result = await progressRepository.getProgress(_userId!);
    final hasScripts = await _checkScriptsExist(_userId!);

    result.fold(
      (failure) => emit(ProgressLoadFailure(failure.message)),
      (progress) => emit(ProgressLoadSuccess(progress, hasScripts: hasScripts)),
    );
  }

  /// Check if scripts exist in local cache or remote database.
  /// This was previously done directly in the UI (dashboard_screen.dart).
  Future<bool> _checkScriptsExist(String userId) async {
    try {
      final hasLocal = await scriptRepository.hasLocalScripts(userId);
      if (hasLocal) return true;
      final hasRemote = await scriptRepository.hasRemoteScripts(userId);
      return hasRemote;
    } catch (_) {
      return false;
    }
  }
}

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/network_info.dart';

// Events
abstract class NetworkEvent extends Equatable {
  const NetworkEvent();
  @override
  List<Object?> get props => [];
}

class NetworkStatusChanged extends NetworkEvent {
  final bool isConnected;
  const NetworkStatusChanged(this.isConnected);
  @override
  List<Object?> get props => [isConnected];
}

class NetworkCheckRequested extends NetworkEvent {
  const NetworkCheckRequested();
}

// States
abstract class NetworkState extends Equatable {
  const NetworkState();
  @override
  List<Object?> get props => [];
}

class NetworkInitial extends NetworkState {
  const NetworkInitial();
}

class NetworkConnected extends NetworkState {
  const NetworkConnected();
}

class NetworkDisconnected extends NetworkState {
  const NetworkDisconnected();
}

// BLoC
class NetworkBloc extends Bloc<NetworkEvent, NetworkState> {
  final NetworkInfo networkInfo;
  StreamSubscription<bool>? _subscription;

  NetworkBloc({required this.networkInfo}) : super(const NetworkInitial()) {
    on<NetworkStatusChanged>(_onStatusChanged);
    on<NetworkCheckRequested>(_onCheckRequested);

    _startListening();
  }

  void _startListening() {
    _subscription = networkInfo.onConnectivityChanged.listen((isConnected) {
      add(NetworkStatusChanged(isConnected));
    });

    // Initial check
    add(const NetworkCheckRequested());
  }

  void _onStatusChanged(
    NetworkStatusChanged event,
    Emitter<NetworkState> emit,
  ) {
    if (event.isConnected) {
      emit(const NetworkConnected());
    } else {
      emit(const NetworkDisconnected());
    }
  }

  Future<void> _onCheckRequested(
    NetworkCheckRequested event,
    Emitter<NetworkState> emit,
  ) async {
    final isConnected = await networkInfo.isConnected;
    if (isConnected) {
      emit(const NetworkConnected());
    } else {
      emit(const NetworkDisconnected());
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}

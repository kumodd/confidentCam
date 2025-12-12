import 'dart:async';

import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:rxdart/rxdart.dart';

/// Abstract class defining network connectivity checking interface.
abstract class NetworkInfo {
  /// Check if device is currently connected to the internet.
  Future<bool> get isConnected;

  /// Stream of connectivity status changes.
  Stream<bool> get onConnectivityChanged;

  /// Dispose resources.
  void dispose();
}

/// Implementation of NetworkInfo using InternetConnectionChecker.
///
/// Provides real internet connectivity checking (not just network interface).
/// Includes debouncing to prevent rapid state changes.
class NetworkInfoImpl implements NetworkInfo {
  final InternetConnectionChecker connectionChecker;

  // BehaviorSubject to provide replay of last value for new subscribers
  final BehaviorSubject<bool> _connectivitySubject = BehaviorSubject<bool>();
  StreamSubscription<InternetConnectionStatus>? _subscription;

  NetworkInfoImpl({required this.connectionChecker}) {
    _initConnectivityListener();
  }

  void _initConnectivityListener() {
    // Initial check
    connectionChecker.hasConnection.then((hasConnection) {
      _connectivitySubject.add(hasConnection);
    });

    // Listen to changes with debounce to prevent rapid toggles
    _subscription = connectionChecker.onStatusChange
        .debounceTime(const Duration(milliseconds: 500))
        .listen((status) {
          final isConnected = status == InternetConnectionStatus.connected;
          _connectivitySubject.add(isConnected);
        });
  }

  @override
  Future<bool> get isConnected => connectionChecker.hasConnection;

  @override
  Stream<bool> get onConnectivityChanged => _connectivitySubject.stream;

  @override
  void dispose() {
    _subscription?.cancel();
    _connectivitySubject.close();
  }
}

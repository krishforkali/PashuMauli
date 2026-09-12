import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pashumauli/domain/entities/entities.dart';

/// Connectivity service — exposes ONLINE / OFFLINE / UNKNOWN status.
/// Phase 4 sync engine will react to this; Phase 3 only reads it for UI.
class ConnectivityService {
  final Connectivity _connectivity;
  late final StreamController<ConnectivityStatus> _controller;
  ConnectivityStatus _current = ConnectivityStatus.unknown;

  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity() {
    _controller = StreamController<ConnectivityStatus>.broadcast();
    _init();
  }

  ConnectivityStatus get current => _current;

  Stream<ConnectivityStatus> get statusStream => _controller.stream;

  Future<void> _init() async {
    // Get initial status
    final results = await _connectivity.checkConnectivity();
    _current = _fromResults(results);
    _controller.add(_current);

    // Listen for changes
    _connectivity.onConnectivityChanged.listen((results) {
      final status = _fromResults(results);
      if (status != _current) {
        _current = status;
        _controller.add(status);
      }
    });
  }

  ConnectivityStatus _fromResults(List<ConnectivityResult> results) {
    if (results.isEmpty || results.contains(ConnectivityResult.none)) {
      return ConnectivityStatus.offline;
    }
    // Any non-none result means we have connectivity
    return ConnectivityStatus.online;
  }

  bool get isOnline => _current == ConnectivityStatus.online;
  bool get isOffline => _current == ConnectivityStatus.offline;

  void dispose() {
    _controller.close();
  }
}

// ─── Riverpod Providers ────────────────────────────────────────────────────────

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService();
  ref.onDispose(service.dispose);
  return service;
});

final connectivityStatusProvider =
    StreamProvider<ConnectivityStatus>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.statusStream;
});

/// Current connectivity status — synchronous snapshot.
final currentConnectivityProvider = Provider<ConnectivityStatus>((ref) {
  final asyncStatus = ref.watch(connectivityStatusProvider);
  return asyncStatus.maybeWhen(
    data: (s) => s,
    orElse: () => ref.watch(connectivityServiceProvider).current,
  );
});

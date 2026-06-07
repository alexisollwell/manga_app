/// Connectivity monitoring service.
/// Tracks online/offline state and notifies when connectivity changes.
library;

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';

class ConnectivityService extends GetxService {
  final _connectivity = Connectivity();
  final isOnline = true.obs;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  @override
  void onInit() {
    super.onInit();
    _checkInitialStatus();
    _subscription = _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);
  }

  Future<void> _checkInitialStatus() async {
    final results = await _connectivity.checkConnectivity();
    _updateStatus(results);
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final wasOffline = !isOnline.value;
    _updateStatus(results);

    // Trigger sync when going from offline → online
    if (wasOffline && isOnline.value) {
      _onReconnected();
    }
  }

  void _updateStatus(List<ConnectivityResult> results) {
    isOnline.value = results.any((r) => r != ConnectivityResult.none);
  }

  void _onReconnected() {
    // SyncService listens to isOnline changes and handles sync
    // ignore: avoid_print
    print('[Connectivity] Reconnected! Triggering sync...');
  }

  @override
  void onClose() {
    _subscription?.cancel();
    super.onClose();
  }
}

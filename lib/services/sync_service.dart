
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'mutation_queue_service.dart';

class SyncService {
  final Connectivity _connectivity = Connectivity();
  final MutationQueueService _mutationQueueService = MutationQueueService();
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  bool _isProcessing = false;

  void initialize() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_handleConnectivityChange);
    _checkAndProcessQueue();
  }

  // Stubbed remote dispatch methods
  Future<bool> _dispatchCreate(String model, Map<String, dynamic> data) async {
    debugPrint('Stubbed dispatching CREATE for model: $model, data: $data');
    // In a real implementation, this would make a network request.
    await Future.delayed(const Duration(milliseconds: 100)); // Simulate network latency
    return true; // Simulate success
  }

  Future<bool> _dispatchUpdate(String model, dynamic id, Map<String, dynamic> data) async {
    debugPrint('Stubbed dispatching UPDATE for model: $model, id: $id, data: $data');
    await Future.delayed(const Duration(milliseconds: 100));
    return true;
  }

  Future<bool> _dispatchDelete(String model, dynamic id) async {
    debugPrint('Stubbed dispatching DELETE for model: $model, id: $id');
    await Future.delayed(const Duration(milliseconds: 100));
    return true;
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.mobile) || results.contains(ConnectivityResult.wifi)) {
      debugPrint('Network connection detected. Starting sync process...');
      _checkAndProcessQueue();
    } else {
      debugPrint('No network connection.');
    }
  }

  Future<void> _checkAndProcessQueue() async {
    if (_isProcessing) {
      debugPrint('Sync process is already running.');
      return;
    }

    final connectivityResult = await _connectivity.checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.mobile) || connectivityResult.contains(ConnectivityResult.wifi)) {
      _processQueue();
    }
  }

  Future<void> _processQueue() async {
    _isProcessing = true;

    try {
      final List<Mutation> unsyncedMutations = await _mutationQueueService.getUnsyncedMutations();

      if (unsyncedMutations.isEmpty) {
        debugPrint('Mutation queue is empty. No items to sync.');
        return;
      }

      debugPrint('Processing ${unsyncedMutations.length} items from the mutation queue.');

      for (final mutation in unsyncedMutations) {
        bool success = false;
        try {
          switch (mutation.action) {
            case 'create':
              success = await _dispatchCreate(mutation.model, mutation.data);
              break;
            case 'update':
              success = await _dispatchUpdate(mutation.model, mutation.data['id'], mutation.data);
              break;
            case 'delete':
              success = await _dispatchDelete(mutation.model, mutation.data['id']);
              break;
            default:
              debugPrint('Unknown mutation action: ${mutation.action}');
          }

          if (success) {
            await _mutationQueueService.deleteMutation(mutation.id!);
            debugPrint('Successfully synced and removed mutation with ID: ${mutation.id}');
          }
        } catch (e) {
          debugPrint('Failed to sync mutation with ID: ${mutation.id}. Error: $e');
        }
      }
    } finally {
      _isProcessing = false;
    }
  }

  void dispose() {
    _connectivitySubscription.cancel();
  }
}

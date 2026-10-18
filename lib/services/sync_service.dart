import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite/sqflite.dart';

import 'package:omen_vault_v3/models/mutation.dart';
import 'package:omen_vault_v3/services/mutation_queue_service.dart';

class SyncService {
  final Database _database;
  final MutationQueueService _mutationQueueService;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  SyncService(this._database, this._mutationQueueService) {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> result) {
      if (!result.contains(ConnectivityResult.none)) {
        processQueue();
      }
    });
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }

  Future<void> processQueue() async {
    final pendingMutations = await _mutationQueueService.getPendingMutations();
    if (pendingMutations.isEmpty) {
      return;
    }

    final mutations = pendingMutations.map((m) => Mutation.fromJson(m)).toList();

    await _database.transaction((txn) async {
      for (final mutation in mutations) {
        try {
          await txn.rawInsert(mutation.sql, mutation.params);
        } catch (e) {
          // TODO: handle failed mutations
        }
      }
    });

    await _mutationQueueService.clearProcessedMutations(mutations.map((m) => m.id).toList());
  }
}

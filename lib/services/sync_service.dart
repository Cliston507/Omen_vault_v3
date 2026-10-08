
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'mutation_queue_service.dart';
import 'database_service.dart';

/// A strategy that applies a mutation remotely. Returns true on success.
typedef MutationDispatcher = Future<bool> Function(Mutation mutation);

/// Reads the current user id for ownership checks. Never throws.
typedef UidProvider = String? Function();

class SyncService {
  /// Shared instance so any part of the app can request a sync pass and
  /// all of them share one queue processor and one listener set.
  static final SyncService instance = SyncService();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<User?>? _authSubscription;
  late final MutationDispatcher _dispatcher;
  late final UidProvider _uidProvider;
  late final bool _enforceOwnership;

  bool _isProcessing = false;

  /// Production constructor: dispatches queued mutations to Firestore via
  /// DatabaseService, scoped to the signed-in user. Queued mutations are
  /// only uploaded while the user that enqueued them is signed in.
  /// The queue is injectable for tests that need a fake database.
  SyncService({
    MutationDispatcher? dispatcher,
    UidProvider? uidProvider,
    MutationQueueService? queue,
  })  : _dispatcher = dispatcher ?? _defaultDispatcher,
        _uidProvider = uidProvider ?? currentUserIdOrNull,
        _enforceOwnership = true,
        _queueOverride = queue;

  /// Lazy default: only touches Firestore when a dispatch actually runs,
  /// so constructing a SyncService never requires an initialized app.
  static Future<bool> _defaultDispatcher(Mutation mutation) =>
      DatabaseService().dispatchMutation(mutation);

  final MutationQueueService? _queueOverride;
  late final MutationQueueService _mutationQueueService =
      _queueOverride ?? MutationQueueService();

  /// Test constructor: keeps the queue-clearing behaviour with a stubbed
  /// dispatcher and no ownership enforcement, so tests can run without
  /// Firebase.
  SyncService.test(MutationQueueService queue,
      {MutationDispatcher? dispatcher})
      : _dispatcher = dispatcher ?? _stubDispatcher,
        _uidProvider = (() => null),
        _enforceOwnership = false,
        _queueOverride = queue;

  static Future<bool> _stubDispatcher(Mutation mutation) async {
    debugPrint('Test dispatching ${mutation.action} for ${mutation.model}');
    await Future.delayed(const Duration(milliseconds: 100)); // Simulate latency
    return true;
  }

  void initialize() {
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen(_handleConnectivityChange);
    // Re-attempt sync after sign-in / account changes, not only after
    // connectivity changes.
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      _checkAndProcessQueue();
    });
    _checkAndProcessQueue();
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    if (results.any(_isOnlineResult)) {
      debugPrint('Network connection detected. Starting sync process...');
      _checkAndProcessQueue();
    } else {
      debugPrint('No network connection.');
    }
  }

  static bool _isOnlineResult(ConnectivityResult result) =>
      result == ConnectivityResult.mobile ||
      result == ConnectivityResult.wifi ||
      result == ConnectivityResult.ethernet;

  /// Requests a sync pass soon (after a save, sign-in, or connectivity
  /// change). Never throws: sync problems are logged, not propagated to
  /// callers that just saved data.
  void scheduleSync() {
    unawaited(_checkAndProcessQueue().catchError((Object e) {
      debugPrint('Sync pass failed: $e');
    }));
  }

  Future<void> _checkAndProcessQueue() async {
    if (_isProcessing) {
      debugPrint('Sync process is already running.');
      return;
    }

    List<ConnectivityResult> connectivityResult;
    try {
      connectivityResult = await _connectivity.checkConnectivity();
    } on Object catch (e) {
      // Connectivity plugins can be unavailable (web, tests): fall back to
      // attempting the sync pass.
      debugPrint('Connectivity check unavailable ($e); syncing anyway.');
      unawaited(processQueue().catchError((Object err) {
        debugPrint('Sync pass failed: $err');
      }));
      return;
    }
    if (connectivityResult.any(_isOnlineResult)) {
      unawaited(processQueue().catchError((Object e) {
        debugPrint('Sync pass failed: $e');
      }));
    }
  }

  /// Processes the offline mutation queue.
  ///
  /// Ordering is preserved: processing stops at the first mutation that
  /// fails to dispatch, so later dependent operations are not applied (and
  /// then removed from the queue) while an earlier one is still pending.
  /// Mutations bound to a different user than the one currently signed in
  /// are skipped, never uploaded, and kept in the queue.
  Future<void> processQueue() async {
    if (_isProcessing) {
      debugPrint('Sync process is already running.');
      return;
    }
    _isProcessing = true;

    try {
      final List<Mutation> unsyncedMutations =
          await _mutationQueueService.getUnsyncedMutations();

      if (unsyncedMutations.isEmpty) {
        debugPrint('Mutation queue is empty. No items to sync.');
        return;
      }

      final String? currentUid = _uidProvider();
      if (_enforceOwnership && currentUid == null) {
        // Signed out: keep everything queued for the next sign-in.
        debugPrint('User is signed out; deferring queue processing.');
        return;
      }

      debugPrint(
          'Processing ${unsyncedMutations.length} items from the mutation queue.');

      for (final mutation in unsyncedMutations) {
        if (_enforceOwnership) {
          // Ownerless legacy entries are not auto-assigned to the current
          // user; they stay queued until they can be attributed safely.
          if (mutation.ownerId == null) {
            debugPrint('Skipping ownerless mutation ${mutation.id}.');
            continue;
          }
          if (mutation.ownerId != currentUid) {
            debugPrint('Skipping mutation ${mutation.id} owned by another '
                'user.');
            continue;
          }
        }

        bool success = false;
        try {
          success = await _dispatcher(mutation);

          if (success) {
            await _mutationQueueService.deleteMutation(mutation.id!);
            debugPrint(
                'Successfully synced and removed mutation with ID: ${mutation.id}');
          } else {
            debugPrint('Dispatch failed for mutation ${mutation.id}; '
                'stopping to preserve ordering.');
            break;
          }
        } catch (e) {
          debugPrint('Failed to sync mutation with ID: ${mutation.id}. '
              'Error: $e — stopping to preserve ordering.');
          break;
        }
      }
    } finally {
      _isProcessing = false;
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _authSubscription?.cancel();
  }
}

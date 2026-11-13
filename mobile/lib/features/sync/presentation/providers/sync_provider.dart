import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/local_database.dart';
import '../../../../core/database/sync_status.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/services/sync_engine_service.dart';

final syncEngineServiceProvider = Provider<SyncEngineService>((ref) {
  return SyncEngineService(
    dio: ref.watch(dioClientProvider),
    localDb: ref.watch(localDatabaseProvider),
  );
});

class SyncCenterState {
  final List<PendingSyncQueueItem> queue;
  final DateTime? lastSyncedAt;
  final bool isSyncing;
  final SyncStatusState overallStatus;
  final String? statusMessage;

  const SyncCenterState({
    this.queue = const [],
    this.lastSyncedAt,
    this.isSyncing = false,
    this.overallStatus = SyncStatusState.synced,
    this.statusMessage,
  });

  int get conflictCount =>
      queue.where((q) => q.syncStatus == SyncStatusState.conflict).length;

  int get pendingCount => queue.length;

  SyncCenterState copyWith({
    List<PendingSyncQueueItem>? queue,
    DateTime? lastSyncedAt,
    bool? isSyncing,
    SyncStatusState? overallStatus,
    String? statusMessage,
  }) {
    return SyncCenterState(
      queue: queue ?? this.queue,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      isSyncing: isSyncing ?? this.isSyncing,
      overallStatus: overallStatus ?? this.overallStatus,
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }
}

class SyncCenterNotifier extends StateNotifier<SyncCenterState> {
  final SyncEngineService _syncEngine;
  final LocalDatabase _localDb;

  SyncCenterNotifier({
    required SyncEngineService syncEngine,
    required LocalDatabase localDb,
  })  : _syncEngine = syncEngine,
        _localDb = localDb,
        super(const SyncCenterState()) {
    refreshQueueState();
  }

  SyncStatusState _deriveOverallStatus(
    List<PendingSyncQueueItem> queue,
    bool isSyncing,
  ) {
    if (isSyncing) return SyncStatusState.syncing;
    if (queue.any((q) => q.syncStatus == SyncStatusState.conflict)) {
      return SyncStatusState.conflict;
    }
    if (queue.any((q) => q.syncStatus == SyncStatusState.syncFailed)) {
      return SyncStatusState.syncFailed;
    }
    if (queue.isNotEmpty) {
      return SyncStatusState.pendingSync;
    }
    return SyncStatusState.synced;
  }

  Future<void> refreshQueueState() async {
    final queue = await _localDb.getPendingSyncQueue();
    final lastSync = await _localDb.getLastSyncTimestamp();
    state = state.copyWith(
      queue: queue,
      lastSyncedAt: lastSync,
      overallStatus: _deriveOverallStatus(queue, state.isSyncing),
    );
  }

  Future<void> triggerSync({bool manual = true}) async {
    state = state.copyWith(
      isSyncing: true,
      overallStatus: SyncStatusState.syncing,
      statusMessage: 'Synchronizing pending changes...',
    );

    final result = await _syncEngine.synchronize(ignoreBackoffWindow: manual);
    final queue = await _localDb.getPendingSyncQueue();
    final lastSync = await _localDb.getLastSyncTimestamp();

    state = state.copyWith(
      queue: queue,
      lastSyncedAt: lastSync ?? result.timestamp,
      isSyncing: false,
      overallStatus: _deriveOverallStatus(queue, false),
      statusMessage:
          'Synced: ${result.appliedCount} applied, ${result.conflictCount} conflicts, ${result.pulledCount} pulled',
    );
  }

  Future<void> resolveKeepClient(PendingSyncQueueItem item) async {
    state = state.copyWith(isSyncing: true);
    await _syncEngine.resolveConflictKeepClient(item);
    await refreshQueueState();
    state = state.copyWith(
      isSyncing: false,
      statusMessage: 'Conflict resolved using your local edit.',
    );
  }

  Future<void> resolveKeepServer(PendingSyncQueueItem item) async {
    state = state.copyWith(isSyncing: true);
    await _syncEngine.resolveConflictKeepServer(item);
    await refreshQueueState();
    state = state.copyWith(
      isSyncing: false,
      statusMessage: 'Conflict resolved using server record.',
    );
  }
}

final syncCenterProvider =
    StateNotifierProvider<SyncCenterNotifier, SyncCenterState>((ref) {
  return SyncCenterNotifier(
    syncEngine: ref.watch(syncEngineServiceProvider),
    localDb: ref.watch(localDatabaseProvider),
  );
});

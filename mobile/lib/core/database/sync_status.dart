enum SyncStatusState {
  localOnly('LOCAL_ONLY'),
  pendingSync('PENDING_SYNC'),
  syncing('SYNCING'),
  synced('SYNCED'),
  syncFailed('SYNC_FAILED'),
  conflict('CONFLICT');

  final String value;
  const SyncStatusState(this.value);

  static SyncStatusState fromString(String? raw) {
    for (final state in SyncStatusState.values) {
      if (state.value == raw) {
        return state;
      }
    }
    return SyncStatusState.synced;
  }
}

class PendingSyncQueueItem {
  final String operationId;
  final String entityType; // TRANSACTION | BUDGET | CATEGORY
  final String entityId;
  final String action; // CREATE | UPDATE | DELETE
  final String payloadJson;
  final SyncStatusState syncStatus;
  final int baseVersion;
  final int retryCount;
  final DateTime? nextRetryAt;
  final String? lastError;
  final String? conflictServerJson;
  final DateTime createdAt;

  const PendingSyncQueueItem({
    required this.operationId,
    required this.entityType,
    required this.entityId,
    required this.action,
    required this.payloadJson,
    required this.syncStatus,
    required this.baseVersion,
    required this.retryCount,
    this.nextRetryAt,
    this.lastError,
    this.conflictServerJson,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'operation_id': operationId,
      'entity_type': entityType,
      'entity_id': entityId,
      'action': action,
      'payload_json': payloadJson,
      'sync_status': syncStatus.value,
      'base_version': baseVersion,
      'retry_count': retryCount,
      'next_retry_at': nextRetryAt?.toUtc().toIso8601String(),
      'last_error': lastError,
      'conflict_server_json': conflictServerJson,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  factory PendingSyncQueueItem.fromMap(Map<String, dynamic> map) {
    return PendingSyncQueueItem(
      operationId: map['operation_id'] as String,
      entityType: map['entity_type'] as String,
      entityId: map['entity_id'] as String,
      action: map['action'] as String,
      payloadJson: map['payload_json'] as String,
      syncStatus: SyncStatusState.fromString(map['sync_status'] as String?),
      baseVersion: (map['base_version'] as num?)?.toInt() ?? 1,
      retryCount: (map['retry_count'] as num?)?.toInt() ?? 0,
      nextRetryAt: map['next_retry_at'] != null
          ? DateTime.parse(map['next_retry_at'] as String)
          : null,
      lastError: map['last_error'] as String?,
      conflictServerJson: map['conflict_server_json'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

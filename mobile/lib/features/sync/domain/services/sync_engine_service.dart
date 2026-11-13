import 'dart:convert';
import 'dart:math' as math;

import 'package:dio/dio.dart';

import '../../../../core/database/local_database.dart';
import '../../../../core/database/sync_status.dart';
import '../../../categories/domain/entities/category_entity.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';

class SyncRunResult {
  final int appliedCount;
  final int conflictCount;
  final int failedCount;
  final int pulledCount;
  final DateTime timestamp;

  const SyncRunResult({
    required this.appliedCount,
    required this.conflictCount,
    required this.failedCount,
    required this.pulledCount,
    required this.timestamp,
  });
}

class SyncEngineService {
  final Dio _dio;
  final LocalDatabase _localDb;

  SyncEngineService({
    required Dio dio,
    required LocalDatabase localDb,
  })  : _dio = dio,
        _localDb = localDb;

  /// Deterministic exponential backoff formula: min(300, 2^retryCount) seconds.
  static Duration calculateBackoffDelay(int retryCount) {
    final safeRetry = retryCount.clamp(0, 8);
    final seconds = math.min(300, 1 << safeRetry);
    return Duration(seconds: seconds);
  }

  Future<SyncRunResult> synchronize({
    String deviceId = 'spendwise-flutter-client',
    bool ignoreBackoffWindow = false,
  }) async {
    final now = DateTime.now().toUtc();
    final queue = await _localDb.getPendingSyncQueue();

    final eligibleOps = queue.where((item) {
      if (item.syncStatus == SyncStatusState.conflict) {
        return false; // Conflicts require explicit resolution
      }
      if (!ignoreBackoffWindow &&
          item.nextRetryAt != null &&
          item.nextRetryAt!.isAfter(now)) {
        return false;
      }
      return true;
    }).toList();

    int appliedCount = 0;
    int conflictCount = 0;
    int failedCount = 0;

    if (eligibleOps.isNotEmpty) {
      for (final op in eligibleOps) {
        await _localDb.updateSyncQueueItemStatus(
          op.operationId,
          status: SyncStatusState.syncing,
        );
        await _localDb.updateTransactionSyncStatus(
          op.entityId,
          SyncStatusState.syncing,
        );
      }

      try {
        final operationsPayload = eligibleOps.map((op) {
          final decoded = jsonDecode(op.payloadJson) as Map<String, dynamic>;
          return {
            'operationId': op.operationId,
            'entityType': op.entityType,
            'entityId': op.entityId,
            'action': op.action,
            'baseVersion': op.baseVersion,
            'forceOverwrite': decoded['forceOverwrite'] == true,
            'payload': decoded,
          };
        }).toList();

        final pushResponse = await _dio.post<Map<String, dynamic>>(
          '/sync/push',
          data: {
            'deviceId': deviceId,
            'operations': operationsPayload,
          },
        );

        final data = pushResponse.data!['data'] as Map<String, dynamic>;
        final results = data['results'] as List<dynamic>;

        for (final rawResult in results) {
          final res = rawResult as Map<String, dynamic>;
          final opId = res['operationId'] as String;
          final entityId = res['entityId'] as String;
          final status = res['status'] as String;

          if (status == 'APPLIED') {
            appliedCount += 1;
            await _localDb.removeSyncQueueItem(opId);
            final recordMap = res['record'] as Map<String, dynamic>?;
            if (recordMap != null) {
              final isDeleted = (recordMap['isDeleted'] as bool?) ?? false;
              final serverTx = TransactionEntity.fromJson(recordMap);
              await _localDb.upsertSingleTransaction(
                serverTx,
                isDeleted: isDeleted,
              );
            } else {
              await _localDb.updateTransactionSyncStatus(
                entityId,
                SyncStatusState.synced,
                newVersion: (res['version'] as num?)?.toInt(),
              );
            }
          } else if (status == 'CONFLICT') {
            conflictCount += 1;
            final serverRecord = res['serverRecord'] as Map<String, dynamic>?;
            await _localDb.updateSyncQueueItemStatus(
              opId,
              status: SyncStatusState.conflict,
              lastError: res['errorMessage'] as String?,
              conflictServerJson:
                  serverRecord != null ? jsonEncode(serverRecord) : null,
            );
            await _localDb.updateTransactionSyncStatus(
              entityId,
              SyncStatusState.conflict,
            );
          } else {
            failedCount += 1;
            final matchedOp =
                eligibleOps.firstWhere((e) => e.operationId == opId);
            final nextRetryCount = matchedOp.retryCount + 1;
            final nextRetryAt =
                now.add(calculateBackoffDelay(nextRetryCount));
            await _localDb.updateSyncQueueItemStatus(
              opId,
              status: SyncStatusState.syncFailed,
              retryCount: nextRetryCount,
              nextRetryAt: nextRetryAt,
              lastError: res['errorMessage'] as String? ?? 'Sync push failed',
            );
            await _localDb.updateTransactionSyncStatus(
              entityId,
              SyncStatusState.syncFailed,
            );
          }
        }
      } catch (networkErr) {
        // Network error: apply exponential backoff to all eligible ops
        for (final op in eligibleOps) {
          failedCount += 1;
          final nextRetryCount = op.retryCount + 1;
          final nextRetryAt = now.add(calculateBackoffDelay(nextRetryCount));
          await _localDb.updateSyncQueueItemStatus(
            op.operationId,
            status: SyncStatusState.syncFailed,
            retryCount: nextRetryCount,
            nextRetryAt: nextRetryAt,
            lastError: networkErr.toString(),
          );
          await _localDb.updateTransactionSyncStatus(
            op.entityId,
            SyncStatusState.syncFailed,
          );
        }
      }
    }

    // Pull delta changes from server
    int pulledCount = 0;
    try {
      final lastPull = await _localDb.getLastSyncTimestamp();
      final pullRes = await _dio.get<Map<String, dynamic>>(
        '/sync/pull',
        queryParameters: {
          if (lastPull != null) 'since': lastPull.toUtc().toIso8601String(),
        },
      );
      final pullData = pullRes.data!['data'] as Map<String, dynamic>;
      final rawCategories = pullData['categories'] as List<dynamic>? ?? const [];
      final rawTransactions =
          pullData['transactions'] as List<dynamic>? ?? const [];

      if (rawCategories.isNotEmpty) {
        final cats = rawCategories
            .map((c) => CategoryEntity.fromJson(c as Map<String, dynamic>))
            .toList();
        await _localDb.upsertCategories(cats);
      }

      for (final rawTx in rawTransactions) {
        final map = rawTx as Map<String, dynamic>;
        final isDeleted = (map['isDeleted'] as bool?) ?? false;
        final tx = TransactionEntity.fromJson(map);
        await _localDb.upsertSingleTransaction(tx, isDeleted: isDeleted);
        pulledCount += 1;
      }

      final serverTsStr = pullData['serverTimestamp'] as String?;
      final serverTs =
          serverTsStr != null ? DateTime.parse(serverTsStr) : now;
      await _localDb.setLastSyncTimestamp(serverTs);
    } catch (_) {
      // Pull failed (e.g., offline); keep cached state intact
    }

    return SyncRunResult(
      appliedCount: appliedCount,
      conflictCount: conflictCount,
      failedCount: failedCount,
      pulledCount: pulledCount,
      timestamp: now,
    );
  }

  /// Resolves a conflict by keeping the client's offline edit (`forceOverwrite: true`).
  Future<void> resolveConflictKeepClient(PendingSyncQueueItem item) async {
    final decoded = jsonDecode(item.payloadJson) as Map<String, dynamic>;
    decoded['forceOverwrite'] = true;
    await _localDb.enqueueSyncOperation(
      PendingSyncQueueItem(
        operationId: item.operationId,
        entityType: item.entityType,
        entityId: item.entityId,
        action: item.action,
        payloadJson: jsonEncode(decoded),
        syncStatus: SyncStatusState.pendingSync,
        baseVersion: item.baseVersion,
        retryCount: 0,
        createdAt: item.createdAt,
      ),
    );
    await _localDb.updateTransactionSyncStatus(
      item.entityId,
      SyncStatusState.pendingSync,
    );
    await synchronize(ignoreBackoffWindow: true);
  }

  /// Resolves a conflict by accepting the server's version and discarding the stale local edit.
  Future<void> resolveConflictKeepServer(PendingSyncQueueItem item) async {
    if (item.conflictServerJson != null) {
      final serverMap =
          jsonDecode(item.conflictServerJson!) as Map<String, dynamic>;
      final serverTx = TransactionEntity.fromJson(serverMap);
      await _localDb.upsertSingleTransaction(serverTx);
    } else {
      await _localDb.updateTransactionSyncStatus(
        item.entityId,
        SyncStatusState.synced,
      );
    }
    await _localDb.removeSyncQueueItem(item.operationId);
  }
}

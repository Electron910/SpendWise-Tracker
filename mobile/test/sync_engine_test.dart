import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise_mobile/core/database/local_database.dart';
import 'package:spendwise_mobile/core/database/sync_status.dart';
import 'package:spendwise_mobile/core/theme/app_theme.dart';
import 'package:spendwise_mobile/features/categories/domain/entities/category_entity.dart';
import 'package:spendwise_mobile/features/sync/domain/services/sync_engine_service.dart';
import 'package:spendwise_mobile/features/sync/presentation/providers/sync_provider.dart';
import 'package:spendwise_mobile/features/sync/presentation/screens/sync_center_screen.dart';
import 'package:spendwise_mobile/features/transactions/domain/entities/transaction_entity.dart';

class FakeSyncInterceptor extends Interceptor {
  bool returnConflict = true;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.path.contains('/sync/push')) {
      final body = options.data as Map<String, dynamic>;
      final ops = body['operations'] as List<dynamic>;
      final firstOp = ops.first as Map<String, dynamic>;
      final force = firstOp['forceOverwrite'] == true;

      if (returnConflict && !force) {
        handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'success': true,
              'data': {
                'serverTimestamp': '2026-11-13T12:00:00.000Z',
                'results': [
                  {
                    'operationId': firstOp['operationId'],
                    'entityId': firstOp['entityId'],
                    'action': firstOp['action'],
                    'status': 'CONFLICT',
                    'version': 2,
                    'errorMessage':
                        'Version conflict: server is v2, client base v1',
                    'serverRecord': {
                      'id': firstOp['entityId'],
                      'categoryId': 'cat-food',
                      'type': 'EXPENSE',
                      'amountPaise': '55000',
                      'currency': 'INR',
                      'description': 'Server Dinner v2',
                      'paymentMethod': 'UPI',
                      'transactionDate': '2026-11-13T10:00:00.000Z',
                      'syncStatus': 'SYNCED',
                      'version': 2,
                      'isDeleted': false,
                      'category': {
                        'id': 'cat-food',
                        'name': 'Food',
                        'type': 'EXPENSE',
                        'icon': 'restaurant',
                        'colorHex': '#EF4444',
                        'isSystem': true,
                      },
                    },
                  },
                ],
              },
            },
          ),
        );
        return;
      }

      handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            'success': true,
            'data': {
              'serverTimestamp': '2026-11-13T12:05:00.000Z',
              'results': [
                {
                  'operationId': firstOp['operationId'],
                  'entityId': firstOp['entityId'],
                  'action': firstOp['action'],
                  'status': 'APPLIED',
                  'version': 3,
                },
              ],
            },
          },
        ),
      );
      return;
    }

    if (options.path.contains('/sync/pull')) {
      handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            'success': true,
            'data': {
              'serverTimestamp': '2026-11-13T12:05:00.000Z',
              'transactions': [],
              'categories': [],
            },
          },
        ),
      );
      return;
    }
  }
}

class FakeSyncCenterNotifier extends SyncCenterNotifier {
  FakeSyncCenterNotifier()
      : super(
          syncEngine: SyncEngineService(
            dio: Dio(),
            localDb: LocalDatabase.inMemory(),
          ),
          localDb: LocalDatabase.inMemory(),
        ) {
    state = SyncCenterState(
      overallStatus: SyncStatusState.conflict,
      statusMessage: '1 conflict detected',
      queue: [
        PendingSyncQueueItem(
          operationId: 'op-conflict-1',
          entityType: 'TRANSACTION',
          entityId: 'tx-conflict-1',
          action: 'UPDATE',
          payloadJson: jsonEncode({
            'id': 'tx-conflict-1',
            'description': 'Client Offline Dinner Edit',
            'amountPaise': '48000',
          }),
          syncStatus: SyncStatusState.conflict,
          baseVersion: 1,
          retryCount: 1,
          conflictServerJson: jsonEncode({
            'id': 'tx-conflict-1',
            'version': 2,
            'description': 'Server Dinner v2',
            'amountPaise': '55000',
          }),
          createdAt: DateTime.utc(2026, 11, 13, 10),
        ),
      ],
    );
  }

  @override
  Future<void> refreshQueueState() async {}

  @override
  Future<void> resolveKeepClient(PendingSyncQueueItem item) async {
    state = const SyncCenterState(
      overallStatus: SyncStatusState.synced,
      queue: [],
      statusMessage: 'Conflict resolved using your local edit.',
    );
  }
}

void main() {
  group('SyncEngineService & Conflict Resolution Tests', () {
    test('calculates exponential backoff delay capped at 300 seconds', () {
      expect(SyncEngineService.calculateBackoffDelay(1).inSeconds, 2);
      expect(SyncEngineService.calculateBackoffDelay(2).inSeconds, 4);
      expect(SyncEngineService.calculateBackoffDelay(3).inSeconds, 8);
      expect(SyncEngineService.calculateBackoffDelay(10).inSeconds, 256);
    });

    test(
        'SyncEngineService detects version conflict during push and resolves via Keep Client',
        () async {
      final localDb = LocalDatabase.inMemory();
      final fakeDio = Dio()..interceptors.add(FakeSyncInterceptor());
      final syncEngine = SyncEngineService(dio: fakeDio, localDb: localDb);

      const foodCat = CategoryEntity(
        id: 'cat-food',
        name: 'Food',
        type: 'EXPENSE',
        icon: 'restaurant',
        colorHex: '#EF4444',
        isSystem: true,
      );

      final localTx = TransactionEntity(
        id: 'tx-conflict-1',
        categoryId: 'cat-food',
        type: 'EXPENSE',
        amountPaise: 48000,
        currency: 'INR',
        description: 'Client Offline Dinner Edit',
        paymentMethod: 'UPI',
        transactionDate: DateTime.utc(2026, 11, 13, 10),
        syncStatus: SyncStatusState.pendingSync.value,
        version: 1,
        category: foodCat,
      );

      await localDb.upsertSingleTransaction(localTx);
      await localDb.enqueueSyncOperation(
        PendingSyncQueueItem(
          operationId: 'op-conflict-1',
          entityType: 'TRANSACTION',
          entityId: 'tx-conflict-1',
          action: 'UPDATE',
          payloadJson: jsonEncode({
            'id': 'tx-conflict-1',
            'categoryId': 'cat-food',
            'type': 'EXPENSE',
            'amountPaise': '48000',
            'description': 'Client Offline Dinner Edit',
          }),
          syncStatus: SyncStatusState.pendingSync,
          baseVersion: 1,
          retryCount: 0,
          createdAt: DateTime.utc(2026, 11, 13, 10),
        ),
      );

      final firstRun = await syncEngine.synchronize(ignoreBackoffWindow: true);
      expect(firstRun.conflictCount, 1);

      final conflictedQueue = await localDb.getPendingSyncQueue();
      expect(conflictedQueue.first.syncStatus, SyncStatusState.conflict);

      await syncEngine.resolveConflictKeepClient(conflictedQueue.first);
      final afterResolveQueue = await localDb.getPendingSyncQueue();
      expect(afterResolveQueue, isEmpty);

      await localDb.close();
    });

    testWidgets(
        'SyncCenterScreen renders conflict comparison and resolves via Keep My Edit',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            syncCenterProvider.overrideWith((ref) => FakeSyncCenterNotifier()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const SyncCenterScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Version Conflict Detected'), findsOneWidget);
      expect(find.textContaining('Server Dinner v2'), findsOneWidget);

      await tester.tap(find.byKey(const Key('resolve_keep_client_op-conflict-1')));
      await tester.pumpAndSettle();

      expect(
        find.text('All local changes are synchronized with the server.'),
        findsOneWidget,
      );
    });
  });
}

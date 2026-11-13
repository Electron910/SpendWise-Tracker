import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise_mobile/core/database/local_database.dart';
import 'package:spendwise_mobile/core/database/sync_status.dart';
import 'package:spendwise_mobile/features/categories/domain/entities/category_entity.dart';
import 'package:spendwise_mobile/features/transactions/data/repositories/transactions_repository_impl.dart';
import 'package:spendwise_mobile/features/transactions/domain/repositories/transactions_repository.dart';

class OfflineFailingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    handler.reject(
      DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        message: 'Simulated offline network outage',
      ),
    );
  }
}

void main() {
  group('Offline SQLite Persistence & Sync Queue Tests', () {
    late LocalDatabase localDb;
    late Dio offlineDio;
    late TransactionsRepositoryImpl repository;

    setUp(() async {
      localDb = LocalDatabase.inMemory();
      offlineDio = Dio()..interceptors.add(OfflineFailingInterceptor());
      repository = TransactionsRepositoryImpl(dio: offlineDio, localDb: localDb);

      await localDb.upsertCategories(const [
        CategoryEntity(
          id: 'cat-food-uuid',
          name: 'Food',
          type: 'EXPENSE',
          icon: 'restaurant',
          colorHex: '#EF4444',
          isSystem: true,
        ),
      ]);
    });

    tearDown(() async {
      await localDb.close();
    });

    test(
        'creates, updates, lists, and deletes transactions offline and enqueues sync operations',
        () async {
      // 1. Offline category lookup
      final cats = await repository.getCategories(type: 'EXPENSE');
      expect(cats.length, 1);
      expect(cats.first.name, 'Food');

      // 2. Offline transaction creation with client UUID and PENDING_SYNC status
      final created = await repository.createTransaction(
        categoryId: 'cat-food-uuid',
        type: 'EXPENSE',
        amountPaise: 35000, // ₹350.00
        description: 'Offline Coffee & Sandwich',
        paymentMethod: 'UPI',
        transactionDate: DateTime.utc(2026, 11, 13, 10, 0),
        merchant: 'Starbucks',
      );

      expect(created.syncStatus, SyncStatusState.pendingSync.value);
      expect(created.amountPaise, 35000);

      // 3. Offline transaction listing computes accurate integer paise summary
      final summary = await repository.getTransactions(const TransactionsFilter());
      expect(summary.transactions.length, 1);
      expect(summary.totalExpensePaise, 35000);
      expect(summary.netSavingsPaise, -35000);

      // 4. Offline transaction update
      final updated = await repository.updateTransaction(
        id: created.id,
        categoryId: 'cat-food-uuid',
        type: 'EXPENSE',
        amountPaise: 42000, // ₹420.00
        description: 'Updated Offline Lunch',
        paymentMethod: 'UPI',
        transactionDate: DateTime.utc(2026, 11, 13, 12, 0),
        expectedVersion: 1,
      );
      expect(updated.amountPaise, 42000);
      expect(updated.syncStatus, SyncStatusState.pendingSync.value);

      // 5. Offline transaction deletion marks tombstone and enqueues DELETE
      await repository.deleteTransaction(created.id);
      final afterDelete = await repository.getTransactions(const TransactionsFilter());
      expect(afterDelete.transactions, isEmpty);

      // 6. Verify sync_queue contains CREATE, UPDATE, and DELETE operations
      final queue = await localDb.getPendingSyncQueue();
      expect(queue.map((q) => q.action).toList(), ['CREATE', 'UPDATE', 'DELETE']);
      expect(queue.every((q) => q.entityId == created.id), isTrue);
    });
  });
}

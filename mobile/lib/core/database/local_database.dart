import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../features/categories/domain/entities/category_entity.dart';
import '../../features/transactions/domain/entities/transaction_entity.dart';
import 'sync_status.dart';

final localDatabaseProvider = Provider<LocalDatabase>((ref) {
  return LocalDatabase();
});

class LocalDatabase {
  final String? _customPath;
  Database? _db;

  LocalDatabase({String? customPath}) : _customPath = customPath;

  factory LocalDatabase.inMemory() {
    return LocalDatabase(customPath: inMemoryDatabasePath);
  }

  Future<Database> get database async {
    if (_db != null && _db!.isOpen) {
      return _db!;
    }
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = _customPath ??
        p.join(await getDatabasesPath(), 'spendwise_offline_v1.db');

    return openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE cached_categories (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            type TEXT NOT NULL,
            icon TEXT NOT NULL,
            color_hex TEXT NOT NULL,
            is_system INTEGER NOT NULL DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE cached_transactions (
            id TEXT PRIMARY KEY,
            category_id TEXT NOT NULL,
            type TEXT NOT NULL,
            amount_paise INTEGER NOT NULL,
            currency TEXT NOT NULL DEFAULT 'INR',
            merchant TEXT,
            description TEXT NOT NULL,
            notes TEXT,
            payment_method TEXT NOT NULL,
            transaction_date TEXT NOT NULL,
            is_auto_categorized INTEGER NOT NULL DEFAULT 0,
            categorization_confidence INTEGER,
            is_demo_data INTEGER NOT NULL DEFAULT 0,
            sync_status TEXT NOT NULL DEFAULT 'SYNCED',
            version INTEGER NOT NULL DEFAULT 1,
            is_deleted INTEGER NOT NULL DEFAULT 0,
            category_json TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE sync_queue (
            operation_id TEXT PRIMARY KEY,
            entity_type TEXT NOT NULL,
            entity_id TEXT NOT NULL,
            action TEXT NOT NULL,
            payload_json TEXT NOT NULL,
            sync_status TEXT NOT NULL,
            base_version INTEGER NOT NULL DEFAULT 1,
            retry_count INTEGER NOT NULL DEFAULT 0,
            next_retry_at TEXT,
            last_error TEXT,
            conflict_server_json TEXT,
            created_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE sync_metadata (
            meta_key TEXT PRIMARY KEY,
            meta_value TEXT NOT NULL
          )
        ''');
      },
    );
  }

  Future<void> upsertCategories(List<CategoryEntity> categories) async {
    final db = await database;
    final batch = db.batch();
    for (final cat in categories) {
      batch.insert(
        'cached_categories',
        {
          'id': cat.id,
          'name': cat.name,
          'type': cat.type,
          'icon': cat.icon,
          'color_hex': cat.colorHex,
          'is_system': cat.isSystem ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<CategoryEntity>> getCachedCategories({String? type}) async {
    final db = await database;
    final rows = await db.query(
      'cached_categories',
      where: type != null ? 'type = ?' : null,
      whereArgs: type != null ? [type] : null,
      orderBy: 'name ASC',
    );
    return rows
        .map(
          (r) => CategoryEntity(
            id: r['id'] as String,
            name: r['name'] as String,
            type: r['type'] as String,
            icon: r['icon'] as String,
            colorHex: r['color_hex'] as String,
            isSystem: (r['is_system'] as int? ?? 0) == 1,
          ),
        )
        .toList();
  }

  Future<void> upsertSingleTransaction(
    TransactionEntity tx, {
    bool isDeleted = false,
  }) async {
    final db = await database;
    await db.insert(
      'cached_transactions',
      {
        'id': tx.id,
        'category_id': tx.categoryId,
        'type': tx.type,
        'amount_paise': tx.amountPaise,
        'currency': tx.currency,
        'merchant': tx.merchant,
        'description': tx.description,
        'notes': tx.notes,
        'payment_method': tx.paymentMethod,
        'transaction_date': tx.transactionDate.toUtc().toIso8601String(),
        'is_auto_categorized': tx.isAutoCategorized ? 1 : 0,
        'categorization_confidence': tx.categorizationConfidence,
        'is_demo_data': tx.isDemoData ? 1 : 0,
        'sync_status': tx.syncStatus,
        'version': tx.version,
        'is_deleted': isDeleted ? 1 : 0,
        'category_json': jsonEncode(tx.category.toJson()),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertTransactions(
    List<TransactionEntity> transactions, {
    bool preservePendingLocal = true,
  }) async {
    final db = await database;
    for (final tx in transactions) {
      if (preservePendingLocal) {
        final existing = await db.query(
          'cached_transactions',
          columns: ['sync_status'],
          where: 'id = ?',
          whereArgs: [tx.id],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          final status = existing.first['sync_status'] as String?;
          if (status == SyncStatusState.pendingSync.value ||
              status == SyncStatusState.localOnly.value ||
              status == SyncStatusState.conflict.value) {
            continue;
          }
        }
      }
      await upsertSingleTransaction(tx);
    }
  }

  Future<void> markTransactionDeletedOffline(String id) async {
    final db = await database;
    await db.update(
      'cached_transactions',
      {
        'is_deleted': 1,
        'sync_status': SyncStatusState.pendingSync.value,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateTransactionSyncStatus(
    String id,
    SyncStatusState status, {
    int? newVersion,
  }) async {
    final db = await database;
    await db.update(
      'cached_transactions',
      {
        'sync_status': status.value,
        if (newVersion != null) 'version': newVersion,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<TransactionEntity>> getCachedTransactions({
    String? type,
    String? categoryId,
    String? search,
  }) async {
    final db = await database;
    final whereClauses = <String>['is_deleted = 0'];
    final args = <Object?>[];

    if (type != null) {
      whereClauses.add('type = ?');
      args.add(type);
    }
    if (categoryId != null) {
      whereClauses.add('category_id = ?');
      args.add(categoryId);
    }
    if (search != null && search.trim().isNotEmpty) {
      whereClauses.add('(description LIKE ? OR merchant LIKE ?)');
      final q = '%${search.trim()}%';
      args.add(q);
      args.add(q);
    }

    final rows = await db.query(
      'cached_transactions',
      where: whereClauses.join(' AND '),
      whereArgs: args,
      orderBy: 'transaction_date DESC',
    );

    return rows.map(_mapRowToTransaction).toList();
  }

  TransactionEntity _mapRowToTransaction(Map<String, Object?> r) {
    final catMap =
        jsonDecode(r['category_json'] as String) as Map<String, dynamic>;
    return TransactionEntity(
      id: r['id'] as String,
      categoryId: r['category_id'] as String,
      type: r['type'] as String,
      amountPaise: (r['amount_paise'] as num).toInt(),
      currency: (r['currency'] as String?) ?? 'INR',
      merchant: r['merchant'] as String?,
      description: r['description'] as String,
      notes: r['notes'] as String?,
      paymentMethod: r['payment_method'] as String,
      transactionDate: DateTime.parse(r['transaction_date'] as String),
      isAutoCategorized: ((r['is_auto_categorized'] as int?) ?? 0) == 1,
      categorizationConfidence: r['categorization_confidence'] as int?,
      isDemoData: ((r['is_demo_data'] as int?) ?? 0) == 1,
      syncStatus: (r['sync_status'] as String?) ?? 'SYNCED',
      version: (r['version'] as int?) ?? 1,
      category: CategoryEntity.fromJson(catMap),
    );
  }

  Future<void> enqueueSyncOperation(PendingSyncQueueItem item) async {
    final db = await database;
    // Deduplicate existing pending operation for the same entityId & action when appropriate
    if (item.action == 'UPDATE') {
      await db.delete(
        'sync_queue',
        where: 'entity_id = ? AND action = ? AND sync_status != ?',
        whereArgs: [item.entityId, 'UPDATE', SyncStatusState.conflict.value],
      );
    }
    await db.insert(
      'sync_queue',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<PendingSyncQueueItem>> getPendingSyncQueue() async {
    final db = await database;
    final rows = await db.query(
      'sync_queue',
      orderBy: 'created_at ASC',
    );
    return rows.map((r) => PendingSyncQueueItem.fromMap(r)).toList();
  }

  Future<void> updateSyncQueueItemStatus(
    String operationId, {
    required SyncStatusState status,
    int? retryCount,
    DateTime? nextRetryAt,
    String? lastError,
    String? conflictServerJson,
  }) async {
    final db = await database;
    await db.update(
      'sync_queue',
      {
        'sync_status': status.value,
        if (retryCount != null) 'retry_count': retryCount,
        if (nextRetryAt != null)
          'next_retry_at': nextRetryAt.toUtc().toIso8601String(),
        if (lastError != null) 'last_error': lastError,
        if (conflictServerJson != null)
          'conflict_server_json': conflictServerJson,
      },
      where: 'operation_id = ?',
      whereArgs: [operationId],
    );
  }

  Future<void> removeSyncQueueItem(String operationId) async {
    final db = await database;
    await db.delete(
      'sync_queue',
      where: 'operation_id = ?',
      whereArgs: [operationId],
    );
  }

  Future<DateTime?> getLastSyncTimestamp() async {
    final db = await database;
    final rows = await db.query(
      'sync_metadata',
      where: 'meta_key = ?',
      whereArgs: ['last_pull_timestamp'],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DateTime.tryParse(rows.first['meta_value'] as String);
  }

  Future<void> setLastSyncTimestamp(DateTime timestamp) async {
    final db = await database;
    await db.insert(
      'sync_metadata',
      {
        'meta_key': 'last_pull_timestamp',
        'meta_value': timestamp.toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}

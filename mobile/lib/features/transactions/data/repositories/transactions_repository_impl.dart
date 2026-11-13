import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/network/api_client.dart';
import '../../../categories/domain/entities/category_entity.dart';
import '../../../categorization/domain/services/deterministic_categorizer.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/repositories/transactions_repository.dart';

final transactionsRepositoryProvider = Provider<TransactionsRepository>((ref) {
  return TransactionsRepositoryImpl(dio: ref.watch(dioClientProvider));
});

class TransactionsRepositoryImpl implements TransactionsRepository {
  TransactionsRepositoryImpl({required Dio dio}) : _dio = dio;

  final Dio _dio;
  static const Uuid _uuid = Uuid();

  String _extractError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final err = data['error'];
        if (err is Map<String, dynamic> && err['message'] is String) {
          return err['message'] as String;
        }
      }
      return error.message ?? 'Network request failed';
    }
    return error.toString();
  }

  @override
  Future<List<CategoryEntity>> getCategories({String? type}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/categories',
        queryParameters: {
          if (type != null) 'type': type,
        },
      );
      final data = response.data!['data'] as Map<String, dynamic>;
      final list = data['categories'] as List<dynamic>;
      return list
          .map((item) => CategoryEntity.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception(_extractError(e));
    }
  }

  @override
  Future<CategoryEntity> createCustomCategory({
    required String name,
    required String type,
    String icon = 'category',
    String colorHex = '#4F46E5',
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/categories',
        data: {
          'id': _uuid.v4(),
          'name': name.trim(),
          'type': type,
          'icon': icon,
          'colorHex': colorHex,
        },
      );
      final data = response.data!['data'] as Map<String, dynamic>;
      return CategoryEntity.fromJson(data['category'] as Map<String, dynamic>);
    } catch (e) {
      throw Exception(_extractError(e));
    }
  }

  @override
  Future<void> deleteCustomCategory(String categoryId) async {
    try {
      await _dio.delete<Map<String, dynamic>>('/categories/$categoryId');
    } catch (e) {
      throw Exception(_extractError(e));
    }
  }

  @override
  Future<TransactionsSummaryResult> getTransactions(
    TransactionsFilter filter,
  ) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/transactions',
        queryParameters: {
          'limit': 100,
          if (filter.type != null) 'type': filter.type,
          if (filter.categoryId != null) 'categoryId': filter.categoryId,
          if (filter.paymentMethod != null)
            'paymentMethod': filter.paymentMethod,
          if (filter.search != null && filter.search!.trim().isNotEmpty)
            'search': filter.search!.trim(),
          if (filter.startDate != null)
            'startDate': filter.startDate!.toUtc().toIso8601String(),
          if (filter.endDate != null)
            'endDate': filter.endDate!.toUtc().toIso8601String(),
          'sortBy': filter.sortBy,
          'sortOrder': filter.sortOrder,
        },
      );

      final data = response.data!['data'] as Map<String, dynamic>;
      final rawList = data['transactions'] as List<dynamic>;
      final summary = data['summary'] as Map<String, dynamic>;

      final transactions = rawList
          .map((item) => TransactionEntity.fromJson(item as Map<String, dynamic>))
          .toList();

      return TransactionsSummaryResult(
        transactions: transactions,
        totalIncomePaise: int.parse(summary['totalIncomePaise'].toString()),
        totalExpensePaise: int.parse(summary['totalExpensePaise'].toString()),
        netSavingsPaise: int.parse(summary['netSavingsPaise'].toString()),
      );
    } catch (e) {
      throw Exception(_extractError(e));
    }
  }

  @override
  Future<TransactionEntity> createTransaction({
    required String categoryId,
    required String type,
    required int amountPaise,
    required String description,
    required String paymentMethod,
    required DateTime transactionDate,
    String? merchant,
    String? notes,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/transactions',
        data: {
          'id': _uuid.v4(),
          'categoryId': categoryId,
          'type': type,
          'amountPaise': amountPaise.toString(),
          'description': description.trim(),
          'paymentMethod': paymentMethod,
          'transactionDate': transactionDate.toUtc().toIso8601String(),
          if (merchant != null && merchant.trim().isNotEmpty)
            'merchant': merchant.trim(),
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        },
      );
      final data = response.data!['data'] as Map<String, dynamic>;
      return TransactionEntity.fromJson(
        data['transaction'] as Map<String, dynamic>,
      );
    } catch (e) {
      throw Exception(_extractError(e));
    }
  }

  @override
  Future<TransactionEntity> updateTransaction({
    required String id,
    required String categoryId,
    required String type,
    required int amountPaise,
    required String description,
    required String paymentMethod,
    required DateTime transactionDate,
    String? merchant,
    String? notes,
    int? expectedVersion,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/transactions/$id',
        data: {
          'categoryId': categoryId,
          'type': type,
          'amountPaise': amountPaise.toString(),
          'description': description.trim(),
          'paymentMethod': paymentMethod,
          'transactionDate': transactionDate.toUtc().toIso8601String(),
          'merchant':
              merchant != null && merchant.trim().isNotEmpty ? merchant.trim() : null,
          'notes': notes != null && notes.trim().isNotEmpty ? notes.trim() : null,
          if (expectedVersion != null) 'expectedVersion': expectedVersion,
        },
      );
      final data = response.data!['data'] as Map<String, dynamic>;
      return TransactionEntity.fromJson(
        data['transaction'] as Map<String, dynamic>,
      );
    } catch (e) {
      throw Exception(_extractError(e));
    }
  }

  @override
  Future<void> deleteTransaction(String id) async {
    try {
      await _dio.delete<Map<String, dynamic>>('/transactions/$id');
    } catch (e) {
      throw Exception(_extractError(e));
    }
  }

  @override
  Future<List<CategorizationRuleEntity>> getUserCategorizationRules() async {
    try {
      final response =
          await _dio.get<Map<String, dynamic>>('/categorization/rules');
      final data = response.data!['data'] as Map<String, dynamic>;
      final list = data['userRules'] as List<dynamic>;
      return list.map((item) {
        final map = item as Map<String, dynamic>;
        final cat = map['category'] as Map<String, dynamic>?;
        return CategorizationRuleEntity(
          id: map['id'] as String?,
          categoryId: map['categoryId'] as String?,
          pattern: map['pattern'] as String,
          categoryName: (cat?['name'] as String?) ?? 'Other',
          transactionType: (map['transactionType'] as String?) ?? 'EXPENSE',
          confidence: (map['confidence'] as int?) ?? 95,
          priority: (map['priority'] as int?) ?? 200,
          isUserCorrection: (map['isUserCorrection'] as bool?) ?? false,
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<CategorizationRuleEntity> saveUserCategorizationRule({
    required String categoryId,
    required String transactionType,
    required String pattern,
    bool isUserCorrection = false,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/categorization/rules',
        data: {
          'categoryId': categoryId,
          'transactionType': transactionType,
          'pattern': pattern.trim(),
          'isUserCorrection': isUserCorrection,
        },
      );
      final data = response.data!['data'] as Map<String, dynamic>;
      final rule = data['rule'] as Map<String, dynamic>;
      final cat = rule['category'] as Map<String, dynamic>?;
      return CategorizationRuleEntity(
        id: rule['id'] as String?,
        categoryId: rule['categoryId'] as String?,
        pattern: rule['pattern'] as String,
        categoryName: (cat?['name'] as String?) ?? 'Other',
        transactionType: (rule['transactionType'] as String?) ?? transactionType,
        confidence: (rule['confidence'] as int?) ?? 98,
        priority: (rule['priority'] as int?) ?? 220,
        isUserCorrection: (rule['isUserCorrection'] as bool?) ?? isUserCorrection,
      );
    } catch (e) {
      throw Exception(_extractError(e));
    }
  }
}

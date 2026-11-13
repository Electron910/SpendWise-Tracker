import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/budget_entity.dart';

abstract class BudgetsRepository {
  Future<MonthlyBudgetsOverview> getBudgets({
    required int month,
    required int year,
  });

  Future<void> saveBudget({
    required int month,
    required int year,
    required int amountPaise,
    String? categoryId,
    List<int> alertThresholds = const [50, 75, 90, 100],
  });

  Future<void> deleteBudget(String id);
}

final budgetsRepositoryProvider = Provider<BudgetsRepository>((ref) {
  return BudgetsRepositoryImpl(dio: ref.watch(dioClientProvider));
});

class BudgetsRepositoryImpl implements BudgetsRepository {
  BudgetsRepositoryImpl({required Dio dio}) : _dio = dio;

  final Dio _dio;

  @override
  Future<MonthlyBudgetsOverview> getBudgets({
    required int month,
    required int year,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/budgets',
      queryParameters: {
        'month': month,
        'year': year,
      },
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    final period = data['period'] as Map<String, dynamic>;
    final overallRaw = data['overallBudget'] as Map<String, dynamic>?;
    final catRaw = data['categoryBudgets'] as List<dynamic>? ?? [];

    return MonthlyBudgetsOverview(
      month: (period['month'] as num).toInt(),
      year: (period['year'] as num).toInt(),
      totalMonthlyExpensePaise:
          int.parse(period['totalMonthlyExpensePaise'].toString()),
      previousMonthExpensePaise:
          int.parse(period['previousMonthExpensePaise'].toString()),
      overallBudget:
          overallRaw != null ? BudgetEntity.fromJson(overallRaw) : null,
      categoryBudgets: catRaw
          .map((e) => BudgetEntity.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  Future<void> saveBudget({
    required int month,
    required int year,
    required int amountPaise,
    String? categoryId,
    List<int> alertThresholds = const [50, 75, 90, 100],
  }) async {
    await _dio.post<Map<String, dynamic>>(
      '/budgets',
      data: {
        'categoryId': categoryId,
        'month': month,
        'year': year,
        'amountPaise': amountPaise.toString(),
        'alertThresholds': alertThresholds,
      },
    );
  }

  @override
  Future<void> deleteBudget(String id) async {
    await _dio.delete<Map<String, dynamic>>('/budgets/$id');
  }
}

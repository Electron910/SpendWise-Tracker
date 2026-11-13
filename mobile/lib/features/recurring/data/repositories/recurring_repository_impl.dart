import 'package:dio/dio.dart';

import '../../domain/entities/recurring_expense_entity.dart';

class RecurringRepositoryImpl {
  final Dio _dio;

  RecurringRepositoryImpl(this._dio);

  Future<List<RecurringExpenseEntity>> fetchRecurringExpenses() async {
    final response = await _dio.get('/recurring');
    final data = response.data['data'] as Map<String, dynamic>;
    final list = data['recurringExpenses'] as List<dynamic>;
    return list
        .map((e) => RecurringExpenseEntity.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<RecurringExpenseEntity> createRecurringExpense({
    required String categoryId,
    required String type,
    required String title,
    String? merchant,
    String? description,
    required int amountPaise,
    required String paymentMethod,
    required String frequency,
    int intervalCount = 1,
    required DateTime startDate,
    DateTime? endDate,
    int reminderDays = 3,
  }) async {
    final response = await _dio.post(
      '/recurring',
      data: {
        'categoryId': categoryId,
        'type': type,
        'title': title,
        if (merchant != null && merchant.isNotEmpty) 'merchant': merchant,
        if (description != null && description.isNotEmpty) 'description': description,
        'amountPaise': amountPaise,
        'paymentMethod': paymentMethod,
        'frequency': frequency,
        'intervalCount': intervalCount,
        'startDate': startDate.toUtc().toIso8601String(),
        if (endDate != null) 'endDate': endDate.toUtc().toIso8601String(),
        'reminderDays': reminderDays,
      },
    );
    final data = response.data['data'] as Map<String, dynamic>;
    return RecurringExpenseEntity.fromJson(
      data['recurringExpense'] as Map<String, dynamic>,
    );
  }

  Future<RecurringExpenseEntity> toggleActiveStatus({
    required String id,
    required bool isActive,
  }) async {
    final response = await _dio.patch(
      '/recurring/$id',
      data: {'isActive': isActive},
    );
    final data = response.data['data'] as Map<String, dynamic>;
    return RecurringExpenseEntity.fromJson(
      data['recurringExpense'] as Map<String, dynamic>,
    );
  }

  Future<void> deleteRecurringExpense(String id) async {
    await _dio.delete('/recurring/$id');
  }
}

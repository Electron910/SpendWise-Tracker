import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../data/repositories/recurring_repository_impl.dart';
import '../../domain/entities/recurring_expense_entity.dart';

final recurringRepositoryProvider = Provider<RecurringRepositoryImpl>((ref) {
  return RecurringRepositoryImpl(ref.watch(dioClientProvider));
});

class RecurringState {
  final List<RecurringExpenseEntity> items;
  final bool isLoading;
  final String? errorMessage;

  const RecurringState({
    this.items = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  RecurringState copyWith({
    List<RecurringExpenseEntity>? items,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return RecurringState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class RecurringNotifier extends StateNotifier<RecurringState> {
  final RecurringRepositoryImpl _repository;

  RecurringNotifier(this._repository) : super(const RecurringState(isLoading: true)) {
    loadRecurring();
  }

  Future<void> loadRecurring() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final list = await _repository.fetchRecurringExpenses();
      state = state.copyWith(items: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<bool> createRecurring({
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
    try {
      await _repository.createRecurringExpense(
        categoryId: categoryId,
        type: type,
        title: title,
        merchant: merchant,
        description: description,
        amountPaise: amountPaise,
        paymentMethod: paymentMethod,
        frequency: frequency,
        intervalCount: intervalCount,
        startDate: startDate,
        endDate: endDate,
        reminderDays: reminderDays,
      );
      await loadRecurring();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  Future<void> toggleActive(String id, bool isActive) async {
    try {
      await _repository.toggleActiveStatus(id: id, isActive: isActive);
      await loadRecurring();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> deleteRecurring(String id) async {
    try {
      await _repository.deleteRecurringExpense(id);
      await loadRecurring();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }
}

final recurringProvider = StateNotifierProvider<RecurringNotifier, RecurringState>((ref) {
  return RecurringNotifier(ref.watch(recurringRepositoryProvider));
});

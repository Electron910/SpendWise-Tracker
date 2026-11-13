import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../categories/domain/entities/category_entity.dart';
import '../../data/repositories/transactions_repository_impl.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/repositories/transactions_repository.dart';

class TransactionsState {
  const TransactionsState({
    this.isLoading = false,
    this.transactions = const [],
    this.categories = const [],
    this.totalIncomePaise = 0,
    this.totalExpensePaise = 0,
    this.netSavingsPaise = 0,
    this.filter = const TransactionsFilter(),
    this.errorMessage,
  });

  final bool isLoading;
  final List<TransactionEntity> transactions;
  final List<CategoryEntity> categories;
  final int totalIncomePaise;
  final int totalExpensePaise;
  final int netSavingsPaise;
  final TransactionsFilter filter;
  final String? errorMessage;

  List<CategoryEntity> categoriesForType(String type) =>
      categories.where((c) => c.type == type).toList();

  TransactionsState copyWith({
    bool? isLoading,
    List<TransactionEntity>? transactions,
    List<CategoryEntity>? categories,
    int? totalIncomePaise,
    int? totalExpensePaise,
    int? netSavingsPaise,
    TransactionsFilter? filter,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TransactionsState(
      isLoading: isLoading ?? this.isLoading,
      transactions: transactions ?? this.transactions,
      categories: categories ?? this.categories,
      totalIncomePaise: totalIncomePaise ?? this.totalIncomePaise,
      totalExpensePaise: totalExpensePaise ?? this.totalExpensePaise,
      netSavingsPaise: netSavingsPaise ?? this.netSavingsPaise,
      filter: filter ?? this.filter,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class TransactionsNotifier extends StateNotifier<TransactionsState> {
  TransactionsNotifier(this._repository) : super(const TransactionsState());

  final TransactionsRepository _repository;

  Future<void> loadInitialData() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final results = await Future.wait([
        _repository.getCategories(),
        _repository.getTransactions(state.filter),
      ]);
      final categories = results[0] as List<CategoryEntity>;
      final txSummary = results[1] as TransactionsSummaryResult;

      state = state.copyWith(
        isLoading: false,
        categories: categories,
        transactions: txSummary.transactions,
        totalIncomePaise: txSummary.totalIncomePaise,
        totalExpensePaise: txSummary.totalExpensePaise,
        netSavingsPaise: txSummary.netSavingsPaise,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> updateFilter(TransactionsFilter newFilter) async {
    state = state.copyWith(filter: newFilter, isLoading: true, clearError: true);
    try {
      final txSummary = await _repository.getTransactions(newFilter);
      state = state.copyWith(
        isLoading: false,
        transactions: txSummary.transactions,
        totalIncomePaise: txSummary.totalIncomePaise,
        totalExpensePaise: txSummary.totalExpensePaise,
        netSavingsPaise: txSummary.netSavingsPaise,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<bool> addTransaction({
    required String categoryId,
    required String type,
    required int amountPaise,
    required String description,
    required String paymentMethod,
    required DateTime transactionDate,
    String? merchant,
    String? notes,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repository.createTransaction(
        categoryId: categoryId,
        type: type,
        amountPaise: amountPaise,
        description: description,
        paymentMethod: paymentMethod,
        transactionDate: transactionDate,
        merchant: merchant,
        notes: notes,
      );
      await loadInitialData();
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  Future<bool> editTransaction({
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
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repository.updateTransaction(
        id: id,
        categoryId: categoryId,
        type: type,
        amountPaise: amountPaise,
        description: description,
        paymentMethod: paymentMethod,
        transactionDate: transactionDate,
        merchant: merchant,
        notes: notes,
        expectedVersion: expectedVersion,
      );
      await loadInitialData();
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  Future<bool> removeTransaction(String id) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repository.deleteTransaction(id);
      await loadInitialData();
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  Future<bool> addCustomCategory({
    required String name,
    required String type,
    String colorHex = '#4F46E5',
  }) async {
    try {
      await _repository.createCustomCategory(
        name: name,
        type: type,
        colorHex: colorHex,
      );
      final updated = await _repository.getCategories();
      state = state.copyWith(categories: updated);
      return true;
    } catch (e) {
      state = state.copyWith(
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }
}

final transactionsNotifierProvider =
    StateNotifierProvider<TransactionsNotifier, TransactionsState>((ref) {
  return TransactionsNotifier(ref.watch(transactionsRepositoryProvider));
});

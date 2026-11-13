import '../../../categories/domain/entities/category_entity.dart';
import '../../../categorization/domain/services/deterministic_categorizer.dart';
import '../entities/transaction_entity.dart';

class TransactionsFilter {
  const TransactionsFilter({
    this.type,
    this.categoryId,
    this.paymentMethod,
    this.search,
    this.startDate,
    this.endDate,
    this.sortBy = 'transactionDate',
    this.sortOrder = 'desc',
  });

  final String? type;
  final String? categoryId;
  final String? paymentMethod;
  final String? search;
  final DateTime? startDate;
  final DateTime? endDate;
  final String sortBy;
  final String sortOrder;

  TransactionsFilter copyWith({
    String? type,
    bool clearType = false,
    String? categoryId,
    bool clearCategory = false,
    String? paymentMethod,
    bool clearPaymentMethod = false,
    String? search,
    DateTime? startDate,
    bool clearDates = false,
    DateTime? endDate,
    String? sortBy,
    String? sortOrder,
  }) {
    return TransactionsFilter(
      type: clearType ? null : (type ?? this.type),
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      paymentMethod:
          clearPaymentMethod ? null : (paymentMethod ?? this.paymentMethod),
      search: search ?? this.search,
      startDate: clearDates ? null : (startDate ?? this.startDate),
      endDate: clearDates ? null : (endDate ?? this.endDate),
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

class TransactionsSummaryResult {
  const TransactionsSummaryResult({
    required this.transactions,
    required this.totalIncomePaise,
    required this.totalExpensePaise,
    required this.netSavingsPaise,
  });

  final List<TransactionEntity> transactions;
  final int totalIncomePaise;
  final int totalExpensePaise;
  final int netSavingsPaise;
}

abstract class TransactionsRepository {
  Future<List<CategoryEntity>> getCategories({String? type});

  Future<CategoryEntity> createCustomCategory({
    required String name,
    required String type,
    String icon = 'category',
    String colorHex = '#4F46E5',
  });

  Future<void> deleteCustomCategory(String categoryId);

  Future<TransactionsSummaryResult> getTransactions(TransactionsFilter filter);

  Future<TransactionEntity> createTransaction({
    required String categoryId,
    required String type,
    required int amountPaise,
    required String description,
    required String paymentMethod,
    required DateTime transactionDate,
    String? merchant,
    String? notes,
  });

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
  });

  Future<void> deleteTransaction(String id);

  Future<List<CategorizationRuleEntity>> getUserCategorizationRules();

  Future<CategorizationRuleEntity> saveUserCategorizationRule({
    required String categoryId,
    required String transactionType,
    required String pattern,
    bool isUserCorrection = false,
  });
}

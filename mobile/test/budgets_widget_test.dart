import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise_mobile/core/theme/app_theme.dart';
import 'package:spendwise_mobile/features/budgets/data/repositories/budgets_repository_impl.dart';
import 'package:spendwise_mobile/features/budgets/domain/entities/budget_entity.dart';
import 'package:spendwise_mobile/features/budgets/presentation/screens/budgets_screen.dart';
import 'package:spendwise_mobile/features/categories/domain/entities/category_entity.dart';
import 'package:spendwise_mobile/features/categorization/domain/services/deterministic_categorizer.dart';
import 'package:spendwise_mobile/features/transactions/data/repositories/transactions_repository_impl.dart';
import 'package:spendwise_mobile/features/transactions/domain/entities/transaction_entity.dart';
import 'package:spendwise_mobile/features/transactions/domain/repositories/transactions_repository.dart';

class FakeBudgetsRepository implements BudgetsRepository {
  final List<BudgetEntity> _categoryBudgets = [
    const BudgetEntity(
      id: 'b-food',
      categoryId: 'cat-food',
      categoryName: 'Food',
      colorHex: '#EF4444',
      icon: 'restaurant',
      month: 11,
      year: 2026,
      budgetPaise: 500000, // ₹5,000
      spentPaise: 450000, // ₹4,500
      remainingPaise: 50000, // ₹500
      previousMonthSpentPaise: 400000,
      monthOverMonthChangePercentage: 12,
      utilizationPercentage: 90,
      alertThresholds: [50, 75, 90, 100],
      reachedThresholds: [50, 75, 90],
      highestReachedThreshold: 90,
      alertLevel: 'CRITICAL',
    ),
  ];

  BudgetEntity? _overallBudget = const BudgetEntity(
    id: 'b-overall',
    categoryId: null,
    categoryName: 'Overall Monthly Budget',
    colorHex: '#4F46E5',
    icon: 'account_balance_wallet',
    month: 11,
    year: 2026,
    budgetPaise: 2500000, // ₹25,000
    spentPaise: 1250000, // ₹12,500
    remainingPaise: 1250000,
    previousMonthSpentPaise: 1000000,
    monthOverMonthChangePercentage: 25,
    utilizationPercentage: 50,
    alertThresholds: [50, 75, 90, 100],
    reachedThresholds: [50],
    highestReachedThreshold: 50,
    alertLevel: 'MODERATE',
  );

  @override
  Future<MonthlyBudgetsOverview> getBudgets({
    required int month,
    required int year,
  }) async {
    return MonthlyBudgetsOverview(
      month: month,
      year: year,
      totalMonthlyExpensePaise: 1250000,
      previousMonthExpensePaise: 1000000,
      overallBudget: _overallBudget,
      categoryBudgets: List.from(_categoryBudgets),
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
    if (categoryId == null) {
      _overallBudget = BudgetEntity(
        id: 'b-overall',
        categoryId: null,
        categoryName: 'Overall Monthly Budget',
        colorHex: '#4F46E5',
        icon: 'account_balance_wallet',
        month: month,
        year: year,
        budgetPaise: amountPaise,
        spentPaise: 1250000,
        remainingPaise: amountPaise - 1250000,
        previousMonthSpentPaise: 1000000,
        monthOverMonthChangePercentage: 25,
        utilizationPercentage: (1250000 * 100) ~/ amountPaise,
        alertThresholds: alertThresholds,
        reachedThresholds: const [],
        alertLevel: 'SAFE',
      );
    }
  }

  @override
  Future<void> deleteBudget(String id) async {
    if (_overallBudget?.id == id) {
      _overallBudget = null;
    } else {
      _categoryBudgets.removeWhere((b) => b.id == id);
    }
  }
}

class StubTransactionsRepo implements TransactionsRepository {
  @override
  Future<List<CategoryEntity>> getCategories({String? type}) async => const [
        CategoryEntity(
          id: 'cat-food',
          name: 'Food',
          type: 'EXPENSE',
          icon: 'restaurant',
          colorHex: '#EF4444',
        ),
      ];

  @override
  Future<TransactionsSummaryResult> getTransactions(
    TransactionsFilter filter,
  ) async =>
      const TransactionsSummaryResult(
        transactions: [],
        totalIncomePaise: 0,
        totalExpensePaise: 0,
        netSavingsPaise: 0,
      );

  @override
  Future<List<CategorizationRuleEntity>> getUserCategorizationRules() async =>
      const [];

  @override
  Future<CategoryEntity> createCustomCategory({
    required String name,
    required String type,
    String icon = 'category',
    String colorHex = '#4F46E5',
  }) =>
      throw UnimplementedError();

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
  }) =>
      throw UnimplementedError();

  @override
  Future<void> deleteCustomCategory(String categoryId) =>
      throw UnimplementedError();

  @override
  Future<void> deleteTransaction(String id) => throw UnimplementedError();

  @override
  Future<CategorizationRuleEntity> saveUserCategorizationRule({
    required String categoryId,
    required String transactionType,
    required String pattern,
    bool isUserCorrection = false,
  }) =>
      throw UnimplementedError();

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
  }) =>
      throw UnimplementedError();
}

void main() {
  group('BudgetsScreen Widget Tests', () {
    testWidgets(
        'renders overall and category budgets with 50% and 90% threshold alerts and MoM comparison',
        (tester) async {
      final fakeBudgetsRepo = FakeBudgetsRepository();
      final stubTxRepo = StubTransactionsRepo();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            budgetsRepositoryProvider.overrideWithValue(fakeBudgetsRepo),
            transactionsRepositoryProvider.overrideWithValue(stubTxRepo),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const BudgetsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Overall Budget card (50% MODERATE)
      expect(find.text('Overall Monthly Budget'), findsOneWidget);
      expect(find.text('50% (MODERATE)'), findsOneWidget);
      expect(
        find.text('Alert: Crossed 50% utilization threshold'),
        findsOneWidget,
      );

      // Verify Food Category Budget card (90% CRITICAL)
      expect(find.text('Food'), findsOneWidget);
      expect(find.text('90% (CRITICAL)'), findsOneWidget);
      expect(
        find.text('Alert: Crossed 90% utilization threshold'),
        findsOneWidget,
      );
      expect(find.textContaining('(+12% MoM)'), findsOneWidget);
    });
  });
}

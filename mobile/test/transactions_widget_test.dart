import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise_mobile/core/theme/app_theme.dart';
import 'package:spendwise_mobile/features/categories/domain/entities/category_entity.dart';
import 'package:spendwise_mobile/features/categorization/domain/services/deterministic_categorizer.dart';
import 'package:spendwise_mobile/features/transactions/data/repositories/transactions_repository_impl.dart';
import 'package:spendwise_mobile/features/transactions/domain/entities/transaction_entity.dart';
import 'package:spendwise_mobile/features/transactions/domain/repositories/transactions_repository.dart';
import 'package:spendwise_mobile/features/transactions/presentation/screens/transactions_screen.dart';

class FakeTransactionsRepository implements TransactionsRepository {
  final List<CategoryEntity> _categories = [
    const CategoryEntity(
      id: 'cat-food',
      name: 'Food',
      type: 'EXPENSE',
      icon: 'restaurant',
      colorHex: '#EF4444',
      isSystem: true,
    ),
    const CategoryEntity(
      id: 'cat-salary',
      name: 'Salary',
      type: 'INCOME',
      icon: 'payments',
      colorHex: '#10B981',
      isSystem: true,
    ),
  ];

  final List<TransactionEntity> _transactions = [
    TransactionEntity(
      id: 'tx-1',
      categoryId: 'cat-food',
      type: 'EXPENSE',
      amountPaise: 45050, // ₹450.50
      currency: 'INR',
      merchant: 'Swiggy',
      description: 'Biryani dinner',
      paymentMethod: 'UPI',
      transactionDate: DateTime(2026, 11, 10, 20, 0),
      category: const CategoryEntity(
        id: 'cat-food',
        name: 'Food',
        type: 'EXPENSE',
        icon: 'restaurant',
        colorHex: '#EF4444',
        isSystem: true,
      ),
    ),
  ];

  @override
  Future<List<CategoryEntity>> getCategories({String? type}) async {
    if (type == null) return List.from(_categories);
    return _categories.where((c) => c.type == type).toList();
  }

  @override
  Future<CategoryEntity> createCustomCategory({
    required String name,
    required String type,
    String icon = 'category',
    String colorHex = '#4F46E5',
  }) async {
    final created = CategoryEntity(
      id: 'cat-${_categories.length + 1}',
      name: name,
      type: type,
      icon: icon,
      colorHex: colorHex,
    );
    _categories.add(created);
    return created;
  }

  @override
  Future<void> deleteCustomCategory(String categoryId) async {
    _categories.removeWhere((c) => c.id == categoryId);
  }

  @override
  Future<TransactionsSummaryResult> getTransactions(
    TransactionsFilter filter,
  ) async {
    var list = List<TransactionEntity>.from(_transactions);
    if (filter.type != null) {
      list = list.where((t) => t.type == filter.type).toList();
    }
    if (filter.search != null && filter.search!.isNotEmpty) {
      final q = filter.search!.toLowerCase();
      list = list
          .where((t) =>
              t.description.toLowerCase().contains(q) ||
              (t.merchant?.toLowerCase().contains(q) ?? false))
          .toList();
    }

    var income = 0;
    var expense = 0;
    for (final tx in list) {
      if (tx.isIncome) {
        income += tx.amountPaise;
      } else {
        expense += tx.amountPaise;
      }
    }

    return TransactionsSummaryResult(
      transactions: list,
      totalIncomePaise: income,
      totalExpensePaise: expense,
      netSavingsPaise: income - expense,
    );
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
    final cat = _categories.firstWhere((c) => c.id == categoryId);
    final created = TransactionEntity(
      id: 'tx-${_transactions.length + 1}',
      categoryId: categoryId,
      type: type,
      amountPaise: amountPaise,
      currency: 'INR',
      merchant: merchant,
      description: description,
      notes: notes,
      paymentMethod: paymentMethod,
      transactionDate: transactionDate,
      category: cat,
    );
    _transactions.insert(0, created);
    return created;
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
    final idx = _transactions.indexWhere((t) => t.id == id);
    final cat = _categories.firstWhere((c) => c.id == categoryId);
    final updated = TransactionEntity(
      id: id,
      categoryId: categoryId,
      type: type,
      amountPaise: amountPaise,
      currency: 'INR',
      merchant: merchant,
      description: description,
      notes: notes,
      paymentMethod: paymentMethod,
      transactionDate: transactionDate,
      version: (expectedVersion ?? 1) + 1,
      category: cat,
    );
    _transactions[idx] = updated;
    return updated;
  }

  @override
  Future<void> deleteTransaction(String id) async {
    _transactions.removeWhere((t) => t.id == id);
  }

  final List<CategorizationRuleEntity> _userRules = [];

  @override
  Future<List<CategorizationRuleEntity>> getUserCategorizationRules() async =>
      List.from(_userRules);

  @override
  Future<CategorizationRuleEntity> saveUserCategorizationRule({
    required String categoryId,
    required String transactionType,
    required String pattern,
    bool isUserCorrection = false,
  }) async {
    final cat = _categories.firstWhere((c) => c.id == categoryId);
    final rule = CategorizationRuleEntity(
      id: 'rule-${_userRules.length + 1}',
      categoryId: categoryId,
      pattern: DeterministicCategorizer.normalize(pattern),
      categoryName: cat.name,
      transactionType: transactionType,
      confidence: 99,
      priority: 250,
      isUserCorrection: isUserCorrection,
    );
    _userRules.add(rule);
    return rule;
  }
}

void main() {
  group('DeterministicCategorizer Unit Tests', () {
    const testCategories = [
      CategoryEntity(
        id: 'cat-food',
        name: 'Food',
        type: 'EXPENSE',
        icon: 'restaurant',
        colorHex: '#EF4444',
      ),
      CategoryEntity(
        id: 'cat-transport',
        name: 'Transportation',
        type: 'EXPENSE',
        icon: 'directions_car',
        colorHex: '#F97316',
      ),
      CategoryEntity(
        id: 'cat-subs',
        name: 'Subscriptions',
        type: 'EXPENSE',
        icon: 'subscriptions',
        colorHex: '#A855F7',
      ),
      CategoryEntity(
        id: 'cat-shopping',
        name: 'Shopping',
        type: 'EXPENSE',
        icon: 'shopping_bag',
        colorHex: '#EC4899',
      ),
      CategoryEntity(
        id: 'cat-groceries',
        name: 'Groceries',
        type: 'EXPENSE',
        icon: 'local_grocery_store',
        colorHex: '#22C55E',
      ),
    ];

    test('maps SWIGGY -> Food, UBER -> Transportation, NETFLIX -> Subscriptions, AMAZON -> Shopping', () {
      final swiggy = DeterministicCategorizer.predict(
        transactionType: 'EXPENSE',
        availableCategories: testCategories,
        merchant: 'Swiggy India',
        description: 'Dinner order',
      );
      expect(swiggy.matched, isTrue);
      expect(swiggy.categoryName, 'Food');
      expect(swiggy.confidence, greaterThanOrEqualTo(90));

      final uber = DeterministicCategorizer.predict(
        transactionType: 'EXPENSE',
        availableCategories: testCategories,
        description: 'Uber cab to airport',
      );
      expect(uber.matched, isTrue);
      expect(uber.categoryName, 'Transportation');

      final netflix = DeterministicCategorizer.predict(
        transactionType: 'EXPENSE',
        availableCategories: testCategories,
        merchant: 'NETFLIX.COM',
      );
      expect(netflix.matched, isTrue);
      expect(netflix.categoryName, 'Subscriptions');

      final amazon = DeterministicCategorizer.predict(
        transactionType: 'EXPENSE',
        availableCategories: testCategories,
        merchant: 'Amazon Retail',
      );
      expect(amazon.matched, isTrue);
      expect(amazon.categoryName, 'Shopping');
    });

    test('prioritizes learned user correction over built-in merchant rule', () {
      const learnedRule = CategorizationRuleEntity(
        categoryId: 'cat-groceries',
        pattern: 'AMAZON PANTRY',
        categoryName: 'Groceries',
        transactionType: 'EXPENSE',
        confidence: 99,
        priority: 250,
        isUserCorrection: true,
      );

      final result = DeterministicCategorizer.predict(
        transactionType: 'EXPENSE',
        availableCategories: testCategories,
        merchant: 'Amazon Pantry Order',
        userRules: const [learnedRule],
      );

      expect(result.matched, isTrue);
      expect(result.categoryName, 'Groceries');
      expect(result.isUserPreference, isTrue);
      expect(result.confidence, 99);
    });
  });

  group('TransactionsScreen & TransactionFormScreen Widget Tests', () {
    testWidgets('renders transaction list and creates a new expense transaction',
        (tester) async {
      final fakeRepo = FakeTransactionsRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            transactionsRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const TransactionsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify initial transaction is rendered
      expect(find.text('Biryani dinner'), findsOneWidget);
      expect(find.text('-₹450.50'), findsWidgets);

      // Tap Add Transaction FAB
      await tester.tap(find.byKey(const Key('add_transaction_fab')));
      await tester.pumpAndSettle();

      // Enter ₹250.00 and description
      await tester.enterText(
        find.byKey(const Key('tx_amount_field')),
        '250.00',
      );
      await tester.enterText(
        find.byKey(const Key('tx_description_field')),
        'Coffee & Snacks',
      );

      final submitBtn = find.byKey(const Key('tx_submit_button'));
      await tester.ensureVisible(submitBtn);
      await tester.pumpAndSettle();
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Verify newly added transaction appears in list
      expect(find.text('Coffee & Snacks'), findsOneWidget);
      expect(find.text('-₹250.00'), findsWidgets);
    });
  });
}

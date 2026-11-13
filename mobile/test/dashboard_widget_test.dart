import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise_mobile/core/theme/app_theme.dart';
import 'package:spendwise_mobile/features/categories/domain/entities/category_entity.dart';
import 'package:spendwise_mobile/features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'package:spendwise_mobile/features/dashboard/domain/entities/dashboard_overview_entity.dart';
import 'package:spendwise_mobile/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:spendwise_mobile/features/transactions/domain/entities/transaction_entity.dart';

class FakeDashboardRepository implements DashboardRepository {
  int lastRequestedMonth = 11;
  int lastRequestedYear = 2026;

  @override
  Future<DashboardOverviewEntity> getOverview({
    required int month,
    required int year,
  }) async {
    lastRequestedMonth = month;
    lastRequestedYear = year;

    return DashboardOverviewEntity(
      month: month,
      year: year,
      totalIncomePaise: 9500000, // ₹95,000
      totalExpensePaise: 2850000, // ₹28,500
      currentSavingsPaise: 6650000, // ₹66,500
      savingsRatePercentage: 70,
      overallBudgetPaise: 5000000, // ₹50,000
      remainingBudgetPaise: 2150000, // ₹21,500
      budgetUtilizationPercentage: 57,
      categoryBreakdown: const [
        CategoryExpenseSummary(
          categoryId: 'cat-rent',
          categoryName: 'Rent',
          colorHex: '#6366F1',
          icon: 'home',
          amountPaise: 2400000,
          percentage: 84,
          transactionCount: 1,
        ),
        CategoryExpenseSummary(
          categoryId: 'cat-food',
          categoryName: 'Food',
          colorHex: '#EF4444',
          icon: 'restaurant',
          amountPaise: 450000,
          percentage: 16,
          transactionCount: 3,
        ),
      ],
      budgetUtilization: const [
        BudgetUtilizationItem(
          budgetId: 'b-food',
          categoryId: 'cat-food',
          categoryName: 'Food',
          colorHex: '#EF4444',
          budgetPaise: 500000,
          spentPaise: 450000,
          remainingPaise: 50000,
          utilizationPercentage: 90,
          alertLevel: 'CRITICAL',
        ),
      ],
      dailySpendingSeries: const [
        DailySpendingPoint(day: 1, incomePaise: 9500000, expensePaise: 0),
        DailySpendingPoint(day: 2, incomePaise: 0, expensePaise: 2400000),
      ],
      recentTransactions: [
        TransactionEntity(
          id: 'tx-rent',
          categoryId: 'cat-rent',
          type: 'EXPENSE',
          amountPaise: 2400000,
          currency: 'INR',
          description: 'Monthly Apartment Rent',
          paymentMethod: 'UPI',
          transactionDate: DateTime(year, month, 2),
          category: const CategoryEntity(
            id: 'cat-rent',
            name: 'Rent',
            type: 'EXPENSE',
            icon: 'home',
            colorHex: '#6366F1',
          ),
        ),
      ],
      upcomingRecurring: [
        UpcomingRecurringItem(
          id: 'rec-netflix',
          title: 'Netflix Standard Plan',
          amountPaise: 64900,
          frequency: 'MONTHLY',
          nextOccurrence: DateTime(year, month, 18),
          categoryName: 'Subscriptions',
          colorHex: '#A855F7',
        ),
      ],
    );
  }
}

void main() {
  group('DashboardScreen Widget Tests', () {
    testWidgets(
        'renders live financial summary, category breakdown, budget utilization, and switches months',
        (tester) async {
      final fakeRepo = FakeDashboardRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dashboardRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(body: DashboardScreen()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check hero financial metrics
      expect(
        find.byKey(const Key('dashboard_net_savings_text')),
        findsOneWidget,
      );
      expect(find.text('₹66,500.00'), findsOneWidget);
      expect(find.text('Savings Rate: 70%'), findsOneWidget);
      expect(find.text('₹21,500'), findsOneWidget); // Remaining budget

      // Scroll down to Category Breakdown and Budget Utilization cards
      await tester.drag(find.byType(ListView), const Offset(0, -350));
      await tester.pumpAndSettle();

      // Check category breakdown & budget utilization
      expect(find.text('Rent (84%)'), findsOneWidget);
      expect(find.text('Food (16%)'), findsOneWidget);

      // Scroll back to top to tap the month switcher
      await tester.drag(find.byType(ListView), const Offset(0, 350));
      await tester.pumpAndSettle();

      // Switch to previous month and verify repository was queried for previous month
      final initialMonth = fakeRepo.lastRequestedMonth;
      await tester.tap(find.byKey(const Key('dashboard_prev_month_btn')));
      await tester.pumpAndSettle();

      final expectedPrevMonth = initialMonth == 1 ? 12 : initialMonth - 1;
      expect(fakeRepo.lastRequestedMonth, expectedPrevMonth);
    });
  });
}

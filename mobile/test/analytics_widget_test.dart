import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise_mobile/core/theme/app_theme.dart';
import 'package:spendwise_mobile/features/analytics/data/repositories/analytics_repository_impl.dart';
import 'package:spendwise_mobile/features/analytics/domain/entities/analytics_entities.dart';
import 'package:spendwise_mobile/features/analytics/presentation/providers/analytics_provider.dart';
import 'package:spendwise_mobile/features/analytics/presentation/screens/analytics_screen.dart';
import 'package:spendwise_mobile/features/insights/data/repositories/insights_repository_impl.dart';
import 'package:spendwise_mobile/features/insights/domain/entities/financial_insight_entity.dart';
import 'package:spendwise_mobile/features/insights/presentation/providers/insights_provider.dart';

class FakeInsightsRepoForAnalytics extends InsightsRepositoryImpl {
  FakeInsightsRepoForAnalytics() : super(Dio());

  @override
  Future<List<FinancialInsightEntity>> fetchInsights({
    required int month,
    required int year,
  }) async {
    return const [];
  }
}

class FakeAnalyticsRepository extends AnalyticsRepositoryImpl {
  FakeAnalyticsRepository() : super(Dio());

  @override
  Future<FinancialAnalyticsBundle> fetchAnalyticsBundle({
    required String period,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return FinancialAnalyticsBundle(
      periodLabel: 'Nov 2026 ($period)',
      totalIncomePaise: 9500000, // ₹95,000.00
      totalExpensePaise: 3250000, // ₹32,500.00
      netSavingsPaise: 6250000, // ₹62,500.00
      averageDailySpendingPaise: 108333, // ₹1,083.33
      monthOverMonthChangePercentage: -8,
      highestSpendingCategoryName: 'Rent',
      highestSpendingCategoryAmountPaise: 1800000,
      biggestExpenseDescription: 'Apartment Rent',
      biggestExpenseAmountPaise: 1800000,
      monthlySeries: const [
        MonthlySeriesPoint(
          month: 10,
          year: 2026,
          label: 'Oct 2026',
          incomePaise: 9000000,
          expensePaise: 3500000,
          savingsPaise: 5500000,
          savingsRatePercentage: 61,
          momExpenseChangePercentage: 0,
        ),
        MonthlySeriesPoint(
          month: 11,
          year: 2026,
          label: 'Nov 2026',
          incomePaise: 9500000,
          expensePaise: 3250000,
          savingsPaise: 6250000,
          savingsRatePercentage: 65,
          momExpenseChangePercentage: -8,
        ),
      ],
      categories: const [
        CategoryDistributionPoint(
          categoryId: 'cat-rent',
          categoryName: 'Rent',
          colorHex: '#0EA5E9',
          icon: 'home',
          amountPaise: 1800000,
          percentage: 55,
          transactionCount: 1,
        ),
        CategoryDistributionPoint(
          categoryId: 'cat-food',
          categoryName: 'Food',
          colorHex: '#EF4444',
          icon: 'restaurant',
          amountPaise: 1450000,
          percentage: 45,
          transactionCount: 12,
        ),
      ],
      dailyTrend: const [
        DailyTrendPoint(date: '2026-11-01', incomePaise: 9500000, expensePaise: 1800000),
        DailyTrendPoint(date: '2026-11-05', incomePaise: 0, expensePaise: 1450000),
      ],
      weeklyTrend: const [
        WeeklyTrendPoint(weekLabel: 'W1', incomePaise: 9500000, expensePaise: 3250000),
      ],
    );
  }
}

void main() {
  testWidgets('AnalyticsScreen renders summary cards, charts, and switches periods',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          analyticsRepositoryProvider.overrideWithValue(FakeAnalyticsRepository()),
          insightsRepositoryProvider.overrideWithValue(FakeInsightsRepoForAnalytics()),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const AnalyticsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Financial Analytics'), findsOneWidget);
    expect(find.text('₹95,000.00'), findsOneWidget);
    expect(find.text('₹32,500.00'), findsOneWidget);
    expect(find.text('₹62,500.00'), findsOneWidget);
    expect(find.text('Rent'), findsOneWidget);
    expect(find.text('Apartment Rent'), findsOneWidget);

    await tester.tap(find.byKey(const Key('analytics_period_LAST_3_MONTHS')));
    await tester.pumpAndSettle();

    expect(find.text('Nov 2026 (LAST_3_MONTHS)'), findsOneWidget);
  });
}

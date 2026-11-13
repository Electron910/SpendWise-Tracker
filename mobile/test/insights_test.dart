import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise_mobile/core/theme/app_theme.dart';
import 'package:spendwise_mobile/features/insights/data/repositories/insights_repository_impl.dart';
import 'package:spendwise_mobile/features/insights/domain/entities/financial_insight_entity.dart';
import 'package:spendwise_mobile/features/insights/domain/services/deterministic_insights_engine.dart';
import 'package:spendwise_mobile/features/insights/presentation/providers/insights_provider.dart';
import 'package:spendwise_mobile/features/insights/presentation/widgets/insights_section_widget.dart';

class FakeInsightsRepository extends InsightsRepositoryImpl {
  FakeInsightsRepository() : super(Dio());

  @override
  Future<List<FinancialInsightEntity>> fetchInsights({
    required int month,
    required int year,
  }) async {
    return const [
      FinancialInsightEntity(
        id: 'mom-food-2026-11',
        type: 'MOM_CATEGORY_CHANGE',
        severity: 'WARNING',
        title: 'You spent 18% more on food this month compared to last month.',
        explanation:
            'Generated because your Food expenditure this month (₹4,720.00) changed by +18% compared to last month (₹4,000.00).',
        metricPaise: 472000,
        percentageValue: 18,
      ),
    ];
  }
}

void main() {
  group('DeterministicInsightsEngine Unit Tests', () {
    test('evaluates MoM, 3-month average, budget utilization, subscriptions, and daily average',
        () {
      final results = DeterministicInsightsEngine.evaluateLocalInsights(
        month: 11,
        year: 2026,
        elapsedDays: 10,
        totalCurrentExpensePaise: 450000, // ₹4,500 across 10 days = ₹450/day
        currentCategoryPaise: {'Food': 472000, 'Transportation': 300000},
        previousCategoryPaise: {'Food': 400000},
        threeMonthTotalCategoryPaise: {'Transportation': 600000},
        distinctHistoricalMonthsCount: 3,
        budgetsByCategoryName: {
          'Shopping': (budgetPaise: 300000, spentPaise: 255000),
        },
        monthlySubscriptionRecurringPaise: 120000, // ₹1,200
      );

      expect(
        results.any(
          (i) => i.title == 'You spent 18% more on food this month compared to last month.',
        ),
        isTrue,
      );
      expect(
        results.any(
          (i) =>
              i.title ==
              'Your transportation expenses are 50% higher than your 3-month average.',
        ),
        isTrue,
      );
      expect(
        results.any((i) => i.title == 'You have spent 85% of your shopping budget.'),
        isTrue,
      );
      expect(
        results.any(
          (i) =>
              i.title ==
              'Your subscriptions account for ₹1,200.00 in monthly recurring expenses.',
        ),
        isTrue,
      );
      expect(
        results.any(
          (i) => i.title == 'Your average daily expenditure this month is ₹450.00.',
        ),
        isTrue,
      );
    });
  });

  testWidgets('InsightsSectionWidget renders insight title and Why explanation',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          insightsRepositoryProvider.overrideWithValue(FakeInsightsRepository()),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: InsightsSectionWidget()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('You spent 18% more on food this month compared to last month.'),
      findsOneWidget,
    );
    expect(find.textContaining('Why: Generated because your Food expenditure'), findsOneWidget);
  });
}

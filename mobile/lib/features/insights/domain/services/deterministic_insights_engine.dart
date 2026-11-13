import '../../../../core/utils/money_utils.dart';
import '../entities/financial_insight_entity.dart';

class DeterministicInsightsEngine {
  static List<FinancialInsightEntity> evaluateLocalInsights({
    required int month,
    required int year,
    required int elapsedDays,
    required int totalCurrentExpensePaise,
    required Map<String, int> currentCategoryPaise,
    required Map<String, int> previousCategoryPaise,
    required Map<String, int> threeMonthTotalCategoryPaise,
    required int distinctHistoricalMonthsCount,
    required Map<String, ({int budgetPaise, int spentPaise})> budgetsByCategoryName,
    required int monthlySubscriptionRecurringPaise,
  }) {
    final insights = <FinancialInsightEntity>[];

    if (totalCurrentExpensePaise == 0 &&
        previousCategoryPaise.isEmpty &&
        monthlySubscriptionRecurringPaise == 0) {
      insights.add(
        FinancialInsightEntity(
          id: 'insufficient-data-$year-$month',
          type: 'INSUFFICIENT_DATA',
          severity: 'INFO',
          title: 'Add a few transactions to unlock personalized spending insights.',
          explanation:
              'SpendWise requires recorded expenses in the selected period to compute deterministic spending patterns without fabricated claims.',
          metricPaise: 0,
        ),
      );
      return insights;
    }

    // 1. Month-over-Month Category Change
    currentCategoryPaise.forEach((catName, currPaise) {
      final prevPaise = previousCategoryPaise[catName] ?? 0;
      if (prevPaise > 0 && currPaise > 0) {
        final pctChange = ((currPaise - prevPaise) * 100) ~/ prevPaise;
        if (pctChange.abs() >= 10) {
          final isIncrease = pctChange > 0;
          final absPct = pctChange.abs();
          insights.add(
            FinancialInsightEntity(
              id: 'mom-${catName.toLowerCase()}-$year-$month',
              type: 'MOM_CATEGORY_CHANGE',
              severity: isIncrease ? 'WARNING' : 'POSITIVE',
              title:
                  'You spent $absPct% ${isIncrease ? 'more' : 'less'} on ${catName.toLowerCase()} this month compared to last month.',
              explanation:
                  'Generated because your $catName expenditure this month (${MoneyUtils.formatPaise(currPaise)}) changed by ${isIncrease ? '+' : '-'}$absPct% compared to last month (${MoneyUtils.formatPaise(prevPaise)}).',
              metricPaise: currPaise,
              percentageValue: pctChange,
            ),
          );
        }
      }
    });

    // 2. Three-Month Average Comparison
    if (distinctHistoricalMonthsCount >= 2) {
      currentCategoryPaise.forEach((catName, currPaise) {
        final histSum = threeMonthTotalCategoryPaise[catName] ?? 0;
        final avgPaise = histSum ~/ distinctHistoricalMonthsCount;
        if (avgPaise > 0 && currPaise > avgPaise) {
          final excessPct = ((currPaise - avgPaise) * 100) ~/ avgPaise;
          if (excessPct >= 15) {
            insights.add(
              FinancialInsightEntity(
                id: 'rolling-${catName.toLowerCase()}-$year-$month',
                type: 'THREE_MONTH_AVERAGE',
                severity: 'WARNING',
                title:
                    'Your ${catName.toLowerCase()} expenses are $excessPct% higher than your $distinctHistoricalMonthsCount-month average.',
                explanation:
                    'Generated because current $catName spending (${MoneyUtils.formatPaise(currPaise)}) exceeds your $distinctHistoricalMonthsCount-month historical average of ${MoneyUtils.formatPaise(avgPaise)}.',
                metricPaise: currPaise,
                percentageValue: excessPct,
              ),
            );
          }
        }
      });
    }

    // 3. Budget Utilization
    budgetsByCategoryName.forEach((catName, b) {
      if (b.budgetPaise > 0 && b.spentPaise > 0) {
        final utilPct = (b.spentPaise * 100) ~/ b.budgetPaise;
        if (utilPct >= 50) {
          final severity = utilPct >= 100
              ? 'CRITICAL'
              : utilPct >= 75
                  ? 'WARNING'
                  : 'INFO';
          insights.add(
            FinancialInsightEntity(
              id: 'budget-${catName.toLowerCase()}-$year-$month',
              type: 'BUDGET_UTILIZATION',
              severity: severity,
              title: 'You have spent $utilPct% of your ${catName.toLowerCase()} budget.',
              explanation:
                  'Generated because recorded expenses of ${MoneyUtils.formatPaise(b.spentPaise)} against your $catName budget of ${MoneyUtils.formatPaise(b.budgetPaise)} reached $utilPct% utilization.',
              metricPaise: b.spentPaise,
              percentageValue: utilPct,
            ),
          );
        }
      }
    });

    // 4. Recurring Subscriptions Burden
    if (monthlySubscriptionRecurringPaise > 0) {
      insights.add(
        FinancialInsightEntity(
          id: 'subscriptions-$year-$month',
          type: 'SUBSCRIPTION_BURDEN',
          severity: 'INFO',
          title:
              'Your subscriptions account for ${MoneyUtils.formatPaise(monthlySubscriptionRecurringPaise)} in monthly recurring expenses.',
          explanation:
              'Generated by summing active recurring subscription schedules normalized to a monthly equivalent.',
          metricPaise: monthlySubscriptionRecurringPaise,
        ),
      );
    }

    // 5. Average Daily Expenditure
    if (elapsedDays >= 1 && totalCurrentExpensePaise > 0) {
      final avgDailyPaise = totalCurrentExpensePaise ~/ elapsedDays;
      insights.add(
        FinancialInsightEntity(
          id: 'daily-avg-$year-$month',
          type: 'DAILY_AVERAGE',
          severity: 'INFO',
          title:
              'Your average daily expenditure this month is ${MoneyUtils.formatPaise(avgDailyPaise)}.',
          explanation:
              'Generated by dividing total monthly expenses of ${MoneyUtils.formatPaise(totalCurrentExpensePaise)} across $elapsedDays elapsed day(s).',
          metricPaise: avgDailyPaise,
        ),
      );
    }

    return insights;
  }
}

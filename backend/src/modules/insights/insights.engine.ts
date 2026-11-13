import { formatPaiseToInr } from '../../utils/money';

export interface CategoryAmount {
  categoryId: string;
  categoryName: string;
  amountPaise: bigint;
}

export interface BudgetSnapshot {
  categoryId: string | null;
  categoryName: string;
  budgetPaise: bigint;
  spentPaise: bigint;
}

export interface InsightEngineInput {
  month: number;
  year: number;
  elapsedDaysInPeriod: number;
  totalPeriodTransactionCount: number;
  totalCurrentExpensePaise: bigint;
  currentMonthCategories: CategoryAmount[];
  previousMonthCategories: CategoryAmount[];
  previousThreeMonthsCategories: CategoryAmount[];
  distinctHistoricalMonthsCount: number;
  budgets: BudgetSnapshot[];
  monthlySubscriptionRecurringPaise: bigint;
  subscriptionCount: number;
}

export interface FinancialInsight {
  id: string;
  type:
    | 'MOM_CATEGORY_CHANGE'
    | 'THREE_MONTH_AVERAGE'
    | 'BUDGET_UTILIZATION'
    | 'SUBSCRIPTION_BURDEN'
    | 'DAILY_AVERAGE'
    | 'INSUFFICIENT_DATA';
  severity: 'INFO' | 'POSITIVE' | 'WARNING' | 'CRITICAL';
  title: string;
  explanation: string;
  metricPaise: string;
  percentageValue: number | null;
}

/**
 * Pure deterministic financial insights engine.
 * All calculations use integer BigInt paise without floating-point arithmetic.
 */
export function computeDeterministicInsights(input: InsightEngineInput): FinancialInsight[] {
  const insights: FinancialInsight[] = [];

  if (
    input.totalPeriodTransactionCount === 0 &&
    input.distinctHistoricalMonthsCount === 0 &&
    input.monthlySubscriptionRecurringPaise === 0n
  ) {
    insights.push({
      id: `insufficient-data-${input.year}-${input.month}`,
      type: 'INSUFFICIENT_DATA',
      severity: 'INFO',
      title: 'Add a few transactions to unlock personalized spending insights.',
      explanation:
        'SpendWise requires at least one recorded expense or active recurring rule in the selected period to compute deterministic spending patterns.',
      metricPaise: '0',
      percentageValue: null,
    });
    return insights;
  }

  // 1. Month-over-Month Category Comparison (only when previous month has data)
  const prevCatMap = new Map<string, bigint>();
  for (const prev of input.previousMonthCategories) {
    if (prev.amountPaise > 0n) {
      prevCatMap.set(prev.categoryName, prev.amountPaise);
    }
  }

  for (const curr of input.currentMonthCategories) {
    const prevAmount = prevCatMap.get(curr.categoryName);
    if (prevAmount !== undefined && prevAmount > 0n && curr.amountPaise > 0n) {
      const diffPaise = curr.amountPaise - prevAmount;
      const pctChange = Number((diffPaise * 100n) / prevAmount);
      if (Math.abs(pctChange) >= 10) {
        const isIncrease = pctChange > 0;
        const absPct = Math.abs(pctChange);
        insights.push({
          id: `mom-${curr.categoryName.toLowerCase()}-${input.year}-${input.month}`,
          type: 'MOM_CATEGORY_CHANGE',
          severity: isIncrease ? 'WARNING' : 'POSITIVE',
          title: `You spent ${absPct}% ${isIncrease ? 'more' : 'less'} on ${curr.categoryName.toLowerCase()} this month compared to last month.`,
          explanation: `Generated because your ${curr.categoryName} expenditure this month (${formatPaiseToInr(curr.amountPaise)}) changed by ${isIncrease ? '+' : '-'}${absPct}% compared to last month's total of ${formatPaiseToInr(prevAmount)}.`,
          metricPaise: curr.amountPaise.toString(),
          percentageValue: pctChange,
        });
      }
    }
  }

  // 2. Three-Month Rolling Average Comparison (only when >= 2 prior months have activity)
  if (input.distinctHistoricalMonthsCount >= 2) {
    const divisor = BigInt(input.distinctHistoricalMonthsCount);
    const threeMonthMap = new Map<string, bigint>();
    for (const hist of input.previousThreeMonthsCategories) {
      threeMonthMap.set(hist.categoryName, hist.amountPaise);
    }

    for (const curr of input.currentMonthCategories) {
      const histTotal = threeMonthMap.get(curr.categoryName) ?? 0n;
      const avgPaise = histTotal / divisor;
      if (avgPaise > 0n && curr.amountPaise > avgPaise) {
        const excessPct = Number(((curr.amountPaise - avgPaise) * 100n) / avgPaise);
        if (excessPct >= 15) {
          insights.push({
            id: `rolling-avg-${curr.categoryName.toLowerCase()}-${input.year}-${input.month}`,
            type: 'THREE_MONTH_AVERAGE',
            severity: 'WARNING',
            title: `Your ${curr.categoryName.toLowerCase()} expenses are ${excessPct}% higher than your ${input.distinctHistoricalMonthsCount}-month average.`,
            explanation: `Generated because current ${curr.categoryName} spending (${formatPaiseToInr(curr.amountPaise)}) exceeds your ${input.distinctHistoricalMonthsCount}-month historical monthly average of ${formatPaiseToInr(avgPaise)}.`,
            metricPaise: curr.amountPaise.toString(),
            percentageValue: excessPct,
          });
        }
      }
    }
  }

  // 3. Budget Utilization Thresholds (>= 50%)
  for (const b of input.budgets) {
    if (b.budgetPaise > 0n && b.spentPaise > 0n) {
      const utilPct = Number((b.spentPaise * 100n) / b.budgetPaise);
      if (utilPct >= 50) {
        const severity =
          utilPct >= 100 ? 'CRITICAL' : utilPct >= 75 ? 'WARNING' : 'INFO';
        insights.push({
          id: `budget-util-${(b.categoryId ?? 'overall').toLowerCase()}-${input.year}-${input.month}`,
          type: 'BUDGET_UTILIZATION',
          severity,
          title: `You have spent ${utilPct}% of your ${b.categoryName.toLowerCase()} budget.`,
          explanation: `Generated because recorded expenses of ${formatPaiseToInr(b.spentPaise)} against your ${b.categoryName} budget of ${formatPaiseToInr(b.budgetPaise)} reached ${utilPct}% utilization.`,
          metricPaise: b.spentPaise.toString(),
          percentageValue: utilPct,
        });
      }
    }
  }

  // 4. Recurring Subscriptions Burden
  if (input.monthlySubscriptionRecurringPaise > 0n) {
    insights.push({
      id: `subscriptions-recurring-${input.year}-${input.month}`,
      type: 'SUBSCRIPTION_BURDEN',
      severity: 'INFO',
      title: `Your subscriptions account for ${formatPaiseToInr(input.monthlySubscriptionRecurringPaise)} in monthly recurring expenses.`,
      explanation: `Generated from ${input.subscriptionCount} active recurring subscription schedule(s) normalized to a monthly equivalent of ${formatPaiseToInr(input.monthlySubscriptionRecurringPaise)}.`,
      metricPaise: input.monthlySubscriptionRecurringPaise.toString(),
      percentageValue: null,
    });
  }

  // 5. Average Daily Expenditure (only when elapsedDaysInPeriod >= 1 and totalCurrentExpensePaise > 0n)
  if (input.elapsedDaysInPeriod >= 1 && input.totalCurrentExpensePaise > 0n) {
    const safeDays = BigInt(Math.max(1, input.elapsedDaysInPeriod));
    const avgDailyPaise = input.totalCurrentExpensePaise / safeDays;
    insights.push({
      id: `daily-avg-${input.year}-${input.month}`,
      type: 'DAILY_AVERAGE',
      severity: 'INFO',
      title: `Your average daily expenditure this month is ${formatPaiseToInr(avgDailyPaise)}.`,
      explanation: `Generated by dividing total monthly expenses of ${formatPaiseToInr(input.totalCurrentExpensePaise)} across ${input.elapsedDaysInPeriod} elapsed day(s) in the selected month.`,
      metricPaise: avgDailyPaise.toString(),
      percentageValue: null,
    });
  }

  return insights;
}

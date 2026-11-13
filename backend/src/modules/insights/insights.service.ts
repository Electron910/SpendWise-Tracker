import { RecurrenceFrequency, TransactionType } from '@prisma/client';
import { prisma } from '../../config/database';
import {
  BudgetSnapshot,
  CategoryAmount,
  computeDeterministicInsights,
  FinancialInsight,
} from './insights.engine';

export class InsightsService {
  static async generateInsights(
    userId: string,
    month: number,
    year: number,
  ): Promise<{
    period: { month: number; year: number; elapsedDays: number };
    insights: FinancialInsight[];
  }> {
    const startOfCurrent = new Date(Date.UTC(year, month - 1, 1, 0, 0, 0));
    const endOfCurrent = new Date(Date.UTC(year, month, 0, 23, 59, 59, 999));

    const prevMonth = month === 1 ? 12 : month - 1;
    const prevYear = month === 1 ? year - 1 : year;
    const startOfPrev = new Date(Date.UTC(prevYear, prevMonth - 1, 1, 0, 0, 0));
    const endOfPrev = new Date(Date.UTC(prevYear, prevMonth, 0, 23, 59, 59, 999));

    const threeMonthsAgoDate = new Date(Date.UTC(year, month - 4, 1, 0, 0, 0));

    const [currentExpenses, prevExpenses, threeMonthsExpenses, budgets, recurring] =
      await Promise.all([
        prisma.transaction.findMany({
          where: {
            userId,
            type: TransactionType.EXPENSE,
            isDeleted: false,
            transactionDate: { gte: startOfCurrent, lte: endOfCurrent },
          },
          include: { category: true },
        }),
        prisma.transaction.findMany({
          where: {
            userId,
            type: TransactionType.EXPENSE,
            isDeleted: false,
            transactionDate: { gte: startOfPrev, lte: endOfPrev },
          },
          include: { category: true },
        }),
        prisma.transaction.findMany({
          where: {
            userId,
            type: TransactionType.EXPENSE,
            isDeleted: false,
            transactionDate: { gte: threeMonthsAgoDate, lte: endOfPrev },
          },
          include: { category: true },
        }),
        prisma.budget.findMany({
          where: { userId, month, year },
          include: { category: true },
        }),
        prisma.recurringExpense.findMany({
          where: {
            userId,
            isActive: true,
            type: TransactionType.EXPENSE,
          },
          include: { category: true },
        }),
      ]);

    const aggregateByCategory = (
      txs: typeof currentExpenses,
    ): { totalPaise: bigint; list: CategoryAmount[]; byCatId: Map<string, bigint> } => {
      let totalPaise = 0n;
      const byName = new Map<string, CategoryAmount>();
      const byCatId = new Map<string, bigint>();
      for (const tx of txs) {
        totalPaise += tx.amountPaise;
        byCatId.set(tx.categoryId, (byCatId.get(tx.categoryId) ?? 0n) + tx.amountPaise);
        const existing = byName.get(tx.category.name);
        if (existing) {
          existing.amountPaise += tx.amountPaise;
        } else {
          byName.set(tx.category.name, {
            categoryId: tx.categoryId,
            categoryName: tx.category.name,
            amountPaise: tx.amountPaise,
          });
        }
      }
      return {
        totalPaise,
        list: Array.from(byName.values()).sort((a, b) =>
          b.amountPaise > a.amountPaise ? 1 : -1,
        ),
        byCatId,
      };
    };

    const currAgg = aggregateByCategory(currentExpenses);
    const prevAgg = aggregateByCategory(prevExpenses);
    const threeMonthAgg = aggregateByCategory(threeMonthsExpenses);

    const distinctMonths = new Set<string>();
    for (const tx of threeMonthsExpenses) {
      distinctMonths.add(
        `${tx.transactionDate.getUTCFullYear()}-${tx.transactionDate.getUTCMonth() + 1}`,
      );
    }

    const budgetSnapshots: BudgetSnapshot[] = budgets.map((b) => ({
      categoryId: b.categoryId,
      categoryName: b.category?.name ?? 'Overall Monthly',
      budgetPaise: b.amountPaise,
      spentPaise:
        b.categoryId === null
          ? currAgg.totalPaise
          : (currAgg.byCatId.get(b.categoryId) ?? 0n),
    }));

    let monthlySubscriptionRecurringPaise = 0n;
    let subscriptionCount = 0;
    for (const rec of recurring) {
      const isSub =
        rec.category.name.toLowerCase() === 'subscriptions' ||
        rec.title.toLowerCase().includes('netflix') ||
        rec.title.toLowerCase().includes('spotify') ||
        rec.title.toLowerCase().includes('subscription');
      if (isSub) {
        subscriptionCount += 1;
        if (rec.frequency === RecurrenceFrequency.MONTHLY) {
          monthlySubscriptionRecurringPaise += rec.amountPaise;
        } else if (rec.frequency === RecurrenceFrequency.WEEKLY) {
          monthlySubscriptionRecurringPaise += rec.amountPaise * 4n;
        } else if (rec.frequency === RecurrenceFrequency.YEARLY) {
          monthlySubscriptionRecurringPaise += rec.amountPaise / 12n;
        } else if (rec.frequency === RecurrenceFrequency.DAILY) {
          monthlySubscriptionRecurringPaise += rec.amountPaise * 30n;
        }
      }
    }

    const now = new Date();
    const daysInSelectedMonth = endOfCurrent.getUTCDate();
    let elapsedDays = daysInSelectedMonth;
    if (now.getUTCFullYear() === year && now.getUTCMonth() + 1 === month) {
      elapsedDays = Math.max(1, now.getUTCDate());
    }

    const insights = computeDeterministicInsights({
      month,
      year,
      elapsedDaysInPeriod: elapsedDays,
      totalPeriodTransactionCount: currentExpenses.length,
      totalCurrentExpensePaise: currAgg.totalPaise,
      currentMonthCategories: currAgg.list,
      previousMonthCategories: prevAgg.list,
      previousThreeMonthsCategories: threeMonthAgg.list,
      distinctHistoricalMonthsCount: distinctMonths.size,
      budgets: budgetSnapshots,
      monthlySubscriptionRecurringPaise,
      subscriptionCount,
    });

    return {
      period: { month, year, elapsedDays },
      insights,
    };
  }
}

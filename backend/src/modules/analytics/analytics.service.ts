import { TransactionType } from '@prisma/client';
import { prisma } from '../../config/database';
import {
  calculateUtilizationPercentage,
  formatPaiseToDecimalString,
} from '../../utils/money';

export class AnalyticsService {
  static async getDashboardOverview(
    userId: string,
    input: { month?: number; year?: number },
  ) {
    const now = new Date();
    const targetMonth = input.month ?? now.getUTCMonth() + 1;
    const targetYear = input.year ?? now.getUTCFullYear();

    const startDate = new Date(Date.UTC(targetYear, targetMonth - 1, 1, 0, 0, 0, 0));
    const endDate = new Date(Date.UTC(targetYear, targetMonth, 0, 23, 59, 59, 999));
    const daysInMonth = endDate.getUTCDate();

    const [transactions, budgets, upcomingRecurring] = await Promise.all([
      prisma.transaction.findMany({
        where: {
          userId,
          isDeleted: false,
          transactionDate: {
            gte: startDate,
            lte: endDate,
          },
        },
        include: { category: true },
        orderBy: { transactionDate: 'desc' },
      }),
      prisma.budget.findMany({
        where: {
          userId,
          month: targetMonth,
          year: targetYear,
          isDeleted: false,
        },
        include: { category: true },
      }),
      prisma.recurringExpense.findMany({
        where: {
          userId,
          isActive: true,
          isDeleted: false,
        },
        include: { category: true },
        orderBy: { nextOccurrence: 'asc' },
        take: 5,
      }),
    ]);

    let totalIncomePaise = 0n;
    let totalExpensePaise = 0n;

    const categoryTotals = new Map<
      string,
      {
        categoryId: string;
        categoryName: string;
        colorHex: string;
        icon: string;
        amountPaise: bigint;
        transactionCount: number;
      }
    >();

    const dailySpendingMap = new Map<number, { incomePaise: bigint; expensePaise: bigint }>();
    for (let day = 1; day <= daysInMonth; day++) {
      dailySpendingMap.set(day, { incomePaise: 0n, expensePaise: 0n });
    }

    for (const tx of transactions) {
      const dayOfMonth = tx.transactionDate.getUTCDate();
      const dayEntry = dailySpendingMap.get(dayOfMonth) ?? {
        incomePaise: 0n,
        expensePaise: 0n,
      };

      if (tx.type === TransactionType.INCOME) {
        totalIncomePaise += tx.amountPaise;
        dayEntry.incomePaise += tx.amountPaise;
      } else {
        totalExpensePaise += tx.amountPaise;
        dayEntry.expensePaise += tx.amountPaise;

        const existingCat = categoryTotals.get(tx.categoryId);
        if (existingCat) {
          existingCat.amountPaise += tx.amountPaise;
          existingCat.transactionCount += 1;
        } else {
          categoryTotals.set(tx.categoryId, {
            categoryId: tx.categoryId,
            categoryName: tx.category.name,
            colorHex: tx.category.colorHex,
            icon: tx.category.icon,
            amountPaise: tx.amountPaise,
            transactionCount: 1,
          });
        }
      }
      dailySpendingMap.set(dayOfMonth, dayEntry);
    }

    const currentSavingsPaise = totalIncomePaise - totalExpensePaise;
    const savingsRatePercentage =
      totalIncomePaise > 0n
        ? Number(((currentSavingsPaise * 100n) / totalIncomePaise))
        : 0;

    // Overall budget (categoryId === null) or sum of category budgets if overall isn't set
    const overallBudgetRecord = budgets.find((b) => b.categoryId === null);
    const categoryBudgetRecords = budgets.filter((b) => b.categoryId !== null);

    let overallBudgetPaise = overallBudgetRecord?.amountPaise ?? 0n;
    if (overallBudgetPaise === 0n && categoryBudgetRecords.length > 0) {
      for (const b of categoryBudgetRecords) {
        overallBudgetPaise += b.amountPaise;
      }
    }

    const remainingBudgetPaise =
      overallBudgetPaise > 0n ? overallBudgetPaise - totalExpensePaise : 0n;
    const overallUtilization = calculateUtilizationPercentage(
      totalExpensePaise,
      overallBudgetPaise,
    );

    const categoryBreakdown = Array.from(categoryTotals.values())
      .sort((a, b) => (b.amountPaise > a.amountPaise ? 1 : -1))
      .map((item) => {
        const share = calculateUtilizationPercentage(item.amountPaise, totalExpensePaise);
        return {
          categoryId: item.categoryId,
          categoryName: item.categoryName,
          colorHex: item.colorHex,
          icon: item.icon,
          amountPaise: item.amountPaise.toString(),
          amountDecimal: formatPaiseToDecimalString(item.amountPaise),
          percentage: share.percentage,
          basisPoints: share.basisPoints,
          transactionCount: item.transactionCount,
        };
      });

    const budgetUtilization = categoryBudgetRecords.map((b) => {
      const catSpent = categoryTotals.get(b.categoryId!)?.amountPaise ?? 0n;
      const util = calculateUtilizationPercentage(catSpent, b.amountPaise);
      const remaining = b.amountPaise - catSpent;
      return {
        budgetId: b.id,
        categoryId: b.categoryId,
        categoryName: b.category?.name ?? 'Overall',
        colorHex: b.category?.colorHex ?? '#4F46E5',
        budgetPaise: b.amountPaise.toString(),
        spentPaise: catSpent.toString(),
        remainingPaise: remaining.toString(),
        utilizationPercentage: util.percentage,
        alertLevel:
          util.percentage >= 100
            ? 'EXCEEDED'
            : util.percentage >= 90
              ? 'CRITICAL'
              : util.percentage >= 75
                ? 'WARNING'
                : util.percentage >= 50
                  ? 'MODERATE'
                  : 'SAFE',
      };
    });

    const dailySpendingSeries = Array.from(dailySpendingMap.entries()).map(
      ([day, values]) => ({
        day,
        incomePaise: values.incomePaise.toString(),
        expensePaise: values.expensePaise.toString(),
      }),
    );

    const recentTransactions = transactions.slice(0, 6).map((tx) => ({
      id: tx.id,
      categoryId: tx.categoryId,
      type: tx.type,
      amountPaise: tx.amountPaise.toString(),
      amountDecimal: formatPaiseToDecimalString(tx.amountPaise),
      currency: tx.currency,
      merchant: tx.merchant,
      description: tx.description,
      paymentMethod: tx.paymentMethod,
      transactionDate: tx.transactionDate,
      isAutoCategorized: tx.isAutoCategorized,
      categorizationConfidence: tx.categorizationConfidence,
      isDemoData: tx.isDemoData,
      syncStatus: tx.syncStatus,
      version: tx.version,
      category: {
        id: tx.category.id,
        name: tx.category.name,
        type: tx.category.type,
        icon: tx.category.icon,
        colorHex: tx.category.colorHex,
      },
    }));

    return {
      period: {
        month: targetMonth,
        year: targetYear,
        daysInMonth,
      },
      summary: {
        totalIncomePaise: totalIncomePaise.toString(),
        totalExpensePaise: totalExpensePaise.toString(),
        currentSavingsPaise: currentSavingsPaise.toString(),
        savingsRatePercentage,
        overallBudgetPaise: overallBudgetPaise.toString(),
        remainingBudgetPaise: remainingBudgetPaise.toString(),
        budgetUtilizationPercentage: overallUtilization.percentage,
      },
      categoryBreakdown,
      budgetUtilization,
      dailySpendingSeries,
      recentTransactions,
      upcomingRecurring: upcomingRecurring.map((r) => ({
        id: r.id,
        title: r.title,
        merchant: r.merchant,
        amountPaise: r.amountPaise.toString(),
        frequency: r.frequency,
        nextOccurrence: r.nextOccurrence,
        categoryName: r.category.name,
        colorHex: r.category.colorHex,
      })),
    };
  }

  static resolveDateRange(input: {
    range?: string;
    startDate?: string;
    endDate?: string;
  }): { startDate: Date; endDate: Date; label: string; dayCount: number } {
    const now = new Date();
    const y = now.getUTCFullYear();
    const m = now.getUTCMonth();
    const d = now.getUTCDate();

    let startDate: Date;
    let endDate = new Date(Date.UTC(y, m + 1, 0, 23, 59, 59, 999));
    let label = 'This Month';

    switch (input.range) {
      case 'THIS_WEEK': {
        const dayOfWeek = now.getUTCDay();
        const diffToMonday = dayOfWeek === 0 ? 6 : dayOfWeek - 1;
        startDate = new Date(Date.UTC(y, m, d - diffToMonday, 0, 0, 0, 0));
        endDate = new Date(Date.UTC(y, m, d + (6 - diffToMonday), 23, 59, 59, 999));
        label = 'This Week';
        break;
      }
      case 'PREVIOUS_MONTH': {
        startDate = new Date(Date.UTC(y, m - 1, 1, 0, 0, 0, 0));
        endDate = new Date(Date.UTC(y, m, 0, 23, 59, 59, 999));
        label = 'Previous Month';
        break;
      }
      case 'LAST_3_MONTHS': {
        startDate = new Date(Date.UTC(y, m - 2, 1, 0, 0, 0, 0));
        label = 'Last 3 Months';
        break;
      }
      case 'LAST_6_MONTHS': {
        startDate = new Date(Date.UTC(y, m - 5, 1, 0, 0, 0, 0));
        label = 'Last 6 Months';
        break;
      }
      case 'CUSTOM': {
        startDate = input.startDate
          ? new Date(input.startDate)
          : new Date(Date.UTC(y, m, 1, 0, 0, 0, 0));
        if (input.endDate) {
          endDate = new Date(input.endDate);
        }
        label = 'Custom Range';
        break;
      }
      case 'THIS_MONTH':
      default: {
        startDate = new Date(Date.UTC(y, m, 1, 0, 0, 0, 0));
        label = 'This Month';
        break;
      }
    }

    const diffMs = Math.max(1, endDate.getTime() - startDate.getTime());
    const dayCount = Math.max(1, Math.ceil(diffMs / (1000 * 60 * 60 * 24)));

    return { startDate, endDate, label, dayCount };
  }

  static async getMonthlyComparison(userId: string, monthsCount = 6) {
    const now = new Date();
    const currentYear = now.getUTCFullYear();
    const currentMonthIdx = now.getUTCMonth();

    const startDate = new Date(
      Date.UTC(currentYear, currentMonthIdx - (monthsCount - 1), 1, 0, 0, 0, 0),
    );
    const endDate = new Date(Date.UTC(currentYear, currentMonthIdx + 1, 0, 23, 59, 59, 999));

    const transactions = await prisma.transaction.findMany({
      where: {
        userId,
        isDeleted: false,
        transactionDate: { gte: startDate, lte: endDate },
      },
      select: {
        type: true,
        amountPaise: true,
        transactionDate: true,
      },
    });

    const buckets = new Map<
      string,
      {
        year: number;
        month: number;
        label: string;
        incomePaise: bigint;
        expensePaise: bigint;
      }
    >();

    const monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    for (let i = monthsCount - 1; i >= 0; i--) {
      const dt = new Date(Date.UTC(currentYear, currentMonthIdx - i, 1));
      const y = dt.getUTCFullYear();
      const m = dt.getUTCMonth() + 1;
      const key = `${y}-${String(m).padStart(2, '0')}`;
      buckets.set(key, {
        year: y,
        month: m,
        label: `${monthNames[m - 1]} ${String(y).slice(2)}`,
        incomePaise: 0n,
        expensePaise: 0n,
      });
    }

    for (const tx of transactions) {
      const y = tx.transactionDate.getUTCFullYear();
      const m = tx.transactionDate.getUTCMonth() + 1;
      const key = `${y}-${String(m).padStart(2, '0')}`;
      const bucket = buckets.get(key);
      if (bucket) {
        if (tx.type === TransactionType.INCOME) {
          bucket.incomePaise += tx.amountPaise;
        } else {
          bucket.expensePaise += tx.amountPaise;
        }
      }
    }

    const series = Array.from(buckets.values()).map((b, idx, arr) => {
      const netSavingsPaise = b.incomePaise - b.expensePaise;
      const prevExpense = idx > 0 ? arr[idx - 1].expensePaise : 0n;
      const momExpenseChangePercentage =
        prevExpense > 0n
          ? Number(((b.expensePaise - prevExpense) * 100n) / prevExpense)
          : 0;

      return {
        year: b.year,
        month: b.month,
        label: b.label,
        incomePaise: b.incomePaise.toString(),
        expensePaise: b.expensePaise.toString(),
        netSavingsPaise: netSavingsPaise.toString(),
        momExpenseChangePercentage,
      };
    });

    return { monthsCount, series };
  }

  static async getCategoryAnalytics(
    userId: string,
    input: { range?: string; startDate?: string; endDate?: string },
  ) {
    const { startDate, endDate, label } = this.resolveDateRange(input);

    const expenses = await prisma.transaction.findMany({
      where: {
        userId,
        type: TransactionType.EXPENSE,
        isDeleted: false,
        transactionDate: { gte: startDate, lte: endDate },
      },
      include: { category: true },
    });

    let totalExpensePaise = 0n;
    const byCategory = new Map<
      string,
      {
        categoryId: string;
        categoryName: string;
        colorHex: string;
        icon: string;
        amountPaise: bigint;
        transactionCount: number;
      }
    >();

    for (const tx of expenses) {
      totalExpensePaise += tx.amountPaise;
      const existing = byCategory.get(tx.categoryId);
      if (existing) {
        existing.amountPaise += tx.amountPaise;
        existing.transactionCount += 1;
      } else {
        byCategory.set(tx.categoryId, {
          categoryId: tx.categoryId,
          categoryName: tx.category.name,
          colorHex: tx.category.colorHex,
          icon: tx.category.icon,
          amountPaise: tx.amountPaise,
          transactionCount: 1,
        });
      }
    }

    const categories = Array.from(byCategory.values())
      .sort((a, b) => (b.amountPaise > a.amountPaise ? 1 : -1))
      .map((c) => {
        const share = calculateUtilizationPercentage(c.amountPaise, totalExpensePaise);
        return {
          categoryId: c.categoryId,
          categoryName: c.categoryName,
          colorHex: c.colorHex,
          icon: c.icon,
          amountPaise: c.amountPaise.toString(),
          amountDecimal: formatPaiseToDecimalString(c.amountPaise),
          percentage: share.percentage,
          transactionCount: c.transactionCount,
        };
      });

    return {
      period: {
        label,
        startDate,
        endDate,
      },
      totalExpensePaise: totalExpensePaise.toString(),
      highestSpendingCategory: categories.length > 0 ? categories[0] : null,
      categories,
    };
  }

  static async getSpendingTrends(
    userId: string,
    input: { range?: string; startDate?: string; endDate?: string },
  ) {
    const { startDate, endDate, label, dayCount } = this.resolveDateRange(input);
    const periodDurationMs = endDate.getTime() - startDate.getTime();
    const prevStartDate = new Date(startDate.getTime() - periodDurationMs - 1000);
    const prevEndDate = new Date(startDate.getTime() - 1000);

    const [transactions, prevExpensesAgg] = await Promise.all([
      prisma.transaction.findMany({
        where: {
          userId,
          isDeleted: false,
          transactionDate: { gte: startDate, lte: endDate },
        },
        include: { category: true },
        orderBy: { transactionDate: 'asc' },
      }),
      prisma.transaction.aggregate({
        where: {
          userId,
          type: TransactionType.EXPENSE,
          isDeleted: false,
          transactionDate: { gte: prevStartDate, lte: prevEndDate },
        },
        _sum: { amountPaise: true },
      }),
    ]);

    let totalIncomePaise = 0n;
    let totalExpensePaise = 0n;
    let biggestExpenseTx: (typeof transactions)[number] | null = null;

    const dailyMap = new Map<string, { date: string; incomePaise: bigint; expensePaise: bigint }>();
    const weeklyMap = new Map<
      string,
      { weekLabel: string; incomePaise: bigint; expensePaise: bigint }
    >();
    const catMap = new Map<string, { name: string; amountPaise: bigint }>();

    for (const tx of transactions) {
      const dateStr = tx.transactionDate.toISOString().slice(0, 10);
      const dayBucket = dailyMap.get(dateStr) ?? {
        date: dateStr,
        incomePaise: 0n,
        expensePaise: 0n,
      };

      const weekIndex = Math.floor(
        (tx.transactionDate.getTime() - startDate.getTime()) / (7 * 24 * 60 * 60 * 1000),
      );
      const weekKey = `W${weekIndex + 1}`;
      const weekBucket = weeklyMap.get(weekKey) ?? {
        weekLabel: weekKey,
        incomePaise: 0n,
        expensePaise: 0n,
      };

      if (tx.type === TransactionType.INCOME) {
        totalIncomePaise += tx.amountPaise;
        dayBucket.incomePaise += tx.amountPaise;
        weekBucket.incomePaise += tx.amountPaise;
      } else {
        totalExpensePaise += tx.amountPaise;
        dayBucket.expensePaise += tx.amountPaise;
        weekBucket.expensePaise += tx.amountPaise;

        if (!biggestExpenseTx || tx.amountPaise > biggestExpenseTx.amountPaise) {
          biggestExpenseTx = tx;
        }

        const existingCat = catMap.get(tx.category.name);
        if (existingCat) {
          existingCat.amountPaise += tx.amountPaise;
        } else {
          catMap.set(tx.category.name, {
            name: tx.category.name,
            amountPaise: tx.amountPaise,
          });
        }
      }

      dailyMap.set(dateStr, dayBucket);
      weeklyMap.set(weekKey, weekBucket);
    }

    const netSavingsPaise = totalIncomePaise - totalExpensePaise;
    const averageDailySpendingPaise = totalExpensePaise / BigInt(dayCount);
    const prevExpensePaise = prevExpensesAgg._sum.amountPaise ?? 0n;
    const momChangePercentage =
      prevExpensePaise > 0n
        ? Number(((totalExpensePaise - prevExpensePaise) * 100n) / prevExpensePaise)
        : 0;

    const sortedCats = Array.from(catMap.values()).sort((a, b) =>
      b.amountPaise > a.amountPaise ? 1 : -1,
    );

    return {
      period: {
        label,
        startDate,
        endDate,
        dayCount,
      },
      summary: {
        totalIncomePaise: totalIncomePaise.toString(),
        totalExpensePaise: totalExpensePaise.toString(),
        netSavingsPaise: netSavingsPaise.toString(),
        averageDailySpendingPaise: averageDailySpendingPaise.toString(),
        monthOverMonthChangePercentage: momChangePercentage,
        highestSpendingCategory:
          sortedCats.length > 0
            ? {
                name: sortedCats[0].name,
                categoryName: sortedCats[0].name,
                amountPaise: sortedCats[0].amountPaise.toString(),
              }
            : null,
        biggestExpense: biggestExpenseTx
          ? {
              id: biggestExpenseTx.id,
              description: biggestExpenseTx.description,
              merchant: biggestExpenseTx.merchant,
              categoryName: biggestExpenseTx.category.name,
              amountPaise: biggestExpenseTx.amountPaise.toString(),
              transactionDate: biggestExpenseTx.transactionDate,
            }
          : null,
      },
      dailyTrend: Array.from(dailyMap.values()).map((d) => ({
        date: d.date,
        incomePaise: d.incomePaise.toString(),
        expensePaise: d.expensePaise.toString(),
      })),
      weeklyTrend: Array.from(weeklyMap.values()).map((w) => ({
        weekLabel: w.weekLabel,
        incomePaise: w.incomePaise.toString(),
        expensePaise: w.expensePaise.toString(),
      })),
    };
  }
}

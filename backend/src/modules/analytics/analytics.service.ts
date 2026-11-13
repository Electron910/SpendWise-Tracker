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
}

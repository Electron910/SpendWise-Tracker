import { TransactionType } from '@prisma/client';
import { prisma } from '../../config/database';
import { AppError } from '../../utils/appError';
import {
  calculateUtilizationPercentage,
  formatPaiseToDecimalString,
} from '../../utils/money';

export interface EvaluatedBudget {
  id: string;
  userId: string;
  categoryId: string | null;
  categoryName: string;
  colorHex: string;
  icon: string;
  month: number;
  year: number;
  budgetPaise: string;
  budgetDecimal: string;
  spentPaise: string;
  spentDecimal: string;
  remainingPaise: string;
  remainingDecimal: string;
  previousMonthSpentPaise: string;
  monthOverMonthChangePercentage: number;
  utilizationPercentage: number;
  utilizationBasisPoints: number;
  alertThresholds: number[];
  reachedThresholds: number[];
  highestReachedThreshold: number | null;
  alertLevel: 'SAFE' | 'MODERATE' | 'WARNING' | 'CRITICAL' | 'EXCEEDED';
  version: number;
}

export class BudgetsService {
  static async listBudgetsWithUtilization(
    userId: string,
    input: { month?: number; year?: number },
  ) {
    const now = new Date();
    const targetMonth = input.month ?? now.getUTCMonth() + 1;
    const targetYear = input.year ?? now.getUTCFullYear();

    const startDate = new Date(Date.UTC(targetYear, targetMonth - 1, 1, 0, 0, 0, 0));
    const endDate = new Date(Date.UTC(targetYear, targetMonth, 0, 23, 59, 59, 999));

    const prevMonthDate = new Date(Date.UTC(targetYear, targetMonth - 2, 1, 0, 0, 0, 0));
    const prevEndDate = new Date(Date.UTC(targetYear, targetMonth - 1, 0, 23, 59, 59, 999));

    const [budgets, currentExpenses, prevExpenses] = await Promise.all([
      prisma.budget.findMany({
        where: {
          userId,
          month: targetMonth,
          year: targetYear,
          isDeleted: false,
        },
        include: { category: true },
        orderBy: [{ categoryId: 'asc' }, { createdAt: 'asc' }],
      }),
      prisma.transaction.findMany({
        where: {
          userId,
          type: TransactionType.EXPENSE,
          isDeleted: false,
          transactionDate: { gte: startDate, lte: endDate },
        },
        select: { categoryId: true, amountPaise: true },
      }),
      prisma.transaction.findMany({
        where: {
          userId,
          type: TransactionType.EXPENSE,
          isDeleted: false,
          transactionDate: { gte: prevMonthDate, lte: prevEndDate },
        },
        select: { categoryId: true, amountPaise: true },
      }),
    ]);

    let totalCurrentExpenses = 0n;
    const currentByCat = new Map<string, bigint>();
    for (const tx of currentExpenses) {
      totalCurrentExpenses += tx.amountPaise;
      currentByCat.set(
        tx.categoryId,
        (currentByCat.get(tx.categoryId) ?? 0n) + tx.amountPaise,
      );
    }

    let totalPrevExpenses = 0n;
    const prevByCat = new Map<string, bigint>();
    for (const tx of prevExpenses) {
      totalPrevExpenses += tx.amountPaise;
      prevByCat.set(tx.categoryId, (prevByCat.get(tx.categoryId) ?? 0n) + tx.amountPaise);
    }

    const evaluated: EvaluatedBudget[] = budgets.map((b) => {
      const isOverall = b.categoryId === null;
      const spentPaise = isOverall
        ? totalCurrentExpenses
        : (currentByCat.get(b.categoryId!) ?? 0n);
      const prevSpentPaise = isOverall
        ? totalPrevExpenses
        : (prevByCat.get(b.categoryId!) ?? 0n);

      const remainingPaise = b.amountPaise - spentPaise;
      const util = calculateUtilizationPercentage(spentPaise, b.amountPaise);

      const sortedThresholds = [...b.alertThresholds].sort((x, y) => x - y);
      const reachedThresholds = sortedThresholds.filter((t) => util.percentage >= t);
      const highestReached =
        reachedThresholds.length > 0
          ? reachedThresholds[reachedThresholds.length - 1]
          : null;

      let alertLevel: EvaluatedBudget['alertLevel'] = 'SAFE';
      if (util.percentage >= 100) {
        alertLevel = 'EXCEEDED';
      } else if (util.percentage >= 90) {
        alertLevel = 'CRITICAL';
      } else if (util.percentage >= 75) {
        alertLevel = 'WARNING';
      } else if (util.percentage >= 50) {
        alertLevel = 'MODERATE';
      }

      let momChangePercentage = 0;
      if (prevSpentPaise > 0n) {
        momChangePercentage = Number(
          ((spentPaise - prevSpentPaise) * 100n) / prevSpentPaise,
        );
      }

      return {
        id: b.id,
        userId: b.userId,
        categoryId: b.categoryId,
        categoryName: isOverall ? 'Overall Monthly Budget' : (b.category?.name ?? 'Category'),
        colorHex: isOverall ? '#4F46E5' : (b.category?.colorHex ?? '#4F46E5'),
        icon: isOverall ? 'account_balance_wallet' : (b.category?.icon ?? 'category'),
        month: b.month,
        year: b.year,
        budgetPaise: b.amountPaise.toString(),
        budgetDecimal: formatPaiseToDecimalString(b.amountPaise),
        spentPaise: spentPaise.toString(),
        spentDecimal: formatPaiseToDecimalString(spentPaise),
        remainingPaise: remainingPaise.toString(),
        remainingDecimal: formatPaiseToDecimalString(remainingPaise),
        previousMonthSpentPaise: prevSpentPaise.toString(),
        monthOverMonthChangePercentage: momChangePercentage,
        utilizationPercentage: util.percentage,
        utilizationBasisPoints: util.basisPoints,
        alertThresholds: sortedThresholds,
        reachedThresholds,
        highestReachedThreshold: highestReached,
        alertLevel,
        version: b.version,
      };
    });

    const overallBudget = evaluated.find((e) => e.categoryId === null) ?? null;
    const categoryBudgets = evaluated.filter((e) => e.categoryId !== null);

    return {
      period: {
        month: targetMonth,
        year: targetYear,
        totalMonthlyExpensePaise: totalCurrentExpenses.toString(),
        previousMonthExpensePaise: totalPrevExpenses.toString(),
      },
      overallBudget,
      categoryBudgets,
      budgets: evaluated,
    };
  }

  static async createOrUpdateBudget(
    userId: string,
    input: {
      id?: string;
      categoryId?: string | null;
      month: number;
      year: number;
      amountPaise: bigint;
      alertThresholds?: number[];
    },
  ) {
    const normalizedCategoryId = input.categoryId ?? null;

    if (normalizedCategoryId) {
      const cat = await prisma.category.findFirst({
        where: {
          id: normalizedCategoryId,
          userId,
          isDeleted: false,
        },
      });
      if (!cat) {
        throw new AppError('Category not found', 404, 'CATEGORY_NOT_FOUND');
      }
      if (cat.type !== TransactionType.EXPENSE) {
        throw new AppError(
          'Budgets can only be created for EXPENSE categories',
          400,
          'INVALID_BUDGET_CATEGORY_TYPE',
        );
      }
    }

    const thresholds = Array.from(new Set(input.alertThresholds ?? [50, 75, 90, 100])).sort(
      (a, b) => a - b,
    );

    const existing = await prisma.budget.findFirst({
      where: {
        userId,
        categoryId: normalizedCategoryId,
        month: input.month,
        year: input.year,
      },
    });

    if (existing) {
      return prisma.budget.update({
        where: { id: existing.id },
        data: {
          amountPaise: input.amountPaise,
          alertThresholds: thresholds,
          isDeleted: false,
          deletedAt: null,
          version: { increment: 1 },
        },
        include: { category: true },
      });
    }

    return prisma.budget.create({
      data: {
        ...(input.id ? { id: input.id } : {}),
        userId,
        categoryId: normalizedCategoryId,
        month: input.month,
        year: input.year,
        amountPaise: input.amountPaise,
        alertThresholds: thresholds,
      },
      include: { category: true },
    });
  }

  static async updateBudget(
    userId: string,
    budgetId: string,
    input: {
      amountPaise?: bigint;
      alertThresholds?: number[];
    },
  ) {
    const existing = await prisma.budget.findFirst({
      where: { id: budgetId, userId, isDeleted: false },
    });

    if (!existing) {
      throw new AppError('Budget not found', 404, 'BUDGET_NOT_FOUND');
    }

    const thresholds = input.alertThresholds
      ? Array.from(new Set(input.alertThresholds)).sort((a, b) => a - b)
      : undefined;

    return prisma.budget.update({
      where: { id: budgetId },
      data: {
        ...(input.amountPaise !== undefined ? { amountPaise: input.amountPaise } : {}),
        ...(thresholds !== undefined ? { alertThresholds: thresholds } : {}),
        version: { increment: 1 },
      },
      include: { category: true },
    });
  }

  static async deleteBudget(userId: string, budgetId: string): Promise<void> {
    const existing = await prisma.budget.findFirst({
      where: { id: budgetId, userId, isDeleted: false },
    });

    if (!existing) {
      throw new AppError('Budget not found', 404, 'BUDGET_NOT_FOUND');
    }

    await prisma.budget.update({
      where: { id: budgetId },
      data: {
        isDeleted: true,
        deletedAt: new Date(),
        version: { increment: 1 },
      },
    });
  }
}

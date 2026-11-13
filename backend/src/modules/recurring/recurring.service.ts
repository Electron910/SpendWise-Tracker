import { PaymentMethod, RecurrenceFrequency, TransactionType } from '@prisma/client';
import { prisma } from '../../config/database';
import { AppError } from '../../middleware/error.middleware';
import { formatPaiseToDecimalString } from '../../utils/money';

export class RecurringService {
  /**
   * Advances a recurrence date by `intervalCount` units of `frequency` in UTC,
   * safely clamping month-end dates (e.g., Jan 31 -> Feb 28/29 -> Mar 31).
   */
  static computeNextOccurrence(
    fromDate: Date,
    frequency: RecurrenceFrequency,
    intervalCount = 1,
    anchorDayOfMonth?: number,
  ): Date {
    const year = fromDate.getUTCFullYear();
    const month = fromDate.getUTCMonth();
    const day = anchorDayOfMonth ?? fromDate.getUTCDate();
    const hours = fromDate.getUTCHours();
    const minutes = fromDate.getUTCMinutes();
    const seconds = fromDate.getUTCSeconds();

    switch (frequency) {
      case RecurrenceFrequency.DAILY:
        return new Date(
          Date.UTC(year, month, fromDate.getUTCDate() + intervalCount, hours, minutes, seconds),
        );
      case RecurrenceFrequency.WEEKLY:
        return new Date(
          Date.UTC(
            year,
            month,
            fromDate.getUTCDate() + intervalCount * 7,
            hours,
            minutes,
            seconds,
          ),
        );
      case RecurrenceFrequency.MONTHLY: {
        const targetMonthIndex = month + intervalCount;
        const targetYear = year + Math.floor(targetMonthIndex / 12);
        const normalizedMonth = ((targetMonthIndex % 12) + 12) % 12;
        const maxDaysInTargetMonth = new Date(
          Date.UTC(targetYear, normalizedMonth + 1, 0),
        ).getUTCDate();
        const clampedDay = Math.min(day, maxDaysInTargetMonth);
        return new Date(
          Date.UTC(targetYear, normalizedMonth, clampedDay, hours, minutes, seconds),
        );
      }
      case RecurrenceFrequency.YEARLY: {
        const targetYear = year + intervalCount;
        const maxDaysInTargetMonth = new Date(Date.UTC(targetYear, month + 1, 0)).getUTCDate();
        const clampedDay = Math.min(day, maxDaysInTargetMonth);
        return new Date(Date.UTC(targetYear, month, clampedDay, hours, minutes, seconds));
      }
    }
  }

  /**
   * Backend-controlled idempotent recurrence generator.
   * Generates due transactions up to `asOfDate` with strict duplicate-prevention checks.
   */
  static async processDueRecurringForUser(
    userId: string,
    asOfDate: Date = new Date(),
  ): Promise<{ generatedCount: number; generatedTransactionIds: string[] }> {
    const dueRules = await prisma.recurringExpense.findMany({
      where: {
        userId,
        isActive: true,
        isDeleted: false,
        nextOccurrence: { lte: asOfDate },
      },
    });

    const generatedTransactionIds: string[] = [];

    for (const rule of dueRules) {
      let cursor = new Date(rule.nextOccurrence);
      let lastGenerated = rule.lastGeneratedAt;
      let isActive = rule.isActive;
      const anchorDay = rule.startDate.getUTCDate();
      let safetyCounter = 0;

      while (cursor <= asOfDate && isActive && safetyCounter < 36) {
        safetyCounter += 1;

        if (rule.endDate && cursor > rule.endDate) {
          isActive = false;
          break;
        }

        // Duplicate safeguard: check if a non-deleted transaction already exists for this rule on this exact UTC date
        const dayStart = new Date(
          Date.UTC(cursor.getUTCFullYear(), cursor.getUTCMonth(), cursor.getUTCDate(), 0, 0, 0),
        );
        const dayEnd = new Date(
          Date.UTC(
            cursor.getUTCFullYear(),
            cursor.getUTCMonth(),
            cursor.getUTCDate(),
            23,
            59,
            59,
            999,
          ),
        );

        const existingTx = await prisma.transaction.findFirst({
          where: {
            userId,
            recurringExpenseId: rule.id,
            isDeleted: false,
            transactionDate: { gte: dayStart, lte: dayEnd },
          },
        });

        if (!existingTx) {
          const created = await prisma.transaction.create({
            data: {
              userId,
              categoryId: rule.categoryId,
              recurringExpenseId: rule.id,
              type: rule.type,
              amountPaise: rule.amountPaise,
              merchant: rule.merchant,
              description: rule.description ?? rule.title,
              paymentMethod: rule.paymentMethod,
              transactionDate: cursor,
            },
          });
          generatedTransactionIds.push(created.id);
        }

        lastGenerated = cursor;
        cursor = this.computeNextOccurrence(
          cursor,
          rule.frequency,
          rule.intervalCount,
          anchorDay,
        );

        if (rule.endDate && cursor > rule.endDate) {
          isActive = false;
        }
      }

      await prisma.recurringExpense.update({
        where: { id: rule.id },
        data: {
          nextOccurrence: cursor,
          lastGeneratedAt: lastGenerated,
          isActive,
          version: { increment: 1 },
        },
      });
    }

    return {
      generatedCount: generatedTransactionIds.length,
      generatedTransactionIds,
    };
  }

  private static formatRule(
    rule: {
      id: string;
      userId: string;
      categoryId: string;
      type: TransactionType;
      title: string;
      merchant: string | null;
      description: string | null;
      amountPaise: bigint;
      paymentMethod: PaymentMethod;
      frequency: RecurrenceFrequency;
      intervalCount: number;
      startDate: Date;
      endDate: Date | null;
      nextOccurrence: Date;
      lastGeneratedAt: Date | null;
      isActive: boolean;
      reminderDays: number;
      version: number;
      category: { id: string; name: string; colorHex: string; icon: string };
      transactions?: Array<{
        id: string;
        amountPaise: bigint;
        transactionDate: Date;
        description: string;
      }>;
    },
    referenceNow: Date = new Date(),
  ) {
    const daysUntilNext = Math.ceil(
      (rule.nextOccurrence.getTime() - referenceNow.getTime()) / (24 * 60 * 60 * 1000),
    );
    const isUpcomingReminder =
      rule.isActive && daysUntilNext >= 0 && daysUntilNext <= rule.reminderDays;

    return {
      id: rule.id,
      categoryId: rule.categoryId,
      categoryName: rule.category.name,
      categoryColorHex: rule.category.colorHex,
      categoryIcon: rule.category.icon,
      type: rule.type,
      title: rule.title,
      merchant: rule.merchant,
      description: rule.description,
      amountPaise: rule.amountPaise.toString(),
      amountDecimal: formatPaiseToDecimalString(rule.amountPaise),
      paymentMethod: rule.paymentMethod,
      frequency: rule.frequency,
      intervalCount: rule.intervalCount,
      startDate: rule.startDate,
      endDate: rule.endDate,
      nextOccurrence: rule.nextOccurrence,
      lastGeneratedAt: rule.lastGeneratedAt,
      isActive: rule.isActive,
      reminderDays: rule.reminderDays,
      daysUntilNext,
      isUpcomingReminder,
      version: rule.version,
      history: (rule.transactions ?? []).map((tx) => ({
        id: tx.id,
        amountPaise: tx.amountPaise.toString(),
        amountDecimal: formatPaiseToDecimalString(tx.amountPaise),
        transactionDate: tx.transactionDate,
        description: tx.description,
      })),
    };
  }

  static async listRecurring(userId: string) {
    await this.processDueRecurringForUser(userId);

    const items = await prisma.recurringExpense.findMany({
      where: { userId, isDeleted: false },
      include: {
        category: true,
        transactions: {
          where: { isDeleted: false },
          orderBy: { transactionDate: 'desc' },
          take: 10,
        },
      },
      orderBy: [{ isActive: 'desc' }, { nextOccurrence: 'asc' }],
    });

    const formatted = items.map((r) => this.formatRule(r));
    const upcomingReminders = formatted.filter((r) => r.isUpcomingReminder);

    return {
      recurringExpenses: formatted,
      upcomingReminders,
    };
  }

  static async createRecurring(
    userId: string,
    input: {
      categoryId: string;
      type: TransactionType;
      title: string;
      merchant?: string | null;
      description?: string | null;
      amountPaise: bigint;
      paymentMethod: PaymentMethod;
      frequency: RecurrenceFrequency;
      intervalCount: number;
      startDate: string;
      endDate?: string | null;
      reminderDays: number;
      isActive: boolean;
    },
  ) {
    const cat = await prisma.category.findFirst({
      where: { id: input.categoryId, userId, isDeleted: false },
    });
    if (!cat) {
      throw new AppError('Selected category not found', 404, 'CATEGORY_NOT_FOUND');
    }

    const startDate = new Date(input.startDate);
    const endDate = input.endDate ? new Date(input.endDate) : null;
    if (endDate && endDate < startDate) {
      throw new AppError('End date cannot be earlier than start date', 400, 'INVALID_DATE_RANGE');
    }

    const created = await prisma.recurringExpense.create({
      data: {
        userId,
        categoryId: input.categoryId,
        type: input.type,
        title: input.title,
        merchant: input.merchant ?? null,
        description: input.description ?? input.title,
        amountPaise: input.amountPaise,
        paymentMethod: input.paymentMethod,
        frequency: input.frequency,
        intervalCount: input.intervalCount,
        startDate,
        endDate,
        nextOccurrence: startDate,
        reminderDays: input.reminderDays,
        isActive: input.isActive,
      },
      include: {
        category: true,
        transactions: {
          where: { isDeleted: false },
          orderBy: { transactionDate: 'desc' },
          take: 10,
        },
      },
    });

    return this.formatRule(created);
  }

  static async updateRecurring(
    userId: string,
    id: string,
    input: {
      categoryId?: string;
      title?: string;
      merchant?: string | null;
      description?: string | null;
      amountPaise?: bigint;
      paymentMethod?: PaymentMethod;
      frequency?: RecurrenceFrequency;
      intervalCount?: number;
      endDate?: string | null;
      reminderDays?: number;
      isActive?: boolean;
    },
  ) {
    const existing = await prisma.recurringExpense.findFirst({
      where: { id, userId, isDeleted: false },
    });
    if (!existing) {
      throw new AppError('Recurring schedule not found', 404, 'RECURRING_NOT_FOUND');
    }

    const updated = await prisma.recurringExpense.update({
      where: { id },
      data: {
        ...(input.categoryId !== undefined ? { categoryId: input.categoryId } : {}),
        ...(input.title !== undefined ? { title: input.title } : {}),
        ...(input.merchant !== undefined ? { merchant: input.merchant } : {}),
        ...(input.description !== undefined ? { description: input.description } : {}),
        ...(input.amountPaise !== undefined ? { amountPaise: input.amountPaise } : {}),
        ...(input.paymentMethod !== undefined ? { paymentMethod: input.paymentMethod } : {}),
        ...(input.frequency !== undefined ? { frequency: input.frequency } : {}),
        ...(input.intervalCount !== undefined ? { intervalCount: input.intervalCount } : {}),
        ...(input.endDate !== undefined
          ? { endDate: input.endDate ? new Date(input.endDate) : null }
          : {}),
        ...(input.reminderDays !== undefined ? { reminderDays: input.reminderDays } : {}),
        ...(input.isActive !== undefined ? { isActive: input.isActive } : {}),
        version: { increment: 1 },
      },
      include: {
        category: true,
        transactions: {
          where: { isDeleted: false },
          orderBy: { transactionDate: 'desc' },
          take: 10,
        },
      },
    });

    return this.formatRule(updated);
  }

  static async deleteRecurring(userId: string, id: string): Promise<void> {
    const existing = await prisma.recurringExpense.findFirst({
      where: { id, userId, isDeleted: false },
    });
    if (!existing) {
      throw new AppError('Recurring schedule not found', 404, 'RECURRING_NOT_FOUND');
    }

    await prisma.recurringExpense.update({
      where: { id },
      data: {
        isDeleted: true,
        isActive: false,
        deletedAt: new Date(),
        version: { increment: 1 },
      },
    });
  }
}

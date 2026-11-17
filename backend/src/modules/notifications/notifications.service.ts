import { NotificationType, TransactionType } from '@prisma/client';
import { prisma } from '../../config/database';
import { AppError } from '../../middleware/error.middleware';
import { calculateUtilizationPercentage, formatPaiseToInr } from '../../utils/money';

export class NotificationsService {
  /**
   * Evaluates deterministic financial alert triggers (budget thresholds 50/75/90/100%
   * and upcoming recurring bills) idempotently without generating duplicate alerts.
   */
  static async evaluateDeterministicAlerts(userId: string): Promise<void> {
    const now = new Date();
    const month = now.getUTCMonth() + 1;
    const year = now.getUTCFullYear();
    const startOfMonth = new Date(Date.UTC(year, month - 1, 1, 0, 0, 0));
    const endOfMonth = new Date(Date.UTC(year, month, 0, 23, 59, 59, 999));

    const [budgets, expenses, recurring, recentNotifications] = await Promise.all([
      prisma.budget.findMany({
        where: { userId, month, year, isDeleted: false },
        include: { category: true },
      }),
      prisma.transaction.findMany({
        where: {
          userId,
          type: TransactionType.EXPENSE,
          isDeleted: false,
          transactionDate: { gte: startOfMonth, lte: endOfMonth },
        },
      }),
      prisma.recurringExpense.findMany({
        where: { userId, isActive: true, isDeleted: false },
      }),
      prisma.notification.findMany({
        where: {
          userId,
          createdAt: { gte: startOfMonth },
        },
        select: { title: true },
      }),
    ]);

    const existingTitles = new Set(recentNotifications.map((n) => n.title));

    let totalExpensePaise = 0n;
    const byCategory = new Map<string, bigint>();
    for (const tx of expenses) {
      totalExpensePaise += tx.amountPaise;
      byCategory.set(tx.categoryId, (byCategory.get(tx.categoryId) ?? 0n) + tx.amountPaise);
    }

    // 1. Evaluate Budget Thresholds (50%, 75%, 90%, 100%)
    for (const b of budgets) {
      const spentPaise =
        b.categoryId === null ? totalExpensePaise : (byCategory.get(b.categoryId) ?? 0n);
      const { percentage } = calculateUtilizationPercentage(spentPaise, b.amountPaise);
      const label = b.category?.name ?? 'Overall Monthly';

      const newTriggered = [...b.triggeredThresholds];
      let thresholdUpdated = false;

      for (const threshold of b.alertThresholds) {
        if (percentage >= threshold && !newTriggered.includes(threshold)) {
          newTriggered.push(threshold);
          thresholdUpdated = true;
          const title = `${label} Budget Alert (${threshold}% reached)`;
          if (!existingTitles.has(title)) {
            await prisma.notification.create({
              data: {
                userId,
                type: NotificationType.BUDGET_THRESHOLD,
                title,
                message: `You have used ${percentage}% (${formatPaiseToInr(spentPaise)} of ${formatPaiseToInr(b.amountPaise)}) of your ${label} budget for ${month}/${year}.`,
                metadata: {
                  budgetId: b.id,
                  threshold,
                  utilizationPercentage: percentage,
                },
              },
            });
            existingTitles.add(title);
          }
        }
      }

      if (thresholdUpdated) {
        await prisma.budget.update({
          where: { id: b.id },
          data: { triggeredThresholds: newTriggered },
        });
      }
    }

    // 2. Evaluate Upcoming Recurring Reminders
    for (const rec of recurring) {
      const daysUntil = Math.ceil(
        (rec.nextOccurrence.getTime() - now.getTime()) / (24 * 60 * 60 * 1000),
      );
      if (daysUntil >= 0 && daysUntil <= rec.reminderDays) {
        const dateKey = rec.nextOccurrence.toISOString().slice(0, 10);
        const title = `Upcoming Recurring: ${rec.title} (${dateKey})`;
        if (!existingTitles.has(title)) {
          await prisma.notification.create({
            data: {
              userId,
              type: NotificationType.UPCOMING_RECURRING,
              title,
              message: `${rec.title} of ${formatPaiseToInr(rec.amountPaise)} is scheduled on ${dateKey}.`,
              metadata: {
                recurringExpenseId: rec.id,
                nextOccurrence: dateKey,
              },
            },
          });
          existingTitles.add(title);
        }
      }
    }
  }

  static async listNotifications(userId: string) {
    await this.evaluateDeterministicAlerts(userId);

    const [notifications, unreadCount] = await Promise.all([
      prisma.notification.findMany({
        where: { userId },
        orderBy: { createdAt: 'desc' },
        take: 50,
      }),
      prisma.notification.count({
        where: { userId, isRead: false },
      }),
    ]);

    return {
      unreadCount,
      notifications,
    };
  }

  static async markAsRead(userId: string, id: string) {
    const existing = await prisma.notification.findFirst({
      where: { id, userId },
    });
    if (!existing) {
      throw new AppError('Notification not found', 404, 'NOTIFICATION_NOT_FOUND');
    }

    return prisma.notification.update({
      where: { id },
      data: { isRead: true },
    });
  }

  static async markAllAsRead(userId: string) {
    const updated = await prisma.notification.updateMany({
      where: { userId, isRead: false },
      data: { isRead: true },
    });
    return { updatedCount: updated.count };
  }
}

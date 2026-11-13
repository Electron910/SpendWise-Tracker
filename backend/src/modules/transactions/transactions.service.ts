import { PaymentMethod, Prisma, SyncStatus, TransactionType } from '@prisma/client';
import { prisma } from '../../config/database';
import { AppError } from '../../utils/appError';
import { formatPaiseToDecimalString } from '../../utils/money';

export interface FormattedTransaction {
  id: string;
  userId: string;
  categoryId: string;
  recurringExpenseId: string | null;
  type: TransactionType;
  amountPaise: string;
  amountDecimal: string;
  currency: string;
  merchant: string | null;
  description: string;
  notes: string | null;
  paymentMethod: PaymentMethod;
  transactionDate: Date;
  isAutoCategorized: boolean;
  categorizationConfidence: number | null;
  isDemoData: boolean;
  syncStatus: SyncStatus;
  version: number;
  isDeleted: boolean;
  createdAt: Date;
  updatedAt: Date;
  category: {
    id: string;
    name: string;
    type: TransactionType;
    icon: string;
    colorHex: string;
  };
}

function formatTransactionRecord(
  tx: Prisma.TransactionGetPayload<{ include: { category: true } }>,
): FormattedTransaction {
  return {
    id: tx.id,
    userId: tx.userId,
    categoryId: tx.categoryId,
    recurringExpenseId: tx.recurringExpenseId,
    type: tx.type,
    amountPaise: tx.amountPaise.toString(),
    amountDecimal: formatPaiseToDecimalString(tx.amountPaise),
    currency: tx.currency,
    merchant: tx.merchant,
    description: tx.description,
    notes: tx.notes,
    paymentMethod: tx.paymentMethod,
    transactionDate: tx.transactionDate,
    isAutoCategorized: tx.isAutoCategorized,
    categorizationConfidence: tx.categorizationConfidence,
    isDemoData: tx.isDemoData,
    syncStatus: tx.syncStatus,
    version: tx.version,
    isDeleted: tx.isDeleted,
    createdAt: tx.createdAt,
    updatedAt: tx.updatedAt,
    category: {
      id: tx.category.id,
      name: tx.category.name,
      type: tx.category.type,
      icon: tx.category.icon,
      colorHex: tx.category.colorHex,
    },
  };
}

export class TransactionsService {
  static async listTransactions(
    userId: string,
    query: {
      page: number;
      limit: number;
      type?: TransactionType;
      categoryId?: string;
      paymentMethod?: PaymentMethod;
      search?: string;
      startDate?: string;
      endDate?: string;
      minAmountPaise?: string;
      maxAmountPaise?: string;
      sortBy: 'transactionDate' | 'amountPaise' | 'createdAt';
      sortOrder: 'asc' | 'desc';
    },
  ): Promise<{
    transactions: FormattedTransaction[];
    summary: {
      totalIncomePaise: string;
      totalExpensePaise: string;
      netSavingsPaise: string;
    };
    pagination: {
      page: number;
      limit: number;
      totalCount: number;
      totalPages: number;
    };
  }> {
    const where: Prisma.TransactionWhereInput = {
      userId,
      isDeleted: false,
    };

    if (query.type) {
      where.type = query.type;
    }

    if (query.categoryId) {
      where.categoryId = query.categoryId;
    }

    if (query.paymentMethod) {
      where.paymentMethod = query.paymentMethod;
    }

    if (query.search && query.search.trim().length > 0) {
      const term = query.search.trim();
      where.OR = [
        { description: { contains: term, mode: 'insensitive' } },
        { merchant: { contains: term, mode: 'insensitive' } },
        { notes: { contains: term, mode: 'insensitive' } },
      ];
    }

    if (query.startDate || query.endDate) {
      where.transactionDate = {};
      if (query.startDate) {
        const start = new Date(query.startDate);
        if (!Number.isNaN(start.getTime())) {
          where.transactionDate.gte = start;
        }
      }
      if (query.endDate) {
        const end = new Date(query.endDate);
        if (!Number.isNaN(end.getTime())) {
          where.transactionDate.lte = end;
        }
      }
    }

    if (query.minAmountPaise || query.maxAmountPaise) {
      where.amountPaise = {};
      if (query.minAmountPaise) {
        where.amountPaise.gte = BigInt(query.minAmountPaise);
      }
      if (query.maxAmountPaise) {
        where.amountPaise.lte = BigInt(query.maxAmountPaise);
      }
    }

    const skip = (query.page - 1) * query.limit;

    const [totalCount, items, incomeAgg, expenseAgg] = await Promise.all([
      prisma.transaction.count({ where }),
      prisma.transaction.findMany({
        where,
        include: { category: true },
        orderBy: { [query.sortBy]: query.sortOrder },
        skip,
        take: query.limit,
      }),
      prisma.transaction.aggregate({
        where: { ...where, type: TransactionType.INCOME },
        _sum: { amountPaise: true },
      }),
      prisma.transaction.aggregate({
        where: { ...where, type: TransactionType.EXPENSE },
        _sum: { amountPaise: true },
      }),
    ]);

    const totalIncomePaise = incomeAgg._sum.amountPaise ?? 0n;
    const totalExpensePaise = expenseAgg._sum.amountPaise ?? 0n;
    const netSavingsPaise = totalIncomePaise - totalExpensePaise;

    return {
      transactions: items.map(formatTransactionRecord),
      summary: {
        totalIncomePaise: totalIncomePaise.toString(),
        totalExpensePaise: totalExpensePaise.toString(),
        netSavingsPaise: netSavingsPaise.toString(),
      },
      pagination: {
        page: query.page,
        limit: query.limit,
        totalCount,
        totalPages: Math.max(1, Math.ceil(totalCount / query.limit)),
      },
    };
  }

  static async getTransactionById(
    userId: string,
    transactionId: string,
  ): Promise<FormattedTransaction> {
    const tx = await prisma.transaction.findFirst({
      where: {
        id: transactionId,
        userId,
        isDeleted: false,
      },
      include: { category: true },
    });

    if (!tx) {
      throw new AppError('Transaction not found', 404, 'TRANSACTION_NOT_FOUND');
    }

    return formatTransactionRecord(tx);
  }

  static async createTransaction(
    userId: string,
    input: {
      id?: string;
      categoryId: string;
      type: TransactionType;
      amountPaise: bigint;
      currency?: string;
      merchant?: string | null;
      description: string;
      notes?: string | null;
      paymentMethod: PaymentMethod;
      transactionDate: Date;
      isAutoCategorized?: boolean;
      categorizationConfidence?: number | null;
    },
  ): Promise<FormattedTransaction> {
    const category = await prisma.category.findFirst({
      where: {
        id: input.categoryId,
        userId,
        isDeleted: false,
      },
    });

    if (!category) {
      throw new AppError('Selected category does not exist', 400, 'INVALID_CATEGORY');
    }

    if (category.type !== input.type) {
      throw new AppError(
        `Category "${category.name}" is for ${category.type} and cannot be used for ${input.type}`,
        400,
        'CATEGORY_TYPE_MISMATCH',
      );
    }

    // Idempotency check if client supplied a UUID
    if (input.id) {
      const existing = await prisma.transaction.findUnique({
        where: { id: input.id },
        include: { category: true },
      });

      if (existing) {
        if (existing.userId !== userId) {
          throw new AppError('Transaction ID conflict', 409, 'TRANSACTION_ID_CONFLICT');
        }
        return formatTransactionRecord(existing);
      }
    }

    const created = await prisma.transaction.create({
      data: {
        ...(input.id ? { id: input.id } : {}),
        userId,
        categoryId: input.categoryId,
        type: input.type,
        amountPaise: input.amountPaise,
        currency: input.currency ?? 'INR',
        merchant: input.merchant ?? null,
        description: input.description.trim(),
        notes: input.notes ?? null,
        paymentMethod: input.paymentMethod,
        transactionDate: input.transactionDate,
        isAutoCategorized: input.isAutoCategorized ?? false,
        categorizationConfidence: input.categorizationConfidence ?? null,
        syncStatus: SyncStatus.SYNCED,
        version: 1,
      },
      include: { category: true },
    });

    return formatTransactionRecord(created);
  }

  static async updateTransaction(
    userId: string,
    transactionId: string,
    input: {
      categoryId?: string;
      type?: TransactionType;
      amountPaise?: bigint;
      merchant?: string | null;
      description?: string;
      notes?: string | null;
      paymentMethod?: PaymentMethod;
      transactionDate?: Date;
      expectedVersion?: number;
    },
  ): Promise<FormattedTransaction> {
    const existing = await prisma.transaction.findFirst({
      where: {
        id: transactionId,
        userId,
        isDeleted: false,
      },
    });

    if (!existing) {
      throw new AppError('Transaction not found', 404, 'TRANSACTION_NOT_FOUND');
    }

    if (input.expectedVersion !== undefined && existing.version !== input.expectedVersion) {
      throw new AppError(
        `Transaction version conflict: expected v${input.expectedVersion}, found v${existing.version}`,
        409,
        'VERSION_CONFLICT',
        { serverVersion: existing.version },
      );
    }

    const targetType = input.type ?? existing.type;
    const targetCategoryId = input.categoryId ?? existing.categoryId;

    const category = await prisma.category.findFirst({
      where: {
        id: targetCategoryId,
        userId,
        isDeleted: false,
      },
    });

    if (!category) {
      throw new AppError('Selected category does not exist', 400, 'INVALID_CATEGORY');
    }

    if (category.type !== targetType) {
      throw new AppError(
        `Category "${category.name}" is for ${category.type} and cannot be used for ${targetType}`,
        400,
        'CATEGORY_TYPE_MISMATCH',
      );
    }

    const updated = await prisma.transaction.update({
      where: { id: transactionId },
      data: {
        categoryId: targetCategoryId,
        type: targetType,
        ...(input.amountPaise !== undefined ? { amountPaise: input.amountPaise } : {}),
        ...(input.merchant !== undefined ? { merchant: input.merchant } : {}),
        ...(input.description !== undefined ? { description: input.description.trim() } : {}),
        ...(input.notes !== undefined ? { notes: input.notes } : {}),
        ...(input.paymentMethod !== undefined ? { paymentMethod: input.paymentMethod } : {}),
        ...(input.transactionDate !== undefined ? { transactionDate: input.transactionDate } : {}),
        clientUpdatedAt: new Date(),
        version: { increment: 1 },
      },
      include: { category: true },
    });

    return formatTransactionRecord(updated);
  }

  static async deleteTransaction(userId: string, transactionId: string): Promise<void> {
    const existing = await prisma.transaction.findFirst({
      where: {
        id: transactionId,
        userId,
        isDeleted: false,
      },
    });

    if (!existing) {
      throw new AppError('Transaction not found', 404, 'TRANSACTION_NOT_FOUND');
    }

    // Soft-delete tombstone for synchronization compatibility
    await prisma.transaction.update({
      where: { id: transactionId },
      data: {
        isDeleted: true,
        deletedAt: new Date(),
        clientUpdatedAt: new Date(),
        version: { increment: 1 },
      },
    });
  }
}

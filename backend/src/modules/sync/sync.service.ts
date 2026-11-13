import { PaymentMethod, SyncStatus, TransactionType } from '@prisma/client';
import { prisma } from '../../config/database';
import { formatPaiseToDecimalString } from '../../utils/money';

export interface SyncPushOperationInput {
  operationId: string;
  entityType: 'TRANSACTION';
  entityId: string;
  action: 'CREATE' | 'UPDATE' | 'DELETE';
  baseVersion: number;
  forceOverwrite?: boolean;
  payload: {
    categoryId?: string;
    type?: TransactionType;
    amountPaise?: number | string;
    description?: string;
    merchant?: string | null;
    notes?: string | null;
    paymentMethod?: PaymentMethod;
    transactionDate?: string;
  };
}

export class SyncService {
  private static serializeTransaction(tx: {
    id: string;
    categoryId: string;
    type: TransactionType;
    amountPaise: bigint;
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
    deletedAt: Date | null;
    updatedAt: Date;
    category: {
      id: string;
      name: string;
      type: TransactionType;
      icon: string;
      colorHex: string;
      isSystem: boolean;
    };
  }) {
    return {
      id: tx.id,
      categoryId: tx.categoryId,
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
      syncStatus: 'SYNCED',
      version: tx.version,
      isDeleted: tx.isDeleted,
      deletedAt: tx.deletedAt,
      updatedAt: tx.updatedAt,
      category: tx.category,
    };
  }

  static async pushOperations(
    userId: string,
    deviceId: string,
    operations: SyncPushOperationInput[],
  ) {
    const results: Array<{
      operationId: string;
      entityId: string;
      action: string;
      status: 'APPLIED' | 'CONFLICT' | 'FAILED';
      version?: number;
      record?: ReturnType<typeof SyncService.serializeTransaction>;
      serverRecord?: ReturnType<typeof SyncService.serializeTransaction>;
      errorMessage?: string;
    }> = [];

    for (const op of operations) {
      try {
        if (op.action === 'CREATE') {
          // Idempotent duplicate prevention check by client-generated UUID
          const existing = await prisma.transaction.findFirst({
            where: { id: op.entityId, userId },
            include: { category: true },
          });

          if (existing) {
            results.push({
              operationId: op.operationId,
              entityId: op.entityId,
              action: op.action,
              status: 'APPLIED',
              version: existing.version,
              record: this.serializeTransaction(existing),
            });
            continue;
          }

          if (!op.payload.categoryId || !op.payload.amountPaise || !op.payload.description) {
            results.push({
              operationId: op.operationId,
              entityId: op.entityId,
              action: op.action,
              status: 'FAILED',
              errorMessage: 'Missing required fields for transaction creation',
            });
            continue;
          }

          const created = await prisma.transaction.create({
            data: {
              id: op.entityId,
              userId,
              categoryId: op.payload.categoryId,
              type: op.payload.type ?? TransactionType.EXPENSE,
              amountPaise: BigInt(op.payload.amountPaise),
              description: op.payload.description,
              merchant: op.payload.merchant ?? null,
              notes: op.payload.notes ?? null,
              paymentMethod: op.payload.paymentMethod ?? PaymentMethod.UPI,
              transactionDate: op.payload.transactionDate
                ? new Date(op.payload.transactionDate)
                : new Date(),
              syncStatus: SyncStatus.SYNCED,
              version: 1,
            },
            include: { category: true },
          });

          results.push({
            operationId: op.operationId,
            entityId: op.entityId,
            action: op.action,
            status: 'APPLIED',
            version: created.version,
            record: this.serializeTransaction(created),
          });
        } else if (op.action === 'UPDATE') {
          const existing = await prisma.transaction.findFirst({
            where: { id: op.entityId, userId },
            include: { category: true },
          });

          if (!existing) {
            results.push({
              operationId: op.operationId,
              entityId: op.entityId,
              action: op.action,
              status: 'FAILED',
              errorMessage: 'Target transaction not found for update',
            });
            continue;
          }

          // Optimistic Concurrency Conflict Detection
          if (existing.version > op.baseVersion && !op.forceOverwrite) {
            results.push({
              operationId: op.operationId,
              entityId: op.entityId,
              action: op.action,
              status: 'CONFLICT',
              version: existing.version,
              serverRecord: this.serializeTransaction(existing),
              errorMessage: `Version conflict: server is at v${existing.version}, client edited from v${op.baseVersion}`,
            });
            continue;
          }

          const updated = await prisma.transaction.update({
            where: { id: op.entityId },
            data: {
              ...(op.payload.categoryId !== undefined
                ? { categoryId: op.payload.categoryId }
                : {}),
              ...(op.payload.type !== undefined ? { type: op.payload.type } : {}),
              ...(op.payload.amountPaise !== undefined
                ? { amountPaise: BigInt(op.payload.amountPaise) }
                : {}),
              ...(op.payload.description !== undefined
                ? { description: op.payload.description }
                : {}),
              ...(op.payload.merchant !== undefined ? { merchant: op.payload.merchant } : {}),
              ...(op.payload.notes !== undefined ? { notes: op.payload.notes } : {}),
              ...(op.payload.paymentMethod !== undefined
                ? { paymentMethod: op.payload.paymentMethod }
                : {}),
              ...(op.payload.transactionDate !== undefined
                ? { transactionDate: new Date(op.payload.transactionDate) }
                : {}),
              syncStatus: SyncStatus.SYNCED,
              version: { increment: 1 },
            },
            include: { category: true },
          });

          results.push({
            operationId: op.operationId,
            entityId: op.entityId,
            action: op.action,
            status: 'APPLIED',
            version: updated.version,
            record: this.serializeTransaction(updated),
          });
        } else if (op.action === 'DELETE') {
          const existing = await prisma.transaction.findFirst({
            where: { id: op.entityId, userId },
            include: { category: true },
          });

          if (!existing || existing.isDeleted) {
            results.push({
              operationId: op.operationId,
              entityId: op.entityId,
              action: op.action,
              status: 'APPLIED',
              version: existing ? existing.version : 1,
            });
            continue;
          }

          const deleted = await prisma.transaction.update({
            where: { id: op.entityId },
            data: {
              isDeleted: true,
              deletedAt: new Date(),
              syncStatus: SyncStatus.SYNCED,
              version: { increment: 1 },
            },
            include: { category: true },
          });

          results.push({
            operationId: op.operationId,
            entityId: op.entityId,
            action: op.action,
            status: 'APPLIED',
            version: deleted.version,
            record: this.serializeTransaction(deleted),
          });
        }
      } catch (err) {
        results.push({
          operationId: op.operationId,
          entityId: op.entityId,
          action: op.action,
          status: 'FAILED',
          errorMessage: err instanceof Error ? err.message : 'Unknown sync push error',
        });
      }
    }

    const serverTimestamp = new Date();
    await prisma.syncMetadata.upsert({
      where: {
        userId_deviceId: { userId, deviceId },
      },
      update: {
        lastPushedAt: serverTimestamp,
        lastSyncRevision: { increment: 1n },
      },
      create: {
        userId,
        deviceId,
        lastPushedAt: serverTimestamp,
        lastSyncRevision: 1n,
      },
    });

    return {
      serverTimestamp,
      results,
      summary: {
        appliedCount: results.filter((r) => r.status === 'APPLIED').length,
        conflictCount: results.filter((r) => r.status === 'CONFLICT').length,
        failedCount: results.filter((r) => r.status === 'FAILED').length,
      },
    };
  }

  static async pullChanges(userId: string, since?: string) {
    const sinceDate = since ? new Date(since) : new Date(0);
    const serverTimestamp = new Date();

    const [transactions, categories] = await Promise.all([
      prisma.transaction.findMany({
        where: {
          userId,
          updatedAt: { gte: sinceDate },
        },
        include: { category: true },
        orderBy: { updatedAt: 'asc' },
      }),
      prisma.category.findMany({
        where: {
          userId,
          updatedAt: { gte: sinceDate },
        },
        orderBy: { name: 'asc' },
      }),
    ]);

    return {
      serverTimestamp,
      since: sinceDate,
      transactions: transactions.map((tx) => this.serializeTransaction(tx)),
      categories,
    };
  }
}

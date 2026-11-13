import { PaymentMethod, TransactionType } from '@prisma/client';
import { z } from 'zod';

const syncOperationSchema = z.object({
  operationId: z.string().min(1),
  entityType: z.enum(['TRANSACTION']).default('TRANSACTION'),
  entityId: z.string().uuid('entityId must be a valid UUID'),
  action: z.enum(['CREATE', 'UPDATE', 'DELETE']),
  baseVersion: z.number().int().min(1).default(1),
  forceOverwrite: z.boolean().default(false),
  payload: z
    .object({
      categoryId: z.string().uuid().optional(),
      type: z.nativeEnum(TransactionType).optional(),
      amountPaise: z
        .union([z.number().int().positive(), z.string().regex(/^\d+$/)])
        .optional(),
      description: z.string().trim().min(1).max(255).optional(),
      merchant: z.string().trim().max(160).optional().nullable(),
      notes: z.string().trim().max(2000).optional().nullable(),
      paymentMethod: z.nativeEnum(PaymentMethod).optional(),
      transactionDate: z.string().optional(),
    })
    .optional()
    .default({}),
});

export const syncPushSchema = z.object({
  body: z.object({
    deviceId: z.string().trim().min(1).max(120).default('default-mobile-device'),
    operations: z.array(syncOperationSchema).max(200),
  }),
});

export const syncPullSchema = z.object({
  query: z.object({
    since: z.string().optional(),
  }),
});

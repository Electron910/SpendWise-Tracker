import { PaymentMethod, TransactionType } from '@prisma/client';
import { z } from 'zod';

const MAX_PAISE = 99_999_999_999_900n; // ₹999,999,999,999.00

export const amountPaiseSchema = z
  .union([z.number().int().positive(), z.string().regex(/^\d+$/, 'amountPaise must be integer paise')])
  .transform((val) => BigInt(val))
  .refine((val) => val > 0n && val <= MAX_PAISE, {
    message: 'Amount in paise must be between 1 and 99,999,999,999,900',
  });

export const createTransactionSchema = z.object({
  body: z.object({
    id: z.string().uuid().optional(),
    categoryId: z.string().uuid('Valid categoryId UUID is required'),
    type: z.nativeEnum(TransactionType),
    amountPaise: amountPaiseSchema,
    currency: z.string().trim().toUpperCase().default('INR'),
    merchant: z.string().trim().max(160).optional().nullable(),
    description: z.string().trim().min(1, 'Description is required').max(255),
    notes: z.string().trim().max(2000).optional().nullable(),
    paymentMethod: z.nativeEnum(PaymentMethod).default(PaymentMethod.UPI),
    transactionDate: z
      .string()
      .datetime({ offset: true })
      .or(z.string().regex(/^\d{4}-\d{2}-\d{2}/))
      .transform((val) => {
        const dt = new Date(val);
        if (Number.isNaN(dt.getTime())) {
          throw new Error('Invalid transactionDate');
        }
        return dt;
      }),
    isAutoCategorized: z.boolean().default(false),
    categorizationConfidence: z.number().int().min(0).max(100).optional().nullable(),
  }),
  query: z.object({}).passthrough(),
  params: z.object({}).passthrough(),
});

export const updateTransactionSchema = z.object({
  body: z.object({
    categoryId: z.string().uuid().optional(),
    type: z.nativeEnum(TransactionType).optional(),
    amountPaise: amountPaiseSchema.optional(),
    merchant: z.string().trim().max(160).optional().nullable(),
    description: z.string().trim().min(1).max(255).optional(),
    notes: z.string().trim().max(2000).optional().nullable(),
    paymentMethod: z.nativeEnum(PaymentMethod).optional(),
    transactionDate: z
      .string()
      .transform((val) => {
        const dt = new Date(val);
        if (Number.isNaN(dt.getTime())) {
          throw new Error('Invalid transactionDate');
        }
        return dt;
      })
      .optional(),
    expectedVersion: z.number().int().positive().optional(),
  }),
  query: z.object({}).passthrough(),
  params: z.object({
    id: z.string().uuid('Valid transaction UUID is required'),
  }),
});

export const listTransactionsSchema = z.object({
  body: z.object({}).passthrough(),
  params: z.object({}).passthrough(),
  query: z.object({
    page: z.coerce.number().int().min(1).default(1),
    limit: z.coerce.number().int().min(1).max(100).default(25),
    type: z.nativeEnum(TransactionType).optional(),
    categoryId: z.string().uuid().optional(),
    paymentMethod: z.nativeEnum(PaymentMethod).optional(),
    search: z.string().trim().optional(),
    startDate: z.string().optional(),
    endDate: z.string().optional(),
    minAmountPaise: z.string().regex(/^\d+$/).optional(),
    maxAmountPaise: z.string().regex(/^\d+$/).optional(),
    sortBy: z.enum(['transactionDate', 'amountPaise', 'createdAt']).default('transactionDate'),
    sortOrder: z.enum(['asc', 'desc']).default('desc'),
  }),
});

export const transactionIdParamSchema = z.object({
  body: z.object({}).passthrough(),
  query: z.object({}).passthrough(),
  params: z.object({
    id: z.string().uuid('Valid transaction UUID is required'),
  }),
});

import { z } from 'zod';
import { amountPaiseSchema } from '../transactions/transactions.validation';

export const listBudgetsSchema = z.object({
  body: z.object({}).passthrough(),
  params: z.object({}).passthrough(),
  query: z.object({
    month: z.coerce.number().int().min(1).max(12).optional(),
    year: z.coerce.number().int().min(2000).max(2100).optional(),
  }),
});

export const createBudgetSchema = z.object({
  body: z.object({
    id: z.string().uuid().optional(),
    categoryId: z.string().uuid().nullable().optional(),
    month: z.number().int().min(1).max(12),
    year: z.number().int().min(2000).max(2100),
    amountPaise: amountPaiseSchema,
    alertThresholds: z
      .array(z.number().int().min(1).max(100))
      .min(1)
      .default([50, 75, 90, 100]),
  }),
  query: z.object({}).passthrough(),
  params: z.object({}).passthrough(),
});

export const updateBudgetSchema = z.object({
  body: z.object({
    amountPaise: amountPaiseSchema.optional(),
    alertThresholds: z.array(z.number().int().min(1).max(100)).min(1).optional(),
  }),
  query: z.object({}).passthrough(),
  params: z.object({
    id: z.string().uuid('Valid budget UUID is required'),
  }),
});

export const budgetIdParamSchema = z.object({
  body: z.object({}).passthrough(),
  query: z.object({}).passthrough(),
  params: z.object({
    id: z.string().uuid('Valid budget UUID is required'),
  }),
});

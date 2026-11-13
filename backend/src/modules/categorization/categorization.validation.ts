import { TransactionType } from '@prisma/client';
import { z } from 'zod';

export const classifyTransactionSchema = z.object({
  body: z.object({
    merchant: z.string().trim().max(160).optional().nullable(),
    description: z.string().trim().max(255).optional().nullable(),
    type: z.nativeEnum(TransactionType).default(TransactionType.EXPENSE),
  }),
  query: z.object({}).passthrough(),
  params: z.object({}).passthrough(),
});

export const createRuleSchema = z.object({
  body: z.object({
    categoryId: z.string().uuid('Valid categoryId UUID is required'),
    transactionType: z.nativeEnum(TransactionType).default(TransactionType.EXPENSE),
    pattern: z.string().trim().min(2, 'Pattern must be at least 2 characters').max(160),
    matchType: z.enum(['CONTAINS', 'EXACT', 'STARTS_WITH']).default('CONTAINS'),
    confidence: z.number().int().min(50).max(100).default(98),
    priority: z.number().int().min(1).max(1000).default(220),
    isUserCorrection: z.boolean().default(false),
  }),
  query: z.object({}).passthrough(),
  params: z.object({}).passthrough(),
});

export const ruleIdParamSchema = z.object({
  body: z.object({}).passthrough(),
  query: z.object({}).passthrough(),
  params: z.object({
    id: z.string().uuid('Valid rule UUID is required'),
  }),
});

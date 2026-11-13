import { PaymentMethod, RecurrenceFrequency, TransactionType } from '@prisma/client';
import { z } from 'zod';

export const createRecurringSchema = z.object({
  body: z.object({
    categoryId: z.string().uuid('Invalid category UUID'),
    type: z.nativeEnum(TransactionType).default(TransactionType.EXPENSE),
    title: z.string().trim().min(2, 'Title is required').max(160),
    merchant: z.string().trim().max(160).optional().nullable(),
    description: z.string().trim().max(255).optional().nullable(),
    amountPaise: z
      .union([z.number().int().positive(), z.string().regex(/^\d+$/)])
      .transform((v) => BigInt(v))
      .refine((v) => v > 0n, 'Amount in paise must be greater than zero'),
    paymentMethod: z.nativeEnum(PaymentMethod).default(PaymentMethod.UPI),
    frequency: z.nativeEnum(RecurrenceFrequency),
    intervalCount: z.number().int().min(1).max(365).default(1),
    startDate: z.string().datetime({ offset: true }).or(z.string().min(10)),
    endDate: z
      .string()
      .datetime({ offset: true })
      .or(z.string().min(10))
      .optional()
      .nullable(),
    reminderDays: z.number().int().min(0).max(30).default(3),
    isActive: z.boolean().default(true),
  }),
});

export const updateRecurringSchema = z.object({
  params: z.object({
    id: z.string().uuid('Invalid recurring expense UUID'),
  }),
  body: z.object({
    categoryId: z.string().uuid().optional(),
    title: z.string().trim().min(2).max(160).optional(),
    merchant: z.string().trim().max(160).optional().nullable(),
    description: z.string().trim().max(255).optional().nullable(),
    amountPaise: z
      .union([z.number().int().positive(), z.string().regex(/^\d+$/)])
      .transform((v) => BigInt(v))
      .refine((v) => v > 0n, 'Amount in paise must be greater than zero')
      .optional(),
    paymentMethod: z.nativeEnum(PaymentMethod).optional(),
    frequency: z.nativeEnum(RecurrenceFrequency).optional(),
    intervalCount: z.number().int().min(1).max(365).optional(),
    endDate: z
      .string()
      .datetime({ offset: true })
      .or(z.string().min(10))
      .optional()
      .nullable(),
    reminderDays: z.number().int().min(0).max(30).optional(),
    isActive: z.boolean().optional(),
  }),
});

export const recurringIdParamSchema = z.object({
  params: z.object({
    id: z.string().uuid('Invalid recurring expense UUID'),
  }),
});

export const processDueSchema = z.object({
  body: z
    .object({
      asOfDate: z.string().optional(),
    })
    .optional(),
});

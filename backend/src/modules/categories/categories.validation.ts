import { TransactionType } from '@prisma/client';
import { z } from 'zod';

export const createCategorySchema = z.object({
  body: z.object({
    id: z.string().uuid().optional(),
    name: z.string().trim().min(1, 'Category name is required').max(80),
    type: z.nativeEnum(TransactionType),
    icon: z.string().trim().min(1).max(60).default('category'),
    colorHex: z
      .string()
      .trim()
      .regex(/^#[0-9A-Fa-f]{6}$/, 'colorHex must be a 6-digit hex color like #4F46E5')
      .default('#4F46E5'),
  }),
  query: z.object({}).passthrough(),
  params: z.object({}).passthrough(),
});

export const updateCategorySchema = z.object({
  body: z.object({
    name: z.string().trim().min(1).max(80).optional(),
    icon: z.string().trim().min(1).max(60).optional(),
    colorHex: z
      .string()
      .trim()
      .regex(/^#[0-9A-Fa-f]{6}$/)
      .optional(),
  }),
  query: z.object({}).passthrough(),
  params: z.object({
    id: z.string().uuid('Valid category UUID is required'),
  }),
});

export const categoryIdParamSchema = z.object({
  body: z.object({}).passthrough(),
  query: z.object({}).passthrough(),
  params: z.object({
    id: z.string().uuid('Valid category UUID is required'),
  }),
});

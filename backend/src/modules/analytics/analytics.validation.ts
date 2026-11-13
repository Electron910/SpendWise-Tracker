import { z } from 'zod';

export const overviewQuerySchema = z.object({
  body: z.object({}).passthrough(),
  params: z.object({}).passthrough(),
  query: z.object({
    month: z.coerce.number().int().min(1).max(12).optional(),
    year: z.coerce.number().int().min(2000).max(2100).optional(),
  }),
});

export const analyticsPeriodQuerySchema = z.object({
  body: z.object({}).passthrough(),
  params: z.object({}).passthrough(),
  query: z.object({
    range: z
      .enum([
        'THIS_WEEK',
        'THIS_MONTH',
        'PREVIOUS_MONTH',
        'LAST_3_MONTHS',
        'LAST_6_MONTHS',
        'CUSTOM',
      ])
      .default('THIS_MONTH'),
    startDate: z.string().optional(),
    endDate: z.string().optional(),
    monthsCount: z.coerce.number().int().min(1).max(12).default(6),
  }),
});

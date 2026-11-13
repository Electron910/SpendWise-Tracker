import { NextFunction, Request, Response } from 'express';
import { z } from 'zod';
import { sendSuccess } from '../../utils/response';
import { InsightsService } from './insights.service';

export const insightsQuerySchema = z.object({
  query: z.object({
    month: z.coerce.number().int().min(1).max(12).optional(),
    year: z.coerce.number().int().min(2000).max(2100).optional(),
  }),
});

export class InsightsController {
  static async getInsights(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = req.user!.userId;
      const now = new Date();
      const month = req.query.month ? Number(req.query.month) : now.getUTCMonth() + 1;
      const year = req.query.year ? Number(req.query.year) : now.getUTCFullYear();

      const data = await InsightsService.generateInsights(userId, month, year);
      sendSuccess(res, data, 'Financial insights retrieved successfully', 200);
    } catch (error) {
      next(error);
    }
  }
}

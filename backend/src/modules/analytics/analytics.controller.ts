import { NextFunction, Request, Response } from 'express';
import { AnalyticsService } from './analytics.service';
import { sendSuccess } from '../../utils/response';

export class AnalyticsController {
  static async getOverview(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = req.user!.userId;
      const month = req.query.month ? Number(req.query.month) : undefined;
      const year = req.query.year ? Number(req.query.year) : undefined;
      const overview = await AnalyticsService.getDashboardOverview(userId, { month, year });
      sendSuccess(res, overview, 'Dashboard overview retrieved', 200);
    } catch (error) {
      next(error);
    }
  }
}

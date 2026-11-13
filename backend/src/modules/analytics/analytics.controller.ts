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

  static async getMonthly(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = req.user!.userId;
      const monthsCount = req.query.monthsCount ? Number(req.query.monthsCount) : 6;
      const result = await AnalyticsService.getMonthlyComparison(userId, monthsCount);
      sendSuccess(res, result, 'Monthly comparison retrieved', 200);
    } catch (error) {
      next(error);
    }
  }

  static async getCategories(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = req.user!.userId;
      const result = await AnalyticsService.getCategoryAnalytics(userId, {
        range: req.query.range as string | undefined,
        startDate: req.query.startDate as string | undefined,
        endDate: req.query.endDate as string | undefined,
      });
      sendSuccess(res, result, 'Category analytics retrieved', 200);
    } catch (error) {
      next(error);
    }
  }

  static async getTrends(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = req.user!.userId;
      const result = await AnalyticsService.getSpendingTrends(userId, {
        range: req.query.range as string | undefined,
        startDate: req.query.startDate as string | undefined,
        endDate: req.query.endDate as string | undefined,
      });
      sendSuccess(res, result, 'Spending trends retrieved', 200);
    } catch (error) {
      next(error);
    }
  }
}

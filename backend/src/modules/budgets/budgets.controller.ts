import { NextFunction, Request, Response } from 'express';
import { BudgetsService } from './budgets.service';
import { sendSuccess } from '../../utils/response';

export class BudgetsController {
  static async list(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = req.user!.userId;
      const month = req.query.month ? Number(req.query.month) : undefined;
      const year = req.query.year ? Number(req.query.year) : undefined;
      const result = await BudgetsService.listBudgetsWithUtilization(userId, {
        month,
        year,
      });
      sendSuccess(res, result, 'Budgets retrieved successfully', 200);
    } catch (error) {
      next(error);
    }
  }

  static async create(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = req.user!.userId;
      const budget = await BudgetsService.createOrUpdateBudget(userId, req.body);
      sendSuccess(res, { budget }, 'Budget saved successfully', 201);
    } catch (error) {
      next(error);
    }
  }

  static async update(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = req.user!.userId;
      const budget = await BudgetsService.updateBudget(
        userId,
        req.params.id as string,
        req.body,
      );
      sendSuccess(res, { budget }, 'Budget updated successfully', 200);
    } catch (error) {
      next(error);
    }
  }

  static async remove(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = req.user!.userId;
      await BudgetsService.deleteBudget(userId, req.params.id as string);
      sendSuccess(res, { deleted: true }, 'Budget deleted successfully', 200);
    } catch (error) {
      next(error);
    }
  }
}

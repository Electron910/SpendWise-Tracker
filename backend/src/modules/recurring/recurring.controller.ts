import { NextFunction, Request, Response } from 'express';
import { sendSuccess } from '../../utils/response';
import { RecurringService } from './recurring.service';

export class RecurringController {
  static async list(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = req.user!.userId;
      const result = await RecurringService.listRecurring(userId);
      sendSuccess(res, result, 'Recurring expenses retrieved successfully', 200);
    } catch (error) {
      next(error);
    }
  }

  static async create(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = req.user!.userId;
      const recurringExpense = await RecurringService.createRecurring(userId, req.body);
      sendSuccess(res, { recurringExpense }, 'Recurring expense created successfully', 201);
    } catch (error) {
      next(error);
    }
  }

  static async update(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = req.user!.userId;
      const recurringExpense = await RecurringService.updateRecurring(
        userId,
        req.params.id as string,
        req.body,
      );
      sendSuccess(res, { recurringExpense }, 'Recurring expense updated successfully', 200);
    } catch (error) {
      next(error);
    }
  }

  static async remove(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = req.user!.userId;
      await RecurringService.deleteRecurring(userId, req.params.id as string);
      sendSuccess(res, { deleted: true }, 'Recurring expense deleted successfully', 200);
    } catch (error) {
      next(error);
    }
  }

  static async processDue(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = req.user!.userId;
      const asOfDate = req.body?.asOfDate ? new Date(req.body.asOfDate) : new Date();
      const result = await RecurringService.processDueRecurringForUser(userId, asOfDate);
      sendSuccess(
        res,
        result,
        'Due recurring occurrences processed idempotently',
        200,
      );
    } catch (error) {
      next(error);
    }
  }
}

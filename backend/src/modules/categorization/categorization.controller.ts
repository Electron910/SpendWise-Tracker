import { NextFunction, Request, Response } from 'express';
import { CategorizationService } from './categorization.service';
import { DEFAULT_CATEGORIZATION_RULES } from './defaultRules';
import { sendSuccess } from '../../utils/response';

export class CategorizationController {
  static async classify(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = req.user!.userId;
      const result = await CategorizationService.classify(userId, req.body);
      sendSuccess(res, { classification: result }, 'Classification computed', 200);
    } catch (error) {
      next(error);
    }
  }

  static async listRules(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = req.user!.userId;
      const userRules = await CategorizationService.listUserRules(userId);
      sendSuccess(
        res,
        {
          userRules,
          builtInRules: DEFAULT_CATEGORIZATION_RULES,
        },
        'Categorization rules retrieved',
        200,
      );
    } catch (error) {
      next(error);
    }
  }

  static async createOrUpdateRule(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = req.user!.userId;
      const rule = await CategorizationService.upsertRule(userId, req.body);
      sendSuccess(res, { rule }, 'Categorization rule saved', 201);
    } catch (error) {
      next(error);
    }
  }

  static async deleteRule(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = req.user!.userId;
      await CategorizationService.deleteRule(userId, req.params.id as string);
      sendSuccess(res, { deleted: true }, 'Categorization rule deleted', 200);
    } catch (error) {
      next(error);
    }
  }
}

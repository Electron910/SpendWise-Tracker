import { NextFunction, Request, Response } from 'express';
import { TransactionType } from '@prisma/client';
import { CategoriesService } from './categories.service';
import { sendSuccess } from '../../utils/response';

export class CategoriesController {
  static async list(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = req.user!.userId;
      const rawType = req.query.type as string | undefined;
      const type =
        rawType === 'EXPENSE' || rawType === 'INCOME' ? (rawType as TransactionType) : undefined;
      const categories = await CategoriesService.listCategories(userId, type);
      sendSuccess(res, { categories }, 'Categories retrieved successfully', 200);
    } catch (error) {
      next(error);
    }
  }

  static async create(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = req.user!.userId;
      const category = await CategoriesService.createCategory(userId, req.body);
      sendSuccess(res, { category }, 'Category created successfully', 201);
    } catch (error) {
      next(error);
    }
  }

  static async update(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = req.user!.userId;
      const categoryId = req.params.id as string;
      const category = await CategoriesService.updateCategory(userId, categoryId, req.body);
      sendSuccess(res, { category }, 'Category updated successfully', 200);
    } catch (error) {
      next(error);
    }
  }

  static async remove(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = req.user!.userId;
      const categoryId = req.params.id as string;
      await CategoriesService.deleteCategory(userId, categoryId);
      sendSuccess(res, { deleted: true }, 'Category deleted successfully', 200);
    } catch (error) {
      next(error);
    }
  }
}

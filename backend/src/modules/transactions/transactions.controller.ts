import { NextFunction, Request, Response } from 'express';
import { PaymentMethod, TransactionType } from '@prisma/client';
import { TransactionsService } from './transactions.service';
import { sendSuccess } from '../../utils/response';

export class TransactionsController {
  static async list(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = req.user!.userId;
      const result = await TransactionsService.listTransactions(userId, {
        page: Number(req.query.page ?? 1),
        limit: Number(req.query.limit ?? 25),
        type: req.query.type as TransactionType | undefined,
        categoryId: req.query.categoryId as string | undefined,
        paymentMethod: req.query.paymentMethod as PaymentMethod | undefined,
        search: req.query.search as string | undefined,
        startDate: req.query.startDate as string | undefined,
        endDate: req.query.endDate as string | undefined,
        minAmountPaise: req.query.minAmountPaise as string | undefined,
        maxAmountPaise: req.query.maxAmountPaise as string | undefined,
        sortBy:
          (req.query.sortBy as 'transactionDate' | 'amountPaise' | 'createdAt') ??
          'transactionDate',
        sortOrder: (req.query.sortOrder as 'asc' | 'desc') ?? 'desc',
      });
      sendSuccess(res, result, 'Transactions retrieved successfully', 200);
    } catch (error) {
      next(error);
    }
  }

  static async getById(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = req.user!.userId;
      const transaction = await TransactionsService.getTransactionById(
        userId,
        req.params.id as string,
      );
      sendSuccess(res, { transaction }, 'Transaction retrieved successfully', 200);
    } catch (error) {
      next(error);
    }
  }

  static async create(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = req.user!.userId;
      const transaction = await TransactionsService.createTransaction(userId, req.body);
      sendSuccess(res, { transaction }, 'Transaction created successfully', 201);
    } catch (error) {
      next(error);
    }
  }

  static async update(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = req.user!.userId;
      const transaction = await TransactionsService.updateTransaction(
        userId,
        req.params.id as string,
        req.body,
      );
      sendSuccess(res, { transaction }, 'Transaction updated successfully', 200);
    } catch (error) {
      next(error);
    }
  }

  static async remove(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = req.user!.userId;
      await TransactionsService.deleteTransaction(userId, req.params.id as string);
      sendSuccess(res, { deleted: true }, 'Transaction deleted successfully', 200);
    } catch (error) {
      next(error);
    }
  }
}

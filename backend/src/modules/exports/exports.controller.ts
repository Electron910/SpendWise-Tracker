import { TransactionType } from '@prisma/client';
import { NextFunction, Request, Response } from 'express';
import { z } from 'zod';
import { sendSuccess } from '../../utils/response';
import { ExportsService } from './exports.service';

export const exportTransactionsQuerySchema = z.object({
  query: z.object({
    startDate: z.string().optional(),
    endDate: z.string().optional(),
    type: z.nativeEnum(TransactionType).optional(),
    categoryId: z.string().uuid().optional(),
    format: z.enum(['json', 'csv']).default('json'),
  }),
});

export const exportMonthlyReportQuerySchema = z.object({
  query: z.object({
    month: z.coerce.number().int().min(1).max(12).optional(),
    year: z.coerce.number().int().min(2000).max(2100).optional(),
    format: z.enum(['json', 'csv']).default('json'),
  }),
});

export class ExportsController {
  static async exportTransactions(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = req.user!.userId;
      const result = await ExportsService.exportTransactionsCsv(userId, {
        startDate: req.query.startDate as string | undefined,
        endDate: req.query.endDate as string | undefined,
        type: req.query.type as TransactionType | undefined,
        categoryId: req.query.categoryId as string | undefined,
      });

      if (req.query.format === 'csv') {
        res.setHeader('Content-Type', 'text/csv; charset=utf-8');
        res.setHeader(
          'Content-Disposition',
          `attachment; filename="${result.filename}"`,
        );
        res.status(200).send(result.csvContent);
        return;
      }

      sendSuccess(res, result, 'Transactions CSV generated successfully', 200);
    } catch (error) {
      next(error);
    }
  }

  static async exportMonthlyReport(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = req.user!.userId;
      const now = new Date();
      const month = req.query.month ? Number(req.query.month) : now.getUTCMonth() + 1;
      const year = req.query.year ? Number(req.query.year) : now.getUTCFullYear();

      const result = await ExportsService.exportMonthlyReport(userId, month, year);

      if (req.query.format === 'csv') {
        res.setHeader('Content-Type', 'text/csv; charset=utf-8');
        res.setHeader(
          'Content-Disposition',
          `attachment; filename="${result.filename}"`,
        );
        res.status(200).send(result.csvContent);
        return;
      }

      sendSuccess(res, result, 'Monthly financial report generated successfully', 200);
    } catch (error) {
      next(error);
    }
  }
}

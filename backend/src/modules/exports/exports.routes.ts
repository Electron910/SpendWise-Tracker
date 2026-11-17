import { Router } from 'express';
import { requireAuth } from '../../middleware/auth.middleware';
import { validateRequest } from '../../middleware/validate.middleware';
import {
  exportMonthlyReportQuerySchema,
  ExportsController,
  exportTransactionsQuerySchema,
} from './exports.controller';

export const exportsRouter = Router();

exportsRouter.use(requireAuth);

exportsRouter.get(
  '/transactions',
  validateRequest(exportTransactionsQuerySchema),
  ExportsController.exportTransactions,
);

exportsRouter.get(
  '/monthly-report',
  validateRequest(exportMonthlyReportQuerySchema),
  ExportsController.exportMonthlyReport,
);

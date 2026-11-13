import { Router } from 'express';
import { TransactionsController } from './transactions.controller';
import { requireAuth } from '../../middleware/auth.middleware';
import { validateRequest } from '../../middleware/validate.middleware';
import {
  createTransactionSchema,
  listTransactionsSchema,
  transactionIdParamSchema,
  updateTransactionSchema,
} from './transactions.validation';

export const transactionsRouter = Router();

transactionsRouter.use(requireAuth);

transactionsRouter.get('/', validateRequest(listTransactionsSchema), TransactionsController.list);
transactionsRouter.post(
  '/',
  validateRequest(createTransactionSchema),
  TransactionsController.create,
);
transactionsRouter.get(
  '/:id',
  validateRequest(transactionIdParamSchema),
  TransactionsController.getById,
);
transactionsRouter.patch(
  '/:id',
  validateRequest(updateTransactionSchema),
  TransactionsController.update,
);
transactionsRouter.delete(
  '/:id',
  validateRequest(transactionIdParamSchema),
  TransactionsController.remove,
);

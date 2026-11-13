import { Router } from 'express';
import { BudgetsController } from './budgets.controller';
import { requireAuth } from '../../middleware/auth.middleware';
import { validateRequest } from '../../middleware/validate.middleware';
import {
  budgetIdParamSchema,
  createBudgetSchema,
  listBudgetsSchema,
  updateBudgetSchema,
} from './budgets.validation';

export const budgetsRouter = Router();

budgetsRouter.use(requireAuth);

budgetsRouter.get('/', validateRequest(listBudgetsSchema), BudgetsController.list);
budgetsRouter.post('/', validateRequest(createBudgetSchema), BudgetsController.create);
budgetsRouter.patch('/:id', validateRequest(updateBudgetSchema), BudgetsController.update);
budgetsRouter.delete('/:id', validateRequest(budgetIdParamSchema), BudgetsController.remove);

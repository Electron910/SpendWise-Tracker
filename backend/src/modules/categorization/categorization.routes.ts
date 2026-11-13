import { Router } from 'express';
import { CategorizationController } from './categorization.controller';
import { requireAuth } from '../../middleware/auth.middleware';
import { validateRequest } from '../../middleware/validate.middleware';
import {
  classifyTransactionSchema,
  createRuleSchema,
  ruleIdParamSchema,
} from './categorization.validation';

export const categorizationRouter = Router();

categorizationRouter.use(requireAuth);

categorizationRouter.post(
  '/classify',
  validateRequest(classifyTransactionSchema),
  CategorizationController.classify,
);
categorizationRouter.get('/rules', CategorizationController.listRules);
categorizationRouter.post(
  '/rules',
  validateRequest(createRuleSchema),
  CategorizationController.createOrUpdateRule,
);
categorizationRouter.delete(
  '/rules/:id',
  validateRequest(ruleIdParamSchema),
  CategorizationController.deleteRule,
);

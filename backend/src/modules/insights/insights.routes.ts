import { Router } from 'express';
import { requireAuth } from '../../middleware/auth.middleware';
import { validateRequest } from '../../middleware/validate.middleware';
import { InsightsController, insightsQuerySchema } from './insights.controller';

export const insightsRouter = Router();

insightsRouter.use(requireAuth);

insightsRouter.get(
  '/',
  validateRequest(insightsQuerySchema),
  InsightsController.getInsights,
);

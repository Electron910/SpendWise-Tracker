import { Router } from 'express';
import { AnalyticsController } from './analytics.controller';
import { requireAuth } from '../../middleware/auth.middleware';
import { validateRequest } from '../../middleware/validate.middleware';
import { analyticsPeriodQuerySchema, overviewQuerySchema } from './analytics.validation';

export const analyticsRouter = Router();

analyticsRouter.use(requireAuth);

analyticsRouter.get(
  '/overview',
  validateRequest(overviewQuerySchema),
  AnalyticsController.getOverview,
);
analyticsRouter.get(
  '/monthly',
  validateRequest(analyticsPeriodQuerySchema),
  AnalyticsController.getMonthly,
);
analyticsRouter.get(
  '/categories',
  validateRequest(analyticsPeriodQuerySchema),
  AnalyticsController.getCategories,
);
analyticsRouter.get(
  '/trends',
  validateRequest(analyticsPeriodQuerySchema),
  AnalyticsController.getTrends,
);

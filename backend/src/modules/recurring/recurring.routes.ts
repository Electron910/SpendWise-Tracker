import { Router } from 'express';
import { requireAuth } from '../../middleware/auth.middleware';
import { validateRequest } from '../../middleware/validate.middleware';
import { RecurringController } from './recurring.controller';
import {
  createRecurringSchema,
  processDueSchema,
  recurringIdParamSchema,
  updateRecurringSchema,
} from './recurring.validation';

export const recurringRouter = Router();

recurringRouter.use(requireAuth);

recurringRouter.get('/', RecurringController.list);
recurringRouter.post('/', validateRequest(createRecurringSchema), RecurringController.create);
recurringRouter.post(
  '/process-due',
  validateRequest(processDueSchema),
  RecurringController.processDue,
);
recurringRouter.patch(
  '/:id',
  validateRequest(updateRecurringSchema),
  RecurringController.update,
);
recurringRouter.delete(
  '/:id',
  validateRequest(recurringIdParamSchema),
  RecurringController.remove,
);

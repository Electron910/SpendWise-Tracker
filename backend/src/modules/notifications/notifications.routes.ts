import { Router } from 'express';
import { requireAuth } from '../../middleware/auth.middleware';
import { validateRequest } from '../../middleware/validate.middleware';
import {
  notificationIdParamSchema,
  NotificationsController,
} from './notifications.controller';

export const notificationsRouter = Router();

notificationsRouter.use(requireAuth);

notificationsRouter.get('/', NotificationsController.list);
notificationsRouter.post('/read-all', NotificationsController.markAllRead);
notificationsRouter.patch(
  '/:id/read',
  validateRequest(notificationIdParamSchema),
  NotificationsController.markRead,
);

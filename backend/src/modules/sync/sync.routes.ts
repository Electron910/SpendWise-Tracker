import { Router } from 'express';
import { requireAuth } from '../../middleware/auth.middleware';
import { validateRequest } from '../../middleware/validate.middleware';
import { SyncController } from './sync.controller';
import { syncPullSchema, syncPushSchema } from './sync.validation';

export const syncRouter = Router();

syncRouter.use(requireAuth);

syncRouter.post('/push', validateRequest(syncPushSchema), SyncController.push);
syncRouter.get('/pull', validateRequest(syncPullSchema), SyncController.pull);

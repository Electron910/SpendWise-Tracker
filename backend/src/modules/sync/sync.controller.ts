import { NextFunction, Request, Response } from 'express';
import { sendSuccess } from '../../utils/response';
import { SyncService } from './sync.service';

export class SyncController {
  static async push(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = req.user!.userId;
      const { deviceId, operations } = req.body;
      const result = await SyncService.pushOperations(
        userId,
        deviceId ?? 'default-mobile-device',
        operations ?? [],
      );
      sendSuccess(res, result, 'Sync push processed successfully', 200);
    } catch (error) {
      next(error);
    }
  }

  static async pull(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = req.user!.userId;
      const since = req.query.since as string | undefined;
      const result = await SyncService.pullChanges(userId, since);
      sendSuccess(res, result, 'Sync pull retrieved successfully', 200);
    } catch (error) {
      next(error);
    }
  }
}

import { NextFunction, Request, Response } from 'express';
import { z } from 'zod';
import { sendSuccess } from '../../utils/response';
import { NotificationsService } from './notifications.service';

export const notificationIdParamSchema = z.object({
  params: z.object({
    id: z.string().uuid('Invalid notification UUID'),
  }),
});

export class NotificationsController {
  static async list(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = req.user!.userId;
      const result = await NotificationsService.listNotifications(userId);
      sendSuccess(res, result, 'Notifications retrieved successfully', 200);
    } catch (error) {
      next(error);
    }
  }

  static async markRead(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = req.user!.userId;
      const notification = await NotificationsService.markAsRead(
        userId,
        req.params.id as string,
      );
      sendSuccess(res, { notification }, 'Notification marked as read', 200);
    } catch (error) {
      next(error);
    }
  }

  static async markAllRead(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = req.user!.userId;
      const result = await NotificationsService.markAllAsRead(userId);
      sendSuccess(res, result, 'All notifications marked as read', 200);
    } catch (error) {
      next(error);
    }
  }
}

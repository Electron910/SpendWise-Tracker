import { NextFunction, Request, Response } from 'express';
import { AuthService } from './auth.service';
import { sendSuccess } from '../../utils/response';

export class AuthController {
  static async register(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const { email, password, fullName, currency } = req.body;
      const result = await AuthService.register({
        email,
        password,
        fullName,
        currency,
        deviceInfo: req.headers['user-agent'],
      });
      sendSuccess(res, result, 'User registered successfully', 201);
    } catch (error) {
      next(error);
    }
  }

  static async login(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const { email, password, deviceInfo } = req.body;
      const result = await AuthService.login({
        email,
        password,
        deviceInfo: deviceInfo ?? req.headers['user-agent'],
      });
      sendSuccess(res, result, 'Login successful', 200);
    } catch (error) {
      next(error);
    }
  }

  static async refresh(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const { refreshToken, deviceInfo } = req.body;
      const result = await AuthService.refreshTokens({
        refreshToken,
        deviceInfo: deviceInfo ?? req.headers['user-agent'],
      });
      sendSuccess(res, result, 'Tokens refreshed successfully', 200);
    } catch (error) {
      next(error);
    }
  }

  static async logout(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const { refreshToken } = req.body;
      await AuthService.logout({
        userId: req.user?.userId,
        refreshToken,
      });
      sendSuccess(res, { loggedOut: true }, 'Logged out successfully', 200);
    } catch (error) {
      next(error);
    }
  }

  static async forgotPassword(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const { email } = req.body;
      const result = await AuthService.forgotPassword(email);
      sendSuccess(res, result, result.message, 200);
    } catch (error) {
      next(error);
    }
  }

  static async resetPassword(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const { email, resetToken, newPassword } = req.body;
      await AuthService.resetPassword({ email, resetToken, newPassword });
      sendSuccess(res, { reset: true }, 'Password has been reset successfully', 200);
    } catch (error) {
      next(error);
    }
  }

  static async me(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = req.user!.userId;
      const profile = await AuthService.getCurrentUser(userId);
      sendSuccess(res, { user: profile }, 'User profile retrieved', 200);
    } catch (error) {
      next(error);
    }
  }
}

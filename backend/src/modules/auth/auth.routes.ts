import { Router } from 'express';
import { AuthController } from './auth.controller';
import { validateRequest } from '../../middleware/validate.middleware';
import { requireAuth } from '../../middleware/auth.middleware';
import {
  forgotPasswordSchema,
  loginSchema,
  logoutSchema,
  refreshSchema,
  registerSchema,
  resetPasswordSchema,
} from './auth.validation';

export const authRouter = Router();

authRouter.post('/register', validateRequest(registerSchema), AuthController.register);
authRouter.post('/login', validateRequest(loginSchema), AuthController.login);
authRouter.post('/refresh', validateRequest(refreshSchema), AuthController.refresh);
authRouter.post('/logout', validateRequest(logoutSchema), AuthController.logout);
authRouter.post(
  '/forgot-password',
  validateRequest(forgotPasswordSchema),
  AuthController.forgotPassword,
);
authRouter.post(
  '/reset-password',
  validateRequest(resetPasswordSchema),
  AuthController.resetPassword,
);
authRouter.get('/me', requireAuth, AuthController.me);

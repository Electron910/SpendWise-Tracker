import { NextFunction, Request, Response } from 'express';
import jwt from 'jsonwebtoken';
import { env } from '../config/env';
import { AppError } from '../utils/appError';

export interface AuthenticatedUser {
  userId: string;
  email: string;
}

declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express {
    interface Request {
      user?: AuthenticatedUser;
    }
  }
}

export function requireAuth(req: Request, _res: Response, next: NextFunction): void {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    next(new AppError('Authentication token is required', 401, 'UNAUTHORIZED'));
    return;
  }

  const token = authHeader.slice(7).trim();
  if (!token) {
    next(new AppError('Authentication token is missing', 401, 'UNAUTHORIZED'));
    return;
  }

  try {
    const decoded = jwt.verify(token, env.JWT_ACCESS_SECRET) as {
      sub: string;
      email: string;
      type?: string;
    };

    if (decoded.type && decoded.type !== 'access') {
      next(new AppError('Invalid token type', 401, 'INVALID_TOKEN_TYPE'));
      return;
    }

    req.user = {
      userId: decoded.sub,
      email: decoded.email,
    };
    next();
  } catch (err) {
    if (err instanceof jwt.TokenExpiredError) {
      next(new AppError('Access token has expired', 401, 'TOKEN_EXPIRED'));
      return;
    }
    next(new AppError('Invalid access token', 401, 'INVALID_TOKEN'));
  }
}

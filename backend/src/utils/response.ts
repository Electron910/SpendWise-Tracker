import { Response } from 'express';
import { serializeBigInt } from './money';

export interface ApiSuccessResponse<T> {
  success: true;
  message: string;
  data: T;
  meta?: Record<string, unknown>;
}

export function sendSuccess<T>(
  res: Response,
  data: T,
  message = 'Success',
  statusCode = 200,
  meta?: Record<string, unknown>,
): Response {
  const payload: ApiSuccessResponse<T> = {
    success: true,
    message,
    data: serializeBigInt(data),
    ...(meta ? { meta: serializeBigInt(meta) } : {}),
  };
  return res.status(statusCode).json(payload);
}

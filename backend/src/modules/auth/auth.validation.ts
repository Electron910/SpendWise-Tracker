import { z } from 'zod';

const passwordRule = z
  .string()
  .min(8, 'Password must be at least 8 characters')
  .max(72, 'Password must not exceed 72 characters')
  .regex(/[A-Z]/, 'Password must contain at least one uppercase letter')
  .regex(/[a-z]/, 'Password must contain at least one lowercase letter')
  .regex(/[0-9]/, 'Password must contain at least one digit');

export const registerSchema = z.object({
  body: z.object({
    email: z.string().trim().email('Valid email address is required').toLowerCase(),
    password: passwordRule,
    fullName: z.string().trim().min(2, 'Full name must be at least 2 characters').max(120),
    currency: z.string().trim().toUpperCase().default('INR'),
  }),
  query: z.object({}).passthrough(),
  params: z.object({}).passthrough(),
});

export const loginSchema = z.object({
  body: z.object({
    email: z.string().trim().email('Valid email address is required').toLowerCase(),
    password: z.string().min(1, 'Password is required'),
    deviceInfo: z.string().max(255).optional(),
  }),
  query: z.object({}).passthrough(),
  params: z.object({}).passthrough(),
});

export const refreshSchema = z.object({
  body: z.object({
    refreshToken: z.string().min(10, 'Refresh token is required'),
    deviceInfo: z.string().max(255).optional(),
  }),
  query: z.object({}).passthrough(),
  params: z.object({}).passthrough(),
});

export const logoutSchema = z.object({
  body: z.object({
    refreshToken: z.string().optional(),
  }),
  query: z.object({}).passthrough(),
  params: z.object({}).passthrough(),
});

export const forgotPasswordSchema = z.object({
  body: z.object({
    email: z.string().trim().email('Valid email address is required').toLowerCase(),
  }),
  query: z.object({}).passthrough(),
  params: z.object({}).passthrough(),
});

export const resetPasswordSchema = z.object({
  body: z.object({
    email: z.string().trim().email('Valid email address is required').toLowerCase(),
    resetToken: z.string().min(6, 'Reset token is required'),
    newPassword: passwordRule,
  }),
  query: z.object({}).passthrough(),
  params: z.object({}).passthrough(),
});

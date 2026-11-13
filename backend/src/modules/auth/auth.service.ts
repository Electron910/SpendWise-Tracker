import crypto from 'crypto';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { v4 as uuidv4 } from 'uuid';
import { prisma } from '../../config/database';
import { env } from '../../config/env';
import { AppError } from '../../utils/appError';
import { DEFAULT_SYSTEM_CATEGORIES } from './defaultCategories';

export interface AuthTokens {
  accessToken: string;
  refreshToken: string;
  expiresIn: string;
}

export interface SafeUserProfile {
  id: string;
  email: string;
  fullName: string;
  currency: string;
  themePreference: string;
  isDemoAccount: boolean;
  notifyBudgetAlerts: boolean;
  notifyRecurringBills: boolean;
  notifyMonthlySummary: boolean;
  notifyUnusualSpending: boolean;
  createdAt: Date;
}

function hashToken(rawToken: string): string {
  return crypto.createHash('sha256').update(rawToken).digest('hex');
}

function toSafeUserProfile(user: {
  id: string;
  email: string;
  fullName: string;
  currency: string;
  themePreference: string;
  isDemoAccount: boolean;
  notifyBudgetAlerts: boolean;
  notifyRecurringBills: boolean;
  notifyMonthlySummary: boolean;
  notifyUnusualSpending: boolean;
  createdAt: Date;
}): SafeUserProfile {
  return {
    id: user.id,
    email: user.email,
    fullName: user.fullName,
    currency: user.currency,
    themePreference: user.themePreference,
    isDemoAccount: user.isDemoAccount,
    notifyBudgetAlerts: user.notifyBudgetAlerts,
    notifyRecurringBills: user.notifyRecurringBills,
    notifyMonthlySummary: user.notifyMonthlySummary,
    notifyUnusualSpending: user.notifyUnusualSpending,
    createdAt: user.createdAt,
  };
}

function signAccessToken(userId: string, email: string): string {
  return jwt.sign(
    {
      sub: userId,
      email,
      type: 'access',
      jti: uuidv4(),
    },
    env.JWT_ACCESS_SECRET,
    {
      expiresIn: env.JWT_ACCESS_EXPIRES_IN as jwt.SignOptions['expiresIn'],
    },
  );
}

function signRefreshToken(userId: string, email: string): string {
  return jwt.sign(
    {
      sub: userId,
      email,
      type: 'refresh',
      jti: uuidv4(),
    },
    env.JWT_REFRESH_SECRET,
    {
      expiresIn: `${env.JWT_REFRESH_EXPIRES_IN_DAYS}d`,
    },
  );
}

export class AuthService {
  static async register(input: {
    email: string;
    password: string;
    fullName: string;
    currency?: string;
    deviceInfo?: string;
  }): Promise<{ user: SafeUserProfile; tokens: AuthTokens }> {
    const normalizedEmail = input.email.trim().toLowerCase();

    const existing = await prisma.user.findUnique({
      where: { email: normalizedEmail },
    });

    if (existing) {
      throw new AppError('An account with this email already exists', 409, 'EMAIL_ALREADY_EXISTS');
    }

    const passwordHash = await bcrypt.hash(input.password, env.BCRYPT_SALT_ROUNDS);
    const refreshToken = signRefreshToken('pending', normalizedEmail);

    const result = await prisma.$transaction(async (tx) => {
      const user = await tx.user.create({
        data: {
          email: normalizedEmail,
          passwordHash,
          fullName: input.fullName.trim(),
          currency: input.currency ?? env.DEFAULT_CURRENCY,
        },
      });

      // Provision default categories for this user
      await tx.category.createMany({
        data: DEFAULT_SYSTEM_CATEGORIES.map((cat) => ({
          userId: user.id,
          name: cat.name,
          type: cat.type,
          icon: cat.icon,
          colorHex: cat.colorHex,
          isSystem: true,
        })),
      });

      const realRefreshToken = signRefreshToken(user.id, user.email);
      const tokenHash = hashToken(realRefreshToken);
      const expiresAt = new Date(
        Date.now() + env.JWT_REFRESH_EXPIRES_IN_DAYS * 24 * 60 * 60 * 1000,
      );

      await tx.refreshToken.create({
        data: {
          userId: user.id,
          tokenHash,
          deviceInfo: input.deviceInfo ?? 'SpendWise Mobile',
          expiresAt,
        },
      });

      const accessToken = signAccessToken(user.id, user.email);

      return {
        user: toSafeUserProfile(user),
        tokens: {
          accessToken,
          refreshToken: realRefreshToken,
          expiresIn: env.JWT_ACCESS_EXPIRES_IN,
        },
      };
    });

    void refreshToken;
    return result;
  }

  static async login(input: {
    email: string;
    password: string;
    deviceInfo?: string;
  }): Promise<{ user: SafeUserProfile; tokens: AuthTokens }> {
    const normalizedEmail = input.email.trim().toLowerCase();

    const user = await prisma.user.findUnique({
      where: { email: normalizedEmail },
    });

    if (!user) {
      throw new AppError('Invalid email or password', 401, 'INVALID_CREDENTIALS');
    }

    const passwordValid = await bcrypt.compare(input.password, user.passwordHash);
    if (!passwordValid) {
      throw new AppError('Invalid email or password', 401, 'INVALID_CREDENTIALS');
    }

    const accessToken = signAccessToken(user.id, user.email);
    const refreshToken = signRefreshToken(user.id, user.email);
    const tokenHash = hashToken(refreshToken);
    const expiresAt = new Date(Date.now() + env.JWT_REFRESH_EXPIRES_IN_DAYS * 24 * 60 * 60 * 1000);

    await prisma.refreshToken.create({
      data: {
        userId: user.id,
        tokenHash,
        deviceInfo: input.deviceInfo ?? 'SpendWise Mobile',
        expiresAt,
      },
    });

    return {
      user: toSafeUserProfile(user),
      tokens: {
        accessToken,
        refreshToken,
        expiresIn: env.JWT_ACCESS_EXPIRES_IN,
      },
    };
  }

  static async refreshTokens(input: {
    refreshToken: string;
    deviceInfo?: string;
  }): Promise<{ user: SafeUserProfile; tokens: AuthTokens }> {
    let decoded: { sub: string; email: string; type?: string };
    try {
      decoded = jwt.verify(input.refreshToken, env.JWT_REFRESH_SECRET) as {
        sub: string;
        email: string;
        type?: string;
      };
    } catch {
      throw new AppError('Invalid or expired refresh token', 401, 'INVALID_REFRESH_TOKEN');
    }

    if (decoded.type && decoded.type !== 'refresh') {
      throw new AppError('Invalid token type for refresh', 401, 'INVALID_TOKEN_TYPE');
    }

    const incomingHash = hashToken(input.refreshToken);

    const storedToken = await prisma.refreshToken.findUnique({
      where: { tokenHash: incomingHash },
      include: { user: true },
    });

    if (!storedToken) {
      throw new AppError('Refresh token not recognized', 401, 'REFRESH_TOKEN_NOT_FOUND');
    }

    if (storedToken.revokedAt || storedToken.expiresAt < new Date()) {
      // Revoke all active tokens for user if reuse of revoked token is detected
      if (storedToken.revokedAt) {
        await prisma.refreshToken.updateMany({
          where: { userId: storedToken.userId, revokedAt: null },
          data: { revokedAt: new Date() },
        });
      }
      throw new AppError('Refresh token has been revoked or expired', 401, 'REFRESH_TOKEN_REVOKED');
    }

    const newAccessToken = signAccessToken(storedToken.user.id, storedToken.user.email);
    const newRefreshToken = signRefreshToken(storedToken.user.id, storedToken.user.email);
    const newRefreshHash = hashToken(newRefreshToken);
    const expiresAt = new Date(Date.now() + env.JWT_REFRESH_EXPIRES_IN_DAYS * 24 * 60 * 60 * 1000);

    await prisma.$transaction([
      prisma.refreshToken.update({
        where: { id: storedToken.id },
        data: {
          revokedAt: new Date(),
          replacedByToken: newRefreshHash,
        },
      }),
      prisma.refreshToken.create({
        data: {
          userId: storedToken.user.id,
          tokenHash: newRefreshHash,
          deviceInfo: input.deviceInfo ?? storedToken.deviceInfo ?? 'SpendWise Mobile',
          expiresAt,
        },
      }),
    ]);

    return {
      user: toSafeUserProfile(storedToken.user),
      tokens: {
        accessToken: newAccessToken,
        refreshToken: newRefreshToken,
        expiresIn: env.JWT_ACCESS_EXPIRES_IN,
      },
    };
  }

  static async logout(input: { userId?: string; refreshToken?: string }): Promise<void> {
    if (input.refreshToken) {
      const tokenHash = hashToken(input.refreshToken);
      await prisma.refreshToken.updateMany({
        where: { tokenHash, revokedAt: null },
        data: { revokedAt: new Date() },
      });
    } else if (input.userId) {
      await prisma.refreshToken.updateMany({
        where: { userId: input.userId, revokedAt: null },
        data: { revokedAt: new Date() },
      });
    }
  }

  static async forgotPassword(email: string): Promise<{
    message: string;
    resetCodeForDemoOnly?: string;
    expiresInMinutes: number;
  }> {
    const normalizedEmail = email.trim().toLowerCase();
    const user = await prisma.user.findUnique({
      where: { email: normalizedEmail },
    });

    // Always return success message to prevent email enumeration
    if (!user) {
      return {
        message: 'If an account with that email exists, a password reset code has been generated.',
        expiresInMinutes: 15,
      };
    }

    // Generate 6-digit numeric reset token for easy entry in mobile flow
    const resetCode = crypto.randomInt(100000, 999999).toString();
    const resetTokenHash = hashToken(resetCode);
    const expiresAt = new Date(Date.now() + 15 * 60 * 1000);

    await prisma.user.update({
      where: { id: user.id },
      data: {
        passwordResetTokenHash: resetTokenHash,
        passwordResetExpiresAt: expiresAt,
      },
    });

    return {
      message: 'If an account with that email exists, a password reset code has been generated.',
      // Returned in non-production environments to allow self-contained portfolio testing without SMTP server
      ...(env.NODE_ENV !== 'production' ? { resetCodeForDemoOnly: resetCode } : {}),
      expiresInMinutes: 15,
    };
  }

  static async resetPassword(input: {
    email: string;
    resetToken: string;
    newPassword: string;
  }): Promise<void> {
    const normalizedEmail = input.email.trim().toLowerCase();
    const user = await prisma.user.findUnique({
      where: { email: normalizedEmail },
    });

    if (
      !user ||
      !user.passwordResetTokenHash ||
      !user.passwordResetExpiresAt ||
      user.passwordResetExpiresAt < new Date()
    ) {
      throw new AppError('Invalid or expired password reset code', 400, 'INVALID_RESET_TOKEN');
    }

    const candidateHash = hashToken(input.resetToken.trim());
    if (candidateHash !== user.passwordResetTokenHash) {
      throw new AppError('Invalid or expired password reset code', 400, 'INVALID_RESET_TOKEN');
    }

    const newPasswordHash = await bcrypt.hash(input.newPassword, env.BCRYPT_SALT_ROUNDS);

    await prisma.$transaction([
      prisma.user.update({
        where: { id: user.id },
        data: {
          passwordHash: newPasswordHash,
          passwordResetTokenHash: null,
          passwordResetExpiresAt: null,
        },
      }),
      // Revoke all existing refresh tokens on password change
      prisma.refreshToken.updateMany({
        where: { userId: user.id, revokedAt: null },
        data: { revokedAt: new Date() },
      }),
    ]);
  }

  static async getCurrentUser(userId: string): Promise<SafeUserProfile> {
    const user = await prisma.user.findUnique({
      where: { id: userId },
    });
    if (!user) {
      throw new AppError('User account not found', 404, 'USER_NOT_FOUND');
    }
    return toSafeUserProfile(user);
  }
}

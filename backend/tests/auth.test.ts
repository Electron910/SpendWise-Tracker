import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import request from 'supertest';
import { app } from '../src/app';
import { prisma } from '../src/config/database';
import {
  calculateUtilizationPercentage,
  formatPaiseToDecimalString,
  parseDecimalRupeesToPaise,
} from '../src/utils/money';

const TEST_EMAIL = `auth.test.${Date.now()}@spendwise.app`;
const TEST_PASSWORD = 'Password123';

describe('Financial Paise Precision Utilities', () => {
  it('converts decimal rupee strings to exact BigInt paise without floating-point drift', () => {
    expect(parseDecimalRupeesToPaise('125.50')).toBe(12550n);
    expect(parseDecimalRupeesToPaise('0.01')).toBe(1n);
    expect(parseDecimalRupeesToPaise('99999999.99')).toBe(9999999999n);
    expect(formatPaiseToDecimalString(12550n)).toBe('125.50');
    expect(formatPaiseToDecimalString(1n)).toBe('0.01');
  });

  it('rejects zero, negative, or malformed monetary strings', () => {
    expect(() => parseDecimalRupeesToPaise('0')).toThrow();
    expect(() => parseDecimalRupeesToPaise('-10.00')).toThrow();
    expect(() => parseDecimalRupeesToPaise('12.345')).toThrow();
  });

  it('calculates integer budget utilization percentages accurately', () => {
    const { percentage, basisPoints } = calculateUtilizationPercentage(375000n, 500000n);
    expect(percentage).toBe(75);
    expect(basisPoints).toBe(7500);
  });
});

describe('Authentication API (/api/v1/auth)', () => {
  let accessToken = '';
  let refreshToken = '';

  beforeAll(async () => {
    await prisma.user.deleteMany({
      where: { email: TEST_EMAIL },
    });
  });

  afterAll(async () => {
    await prisma.user.deleteMany({
      where: { email: TEST_EMAIL },
    });
    await prisma.$disconnect();
  });

  it('registers a new user and provisions 18 default categories', async () => {
    const res = await request(app).post('/api/v1/auth/register').send({
      email: TEST_EMAIL,
      password: TEST_PASSWORD,
      fullName: 'Rohan Verma',
      currency: 'INR',
    });

    expect(res.status).toBe(201);
    expect(res.body.success).toBe(true);
    expect(res.body.data.user.email).toBe(TEST_EMAIL);
    expect(res.body.data.tokens.accessToken).toBeDefined();
    expect(res.body.data.tokens.refreshToken).toBeDefined();

    accessToken = res.body.data.tokens.accessToken;
    refreshToken = res.body.data.tokens.refreshToken;

    const categoryCount = await prisma.category.count({
      where: { userId: res.body.data.user.id },
    });
    expect(categoryCount).toBe(18);
  });

  it('rejects duplicate registration with 409 EMAIL_ALREADY_EXISTS', async () => {
    const res = await request(app).post('/api/v1/auth/register').send({
      email: TEST_EMAIL,
      password: TEST_PASSWORD,
      fullName: 'Rohan Verma',
    });

    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('EMAIL_ALREADY_EXISTS');
  });

  it('authenticates user on login and returns JWT tokens', async () => {
    const res = await request(app).post('/api/v1/auth/login').send({
      email: TEST_EMAIL,
      password: TEST_PASSWORD,
    });

    expect(res.status).toBe(200);
    expect(res.body.data.tokens.accessToken).toBeDefined();
    accessToken = res.body.data.tokens.accessToken;
    refreshToken = res.body.data.tokens.refreshToken;
  });

  it('rejects invalid password with 401 INVALID_CREDENTIALS', async () => {
    const res = await request(app).post('/api/v1/auth/login').send({
      email: TEST_EMAIL,
      password: 'WrongPassword999',
    });

    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('INVALID_CREDENTIALS');
  });

  it('returns current user profile on protected /me endpoint', async () => {
    const res = await request(app)
      .get('/api/v1/auth/me')
      .set('Authorization', `Bearer ${accessToken}`);

    expect(res.status).toBe(200);
    expect(res.body.data.user.email).toBe(TEST_EMAIL);
  });

  it('rotates refresh token and invalidates the old refresh token', async () => {
    const oldRefresh = refreshToken;
    const res = await request(app).post('/api/v1/auth/refresh').send({
      refreshToken: oldRefresh,
    });

    expect(res.status).toBe(200);
    expect(res.body.data.tokens.refreshToken).not.toBe(oldRefresh);
    refreshToken = res.body.data.tokens.refreshToken;

    // Attempting to reuse old refresh token must fail
    const replayRes = await request(app).post('/api/v1/auth/refresh').send({
      refreshToken: oldRefresh,
    });
    expect(replayRes.status).toBe(401);
  });

  it('supports forgot-password and reset-password flow', async () => {
    const forgotRes = await request(app).post('/api/v1/auth/forgot-password').send({
      email: TEST_EMAIL,
    });

    expect(forgotRes.status).toBe(200);
    const resetCode = forgotRes.body.data.resetCodeForDemoOnly;
    expect(resetCode).toBeDefined();

    const newPassword = 'NewPassword456';
    const resetRes = await request(app).post('/api/v1/auth/reset-password').send({
      email: TEST_EMAIL,
      resetToken: resetCode,
      newPassword,
    });
    expect(resetRes.status).toBe(200);

    // Login with new password succeeds
    const loginRes = await request(app).post('/api/v1/auth/login').send({
      email: TEST_EMAIL,
      password: newPassword,
    });
    expect(loginRes.status).toBe(200);
  });
});

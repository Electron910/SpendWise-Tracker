import { RecurrenceFrequency } from '@prisma/client';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import request from 'supertest';
import { app } from '../src/app';
import { prisma } from '../src/config/database';
import { RecurringService } from '../src/modules/recurring/recurring.service';

const TEST_EMAIL = `recurring.${Date.now()}@spendwise.app`;
const PASSWORD = 'Password123';

describe('Recurring Expenses Engine & API (/api/v1/recurring)', () => {
  let token = '';
  let rentCatId = '';
  let subCatId = '';
  let recurringId = '';

  beforeAll(async () => {
    await prisma.user.deleteMany({ where: { email: TEST_EMAIL } });
    const reg = await request(app).post('/api/v1/auth/register').send({
      email: TEST_EMAIL,
      password: PASSWORD,
      fullName: 'Recurring User',
    });
    token = reg.body.data.tokens.accessToken;

    const catRes = await request(app)
      .get('/api/v1/categories')
      .set('Authorization', `Bearer ${token}`);
    const categories = catRes.body.data.categories as Array<{
      id: string;
      name: string;
      type: string;
    }>;
    rentCatId = categories.find((c) => c.name === 'Rent' && c.type === 'EXPENSE')!.id;
    subCatId = categories.find(
      (c) => c.name === 'Subscriptions' && c.type === 'EXPENSE',
    )!.id;
  });

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { email: TEST_EMAIL } });
    await prisma.$disconnect();
  });

  it('safely clamps month-end dates and leap years in computeNextOccurrence', () => {
    const jan31NonLeap = new Date('2026-01-31T10:00:00.000Z');
    const febNext = RecurringService.computeNextOccurrence(
      jan31NonLeap,
      RecurrenceFrequency.MONTHLY,
      1,
      31,
    );
    expect(febNext.toISOString().slice(0, 10)).toBe('2026-02-28');

    const marNext = RecurringService.computeNextOccurrence(
      febNext,
      RecurrenceFrequency.MONTHLY,
      1,
      31,
    );
    expect(marNext.toISOString().slice(0, 10)).toBe('2026-03-31');

    const leapFeb29 = new Date('2024-02-29T10:00:00.000Z');
    const nextYear = RecurringService.computeNextOccurrence(
      leapFeb29,
      RecurrenceFrequency.YEARLY,
      1,
      29,
    );
    expect(nextYear.toISOString().slice(0, 10)).toBe('2025-02-28');
  });

  it('creates a recurring subscription and idempotently generates due transactions without duplicates', async () => {
    const createRes = await request(app)
      .post('/api/v1/recurring')
      .set('Authorization', `Bearer ${token}`)
      .send({
        categoryId: subCatId,
        type: 'EXPENSE',
        title: 'Netflix Ultra HD',
        merchant: 'Netflix',
        description: 'Monthly Streaming Plan',
        amountPaise: 64900, // ₹649.00
        paymentMethod: 'CREDIT_CARD',
        frequency: 'MONTHLY',
        intervalCount: 1,
        startDate: '2026-10-01T08:00:00.000Z',
        reminderDays: 3,
      });

    expect(createRes.status).toBe(201);
    recurringId = createRes.body.data.recurringExpense.id;
    expect(createRes.body.data.recurringExpense.amountPaise).toBe('64900');

    // Process due occurrences up to 2026-11-05 (should generate Oct 1 and Nov 1 = 2 transactions)
    const firstProcess = await request(app)
      .post('/api/v1/recurring/process-due')
      .set('Authorization', `Bearer ${token}`)
      .send({ asOfDate: '2026-11-05T12:00:00.000Z' });

    expect(firstProcess.status).toBe(200);
    expect(firstProcess.body.data.generatedCount).toBe(2);

    // Re-running process-due for the same date must generate 0 duplicates
    const secondProcess = await request(app)
      .post('/api/v1/recurring/process-due')
      .set('Authorization', `Bearer ${token}`)
      .send({ asOfDate: '2026-11-05T12:00:00.000Z' });

    expect(secondProcess.status).toBe(200);
    expect(secondProcess.body.data.generatedCount).toBe(0);

    // Verify history and nextOccurrence (should now be 2026-12-01)
    const listRes = await request(app)
      .get('/api/v1/recurring')
      .set('Authorization', `Bearer ${token}`);
    expect(listRes.status).toBe(200);
    const list = listRes.body.data.recurringExpenses as Array<{
      id: string;
      nextOccurrence: string;
      history: Array<{ id: string }>;
    }>;
    const item = list.find((r) => r.id === recurringId)!;
    expect(item.nextOccurrence.slice(0, 10)).toBe('2026-12-01');
    expect(item.history.length).toBe(2);
  });

  it('toggles active status and soft-deletes recurring schedule', async () => {
    const patchRes = await request(app)
      .patch(`/api/v1/recurring/${recurringId}`)
      .set('Authorization', `Bearer ${token}`)
      .send({ isActive: false, categoryId: rentCatId });

    expect(patchRes.status).toBe(200);
    expect(patchRes.body.data.recurringExpense.isActive).toBe(false);

    const delRes = await request(app)
      .delete(`/api/v1/recurring/${recurringId}`)
      .set('Authorization', `Bearer ${token}`);
    expect(delRes.status).toBe(200);
  });
});

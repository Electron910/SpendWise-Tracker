import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import request from 'supertest';
import { app } from '../src/app';
import { prisma } from '../src/config/database';

const TEST_EMAIL = `cat.engine.${Date.now()}@spendwise.app`;
const PASSWORD = 'Password123';

describe('Deterministic Expense Categorization Engine (/api/v1/categorization)', () => {
  let token = '';
  let categories: Array<{ id: string; name: string; type: string }> = [];

  beforeAll(async () => {
    await prisma.user.deleteMany({ where: { email: TEST_EMAIL } });
    const reg = await request(app).post('/api/v1/auth/register').send({
      email: TEST_EMAIL,
      password: PASSWORD,
      fullName: 'Categorizer Tester',
    });
    token = reg.body.data.tokens.accessToken;

    const catRes = await request(app)
      .get('/api/v1/categories')
      .set('Authorization', `Bearer ${token}`);
    categories = catRes.body.data.categories;
  });

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { email: TEST_EMAIL } });
    await prisma.$disconnect();
  });

  it('classifies SWIGGY, UBER, NETFLIX, and AMAZON deterministically with high confidence', async () => {
    const cases = [
      { merchant: 'Swiggy Instamart/Food', description: 'SWIGGY order #992', expected: 'Food' },
      { merchant: 'UBER INDIA', description: 'Airport cab', expected: 'Transportation' },
      { merchant: 'Netflix.com', description: 'Monthly plan', expected: 'Subscriptions' },
      { merchant: 'Amazon Pay', description: 'USB-C hub', expected: 'Shopping' },
    ];

    for (const tc of cases) {
      const res = await request(app)
        .post('/api/v1/categorization/classify')
        .set('Authorization', `Bearer ${token}`)
        .send({
          merchant: tc.merchant,
          description: tc.description,
          type: 'EXPENSE',
        });

      expect(res.status).toBe(200);
      expect(res.body.data.classification.matched).toBe(true);
      expect(res.body.data.classification.categoryName).toBe(tc.expected);
      expect(res.body.data.classification.confidence).toBeGreaterThanOrEqual(90);
    }
  });

  it('auto-categorizes a transaction when categoryId is omitted on creation', async () => {
    const res = await request(app)
      .post('/api/v1/transactions')
      .set('Authorization', `Bearer ${token}`)
      .send({
        type: 'EXPENSE',
        amountPaise: 32000,
        merchant: 'Uber Trip',
        description: 'Morning commute to office',
        paymentMethod: 'UPI',
        transactionDate: '2026-11-11T09:00:00.000Z',
      });

    expect(res.status).toBe(201);
    expect(res.body.data.transaction.category.name).toBe('Transportation');
    expect(res.body.data.transaction.isAutoCategorized).toBe(true);
    expect(res.body.data.transaction.categorizationConfidence).toBeGreaterThanOrEqual(90);
  });

  it('learns from user category correction and prioritizes user preference on subsequent classifications', async () => {
    // Initially "Amazon Fresh Store" matches AMAZON -> Shopping
    const initialTx = await request(app)
      .post('/api/v1/transactions')
      .set('Authorization', `Bearer ${token}`)
      .send({
        type: 'EXPENSE',
        amountPaise: 85000,
        merchant: 'Amazon Pantry Fresh',
        description: 'Vegetables and milk',
        paymentMethod: 'UPI',
        transactionDate: '2026-11-11T11:00:00.000Z',
      });

    expect(initialTx.status).toBe(201);
    expect(initialTx.body.data.transaction.category.name).toBe('Shopping');

    const groceriesCat = categories.find((c) => c.name === 'Groceries' && c.type === 'EXPENSE')!;

    // User corrects category of "Amazon Pantry Fresh" to Groceries
    const updateRes = await request(app)
      .patch(`/api/v1/transactions/${initialTx.body.data.transaction.id}`)
      .set('Authorization', `Bearer ${token}`)
      .send({
        categoryId: groceriesCat.id,
        rememberCategoryCorrection: true,
      });
    expect(updateRes.status).toBe(200);
    expect(updateRes.body.data.transaction.category.name).toBe('Groceries');

    // Now classifying "Amazon Pantry Fresh" must return Groceries with USER_CORRECTION source
    const classifyAfter = await request(app)
      .post('/api/v1/categorization/classify')
      .set('Authorization', `Bearer ${token}`)
      .send({
        merchant: 'Amazon Pantry Fresh',
        description: 'Weekly fruits',
        type: 'EXPENSE',
      });

    expect(classifyAfter.status).toBe(200);
    expect(classifyAfter.body.data.classification.categoryName).toBe('Groceries');
    expect(classifyAfter.body.data.classification.source).toBe('USER_CORRECTION');
    expect(classifyAfter.body.data.classification.confidence).toBe(99);
  });
});

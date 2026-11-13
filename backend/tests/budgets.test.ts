import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import request from 'supertest';
import { app } from '../src/app';
import { prisma } from '../src/config/database';

const TEST_EMAIL = `budgets.${Date.now()}@spendwise.app`;
const PASSWORD = 'Password123';

describe('Budgets Management API (/api/v1/budgets)', () => {
  let token = '';
  let foodCatId = '';
  let shoppingCatId = '';
  let salaryCatId = '';
  let foodBudgetId = '';

  beforeAll(async () => {
    await prisma.user.deleteMany({ where: { email: TEST_EMAIL } });
    const reg = await request(app).post('/api/v1/auth/register').send({
      email: TEST_EMAIL,
      password: PASSWORD,
      fullName: 'Budget Tester',
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

    foodCatId = categories.find((c) => c.name === 'Food' && c.type === 'EXPENSE')!.id;
    shoppingCatId = categories.find((c) => c.name === 'Shopping' && c.type === 'EXPENSE')!.id;
    salaryCatId = categories.find((c) => c.name === 'Salary' && c.type === 'INCOME')!.id;
  });

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { email: TEST_EMAIL } });
    await prisma.$disconnect();
  });

  it('creates overall and category budgets and rejects INCOME category budgets', async () => {
    // Overall monthly budget: ₹20,000 (2,000,000 paise)
    const overallRes = await request(app)
      .post('/api/v1/budgets')
      .set('Authorization', `Bearer ${token}`)
      .send({
        categoryId: null,
        month: 11,
        year: 2026,
        amountPaise: 2000000,
      });
    expect(overallRes.status).toBe(201);

    // Food budget: ₹5,000 (500,000 paise)
    const foodRes = await request(app)
      .post('/api/v1/budgets')
      .set('Authorization', `Bearer ${token}`)
      .send({
        categoryId: foodCatId,
        month: 11,
        year: 2026,
        amountPaise: 500000,
        alertThresholds: [50, 75, 90, 100],
      });
    expect(foodRes.status).toBe(201);
    foodBudgetId = foodRes.body.data.budget.id;

    // Shopping budget: ₹3,000 (300,000 paise)
    const shopRes = await request(app)
      .post('/api/v1/budgets')
      .set('Authorization', `Bearer ${token}`)
      .send({
        categoryId: shoppingCatId,
        month: 11,
        year: 2026,
        amountPaise: 300000,
      });
    expect(shopRes.status).toBe(201);

    // Reject INCOME category budget
    const incomeBudgetRes = await request(app)
      .post('/api/v1/budgets')
      .set('Authorization', `Bearer ${token}`)
      .send({
        categoryId: salaryCatId,
        month: 11,
        year: 2026,
        amountPaise: 500000,
      });
    expect(incomeBudgetRes.status).toBe(400);
    expect(incomeBudgetRes.body.error.code).toBe('INVALID_BUDGET_CATEGORY_TYPE');
  });

  it('evaluates 50%, 75%, 90%, and 100% alert thresholds and MoM comparison accurately when transactions change', async () => {
    // Previous month (Oct 2026) Food expense: ₹4,000 (400,000 paise)
    await request(app)
      .post('/api/v1/transactions')
      .set('Authorization', `Bearer ${token}`)
      .send({
        categoryId: foodCatId,
        type: 'EXPENSE',
        amountPaise: 400000,
        description: 'Oct Food',
        transactionDate: '2026-10-15T12:00:00.000Z',
      });

    // Current month (Nov 2026) Food expense: ₹4,500 (450,000 paise -> 90% of ₹5,000 budget)
    const txRes = await request(app)
      .post('/api/v1/transactions')
      .set('Authorization', `Bearer ${token}`)
      .send({
        categoryId: foodCatId,
        type: 'EXPENSE',
        amountPaise: 450000,
        description: 'Nov Food',
        transactionDate: '2026-11-10T12:00:00.000Z',
      });
    const novTxId = txRes.body.data.transaction.id;

    const listRes = await request(app)
      .get('/api/v1/budgets?month=11&year=2026')
      .set('Authorization', `Bearer ${token}`);
    expect(listRes.status).toBe(200);

    const foodEval = listRes.body.data.categoryBudgets.find(
      (b: { categoryId: string }) => b.categoryId === foodCatId,
    );
    expect(foodEval.utilizationPercentage).toBe(90);
    expect(foodEval.alertLevel).toBe('CRITICAL');
    expect(foodEval.reachedThresholds).toEqual([50, 75, 90]);
    expect(foodEval.highestReachedThreshold).toBe(90);
    expect(foodEval.monthOverMonthChangePercentage).toBe(12); // (4500 - 4000) / 4000 = +12%

    // Edit transaction to ₹5,200 (520,000 paise -> 104% EXCEEDED)
    await request(app)
      .patch(`/api/v1/transactions/${novTxId}`)
      .set('Authorization', `Bearer ${token}`)
      .send({ amountPaise: 520000 });

    const afterEditRes = await request(app)
      .get('/api/v1/budgets?month=11&year=2026')
      .set('Authorization', `Bearer ${token}`);
    const foodAfterEdit = afterEditRes.body.data.categoryBudgets.find(
      (b: { categoryId: string }) => b.categoryId === foodCatId,
    );
    expect(foodAfterEdit.utilizationPercentage).toBe(104);
    expect(foodAfterEdit.alertLevel).toBe('EXCEEDED');
    expect(foodAfterEdit.reachedThresholds).toEqual([50, 75, 90, 100]);

    // Delete transaction -> utilization drops back to 0%
    await request(app)
      .delete(`/api/v1/transactions/${novTxId}`)
      .set('Authorization', `Bearer ${token}`);

    const afterDeleteRes = await request(app)
      .get('/api/v1/budgets?month=11&year=2026')
      .set('Authorization', `Bearer ${token}`);
    const foodAfterDelete = afterDeleteRes.body.data.categoryBudgets.find(
      (b: { categoryId: string }) => b.categoryId === foodCatId,
    );
    expect(foodAfterDelete.utilizationPercentage).toBe(0);
    expect(foodAfterDelete.alertLevel).toBe('SAFE');

    // Update and delete budget
    const patchRes = await request(app)
      .patch(`/api/v1/budgets/${foodBudgetId}`)
      .set('Authorization', `Bearer ${token}`)
      .send({ amountPaise: 600000 });
    expect(patchRes.status).toBe(200);

    const delBudgetRes = await request(app)
      .delete(`/api/v1/budgets/${foodBudgetId}`)
      .set('Authorization', `Bearer ${token}`);
    expect(delBudgetRes.status).toBe(200);
  });
});

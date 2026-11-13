import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import request from 'supertest';
import { app } from '../src/app';
import { prisma } from '../src/config/database';

const TEST_EMAIL = `dashboard.${Date.now()}@spendwise.app`;
const PASSWORD = 'Password123';

describe('Dashboard Overview API (/api/v1/analytics/overview)', () => {
  let token = '';
  let userId = '';
  let foodCatId = '';
  let salaryCatId = '';

  beforeAll(async () => {
    await prisma.user.deleteMany({ where: { email: TEST_EMAIL } });
    const reg = await request(app).post('/api/v1/auth/register').send({
      email: TEST_EMAIL,
      password: PASSWORD,
      fullName: 'Dashboard User',
    });
    token = reg.body.data.tokens.accessToken;
    userId = reg.body.data.user.id;

    const catRes = await request(app)
      .get('/api/v1/categories')
      .set('Authorization', `Bearer ${token}`);
    const categories = catRes.body.data.categories as Array<{
      id: string;
      name: string;
      type: string;
    }>;
    foodCatId = categories.find((c) => c.name === 'Food' && c.type === 'EXPENSE')!.id;
    salaryCatId = categories.find((c) => c.name === 'Salary' && c.type === 'INCOME')!.id;

    // Seed November 2026 income (₹80,000 = 8,000,000 paise) and Food expense (₹4,000 = 400,000 paise)
    await request(app)
      .post('/api/v1/transactions')
      .set('Authorization', `Bearer ${token}`)
      .send({
        categoryId: salaryCatId,
        type: 'INCOME',
        amountPaise: 8000000,
        description: 'Nov Salary',
        transactionDate: '2026-11-01T10:00:00.000Z',
      });

    await request(app)
      .post('/api/v1/transactions')
      .set('Authorization', `Bearer ${token}`)
      .send({
        categoryId: foodCatId,
        type: 'EXPENSE',
        amountPaise: 400000,
        merchant: 'Swiggy',
        description: 'Nov Dining',
        transactionDate: '2026-11-05T19:00:00.000Z',
      });

    // Seed overall budget (₹40,000 = 4,000,000 paise) and Food budget (₹5,000 = 500,000 paise)
    await prisma.budget.createMany({
      data: [
        {
          userId,
          categoryId: null,
          month: 11,
          year: 2026,
          amountPaise: 4000000n,
        },
        {
          userId,
          categoryId: foodCatId,
          month: 11,
          year: 2026,
          amountPaise: 500000n,
        },
      ],
    });
  });

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { email: TEST_EMAIL } });
    await prisma.$disconnect();
  });

  it('computes accurate monthly income, expenses, savings rate, remaining budget, and category breakdown', async () => {
    const res = await request(app)
      .get('/api/v1/analytics/overview?month=11&year=2026')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    const { summary, categoryBreakdown, budgetUtilization, recentTransactions } = res.body.data;

    expect(summary.totalIncomePaise).toBe('8000000');
    expect(summary.totalExpensePaise).toBe('400000');
    expect(summary.currentSavingsPaise).toBe('7600000');
    expect(summary.savingsRatePercentage).toBe(95);
    expect(summary.overallBudgetPaise).toBe('4000000');
    expect(summary.remainingBudgetPaise).toBe('3600000');
    expect(summary.budgetUtilizationPercentage).toBe(10);

    expect(categoryBreakdown.length).toBe(1);
    expect(categoryBreakdown[0].categoryName).toBe('Food');
    expect(categoryBreakdown[0].percentage).toBe(100);

    expect(budgetUtilization.length).toBe(1);
    expect(budgetUtilization[0].utilizationPercentage).toBe(80);
    expect(budgetUtilization[0].alertLevel).toBe('WARNING'); // >= 75%

    expect(recentTransactions.length).toBe(2);
  });

  it('returns monthly comparison, category distribution, and spending trends across date ranges', async () => {
    const monthlyRes = await request(app)
      .get('/api/v1/analytics/monthly?months=6')
      .set('Authorization', `Bearer ${token}`);
    expect(monthlyRes.status).toBe(200);
    expect(monthlyRes.body.data.series.length).toBe(6);

    const catRes = await request(app)
      .get('/api/v1/analytics/categories?period=CUSTOM&startDate=2026-11-01T00:00:00.000Z&endDate=2026-11-30T23:59:59.000Z')
      .set('Authorization', `Bearer ${token}`);
    expect(catRes.status).toBe(200);
    expect(catRes.body.data.totalExpensePaise).toBe('400000');
    expect(catRes.body.data.categories[0].categoryName).toBe('Food');

    const trendsRes = await request(app)
      .get('/api/v1/analytics/trends?period=CUSTOM&startDate=2026-11-01T00:00:00.000Z&endDate=2026-11-30T23:59:59.000Z')
      .set('Authorization', `Bearer ${token}`);
    expect(trendsRes.status).toBe(200);
    const { summary } = trendsRes.body.data;
    expect(summary.totalIncomePaise).toBe('8000000');
    expect(summary.totalExpensePaise).toBe('400000');
    expect(summary.netSavingsPaise).toBe('7600000');
    expect(summary.highestSpendingCategory.categoryName).toBe('Food');
    expect(summary.biggestExpense.description).toBe('Nov Dining');
  });
});

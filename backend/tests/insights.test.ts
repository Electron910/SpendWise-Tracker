import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import request from 'supertest';
import { app } from '../src/app';
import { prisma } from '../src/config/database';
import { computeDeterministicInsights } from '../src/modules/insights/insights.engine';

const TEST_EMAIL = `insights.${Date.now()}@spendwise.app`;
const PASSWORD = 'Password123';

describe('Deterministic Financial Insights Engine & API (/api/v1/insights)', () => {
  let token = '';
  let userId = '';
  let foodCatId = '';
  let shoppingCatId = '';

  beforeAll(async () => {
    await prisma.user.deleteMany({ where: { email: TEST_EMAIL } });
    const reg = await request(app).post('/api/v1/auth/register').send({
      email: TEST_EMAIL,
      password: PASSWORD,
      fullName: 'Insights User',
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
    shoppingCatId = categories.find(
      (c) => c.name === 'Shopping' && c.type === 'EXPENSE',
    )!.id;

    // Seed Oct 2026 Food expense (₹4,000 = 400,000 paise) and Nov 2026 Food expense (₹4,720 = 472,000 paise -> +18%)
    await prisma.transaction.createMany({
      data: [
        {
          userId,
          categoryId: foodCatId,
          type: 'EXPENSE',
          amountPaise: 400000n,
          description: 'Oct Groceries & Dining',
          transactionDate: new Date('2026-10-15T12:00:00.000Z'),
        },
        {
          userId,
          categoryId: foodCatId,
          type: 'EXPENSE',
          amountPaise: 472000n,
          description: 'Nov Dining Out',
          transactionDate: new Date('2026-11-10T12:00:00.000Z'),
        },
        {
          userId,
          categoryId: shoppingCatId,
          type: 'EXPENSE',
          amountPaise: 255000n, // 85% of ₹3,000 shopping budget
          description: 'Winter Jacket',
          transactionDate: new Date('2026-11-12T12:00:00.000Z'),
        },
      ],
    });

    await prisma.budget.create({
      data: {
        userId,
        categoryId: shoppingCatId,
        month: 11,
        year: 2026,
        amountPaise: 300000n, // ₹3,000
      },
    });
  });

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { email: TEST_EMAIL } });
    await prisma.$disconnect();
  });

  it('handles insufficient historical data gracefully without fabricated claims', () => {
    const emptyInsights = computeDeterministicInsights({
      month: 11,
      year: 2026,
      elapsedDaysInPeriod: 10,
      totalPeriodTransactionCount: 0,
      totalCurrentExpensePaise: 0n,
      currentMonthCategories: [],
      previousMonthCategories: [],
      previousThreeMonthsCategories: [],
      distinctHistoricalMonthsCount: 0,
      budgets: [],
      monthlySubscriptionRecurringPaise: 0n,
      subscriptionCount: 0,
    });

    expect(emptyInsights.length).toBe(1);
    expect(emptyInsights[0].type).toBe('INSUFFICIENT_DATA');
  });

  it('computes 3-month rolling average, subscription burden, and daily average deterministically', () => {
    const insights = computeDeterministicInsights({
      month: 11,
      year: 2026,
      elapsedDaysInPeriod: 10,
      totalPeriodTransactionCount: 4,
      totalCurrentExpensePaise: 450000n, // ₹4,500 across 10 days -> ₹450/day
      currentMonthCategories: [
        { categoryId: 'c1', categoryName: 'Transportation', amountPaise: 300000n },
      ],
      previousMonthCategories: [],
      previousThreeMonthsCategories: [
        { categoryId: 'c1', categoryName: 'Transportation', amountPaise: 600000n }, // ₹2,000 avg across 3 months
      ],
      distinctHistoricalMonthsCount: 3,
      budgets: [],
      monthlySubscriptionRecurringPaise: 120000n, // ₹1,200
      subscriptionCount: 2,
    });

    const rollingAvg = insights.find((i) => i.type === 'THREE_MONTH_AVERAGE');
    expect(rollingAvg).toBeDefined();
    expect(rollingAvg?.title).toContain('transportation expenses are 50% higher');

    const subInsight = insights.find((i) => i.type === 'SUBSCRIPTION_BURDEN');
    expect(subInsight?.title).toBe(
      'Your subscriptions account for ₹1,200 in monthly recurring expenses.',
    );

    const dailyAvg = insights.find((i) => i.type === 'DAILY_AVERAGE');
    expect(dailyAvg?.title).toBe('Your average daily expenditure this month is ₹450.');
  });

  it('returns live deterministic insights with explanations from GET /api/v1/insights', async () => {
    const res = await request(app)
      .get('/api/v1/insights?month=11&year=2026')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    const insights = res.body.data.insights as Array<{
      type: string;
      title: string;
      explanation: string;
    }>;

    const momFood = insights.find((i) => i.type === 'MOM_CATEGORY_CHANGE');
    expect(momFood).toBeDefined();
    expect(momFood?.title).toBe(
      'You spent 18% more on food this month compared to last month.',
    );
    expect(momFood?.explanation).toContain('₹4,720');

    const shoppingBudget = insights.find((i) => i.type === 'BUDGET_UTILIZATION');
    expect(shoppingBudget).toBeDefined();
    expect(shoppingBudget?.title).toBe('You have spent 85% of your shopping budget.');
  });
});

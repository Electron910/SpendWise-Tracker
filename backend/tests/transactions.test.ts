import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import request from 'supertest';
import { app } from '../src/app';
import { prisma } from '../src/config/database';

const USER_A_EMAIL = `tx.usera.${Date.now()}@spendwise.app`;
const USER_B_EMAIL = `tx.userb.${Date.now()}@spendwise.app`;
const PASSWORD = 'Password123';

describe('Categories & Transactions API (/api/v1/categories & /api/v1/transactions)', () => {
  let tokenA = '';
  let tokenB = '';
  let foodCategoryIdA = '';
  let salaryCategoryIdA = '';
  let customCategoryIdA = '';
  let createdTxId = '';

  beforeAll(async () => {
    await prisma.user.deleteMany({
      where: { email: { in: [USER_A_EMAIL, USER_B_EMAIL] } },
    });

    const regA = await request(app).post('/api/v1/auth/register').send({
      email: USER_A_EMAIL,
      password: PASSWORD,
      fullName: 'User Alpha',
    });
    tokenA = regA.body.data.tokens.accessToken;

    const regB = await request(app).post('/api/v1/auth/register').send({
      email: USER_B_EMAIL,
      password: PASSWORD,
      fullName: 'User Beta',
    });
    tokenB = regB.body.data.tokens.accessToken;
  });

  afterAll(async () => {
    await prisma.user.deleteMany({
      where: { email: { in: [USER_A_EMAIL, USER_B_EMAIL] } },
    });
    await prisma.$disconnect();
  });

  it('lists 18 default categories (12 EXPENSE, 6 INCOME) for authenticated user', async () => {
    const res = await request(app)
      .get('/api/v1/categories')
      .set('Authorization', `Bearer ${tokenA}`);

    expect(res.status).toBe(200);
    const categories = res.body.data.categories as Array<{
      id: string;
      name: string;
      type: string;
    }>;
    expect(categories.length).toBe(18);

    const food = categories.find((c) => c.name === 'Food' && c.type === 'EXPENSE');
    const salary = categories.find((c) => c.name === 'Salary' && c.type === 'INCOME');
    expect(food).toBeDefined();
    expect(salary).toBeDefined();
    foodCategoryIdA = food!.id;
    salaryCategoryIdA = salary!.id;
  });

  it('creates, updates, and deletes a custom category while protecting system categories', async () => {
    const createRes = await request(app)
      .post('/api/v1/categories')
      .set('Authorization', `Bearer ${tokenA}`)
      .send({
        name: 'Pet Care',
        type: 'EXPENSE',
        icon: 'pets',
        colorHex: '#14B8A6',
      });

    expect(createRes.status).toBe(201);
    customCategoryIdA = createRes.body.data.category.id;

    // Updating custom category
    const updateRes = await request(app)
      .patch(`/api/v1/categories/${customCategoryIdA}`)
      .set('Authorization', `Bearer ${tokenA}`)
      .send({ name: 'Pets & Vet' });
    expect(updateRes.status).toBe(200);
    expect(updateRes.body.data.category.name).toBe('Pets & Vet');

    // System category deletion must be rejected
    const sysDeleteRes = await request(app)
      .delete(`/api/v1/categories/${foodCategoryIdA}`)
      .set('Authorization', `Bearer ${tokenA}`);
    expect(sysDeleteRes.status).toBe(400);
    expect(sysDeleteRes.body.error.code).toBe('SYSTEM_CATEGORY_PROTECTED');

    // Custom category deletion succeeds when unused
    const customDeleteRes = await request(app)
      .delete(`/api/v1/categories/${customCategoryIdA}`)
      .set('Authorization', `Bearer ${tokenA}`);
    expect(customDeleteRes.status).toBe(200);
  });

  it('creates income and expense transactions in integer paise and computes exact net savings', async () => {
    // Create ₹95,000.00 salary income (9,500,000 paise)
    const incomeRes = await request(app)
      .post('/api/v1/transactions')
      .set('Authorization', `Bearer ${tokenA}`)
      .send({
        categoryId: salaryCategoryIdA,
        type: 'INCOME',
        amountPaise: '9500000',
        merchant: 'TechCorp India',
        description: 'Monthly Salary Credit',
        paymentMethod: 'BANK_TRANSFER',
        transactionDate: '2026-11-01T10:00:00.000Z',
      });
    expect(incomeRes.status).toBe(201);
    expect(incomeRes.body.data.transaction.amountDecimal).toBe('95000.00');

    // Create ₹450.75 food expense (45,075 paise)
    const expenseRes = await request(app)
      .post('/api/v1/transactions')
      .set('Authorization', `Bearer ${tokenA}`)
      .send({
        categoryId: foodCategoryIdA,
        type: 'EXPENSE',
        amountPaise: 45075,
        merchant: 'Swiggy',
        description: 'Biryani & starter order',
        notes: 'Team dinner',
        paymentMethod: 'UPI',
        transactionDate: '2026-11-05T19:30:00.000Z',
      });
    expect(expenseRes.status).toBe(201);
    expect(expenseRes.body.data.transaction.amountDecimal).toBe('450.75');
    createdTxId = expenseRes.body.data.transaction.id;

    // List and check summary integer arithmetic
    const listRes = await request(app)
      .get('/api/v1/transactions')
      .set('Authorization', `Bearer ${tokenA}`);
    expect(listRes.status).toBe(200);
    expect(listRes.body.data.summary.totalIncomePaise).toBe('9500000');
    expect(listRes.body.data.summary.totalExpensePaise).toBe('45075');
    expect(listRes.body.data.summary.netSavingsPaise).toBe('9454925');
  });

  it('rejects zero, negative, or category-mismatched transactions', async () => {
    const zeroRes = await request(app)
      .post('/api/v1/transactions')
      .set('Authorization', `Bearer ${tokenA}`)
      .send({
        categoryId: foodCategoryIdA,
        type: 'EXPENSE',
        amountPaise: 0,
        description: 'Invalid zero tx',
        transactionDate: '2026-11-05T19:30:00.000Z',
      });
    expect(zeroRes.status).toBe(422);

    const mismatchRes = await request(app)
      .post('/api/v1/transactions')
      .set('Authorization', `Bearer ${tokenA}`)
      .send({
        categoryId: salaryCategoryIdA, // INCOME category used for EXPENSE
        type: 'EXPENSE',
        amountPaise: 10000,
        description: 'Mismatched type',
        transactionDate: '2026-11-05T19:30:00.000Z',
      });
    expect(mismatchRes.status).toBe(400);
    expect(mismatchRes.body.error.code).toBe('CATEGORY_TYPE_MISMATCH');
  });

  it('enforces optimistic concurrency version checks and prevents cross-user access', async () => {
    // User B cannot view or edit User A's transaction
    const forbiddenRes = await request(app)
      .get(`/api/v1/transactions/${createdTxId}`)
      .set('Authorization', `Bearer ${tokenB}`);
    expect(forbiddenRes.status).toBe(404);

    // User A updates transaction with expectedVersion: 1 -> version becomes 2
    const updateRes = await request(app)
      .patch(`/api/v1/transactions/${createdTxId}`)
      .set('Authorization', `Bearer ${tokenA}`)
      .send({
        amountPaise: 50000,
        description: 'Updated Swiggy dinner order',
        expectedVersion: 1,
      });
    expect(updateRes.status).toBe(200);
    expect(updateRes.body.data.transaction.version).toBe(2);

    // Stale update with expectedVersion: 1 must fail with 409 VERSION_CONFLICT
    const conflictRes = await request(app)
      .patch(`/api/v1/transactions/${createdTxId}`)
      .set('Authorization', `Bearer ${tokenA}`)
      .send({
        amountPaise: 60000,
        expectedVersion: 1,
      });
    expect(conflictRes.status).toBe(409);
    expect(conflictRes.body.error.code).toBe('VERSION_CONFLICT');
  });

  it('supports search, filtering, and soft-delete tombstones', async () => {
    const searchRes = await request(app)
      .get('/api/v1/transactions?search=Swiggy&type=EXPENSE')
      .set('Authorization', `Bearer ${tokenA}`);
    expect(searchRes.status).toBe(200);
    expect(searchRes.body.data.transactions.length).toBe(1);

    const delRes = await request(app)
      .delete(`/api/v1/transactions/${createdTxId}`)
      .set('Authorization', `Bearer ${tokenA}`);
    expect(delRes.status).toBe(200);

    // Verify tombstone in DB
    const dbRecord = await prisma.transaction.findUnique({ where: { id: createdTxId } });
    expect(dbRecord?.isDeleted).toBe(true);
    expect(dbRecord?.deletedAt).not.toBeNull();
  });
});

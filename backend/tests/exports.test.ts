import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import request from 'supertest';
import { app } from '../src/app';
import { prisma } from '../src/config/database';
import { ExportsService } from '../src/modules/exports/exports.service';

const TEST_EMAIL = `exports.${Date.now()}@spendwise.app`;
const PASSWORD = 'Password123';

describe('CSV Export & Monthly Report API (/api/v1/exports)', () => {
  let token = '';
  let foodCatId = '';

  beforeAll(async () => {
    await prisma.user.deleteMany({ where: { email: TEST_EMAIL } });
    const reg = await request(app).post('/api/v1/auth/register').send({
      email: TEST_EMAIL,
      password: PASSWORD,
      fullName: 'Export User',
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

    await request(app)
      .post('/api/v1/transactions')
      .set('Authorization', `Bearer ${token}`)
      .send({
        categoryId: foodCatId,
        type: 'EXPENSE',
        amountPaise: 52550, // ₹525.50
        merchant: 'Swiggy, India',
        description: 'Dinner & Dessert',
        paymentMethod: 'UPI',
        transactionDate: '2026-11-12T19:30:00.000Z',
      });
  });

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { email: TEST_EMAIL } });
    await prisma.$disconnect();
  });

  it('escapes RFC-4180 CSV cells and neutralizes formula injection characters', () => {
    expect(ExportsService.escapeCsvCell('=SUM(A1:A2)')).toBe("'=SUM(A1:A2)");
    expect(ExportsService.escapeCsvCell('Swiggy, India')).toBe('"Swiggy, India"');
  });

  it('exports transactions CSV and monthly category summary report', async () => {
    const txExport = await request(app)
      .get('/api/v1/exports/transactions')
      .set('Authorization', `Bearer ${token}`);

    expect(txExport.status).toBe(200);
    expect(txExport.body.data.rowCount).toBe(1);
    expect(txExport.body.data.csvContent).toContain('"Swiggy, India"');
    expect(txExport.body.data.csvContent).toContain('525.50,52550');

    const rawCsvRes = await request(app)
      .get('/api/v1/exports/transactions?format=csv')
      .set('Authorization', `Bearer ${token}`);
    expect(rawCsvRes.status).toBe(200);
    expect(rawCsvRes.headers['content-type']).toContain('text/csv');

    const monthlyRes = await request(app)
      .get('/api/v1/exports/monthly-report?month=11&year=2026')
      .set('Authorization', `Bearer ${token}`);
    expect(monthlyRes.status).toBe(200);
    expect(monthlyRes.body.data.summary.totalExpensePaise).toBe('52550');
    expect(monthlyRes.body.data.categories[0].categoryName).toBe('Food');
  });
});

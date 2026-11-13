import { randomUUID } from 'crypto';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import request from 'supertest';
import { app } from '../src/app';
import { prisma } from '../src/config/database';

const TEST_EMAIL = `sync.${Date.now()}@spendwise.app`;
const PASSWORD = 'Password123';

describe('Offline Synchronization & Conflict Resolution API (/api/v1/sync)', () => {
  let token = '';
  let foodCatId = '';
  const txId = randomUUID();

  beforeAll(async () => {
    await prisma.user.deleteMany({ where: { email: TEST_EMAIL } });
    const reg = await request(app).post('/api/v1/auth/register').send({
      email: TEST_EMAIL,
      password: PASSWORD,
      fullName: 'Sync User',
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
  });

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { email: TEST_EMAIL } });
    await prisma.$disconnect();
  });

  it('prevents duplicate creation when the same client UUID is pushed multiple times', async () => {
    const createOp = {
      operationId: 'op-create-1',
      entityType: 'TRANSACTION',
      entityId: txId,
      action: 'CREATE',
      baseVersion: 1,
      payload: {
        categoryId: foodCatId,
        type: 'EXPENSE',
        amountPaise: 25000, // ₹250.00
        description: 'Offline Metro Coffee',
        paymentMethod: 'UPI',
        transactionDate: '2026-11-12T09:00:00.000Z',
      },
    };

    const res1 = await request(app)
      .post('/api/v1/sync/push')
      .set('Authorization', `Bearer ${token}`)
      .send({ deviceId: 'pixel-9-pro', operations: [createOp] });

    expect(res1.status).toBe(200);
    expect(res1.body.data.summary.appliedCount).toBe(1);

    // Push same UUID again (simulating network retry after dropped response)
    const res2 = await request(app)
      .post('/api/v1/sync/push')
      .set('Authorization', `Bearer ${token}`)
      .send({ deviceId: 'pixel-9-pro', operations: [createOp] });

    expect(res2.status).toBe(200);
    expect(res2.body.data.summary.appliedCount).toBe(1);
    expect(res2.body.data.results[0].version).toBe(1);
  });

  it('detects optimistic concurrency version conflicts and resolves via forceOverwrite', async () => {
    // First, Device A updates the transaction online -> bumps version to 2
    await request(app)
      .patch(`/api/v1/transactions/${txId}`)
      .set('Authorization', `Bearer ${token}`)
      .send({ amountPaise: 30000, description: 'Server Edited Coffee (v2)' });

    // Second, Device B pushes an offline edit based on stale baseVersion = 1
    const staleUpdateRes = await request(app)
      .post('/api/v1/sync/push')
      .set('Authorization', `Bearer ${token}`)
      .send({
        deviceId: 'offline-tablet',
        operations: [
          {
            operationId: 'op-update-stale',
            entityType: 'TRANSACTION',
            entityId: txId,
            action: 'UPDATE',
            baseVersion: 1,
            forceOverwrite: false,
            payload: {
              amountPaise: 28000,
              description: 'Client Offline Edit from v1',
            },
          },
        ],
      });

    expect(staleUpdateRes.status).toBe(200);
    expect(staleUpdateRes.body.data.summary.conflictCount).toBe(1);
    const conflictResult = staleUpdateRes.body.data.results[0];
    expect(conflictResult.status).toBe('CONFLICT');
    expect(conflictResult.serverRecord.version).toBe(2);
    expect(conflictResult.serverRecord.amountPaise).toBe('30000');

    // Third, user resolves conflict in favor of client version (forceOverwrite: true)
    const resolvedRes = await request(app)
      .post('/api/v1/sync/push')
      .set('Authorization', `Bearer ${token}`)
      .send({
        deviceId: 'offline-tablet',
        operations: [
          {
            operationId: 'op-update-resolved',
            entityType: 'TRANSACTION',
            entityId: txId,
            action: 'UPDATE',
            baseVersion: 1,
            forceOverwrite: true,
            payload: {
              amountPaise: 28000,
              description: 'Client Offline Edit Resolved (v3)',
            },
          },
        ],
      });

    expect(resolvedRes.status).toBe(200);
    expect(resolvedRes.body.data.summary.appliedCount).toBe(1);
    expect(resolvedRes.body.data.results[0].version).toBe(3);
  });

  it('synchronizes tombstone soft-deletions and returns delta changes on pull', async () => {
    const delRes = await request(app)
      .post('/api/v1/sync/push')
      .set('Authorization', `Bearer ${token}`)
      .send({
        deviceId: 'pixel-9-pro',
        operations: [
          {
            operationId: 'op-delete-1',
            entityType: 'TRANSACTION',
            entityId: txId,
            action: 'DELETE',
            baseVersion: 3,
          },
        ],
      });

    expect(delRes.status).toBe(200);
    expect(delRes.body.data.summary.appliedCount).toBe(1);

    const pullRes = await request(app)
      .get('/api/v1/sync/pull?since=2026-01-01T00:00:00.000Z')
      .set('Authorization', `Bearer ${token}`);

    expect(pullRes.status).toBe(200);
    const pulledTx = (
      pullRes.body.data.transactions as Array<{ id: string; isDeleted: boolean }>
    ).find((t) => t.id === txId);
    expect(pulledTx).toBeDefined();
    expect(pulledTx?.isDeleted).toBe(true);
  });
});

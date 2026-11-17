# SpendWise — Offline-First Synchronization & Conflict Resolution Design

## 1. Synchronization State Machine

Every locally cached transaction and pending queue operation tracks its lifecycle through `SyncStatusState` ([mobile/lib/core/database/sync_status.dart](./mobile/lib/core/database/sync_status.dart)):

```
LOCAL_ONLY / PENDING_SYNC  ──(Sync Triggered)──►  SYNCING
                                                     │
                    ┌────────────────────────────────┼────────────────────────────────┐
                    ▼                                ▼                                ▼
                 SYNCED                          CONFLICT                        SYNC_FAILED
        (Queue item removed;             (Server version > baseVersion;    (Exponential backoff scheduled:
         local version updated)           conflictServerJson stored)        nextRetryAt = now + 2^retryCount s)
```

---

## 2. Local SQLite Schema (`LocalDatabase`)

Implemented in [mobile/lib/core/database/local_database.dart](./mobile/lib/core/database/local_database.dart):

1. `cached_categories`: Stores user categories for offline transaction creation and display.
2. `cached_transactions`: Stores full transaction records, integer `amount_paise`, `sync_status`, `version`, and `is_deleted` tombstones.
   - **Pending Mutation Protection**: When online reads upsert server records into `cached_transactions`, any local row currently in `PENDING_SYNC`, `LOCAL_ONLY`, or `CONFLICT` state is preserved and never overwritten by stale server reads.
3. `sync_queue`: Stores ordered `PendingSyncQueueItem` mutations (`CREATE`, `UPDATE`, `DELETE`) with `base_version`, `retry_count`, `next_retry_at`, and `conflict_server_json`.
4. `sync_metadata`: Stores `last_pull_timestamp` for delta pulls (`GET /api/v1/sync/pull?since=...`).

---

## 3. Idempotency & Duplicate Prevention

- Offline-created transactions generate a v4 UUID (`Uuid().v4()`) on the client immediately.
- When `POST /api/v1/sync/push` receives a `CREATE` operation, `SyncService` checks whether a transaction with `id == entityId` already exists for that user.
- If a prior push succeeded on the server but the HTTP response dropped in transit, re-pushing the same `CREATE` operation returns `status: 'APPLIED'` idempotently with the existing record instead of creating a duplicate transaction.

---

## 4. Optimistic Concurrency & Conflict Resolution

- Every transaction carries an integer `version` (starting at `1` and incremented on every server mutation).
- When a user edits a transaction offline, `PendingSyncQueueItem` records `baseVersion = tx.version`.
- On `POST /api/v1/sync/push`, if `existing.version > op.baseVersion` and `forceOverwrite != true`, the backend refuses to overwrite the newer server state and returns:
  ```json
  {
    "operationId": "...",
    "entityId": "...",
    "status": "CONFLICT",
    "version": 2,
    "serverRecord": { ... }
  }
  ```
- The mobile `SyncCenterScreen` presents both the **Client Offline Edit** and the **Server Version** side by side, allowing the user to choose:
  - **Keep My Edit**: Re-pushes the operation with `forceOverwrite: true`, advancing the server version to `v3`.
  - **Keep Server Version**: Applies `conflictServerJson` to local SQLite and removes the queue item.

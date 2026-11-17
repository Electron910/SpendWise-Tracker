# SpendWise — Database Design (`PostgreSQL` + `Prisma`)

The canonical schema lives in [backend/prisma/schema.prisma](./backend/prisma/schema.prisma).

## 1. Core Design Decisions

1. **Integer Minor Units (`BIGINT` Paise)**:
   - All monetary columns (`Transaction.amountPaise`, `Budget.amountPaise`, `RecurringExpense.amountPaise`) use PostgreSQL `BIGINT` (`@db.BigInt` / `BigInt` in Prisma).
   - `₹1.00 = 100 paise`. Zero `FLOAT`, `REAL`, or `DOUBLE PRECISION` columns exist anywhere in the schema.
2. **Client-Generated UUID Primary Keys**:
   - `Transaction.id`, `Category.id`, `Budget.id`, and `RecurringExpense.id` use `@db.Uuid` and accept client-generated v4 UUIDs so offline-created records have globally unique identifiers before reaching the server.
3. **Tombstone Soft-Deletion & Optimistic Concurrency**:
   - Syncable tables (`Transaction`, `Category`, `Budget`, `RecurringExpense`, `CategorizationRule`) include `version Int @default(1)`, `isDeleted Boolean @default(false)`, and `deletedAt DateTime?`.
   - Deletions never destroy rows needed for multi-device delta sync (`GET /api/v1/sync/pull?since=...`).

---

## 2. Entity-Relationship Summary

| Table / Model | Purpose | Key Indexes & Constraints |
| :--- | :--- | :--- |
| `User` | User account, password hash, reset token hash, currency (`INR`), `isDemoAccount` flag. | `@unique(email)` |
| `RefreshToken` | Rotating refresh token sessions with SHA-256 `tokenHash`, `revokedAt`, `replacedByToken`. | `@unique(tokenHash)`, `@@index([userId, revokedAt])` |
| `Category` | Expense & Income categories (`isSystem` default vs. custom user categories). | `@@unique([userId, name, type])`, `@@index([userId, type, isDeleted])` |
| `Transaction` | Financial ledger records (`EXPENSE` / `INCOME`) in `amountPaise` (`BigInt`), linked to `Category` and optional `RecurringExpense`. | `@@index([userId, transactionDate(sort: Desc), isDeleted])`, `@@index([userId, updatedAt])` |
| `Budget` | Overall monthly (`categoryId: null`) and category-specific budgets with `alertThresholds` (`[50, 75, 90, 100]`) and `triggeredThresholds`. | `@@index([userId, year, month, isDeleted])` |
| `RecurringExpense` | Recurring schedules (`DAILY`, `WEEKLY`, `MONTHLY`, `YEARLY`) with `nextOccurrence`, `lastGeneratedAt`, and `reminderDays`. | `@@index([userId, isActive, nextOccurrence, isDeleted])` |
| `CategorizationRule` | User-defined and learned (`isUserCorrection`) merchant/keyword categorization rules. | `@@unique([userId, pattern, transactionType])` |
| `Notification` | In-app alerts (`BUDGET_THRESHOLD`, `UPCOMING_RECURRING`, `MONTHLY_SUMMARY`, `UNUSUAL_SPENDING`). | `@@index([userId, isRead, createdAt(sort: Desc)])` |
| `SyncMetadata` | Per-device synchronization watermarks (`lastPulledAt`, `lastPushedAt`, `lastSyncRevision`). | `@@unique([userId, deviceId])` |

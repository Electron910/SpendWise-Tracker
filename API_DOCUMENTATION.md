# SpendWise — REST API Documentation (`/api/v1`)

Interactive OpenAPI/Swagger documentation is served at `http://localhost:4000/api-docs` when the backend server is running.

All protected endpoints require an `Authorization: Bearer <accessToken>` header.

---

## Standard Response Envelope

### Success (`200 OK` / `201 Created`)
```json
{
  "success": true,
  "message": "Operation completed successfully",
  "data": { ... }
}
```

### Error (`400`, `401`, `404`, `409`, `422`, `429`, `500`)
```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Request validation failed",
    "details": [...]
  }
}
```

---

## 1. Authentication (`/api/v1/auth`)

| Method | Path | Auth | Description |
| :--- | :--- | :--- | :--- |
| `POST` | `/auth/register` | Public | Registers a new user, provisions 18 default categories (12 Expense, 6 Income), and returns JWT access + refresh tokens. |
| `POST` | `/auth/login` | Public | Authenticates user credentials and issues access + refresh tokens. |
| `POST` | `/auth/refresh` | Public | Rotates a valid refresh token and revokes the previous token (`replacedByToken`). |
| `POST` | `/auth/logout` | Public | Revokes the active refresh token. |
| `POST` | `/auth/forgot-password` | Public | Generates a 15-minute 6-digit password reset code. |
| `POST` | `/auth/reset-password` | Public | Verifies the reset code, updates the password hash, and revokes all active sessions. |
| `GET` | `/auth/me` | Bearer | Returns the authenticated user's profile. |
| `PATCH` | `/auth/profile` | Bearer | Updates `fullName`, `currency`, and `timezone`. |

---

## 2. Categories & Transactions (`/api/v1/categories`, `/api/v1/transactions`)

| Method | Path | Description |
| :--- | :--- | :--- |
| `GET` | `/categories?type=EXPENSE\|INCOME` | Lists system and custom categories for the user. |
| `POST` | `/categories` | Creates a custom category (`name`, `type`, `icon`, `colorHex`). |
| `DELETE` | `/categories/:id` | Soft-deletes a custom category (system categories are protected). |
| `GET` | `/transactions` | Lists transactions with pagination, `search`, `type`, `categoryId`, `paymentMethod`, `startDate`, `endDate`, `sortBy`, `sortOrder`, and integer paise totals. |
| `POST` | `/transactions` | Creates a transaction in integer `amountPaise`. Auto-categorizes if `categoryId` is omitted. |
| `PATCH` | `/transactions/:id` | Updates a transaction with optional `expectedVersion` optimistic concurrency check and automatic user-correction learning. |
| `DELETE` | `/transactions/:id` | Soft-deletes a transaction (`isDeleted: true`, `deletedAt`, increments `version`). |

---

## 3. Deterministic Categorization (`/api/v1/categorization`)

| Method | Path | Description |
| :--- | :--- | :--- |
| `POST` | `/categorization/classify` | Classifies `{ merchant, description, type }` using user corrections (`priority >= 250`) and built-in rules (`SWIGGY -> Food`, `UBER -> Transportation`, `NETFLIX -> Subscriptions`, `AMAZON -> Shopping`). |
| `GET` | `/categorization/rules` | Lists user-defined and learned categorization rules plus built-in defaults. |
| `POST` | `/categorization/rules` | Creates or updates a user categorization rule. |

---

## 4. Budgets (`/api/v1/budgets`)

| Method | Path | Description |
| :--- | :--- | :--- |
| `GET` | `/budgets?month=11&year=2026` | Returns overall (`categoryId: null`) and category budgets with spent/remaining paise, utilization %, alert level (`NORMAL`, `NOTICE` >=50%, `WARNING` >=75%, `CRITICAL` >=90%, `EXCEEDED` >=100%), and MoM change %. |
| `POST` | `/budgets` | Creates or upserts a monthly overall or category budget in integer `amountPaise`. |
| `PATCH` | `/budgets/:id` | Updates budget `amountPaise` or `alertThresholds`. |
| `DELETE` | `/budgets/:id` | Soft-deletes a budget. |

---

## 5. Analytics & Insights (`/api/v1/analytics`, `/api/v1/insights`)

| Method | Path | Description |
| :--- | :--- | :--- |
| `GET` | `/analytics/overview?month=11&year=2026` | Home dashboard summary (income, expense, net savings, savings rate %, remaining budget, category breakdown, daily series, upcoming recurring, recent transactions). |
| `GET` | `/analytics/monthly?months=6` | Multi-month income vs. expense, savings rate, and MoM expense change series. |
| `GET` | `/analytics/categories?period=THIS_MONTH` | Category expense distribution for `THIS_WEEK`, `THIS_MONTH`, `PREVIOUS_MONTH`, `LAST_3_MONTHS`, `LAST_6_MONTHS`, or `CUSTOM`. |
| `GET` | `/analytics/trends?period=THIS_MONTH` | Daily trend, weekly trend, highest spending category, average daily spending, and biggest single expense. |
| `GET` | `/insights?month=11&year=2026` | Deterministic financial insights with `title`, `explanation` (`Why:`), `severity`, and `metricPaise`. |

---

## 6. Recurring Expenses, Sync, Exports & Notifications

| Method | Path | Description |
| :--- | :--- | :--- |
| `GET` | `/recurring` | Processes due occurrences idempotently and lists recurring schedules + upcoming reminders + generated transaction history. |
| `POST` | `/recurring` | Creates a recurring schedule (`DAILY`, `WEEKLY`, `MONTHLY`, `YEARLY`). |
| `POST` | `/recurring/process-due` | Explicitly triggers idempotent due-transaction generation up to `asOfDate`. |
| `PATCH` | `/recurring/:id` | Updates or toggles `isActive` on a recurring schedule. |
| `DELETE` | `/recurring/:id` | Soft-deletes a recurring schedule. |
| `POST` | `/sync/push` | Replays client offline mutations (`CREATE`, `UPDATE`, `DELETE`) with client UUID deduplication and optimistic concurrency conflict detection. |
| `GET` | `/sync/pull?since=...` | Returns delta changes for transactions (including tombstones) and categories. |
| `GET` | `/exports/transactions` | Exports filtered transactions as RFC-4180 CSV (`?format=csv` or JSON envelope). |
| `GET` | `/exports/monthly-report` | Generates monthly category summary report and CSV. |
| `GET` | `/notifications` | Evaluates deterministic alerts and lists notifications + `unreadCount`. |
| `PATCH` | `/notifications/:id/read` | Marks a notification as read. |
| `POST` | `/notifications/read-all` | Marks all notifications as read. |

# SpendWise — System & Mobile Architecture

## 1. Architectural Overview

SpendWise is structured as a modular monorepo containing:
- `backend/`: Layered Node.js + TypeScript + Express REST API backed by PostgreSQL and Prisma ORM.
- `mobile/`: Feature-first Clean Architecture Flutter application using Riverpod, GoRouter, Dio, and local SQLite persistence (`sqflite`).

```
SpendWise-Tracker/
├── backend/
│   ├── prisma/              # PostgreSQL schema & deterministic demo seed
│   ├── src/
│   │   ├── config/          # Env validation (Zod), Prisma client, Swagger, Pino logger
│   │   ├── middleware/      # JWT auth guard, Zod request validator, centralized error handler
│   │   ├── modules/         # Domain modules (auth, categories, transactions, budgets, analytics, insights, recurring, sync, exports, notifications)
│   │   └── utils/           # Integer paise money utilities & standard API envelopes
│   └── tests/               # Vitest + Supertest integration & unit suites
└── mobile/
    ├── lib/
    │   ├── core/            # Theme tokens, GoRouter, Dio 401 refresh interceptor, SQLite LocalDatabase, MoneyUtils
    │   └── features/        # Feature-first Clean Architecture slices
    └── test/                # Flutter unit & widget test suites
```

---

## 2. Mobile Feature-First Clean Architecture

Each feature inside `mobile/lib/features/<feature_name>/` is strictly divided into three layers:

1. **Domain Layer (`domain/`)**:
   - **Entities**: Immutable Dart classes (`TransactionEntity`, `CategoryEntity`, `BudgetEntity`, `FinancialInsightEntity`, `RecurringExpenseEntity`) representing core business state in integer paise (`int`).
   - **Pure Domain Services**: `DeterministicCategorizer` and `DeterministicInsightsEngine` contain zero UI or network dependencies and are unit-tested in isolation.
   - **Repository Interfaces**: Abstract contracts (`TransactionsRepository`, `AuthRepository`) decoupling presentation state from data sources.

2. **Data Layer (`data/`)**:
   - **Repository Implementations**: Coordinate remote REST API calls (`Dio`) with local SQLite persistence (`LocalDatabase`) and `SecureTokenStorage`.
   - **Offline Fallback**: When network requests fail with connection errors, `TransactionsRepositoryImpl` reads from `cached_transactions` / `cached_categories` and enqueues mutations in `sync_queue`.

3. **Presentation Layer (`presentation/`)**:
   - **Riverpod Notifiers (`providers/`)**: `StateNotifier` classes managing immutable UI state (`isLoading`, `errorMessage`, domain data).
   - **Screens & Widgets (`screens/`, `widgets/`)**: Material 3 responsive components consuming Riverpod providers without embedding business calculations.

---

## 3. Financial Precision Architecture (Zero Floating-Point Math)

Floating-point numbers (`double` in Dart, `number` float in JavaScript) suffer from IEEE-754 representation errors (e.g., `0.1 + 0.2 = 0.30000000000000004`).

SpendWise enforces a strict **Integer Minor-Unit (Paise)** invariant across all layers:
- **Storage**: PostgreSQL `BIGINT` (`BigInt` in Prisma, `INTEGER` in SQLite).
- **Transport**: Serialized as integer strings (`"amountPaise": "12550"`) in JSON responses to prevent 53-bit integer overflow.
- **Parsing**: User-entered decimal strings (`"125.50"`) are split on `.` and parsed via pure integer arithmetic (`125 * 100 + 50 = 12550` paise) in both `backend/src/utils/money.ts` and `mobile/lib/core/utils/money_utils.dart`.
- **Percentages**: Utilization and savings rates are computed using integer division (`(spentPaise * 100n) / budgetPaise`).

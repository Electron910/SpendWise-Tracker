# SpendWise — Intelligent Expense Tracker

SpendWise is a production-quality, offline-first personal expense tracking and budgeting application built with **Flutter (Material 3, Riverpod, GoRouter, SQLite)** and **Node.js + TypeScript + Express + PostgreSQL + Prisma**.

> **Important Product Principle**: SpendWise is a personal expense tracking and budgeting application. It is **NOT** a banking application. It never connects to real bank accounts or processes payments. All financial records are user-entered or generated from clearly labeled fictional demo data (`isDemoAccount` / `isDemoData`).

---

## Core Capabilities

- **Integer-Paise Financial Precision**: Zero floating-point arithmetic (`double` / IEEE-754 float) for monetary storage or calculations. Every monetary value is stored and computed in integer minor units (**paise**: `₹1.00 = 100 paise`, PostgreSQL `BIGINT`, Prisma `BigInt`, Dart `int`).
- **Authentication & Security**: JWT access tokens + rotating refresh tokens with SHA-256 token hashing, `bcrypt` password hashing, rate limiting, `helmet`, and `flutter_secure_storage`.
- **Home Financial Dashboard**: Real-time monthly income, expenses, remaining budget, net savings, savings rate %, `fl_chart` daily bar chart, category breakdown, budget utilization cards, and upcoming recurring bills.
- **Transaction Management**: Full CRUD for expenses and income across 18 default categories (12 Expense + 6 Income) plus custom user categories, search, multi-criteria filtering, and sorting.
- **Deterministic Expense Categorization Engine**: Rule-based merchant & description normalization (`SWIGGY -> Food`, `UBER -> Transportation`, `NETFLIX -> Subscriptions`, `AMAZON -> Shopping`, etc.) with confidence scores and automatic user-correction preference learning (`USER_CORRECTION` priority).
- **Budget Management**: Overall monthly and category-specific budgets with configurable `50%`, `75%`, `90%`, and `100%` utilization alerts and month-over-month comparisons.
- **Financial Analytics & Reports**: Multi-period analytics (`This Week`, `This Month`, `Previous Month`, `Last 3 Months`, `Last 6 Months`, `Custom Range`) with 5 interactive `fl_chart` charts and RFC-4180 CSV exports.
- **Deterministic Financial Insights Engine**: Analyzes historical transactions (MoM category changes, 3-month rolling averages, budget utilization, subscription burden, average daily expenditure) and provides a transparent `Why:` explanation for every insight.
- **Recurring Expenses Engine**: Backend-controlled idempotent recurrence generator (`DAILY`, `WEEKLY`, `MONTHLY`, `YEARLY`) with month-end/leap-year clamping and duplicate-prevention safeguards.
- **Offline-First SQLite Persistence & Sync Engine**: Full offline transaction CRUD with client-generated UUIDs, `sync_queue` state machine (`LOCAL_ONLY`, `PENDING_SYNC`, `SYNCING`, `SYNCED`, `SYNC_FAILED`, `CONFLICT`), exponential backoff retry, and interactive optimistic-concurrency conflict resolution.

---

## Technology Stack

| Layer | Technologies |
| :--- | :--- |
| **Mobile App** | Flutter 3, Dart 3, Material 3, Riverpod, GoRouter, Dio, `sqflite` / `sqflite_common_ffi`, `flutter_secure_storage`, `fl_chart`, `flutter_local_notifications`, `share_plus` |
| **Backend API** | Node.js, TypeScript, Express.js, Prisma ORM, PostgreSQL, Zod, JWT (`jsonwebtoken`), `bcryptjs`, Swagger/OpenAPI (`swagger-ui-express`), Pino |
| **Testing & QA** | Vitest + Supertest (34 backend tests), `flutter_test` (20 mobile unit & widget tests) |
| **DevOps & CI/CD** | Docker Compose, Dockerfile, GitHub Actions (`.github/workflows/ci.yml`), ESLint, Prettier, `flutter analyze` |

---

## Quick Start (Running Locally)

### 1. Prerequisites
- **Node.js** 20+ and **PostgreSQL** 16+ (or Docker Compose)
- **Flutter SDK** 3.24+

### 2. Start PostgreSQL & Backend API
```bash
cd backend
cp ../.env.example .env
# Edit .env with your DATABASE_URL if needed

npm install
npx prisma generate
npx prisma db push

# Seed fictional demo user & 3 months of sample transactions
npm run prisma:seed

# Start development server on http://localhost:4000
npm run dev
```
- **Health Check**: `http://localhost:4000/health`
- **Swagger / OpenAPI UI**: `http://localhost:4000/api-docs`

### 3. Run the Flutter Mobile App
```bash
cd mobile
flutter pub get

# Run on Windows Desktop / macOS / Chrome
flutter run -d windows

# Or run on Android Emulator (pointing to host localhost:4000 via 10.0.2.2)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000/api/v1
```

### 4. Demo Credentials (Simulated Data)
Tap **"Explore with Demo Account (Simulated Data)"** on the Login screen or enter:
- **Email**: `demo@spendwise.app`
- **Password**: `DemoPassword123`

---

## Running with Docker Compose

```bash
docker compose up --build -d
```
This provisions:
- `spendwise-postgres` (`postgres:16-alpine` on port `5432`)
- `spendwise-backend` (Express API on port `4000`)

---

## Documentation Index

- [ARCHITECTURE.md](./ARCHITECTURE.md) — Clean Architecture layers, state management, and financial precision design.
- [API_DOCUMENTATION.md](./API_DOCUMENTATION.md) — Complete REST API endpoint reference and request/response schemas.
- [DATABASE_DESIGN.md](./DATABASE_DESIGN.md) — PostgreSQL + Prisma ER schema, indexes, and `BIGINT` paise storage.
- [SYNC_DESIGN.md](./SYNC_DESIGN.md) — Offline-first SQLite queue, state machine, exponential backoff, and conflict resolution.
- [CONTRIBUTING.md](./CONTRIBUTING.md) — Feature-branch Git workflow and coding standards.
- [DEVELOPMENT_PROGRESS.md](./DEVELOPMENT_PROGRESS.md) — Milestone and feature branch completion tracker.

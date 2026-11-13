# SpendWise — Intelligent Expense Tracker

> **Product Principle**: SpendWise is a personal expense tracking and budgeting application. It is **NOT** a banking application. It does not connect to real bank accounts or process actual payments. All financial records are user-entered or generated from clearly labeled fictional demo data.

## Overview

SpendWise is a production-quality personal finance platform built with **Flutter (Material 3, Riverpod, GoRouter, Drift/SQLite, fl_chart)** on mobile and **Node.js, TypeScript, Express, Prisma ORM, and PostgreSQL** on the backend.

### Core Highlights
- **Zero Floating-Point Monetary Math**: All currency amounts are stored and calculated in integer minor units (**paise**, `₹125.50 = 12550 paise`) using PostgreSQL `BIGINT` and Dart `int`.
- **Offline-First Architecture**: Full local SQLite persistence, pending sync queue, client-generated UUIDs, tombstones for deletions, and optimistic concurrency control (`version` numbers).
- **Deterministic Categorization & Insights**: Transparent, rule-based merchant categorization with user correction learning and explainable historical spending insights.
- **Feature-First Clean Architecture**: Strict separation between presentation, domain, and data layers across both mobile and backend.

See [DEVELOPMENT_PROGRESS.md](./DEVELOPMENT_PROGRESS.md) for current milestone and branch status.

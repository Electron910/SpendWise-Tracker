# Contributing to SpendWise

## 1. Feature-Branch Git Workflow

SpendWise follows a strict feature-branch workflow:

1. **Never commit directly to `main`**.
2. Create a dedicated feature branch from `main`:
   ```bash
   git checkout main
   git pull origin main
   git checkout -b feature/<feature-name>
   ```
3. Implement the feature across backend and/or mobile layers.
4. Run static analysis and automated tests:
   ```bash
   # Backend
   cd backend && npm run lint && npm test

   # Mobile
   cd mobile && flutter analyze && flutter test
   ```
5. Stage and commit using Conventional Commits:
   - `feat(<scope>): ...`
   - `fix(<scope>): ...`
   - `refactor(<scope>): ...`
   - `test(<scope>): ...`
   - `docs(<scope>): ...`
   - `chore(<scope>): ...`
6. Push the feature branch to `origin` and obtain review approval before merging into `main`.

---

## 2. Engineering Rules

- **Zero Floating-Point Monetary Math**: Never use `double` (Dart) or floating-point `number` (TypeScript) for storing or calculating currency amounts. Always use integer minor units (`amountPaise`).
- **No Secret Commits**: Never commit `.env` files, private keys, or database credentials. Keep `.env.example` updated with placeholder variables.
- **Deterministic Logic**: Categorization and financial insights must be deterministic, explainable, and unit-testable in isolation.

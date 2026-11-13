import bcrypt from 'bcryptjs';
import { PaymentMethod, RecurrenceFrequency, SyncStatus, TransactionType } from '@prisma/client';
import { prisma } from '../src/config/database';
import { DEFAULT_SYSTEM_CATEGORIES } from '../src/modules/auth/defaultCategories';

export const DEMO_USER_EMAIL = 'demo@spendwise.app';
export const DEMO_USER_PASSWORD = 'DemoPassword123';

async function main() {
  console.log('Seeding SpendWise demo account, categories & fictional transactions...');

  const passwordHash = await bcrypt.hash(DEMO_USER_PASSWORD, 10);

  const demoUser = await prisma.user.upsert({
    where: { email: DEMO_USER_EMAIL },
    update: {
      fullName: 'Aarav Sharma (Demo)',
      isDemoAccount: true,
      currency: 'INR',
    },
    create: {
      email: DEMO_USER_EMAIL,
      passwordHash,
      fullName: 'Aarav Sharma (Demo)',
      isDemoAccount: true,
      currency: 'INR',
    },
  });

  const categoryMap = new Map<string, string>();

  for (const cat of DEFAULT_SYSTEM_CATEGORIES) {
    const saved = await prisma.category.upsert({
      where: {
        userId_name_type: {
          userId: demoUser.id,
          name: cat.name,
          type: cat.type,
        },
      },
      update: {
        icon: cat.icon,
        colorHex: cat.colorHex,
        isSystem: true,
      },
      create: {
        userId: demoUser.id,
        name: cat.name,
        type: cat.type,
        icon: cat.icon,
        colorHex: cat.colorHex,
        isSystem: true,
      },
    });
    categoryMap.set(`${cat.type}:${cat.name}`, saved.id);
  }

  // Seed fictional multi-month demo transactions if none exist yet
  const existingTxCount = await prisma.transaction.count({
    where: { userId: demoUser.id, isDeleted: false },
  });

  if (existingTxCount === 0) {
    const now = new Date();
    const y = now.getUTCFullYear();
    const m = now.getUTCMonth();

    const makeDate = (monthOffset: number, day: number) =>
      new Date(Date.UTC(y, m + monthOffset, day, 10, 0, 0));

    const demoTransactions = [
      // Current Month Income & Expenses
      {
        type: TransactionType.INCOME,
        categoryKey: 'INCOME:Salary',
        amountPaise: 9500000n, // ₹95,000.00
        merchant: 'Acme Tech Solutions Pvt Ltd',
        description: 'Monthly Salary Credit',
        paymentMethod: PaymentMethod.BANK_TRANSFER,
        transactionDate: makeDate(0, 1),
      },
      {
        type: TransactionType.INCOME,
        categoryKey: 'INCOME:Freelance',
        amountPaise: 1500000n, // ₹15,000.00
        merchant: 'Upwork Global',
        description: 'UI Design Advisory Retainer',
        paymentMethod: PaymentMethod.BANK_TRANSFER,
        transactionDate: makeDate(0, 5),
      },
      {
        type: TransactionType.EXPENSE,
        categoryKey: 'EXPENSE:Rent',
        amountPaise: 2400000n, // ₹24,000.00
        merchant: 'Indiranagar Apartment Owner',
        description: 'Monthly House Rent',
        paymentMethod: PaymentMethod.UPI,
        transactionDate: makeDate(0, 2),
      },
      {
        type: TransactionType.EXPENSE,
        categoryKey: 'EXPENSE:Groceries',
        amountPaise: 425050n, // ₹4,250.50
        merchant: 'BigBasket',
        description: 'Monthly groceries and fresh produce',
        paymentMethod: PaymentMethod.UPI,
        transactionDate: makeDate(0, 4),
      },
      {
        type: TransactionType.EXPENSE,
        categoryKey: 'EXPENSE:Food',
        amountPaise: 185000n, // ₹1,850.00
        merchant: 'Swiggy',
        description: 'Dinner order from Meghana Foods',
        paymentMethod: PaymentMethod.UPI,
        transactionDate: makeDate(0, 6),
      },
      {
        type: TransactionType.EXPENSE,
        categoryKey: 'EXPENSE:Transportation',
        amountPaise: 94500n, // ₹945.00
        merchant: 'Uber India',
        description: 'Airport & office commute rides',
        paymentMethod: PaymentMethod.UPI,
        transactionDate: makeDate(0, 7),
      },
      {
        type: TransactionType.EXPENSE,
        categoryKey: 'EXPENSE:Subscriptions',
        amountPaise: 64900n, // ₹649.00
        merchant: 'Netflix',
        description: 'Netflix Standard Monthly Plan',
        paymentMethod: PaymentMethod.CREDIT_CARD,
        transactionDate: makeDate(0, 8),
      },
      {
        type: TransactionType.EXPENSE,
        categoryKey: 'EXPENSE:Shopping',
        amountPaise: 349900n, // ₹3,499.00
        merchant: 'Amazon India',
        description: 'Wireless ergonomic keyboard & stand',
        paymentMethod: PaymentMethod.CREDIT_CARD,
        transactionDate: makeDate(0, 9),
      },
      {
        type: TransactionType.EXPENSE,
        categoryKey: 'EXPENSE:Utilities',
        amountPaise: 215000n, // ₹2,150.00
        merchant: 'BESCOM & Airtel Fiber',
        description: 'Electricity and fiber broadband bill',
        paymentMethod: PaymentMethod.UPI,
        transactionDate: makeDate(0, 10),
      },
      // Previous Month (-1)
      {
        type: TransactionType.INCOME,
        categoryKey: 'INCOME:Salary',
        amountPaise: 9500000n,
        merchant: 'Acme Tech Solutions Pvt Ltd',
        description: 'Monthly Salary Credit',
        paymentMethod: PaymentMethod.BANK_TRANSFER,
        transactionDate: makeDate(-1, 1),
      },
      {
        type: TransactionType.EXPENSE,
        categoryKey: 'EXPENSE:Rent',
        amountPaise: 2400000n,
        merchant: 'Indiranagar Apartment Owner',
        description: 'Monthly House Rent',
        paymentMethod: PaymentMethod.UPI,
        transactionDate: makeDate(-1, 2),
      },
      {
        type: TransactionType.EXPENSE,
        categoryKey: 'EXPENSE:Food',
        amountPaise: 142000n,
        merchant: 'Zomato',
        description: 'Weekend lunches and coffee',
        paymentMethod: PaymentMethod.UPI,
        transactionDate: makeDate(-1, 12),
      },
      {
        type: TransactionType.EXPENSE,
        categoryKey: 'EXPENSE:Shopping',
        amountPaise: 280000n,
        merchant: 'Myntra',
        description: 'Formal office wear',
        paymentMethod: PaymentMethod.DEBIT_CARD,
        transactionDate: makeDate(-1, 18),
      },
      // Two Months Ago (-2)
      {
        type: TransactionType.INCOME,
        categoryKey: 'INCOME:Salary',
        amountPaise: 9500000n,
        merchant: 'Acme Tech Solutions Pvt Ltd',
        description: 'Monthly Salary Credit',
        paymentMethod: PaymentMethod.BANK_TRANSFER,
        transactionDate: makeDate(-2, 1),
      },
      {
        type: TransactionType.EXPENSE,
        categoryKey: 'EXPENSE:Rent',
        amountPaise: 2400000n,
        merchant: 'Indiranagar Apartment Owner',
        description: 'Monthly House Rent',
        paymentMethod: PaymentMethod.UPI,
        transactionDate: makeDate(-2, 2),
      },
      {
        type: TransactionType.EXPENSE,
        categoryKey: 'EXPENSE:Healthcare',
        amountPaise: 180000n,
        merchant: 'Apollo Pharmacy',
        description: 'Annual health checkup & vitamins',
        paymentMethod: PaymentMethod.UPI,
        transactionDate: makeDate(-2, 15),
      },
    ];

    await prisma.transaction.createMany({
      data: demoTransactions.map((tx) => ({
        userId: demoUser.id,
        categoryId: categoryMap.get(tx.categoryKey)!,
        type: tx.type,
        amountPaise: tx.amountPaise,
        currency: 'INR',
        merchant: tx.merchant,
        description: tx.description,
        paymentMethod: tx.paymentMethod,
        transactionDate: tx.transactionDate,
        isDemoData: true,
        syncStatus: SyncStatus.SYNCED,
      })),
    });
  }

  // Seed fictional monthly budgets & recurring expenses for demo user if none exist
  const now = new Date();
  const currentMonth = now.getUTCMonth() + 1;
  const currentYear = now.getUTCFullYear();

  const existingBudgets = await prisma.budget.count({
    where: { userId: demoUser.id, month: currentMonth, year: currentYear, isDeleted: false },
  });

  if (existingBudgets === 0) {
    await prisma.budget.createMany({
      data: [
        {
          userId: demoUser.id,
          categoryId: null, // Overall monthly budget: ₹50,000
          month: currentMonth,
          year: currentYear,
          amountPaise: 5000000n,
        },
        {
          userId: demoUser.id,
          categoryId: categoryMap.get('EXPENSE:Food')!, // ₹5,000
          month: currentMonth,
          year: currentYear,
          amountPaise: 500000n,
        },
        {
          userId: demoUser.id,
          categoryId: categoryMap.get('EXPENSE:Transportation')!, // ₹2,000
          month: currentMonth,
          year: currentYear,
          amountPaise: 200000n,
        },
        {
          userId: demoUser.id,
          categoryId: categoryMap.get('EXPENSE:Shopping')!, // ₹4,000
          month: currentMonth,
          year: currentYear,
          amountPaise: 400000n,
        },
      ],
    });
  }

  const existingRecurring = await prisma.recurringExpense.count({
    where: { userId: demoUser.id, isDeleted: false },
  });

  if (existingRecurring === 0) {
    const nextMonthStart = new Date(Date.UTC(currentYear, currentMonth, 2, 9, 0, 0));
    await prisma.recurringExpense.createMany({
      data: [
        {
          userId: demoUser.id,
          categoryId: categoryMap.get('EXPENSE:Rent')!,
          type: TransactionType.EXPENSE,
          title: 'Monthly Apartment Rent',
          merchant: 'Indiranagar Apartment Owner',
          amountPaise: 2400000n,
          frequency: RecurrenceFrequency.MONTHLY,
          startDate: new Date(Date.UTC(currentYear, 0, 2)),
          nextOccurrence: nextMonthStart,
        },
        {
          userId: demoUser.id,
          categoryId: categoryMap.get('EXPENSE:Subscriptions')!,
          type: TransactionType.EXPENSE,
          title: 'Netflix Standard Plan',
          merchant: 'Netflix',
          amountPaise: 64900n,
          frequency: RecurrenceFrequency.MONTHLY,
          startDate: new Date(Date.UTC(currentYear, 0, 8)),
          nextOccurrence: new Date(Date.UTC(currentYear, currentMonth, 8, 9, 0, 0)),
        },
      ],
    });
  }

  console.log(`Seeded demo account: ${DEMO_USER_EMAIL} / ${DEMO_USER_PASSWORD}`);
}

main()
  .catch((err) => {
    console.error('Seed failed:', err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

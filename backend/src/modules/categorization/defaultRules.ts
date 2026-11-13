import { TransactionType } from '@prisma/client';

export interface BuiltInMerchantRule {
  pattern: string;
  categoryName: string;
  transactionType: TransactionType;
  confidence: number;
  priority: number;
}

/**
 * Deterministic Built-In Merchant & Keyword Rules
 * Note: User-defined rules and learned user corrections always take higher priority (priority >= 200).
 */
export const DEFAULT_CATEGORIZATION_RULES: BuiltInMerchantRule[] = [
  // Food & Dining
  { pattern: 'SWIGGY', categoryName: 'Food', transactionType: TransactionType.EXPENSE, confidence: 96, priority: 120 },
  { pattern: 'ZOMATO', categoryName: 'Food', transactionType: TransactionType.EXPENSE, confidence: 96, priority: 120 },
  { pattern: 'STARBUCKS', categoryName: 'Food', transactionType: TransactionType.EXPENSE, confidence: 94, priority: 115 },
  { pattern: 'DOMINOS', categoryName: 'Food', transactionType: TransactionType.EXPENSE, confidence: 94, priority: 115 },
  { pattern: 'MCDONALD', categoryName: 'Food', transactionType: TransactionType.EXPENSE, confidence: 94, priority: 115 },
  { pattern: 'KFC', categoryName: 'Food', transactionType: TransactionType.EXPENSE, confidence: 93, priority: 115 },
  { pattern: 'RESTAURANT', categoryName: 'Food', transactionType: TransactionType.EXPENSE, confidence: 85, priority: 100 },
  { pattern: 'CAFE', categoryName: 'Food', transactionType: TransactionType.EXPENSE, confidence: 84, priority: 100 },

  // Groceries
  { pattern: 'BIGBASKET', categoryName: 'Groceries', transactionType: TransactionType.EXPENSE, confidence: 96, priority: 120 },
  { pattern: 'BLINKIT', categoryName: 'Groceries', transactionType: TransactionType.EXPENSE, confidence: 95, priority: 120 },
  { pattern: 'ZEPTO', categoryName: 'Groceries', transactionType: TransactionType.EXPENSE, confidence: 95, priority: 120 },
  { pattern: 'INSTAMART', categoryName: 'Groceries', transactionType: TransactionType.EXPENSE, confidence: 95, priority: 120 },
  { pattern: 'DMART', categoryName: 'Groceries', transactionType: TransactionType.EXPENSE, confidence: 94, priority: 115 },
  { pattern: 'GROCER', categoryName: 'Groceries', transactionType: TransactionType.EXPENSE, confidence: 86, priority: 100 },

  // Transportation
  { pattern: 'UBER', categoryName: 'Transportation', transactionType: TransactionType.EXPENSE, confidence: 96, priority: 120 },
  { pattern: 'OLA', categoryName: 'Transportation', transactionType: TransactionType.EXPENSE, confidence: 95, priority: 120 },
  { pattern: 'RAPIDO', categoryName: 'Transportation', transactionType: TransactionType.EXPENSE, confidence: 95, priority: 120 },
  { pattern: 'NAMMA YATRI', categoryName: 'Transportation', transactionType: TransactionType.EXPENSE, confidence: 95, priority: 120 },
  { pattern: 'METRO', categoryName: 'Transportation', transactionType: TransactionType.EXPENSE, confidence: 88, priority: 105 },
  { pattern: 'PETROL', categoryName: 'Transportation', transactionType: TransactionType.EXPENSE, confidence: 90, priority: 110 },
  { pattern: 'INDIAN OIL', categoryName: 'Transportation', transactionType: TransactionType.EXPENSE, confidence: 92, priority: 110 },
  { pattern: 'HPCL', categoryName: 'Transportation', transactionType: TransactionType.EXPENSE, confidence: 92, priority: 110 },
  { pattern: 'SHELL', categoryName: 'Transportation', transactionType: TransactionType.EXPENSE, confidence: 90, priority: 110 },

  // Subscriptions
  { pattern: 'NETFLIX', categoryName: 'Subscriptions', transactionType: TransactionType.EXPENSE, confidence: 98, priority: 125 },
  { pattern: 'SPOTIFY', categoryName: 'Subscriptions', transactionType: TransactionType.EXPENSE, confidence: 98, priority: 125 },
  { pattern: 'YOUTUBE PREMIUM', categoryName: 'Subscriptions', transactionType: TransactionType.EXPENSE, confidence: 97, priority: 125 },
  { pattern: 'HOTSTAR', categoryName: 'Subscriptions', transactionType: TransactionType.EXPENSE, confidence: 96, priority: 120 },
  { pattern: 'APPLE COM BILL', categoryName: 'Subscriptions', transactionType: TransactionType.EXPENSE, confidence: 92, priority: 115 },
  { pattern: 'CHATGPT', categoryName: 'Subscriptions', transactionType: TransactionType.EXPENSE, confidence: 94, priority: 115 },

  // Shopping
  { pattern: 'AMAZON', categoryName: 'Shopping', transactionType: TransactionType.EXPENSE, confidence: 95, priority: 120 },
  { pattern: 'FLIPKART', categoryName: 'Shopping', transactionType: TransactionType.EXPENSE, confidence: 95, priority: 120 },
  { pattern: 'MYNTRA', categoryName: 'Shopping', transactionType: TransactionType.EXPENSE, confidence: 95, priority: 120 },
  { pattern: 'AJIO', categoryName: 'Shopping', transactionType: TransactionType.EXPENSE, confidence: 94, priority: 115 },
  { pattern: 'NYKAA', categoryName: 'Shopping', transactionType: TransactionType.EXPENSE, confidence: 94, priority: 115 },
  { pattern: 'DECATHLON', categoryName: 'Shopping', transactionType: TransactionType.EXPENSE, confidence: 93, priority: 115 },

  // Entertainment
  { pattern: 'BOOKMYSHOW', categoryName: 'Entertainment', transactionType: TransactionType.EXPENSE, confidence: 96, priority: 120 },
  { pattern: 'PVR', categoryName: 'Entertainment', transactionType: TransactionType.EXPENSE, confidence: 95, priority: 120 },
  { pattern: 'INOX', categoryName: 'Entertainment', transactionType: TransactionType.EXPENSE, confidence: 95, priority: 120 },
  { pattern: 'STEAM', categoryName: 'Entertainment', transactionType: TransactionType.EXPENSE, confidence: 92, priority: 115 },

  // Healthcare
  { pattern: 'APOLLO', categoryName: 'Healthcare', transactionType: TransactionType.EXPENSE, confidence: 94, priority: 115 },
  { pattern: 'PHARMACY', categoryName: 'Healthcare', transactionType: TransactionType.EXPENSE, confidence: 92, priority: 110 },
  { pattern: '1MG', categoryName: 'Healthcare', transactionType: TransactionType.EXPENSE, confidence: 95, priority: 120 },
  { pattern: 'PHARMEASY', categoryName: 'Healthcare', transactionType: TransactionType.EXPENSE, confidence: 95, priority: 120 },
  { pattern: 'HOSPITAL', categoryName: 'Healthcare', transactionType: TransactionType.EXPENSE, confidence: 90, priority: 110 },

  // Utilities
  { pattern: 'BESCOM', categoryName: 'Utilities', transactionType: TransactionType.EXPENSE, confidence: 96, priority: 120 },
  { pattern: 'AIRTEL', categoryName: 'Utilities', transactionType: TransactionType.EXPENSE, confidence: 93, priority: 115 },
  { pattern: 'JIO', categoryName: 'Utilities', transactionType: TransactionType.EXPENSE, confidence: 93, priority: 115 },
  { pattern: 'ELECTRICITY', categoryName: 'Utilities', transactionType: TransactionType.EXPENSE, confidence: 90, priority: 110 },
  { pattern: 'BROADBAND', categoryName: 'Utilities', transactionType: TransactionType.EXPENSE, confidence: 90, priority: 110 },

  // Travel
  { pattern: 'IRCTC', categoryName: 'Travel', transactionType: TransactionType.EXPENSE, confidence: 96, priority: 120 },
  { pattern: 'MAKEMYTRIP', categoryName: 'Travel', transactionType: TransactionType.EXPENSE, confidence: 96, priority: 120 },
  { pattern: 'INDIGO', categoryName: 'Travel', transactionType: TransactionType.EXPENSE, confidence: 95, priority: 120 },
  { pattern: 'AIRBNB', categoryName: 'Travel', transactionType: TransactionType.EXPENSE, confidence: 95, priority: 120 },

  // Education
  { pattern: 'UDEMY', categoryName: 'Education', transactionType: TransactionType.EXPENSE, confidence: 95, priority: 120 },
  { pattern: 'COURSERA', categoryName: 'Education', transactionType: TransactionType.EXPENSE, confidence: 95, priority: 120 },
  { pattern: 'TUITION', categoryName: 'Education', transactionType: TransactionType.EXPENSE, confidence: 90, priority: 110 },

  // Rent
  { pattern: 'HOUSE RENT', categoryName: 'Rent', transactionType: TransactionType.EXPENSE, confidence: 96, priority: 120 },
  { pattern: 'LANDLORD', categoryName: 'Rent', transactionType: TransactionType.EXPENSE, confidence: 93, priority: 115 },

  // Income
  { pattern: 'SALARY', categoryName: 'Salary', transactionType: TransactionType.INCOME, confidence: 97, priority: 125 },
  { pattern: 'PAYROLL', categoryName: 'Salary', transactionType: TransactionType.INCOME, confidence: 96, priority: 125 },
  { pattern: 'UPWORK', categoryName: 'Freelance', transactionType: TransactionType.INCOME, confidence: 96, priority: 120 },
  { pattern: 'FIVERR', categoryName: 'Freelance', transactionType: TransactionType.INCOME, confidence: 96, priority: 120 },
  { pattern: 'DIVIDEND', categoryName: 'Investments', transactionType: TransactionType.INCOME, confidence: 95, priority: 120 },
];

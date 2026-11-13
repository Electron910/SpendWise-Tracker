import { TransactionType } from '@prisma/client';

export interface SystemCategorySeed {
  name: string;
  type: TransactionType;
  icon: string;
  colorHex: string;
}

export const DEFAULT_SYSTEM_CATEGORIES: SystemCategorySeed[] = [
  // EXPENSE CATEGORIES
  { name: 'Food', type: TransactionType.EXPENSE, icon: 'restaurant', colorHex: '#EF4444' },
  { name: 'Transportation', type: TransactionType.EXPENSE, icon: 'directions_car', colorHex: '#F97316' },
  { name: 'Shopping', type: TransactionType.EXPENSE, icon: 'shopping_bag', colorHex: '#EC4899' },
  { name: 'Entertainment', type: TransactionType.EXPENSE, icon: 'movie', colorHex: '#8B5CF6' },
  { name: 'Healthcare', type: TransactionType.EXPENSE, icon: 'medical_services', colorHex: '#06B6D4' },
  { name: 'Education', type: TransactionType.EXPENSE, icon: 'school', colorHex: '#3B82F6' },
  { name: 'Rent', type: TransactionType.EXPENSE, icon: 'home', colorHex: '#6366F1' },
  { name: 'Utilities', type: TransactionType.EXPENSE, icon: 'bolt', colorHex: '#EAB308' },
  { name: 'Travel', type: TransactionType.EXPENSE, icon: 'flight', colorHex: '#14B8A6' },
  { name: 'Subscriptions', type: TransactionType.EXPENSE, icon: 'subscriptions', colorHex: '#A855F7' },
  { name: 'Groceries', type: TransactionType.EXPENSE, icon: 'local_grocery_store', colorHex: '#22C55E' },
  { name: 'Other', type: TransactionType.EXPENSE, icon: 'more_horiz', colorHex: '#64748B' },

  // INCOME CATEGORIES
  { name: 'Salary', type: TransactionType.INCOME, icon: 'payments', colorHex: '#10B981' },
  { name: 'Freelance', type: TransactionType.INCOME, icon: 'laptop_mac', colorHex: '#059669' },
  { name: 'Business', type: TransactionType.INCOME, icon: 'storefront', colorHex: '#0D9488' },
  { name: 'Investments', type: TransactionType.INCOME, icon: 'trending_up', colorHex: '#2563EB' },
  { name: 'Gifts', type: TransactionType.INCOME, icon: 'card_giftcard', colorHex: '#D946EF' },
  { name: 'Other', type: TransactionType.INCOME, icon: 'account_balance_wallet', colorHex: '#475569' },
];

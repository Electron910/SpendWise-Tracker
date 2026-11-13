import { TransactionType } from '@prisma/client';
import { prisma } from '../../config/database';
import { calculateUtilizationPercentage, formatPaiseToDecimalString } from '../../utils/money';

export class ExportsService {
  /**
   * Escapes a CSV cell per RFC-4180 and neutralizes spreadsheet formula injection (`=`, `+`, `-`, `@`).
   */
  static escapeCsvCell(value: string | number | bigint | null | undefined): string {
    if (value === null || value === undefined) {
      return '';
    }
    let str = String(value);
    if (/^[=+\-@]/.test(str)) {
      str = `'${str}`;
    }
    if (/[",\r\n]/.test(str)) {
      return `"${str.replace(/"/g, '""')}"`;
    }
    return str;
  }

  static async exportTransactionsCsv(
    userId: string,
    filters: {
      startDate?: string;
      endDate?: string;
      type?: TransactionType;
      categoryId?: string;
    },
  ) {
    const transactions = await prisma.transaction.findMany({
      where: {
        userId,
        isDeleted: false,
        ...(filters.type ? { type: filters.type } : {}),
        ...(filters.categoryId ? { categoryId: filters.categoryId } : {}),
        ...(filters.startDate || filters.endDate
          ? {
              transactionDate: {
                ...(filters.startDate ? { gte: new Date(filters.startDate) } : {}),
                ...(filters.endDate ? { lte: new Date(filters.endDate) } : {}),
              },
            }
          : {}),
      },
      include: { category: true },
      orderBy: { transactionDate: 'desc' },
    });

    const headers = [
      'Transaction ID',
      'Date (UTC)',
      'Type',
      'Category',
      'Merchant',
      'Description',
      'Payment Method',
      'Currency',
      'Amount (INR)',
      'Amount (Paise)',
      'Notes',
    ];

    const rows = [headers.join(',')];
    let totalIncomePaise = 0n;
    let totalExpensePaise = 0n;

    for (const tx of transactions) {
      if (tx.type === TransactionType.INCOME) {
        totalIncomePaise += tx.amountPaise;
      } else {
        totalExpensePaise += tx.amountPaise;
      }

      const row = [
        this.escapeCsvCell(tx.id),
        this.escapeCsvCell(tx.transactionDate.toISOString()),
        this.escapeCsvCell(tx.type),
        this.escapeCsvCell(tx.category.name),
        this.escapeCsvCell(tx.merchant),
        this.escapeCsvCell(tx.description),
        this.escapeCsvCell(tx.paymentMethod),
        this.escapeCsvCell(tx.currency),
        this.escapeCsvCell(formatPaiseToDecimalString(tx.amountPaise)),
        this.escapeCsvCell(tx.amountPaise.toString()),
        this.escapeCsvCell(tx.notes),
      ];
      rows.push(row.join(','));
    }

    return {
      filename: `spendwise_transactions_${new Date().toISOString().slice(0, 10)}.csv`,
      rowCount: transactions.length,
      totalIncomePaise: totalIncomePaise.toString(),
      totalExpensePaise: totalExpensePaise.toString(),
      netSavingsPaise: (totalIncomePaise - totalExpensePaise).toString(),
      csvContent: rows.join('\n'),
    };
  }

  static async exportMonthlyReport(userId: string, month: number, year: number) {
    const startOfMonth = new Date(Date.UTC(year, month - 1, 1, 0, 0, 0));
    const endOfMonth = new Date(Date.UTC(year, month, 0, 23, 59, 59, 999));

    const transactions = await prisma.transaction.findMany({
      where: {
        userId,
        isDeleted: false,
        transactionDate: { gte: startOfMonth, lte: endOfMonth },
      },
      include: { category: true },
    });

    let totalIncomePaise = 0n;
    let totalExpensePaise = 0n;
    const byCategory = new Map<
      string,
      {
        categoryName: string;
        type: TransactionType;
        count: number;
        amountPaise: bigint;
      }
    >();

    for (const tx of transactions) {
      if (tx.type === TransactionType.INCOME) {
        totalIncomePaise += tx.amountPaise;
      } else {
        totalExpensePaise += tx.amountPaise;
      }

      const key = `${tx.type}:${tx.category.name}`;
      const existing = byCategory.get(key);
      if (existing) {
        existing.count += 1;
        existing.amountPaise += tx.amountPaise;
      } else {
        byCategory.set(key, {
          categoryName: tx.category.name,
          type: tx.type,
          count: 1,
          amountPaise: tx.amountPaise,
        });
      }
    }

    const headers = [
      'Category',
      'Type',
      'Transaction Count',
      'Total Amount (INR)',
      'Total Amount (Paise)',
      'Share (%)',
    ];
    const rows = [headers.join(',')];

    const categorySummaries = Array.from(byCategory.values())
      .sort((a, b) => (b.amountPaise > a.amountPaise ? 1 : -1))
      .map((c) => {
        const denominator =
          c.type === TransactionType.INCOME ? totalIncomePaise : totalExpensePaise;
        const share = calculateUtilizationPercentage(c.amountPaise, denominator);
        const decimalStr = formatPaiseToDecimalString(c.amountPaise);
        rows.push(
          [
            this.escapeCsvCell(c.categoryName),
            this.escapeCsvCell(c.type),
            this.escapeCsvCell(c.count),
            this.escapeCsvCell(decimalStr),
            this.escapeCsvCell(c.amountPaise.toString()),
            this.escapeCsvCell(share.percentage),
          ].join(','),
        );
        return {
          categoryName: c.categoryName,
          type: c.type,
          transactionCount: c.count,
          amountPaise: c.amountPaise.toString(),
          amountDecimal: decimalStr,
          sharePercentage: share.percentage,
        };
      });

    return {
      period: { month, year },
      filename: `spendwise_monthly_report_${year}_${String(month).padStart(2, '0')}.csv`,
      summary: {
        totalIncomePaise: totalIncomePaise.toString(),
        totalExpensePaise: totalExpensePaise.toString(),
        netSavingsPaise: (totalIncomePaise - totalExpensePaise).toString(),
      },
      categories: categorySummaries,
      csvContent: rows.join('\n'),
    };
  }
}

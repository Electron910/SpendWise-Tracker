import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise_mobile/core/theme/app_theme.dart';
import 'package:spendwise_mobile/features/categories/domain/entities/category_entity.dart';
import 'package:spendwise_mobile/features/exports/domain/services/csv_export_service.dart';
import 'package:spendwise_mobile/features/exports/presentation/screens/exports_screen.dart';
import 'package:spendwise_mobile/features/transactions/domain/entities/transaction_entity.dart';

class FakeCsvExportService extends CsvExportService {
  FakeCsvExportService() : super(dio: Dio());

  @override
  Future<ExportCsvResult> generateTransactionsExport({String? type}) async {
    return CsvExportService.buildLocalTransactionsCsv([
      TransactionEntity(
        id: 'tx-export-1',
        categoryId: 'cat-food',
        type: 'EXPENSE',
        amountPaise: 52550,
        currency: 'INR',
        merchant: 'Swiggy, India',
        description: 'Dinner & Dessert',
        paymentMethod: 'UPI',
        transactionDate: DateTime.utc(2026, 11, 12, 19, 30),
        category: const CategoryEntity(
          id: 'cat-food',
          name: 'Food',
          type: 'EXPENSE',
          icon: 'restaurant',
          colorHex: '#EF4444',
          isSystem: true,
        ),
      ),
    ]);
  }
}

void main() {
  test('CsvExportService escapes RFC-4180 cells and formula injection prefixes', () {
    expect(CsvExportService.escapeCsvCell('=SUM(A1:A2)'), "'=SUM(A1:A2)");
    expect(CsvExportService.escapeCsvCell('Swiggy, India'), '"Swiggy, India"');
  });

  testWidgets('ExportsScreen generates and displays CSV preview with integer paise summary',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          csvExportServiceProvider.overrideWithValue(FakeCsvExportService()),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const ExportsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('export_transactions_csv_button')));
    await tester.pumpAndSettle();

    expect(find.text('spendwise_transactions_offline.csv'), findsOneWidget);
    expect(find.textContaining('Rows: 1 • Income: ₹0.00 • Expenses: ₹525.50'), findsOneWidget);
    expect(find.textContaining('"Swiggy, India"'), findsOneWidget);
  });
}

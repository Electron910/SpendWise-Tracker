import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/local_database.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/money_utils.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';

final csvExportServiceProvider = Provider<CsvExportService>((ref) {
  return CsvExportService(
    dio: ref.watch(dioClientProvider),
    localDb: ref.watch(localDatabaseProvider),
  );
});

class ExportCsvResult {
  final String filename;
  final int rowCount;
  final int totalIncomePaise;
  final int totalExpensePaise;
  final int netSavingsPaise;
  final String csvContent;

  const ExportCsvResult({
    required this.filename,
    required this.rowCount,
    required this.totalIncomePaise,
    required this.totalExpensePaise,
    required this.netSavingsPaise,
    required this.csvContent,
  });
}

class CsvExportService {
  final Dio _dio;
  final LocalDatabase? _localDb;

  CsvExportService({
    required Dio dio,
    LocalDatabase? localDb,
  })  : _dio = dio,
        _localDb = localDb;

  static String escapeCsvCell(String? value) {
    if (value == null || value.isEmpty) return '';
    var str = value;
    if (RegExp(r'^[=+\-@]').hasMatch(str)) {
      str = "'$str";
    }
    if (str.contains(',') || str.contains('"') || str.contains('\n')) {
      return '"${str.replaceAll('"', '""')}"';
    }
    return str;
  }

  static ExportCsvResult buildLocalTransactionsCsv(
    List<TransactionEntity> transactions,
  ) {
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
    final rows = <String>[headers.join(',')];
    int incomePaise = 0;
    int expensePaise = 0;

    for (final tx in transactions) {
      if (tx.isIncome) {
        incomePaise += tx.amountPaise;
      } else {
        expensePaise += tx.amountPaise;
      }
      rows.add(
        [
          escapeCsvCell(tx.id),
          escapeCsvCell(tx.transactionDate.toUtc().toIso8601String()),
          escapeCsvCell(tx.type),
          escapeCsvCell(tx.category.name),
          escapeCsvCell(tx.merchant),
          escapeCsvCell(tx.description),
          escapeCsvCell(tx.paymentMethod),
          escapeCsvCell(tx.currency),
          escapeCsvCell(MoneyUtils.formatPaise(tx.amountPaise)),
          escapeCsvCell(tx.amountPaise.toString()),
          escapeCsvCell(tx.notes),
        ].join(','),
      );
    }

    return ExportCsvResult(
      filename: 'spendwise_transactions_offline.csv',
      rowCount: transactions.length,
      totalIncomePaise: incomePaise,
      totalExpensePaise: expensePaise,
      netSavingsPaise: incomePaise - expensePaise,
      csvContent: rows.join('\n'),
    );
  }

  Future<ExportCsvResult> generateTransactionsExport({String? type}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/exports/transactions',
        queryParameters: {
          if (type != null) 'type': type,
        },
      );
      final data = response.data!['data'] as Map<String, dynamic>;
      return ExportCsvResult(
        filename: data['filename'] as String,
        rowCount: (data['rowCount'] as num).toInt(),
        totalIncomePaise: int.parse(data['totalIncomePaise'].toString()),
        totalExpensePaise: int.parse(data['totalExpensePaise'].toString()),
        netSavingsPaise: int.parse(data['netSavingsPaise'].toString()),
        csvContent: data['csvContent'] as String,
      );
    } catch (_) {
      if (_localDb != null) {
        final cached = await _localDb.getCachedTransactions(type: type);
        return buildLocalTransactionsCsv(cached);
      }
      rethrow;
    }
  }

  Future<ExportCsvResult> generateMonthlyReportExport({
    required int month,
    required int year,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/exports/monthly-report',
      queryParameters: {'month': month, 'year': year},
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    final summary = data['summary'] as Map<String, dynamic>;
    final categories = data['categories'] as List<dynamic>;

    return ExportCsvResult(
      filename: data['filename'] as String,
      rowCount: categories.length,
      totalIncomePaise: int.parse(summary['totalIncomePaise'].toString()),
      totalExpensePaise: int.parse(summary['totalExpensePaise'].toString()),
      netSavingsPaise: int.parse(summary['netSavingsPaise'].toString()),
      csvContent: data['csvContent'] as String,
    );
  }
}

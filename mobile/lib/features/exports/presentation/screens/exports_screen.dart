import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/money_utils.dart';
import '../../domain/services/csv_export_service.dart';

class ExportsScreen extends ConsumerStatefulWidget {
  const ExportsScreen({super.key});

  @override
  ConsumerState<ExportsScreen> createState() => _ExportsScreenState();
}

class _ExportsScreenState extends ConsumerState<ExportsScreen> {
  ExportCsvResult? _latestExport;
  bool _isLoading = false;
  String? _error;

  Future<void> _runTransactionsExport() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(csvExportServiceProvider)
          .generateTransactionsExport();
      setState(() {
        _latestExport = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _runMonthlyReportExport() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final now = DateTime.now();
    try {
      final result = await ref
          .read(csvExportServiceProvider)
          .generateMonthlyReportExport(month: now.month, year: now.year);
      setState(() {
        _latestExport = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final export = _latestExport;

    return Scaffold(
      appBar: AppBar(
        title: const Text('CSV Export & Reports'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Generate Financial Exports',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Export your transactions or monthly category breakdown as RFC-4180 CSV with integer paise precision.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          key: const Key('export_transactions_csv_button'),
                          onPressed: _isLoading ? null : _runTransactionsExport,
                          icon: const Icon(Icons.table_chart_outlined, size: 18),
                          label: const Text('Transactions CSV'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const Key('export_monthly_report_button'),
                          onPressed: _isLoading ? null : _runMonthlyReportExport,
                          icon: const Icon(Icons.summarize_outlined, size: 18),
                          label: const Text('Monthly Report'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.expenseRed),
              ),
            ),
          if (export != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      export.filename,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Rows: ${export.rowCount} • Income: ${MoneyUtils.formatPaise(export.totalIncomePaise)} • Expenses: ${MoneyUtils.formatPaise(export.totalExpensePaise)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const Key('copy_csv_clipboard_button'),
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(text: export.csvContent),
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('CSV copied to clipboard'),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.copy_rounded, size: 16),
                            label: const Text('Copy CSV'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Share.share(
                                export.csvContent,
                                subject: export.filename,
                              );
                            },
                            icon: const Icon(Icons.share_outlined, size: 16),
                            label: const Text('Share CSV'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.lightBackground,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.lightBorder),
                      ),
                      child: SelectableText(
                        export.csvContent,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

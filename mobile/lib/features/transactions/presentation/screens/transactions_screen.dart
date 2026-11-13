import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/money_utils.dart';
import '../../domain/entities/transaction_entity.dart';
import '../providers/transactions_provider.dart';
import 'transaction_form_screen.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(transactionsNotifierProvider.notifier).loadInitialData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openTransactionForm([TransactionEntity? existing]) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TransactionFormScreen(existingTransaction: existing),
      ),
    );
  }

  Future<void> _confirmDelete(TransactionEntity tx) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: Text(
          'Are you sure you want to delete "${tx.description}" (${MoneyUtils.formatPaise(tx.amountPaise)})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            key: const Key('confirm_delete_tx_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.expenseRed,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref
          .read(transactionsNotifierProvider.notifier)
          .removeTransaction(tx.id);
    }
  }

  void _showTransactionDetails(TransactionEntity tx) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: tx.category.color.withValues(alpha: 0.15),
                    child: Icon(tx.category.iconData, color: tx.category.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tx.description,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${tx.category.name} • ${tx.paymentMethod.replaceAll('_', ' ')}',
                          style: const TextStyle(
                            color: AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${tx.isExpense ? '-' : '+'}${MoneyUtils.formatPaise(tx.amountPaise)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: tx.isExpense
                          ? AppColors.expenseRed
                          : AppColors.emeraldIncome,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (tx.merchant != null && tx.merchant!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('Merchant: ${tx.merchant}'),
                ),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'Date: ${DateFormat('dd MMM yyyy, hh:mm a').format(tx.transactionDate.toLocal())}',
                ),
              ),
              if (tx.notes != null && tx.notes!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('Notes: ${tx.notes}'),
                ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Sync Status: ${tx.syncStatus} (v${tx.version})${tx.isDemoData ? ' • Simulated Demo Record' : ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.lightTextSecondary,
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _confirmDelete(tx);
                    },
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.expenseRed,
                    ),
                    label: const Text(
                      'Delete',
                      style: TextStyle(color: AppColors.expenseRed),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _openTransactionForm(tx);
                    },
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final txState = ref.watch(transactionsNotifierProvider);
    final filter = txState.filter;

    return Scaffold(
      body: Column(
        children: [
          // Top Summary Banner
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: _SummaryMiniCard(
                    title: 'Income',
                    amountPaise: txState.totalIncomePaise,
                    color: AppColors.emeraldIncome,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SummaryMiniCard(
                    title: 'Expenses',
                    amountPaise: txState.totalExpensePaise,
                    color: AppColors.expenseRed,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SummaryMiniCard(
                    title: 'Net Savings',
                    amountPaise: txState.netSavingsPaise,
                    color: AppColors.indigoAccent,
                  ),
                ),
              ],
            ),
          ),

          // Search & Filter Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Column(
              children: [
                TextField(
                  key: const Key('tx_search_field'),
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search description, merchant, or notes...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                              ref
                                  .read(transactionsNotifierProvider.notifier)
                                  .updateFilter(filter.copyWith(search: ''));
                            },
                          )
                        : null,
                  ),
                  onSubmitted: (query) {
                    ref
                        .read(transactionsNotifierProvider.notifier)
                        .updateFilter(filter.copyWith(search: query));
                  },
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('All'),
                        selected: filter.type == null,
                        onSelected: (_) {
                          ref
                              .read(transactionsNotifierProvider.notifier)
                              .updateFilter(filter.copyWith(clearType: true));
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Expenses'),
                        selected: filter.type == 'EXPENSE',
                        onSelected: (_) {
                          ref
                              .read(transactionsNotifierProvider.notifier)
                              .updateFilter(filter.copyWith(type: 'EXPENSE'));
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Income'),
                        selected: filter.type == 'INCOME',
                        onSelected: (_) {
                          ref
                              .read(transactionsNotifierProvider.notifier)
                              .updateFilter(filter.copyWith(type: 'INCOME'));
                        },
                      ),
                      const SizedBox(width: 8),
                      ActionChip(
                        avatar: const Icon(Icons.sort_rounded, size: 16),
                        label: Text(
                          filter.sortBy == 'amountPaise'
                              ? 'Sort: Amount'
                              : 'Sort: Date',
                        ),
                        onPressed: () {
                          final nextSort = filter.sortBy == 'transactionDate'
                              ? 'amountPaise'
                              : 'transactionDate';
                          ref
                              .read(transactionsNotifierProvider.notifier)
                              .updateFilter(filter.copyWith(sortBy: nextSort));
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: txState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : txState.transactions.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 56,
                              color: AppColors.lightTextSecondary,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'No transactions found',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Tap + below to record an income or expense.',
                              style: TextStyle(
                                color: AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: txState.transactions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final tx = txState.transactions[index];
                          return Card(
                            child: ListTile(
                              onTap: () => _showTransactionDetails(tx),
                              leading: CircleAvatar(
                                backgroundColor:
                                    tx.category.color.withValues(alpha: 0.14),
                                child: Icon(
                                  tx.category.iconData,
                                  color: tx.category.color,
                                ),
                              ),
                              title: Text(
                                tx.description,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                '${tx.category.name} • ${DateFormat('dd MMM yyyy').format(tx.transactionDate.toLocal())}${tx.syncStatus != 'SYNCED' ? ' • ${tx.syncStatus}' : ''}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.lightTextSecondary,
                                ),
                              ),
                              trailing: Text(
                                '${tx.isExpense ? '-' : '+'}${MoneyUtils.formatPaise(tx.amountPaise)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: tx.isExpense
                                      ? AppColors.expenseRed
                                      : AppColors.emeraldIncome,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add_transaction_fab'),
        onPressed: () => _openTransactionForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Transaction'),
      ),
    );
  }
}

class _SummaryMiniCard extends StatelessWidget {
  const _SummaryMiniCard({
    required this.title,
    required this.amountPaise,
    required this.color,
  });

  final String title;
  final int amountPaise;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.lightTextSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                MoneyUtils.formatPaise(amountPaise, includeDecimals: false),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

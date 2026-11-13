import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/money_utils.dart';
import '../../../transactions/presentation/providers/transactions_provider.dart';
import '../../domain/entities/recurring_expense_entity.dart';
import '../providers/recurring_provider.dart';

class RecurringExpensesScreen extends ConsumerWidget {
  const RecurringExpensesScreen({super.key});

  Future<void> _showCreateRecurringDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final txState = ref.read(transactionsNotifierProvider);
    final categories = txState.categories;

    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final merchantCtrl = TextEditingController();
    String selectedType = 'EXPENSE';
    String selectedFrequency = 'MONTHLY';
    String? selectedCategoryId = categories.isNotEmpty ? categories.first.id : null;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredCats =
                categories.where((c) => c.type == selectedType).toList();
            if (filteredCats.isNotEmpty &&
                !filteredCats.any((c) => c.id == selectedCategoryId)) {
              selectedCategoryId = filteredCats.first.id;
            }

            return AlertDialog(
              title: const Text('New Recurring Schedule'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'EXPENSE', label: Text('Expense')),
                        ButtonSegment(value: 'INCOME', label: Text('Income')),
                      ],
                      selected: {selectedType},
                      onSelectionChanged: (s) {
                        setDialogState(() {
                          selectedType = s.first;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('recurring_title_input'),
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Title (e.g., Monthly Rent, Netflix, Salary)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('recurring_amount_input'),
                      controller: amountCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Amount (₹)',
                        prefixText: '₹ ',
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (filteredCats.isNotEmpty)
                      DropdownButtonFormField<String>(
                        initialValue: selectedCategoryId,
                        decoration: const InputDecoration(labelText: 'Category'),
                        items: filteredCats
                            .map(
                              (c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(c.name),
                              ),
                            )
                            .toList(),
                        onChanged: (val) =>
                            setDialogState(() => selectedCategoryId = val),
                      ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedFrequency,
                      decoration: const InputDecoration(labelText: 'Frequency'),
                      items: const [
                        DropdownMenuItem(value: 'DAILY', child: Text('Daily')),
                        DropdownMenuItem(value: 'WEEKLY', child: Text('Weekly')),
                        DropdownMenuItem(value: 'MONTHLY', child: Text('Monthly')),
                        DropdownMenuItem(value: 'YEARLY', child: Text('Yearly')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedFrequency = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: merchantCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Merchant / Payee (Optional)',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  key: const Key('save_recurring_button'),
                  onPressed: () async {
                    final paise = MoneyUtils.tryParseRupeesToPaise(amountCtrl.text);
                    if (titleCtrl.text.trim().length < 2 ||
                        paise == null ||
                        paise <= 0 ||
                        selectedCategoryId == null) {
                      return;
                    }
                    final ok = await ref
                        .read(recurringProvider.notifier)
                        .createRecurring(
                          categoryId: selectedCategoryId!,
                          type: selectedType,
                          title: titleCtrl.text.trim(),
                          merchant: merchantCtrl.text.trim(),
                          amountPaise: paise,
                          paymentMethod: 'UPI',
                          frequency: selectedFrequency,
                          startDate: DateTime.now(),
                        );
                    if (ok && ctx.mounted) {
                      Navigator.of(ctx).pop();
                    }
                  },
                  child: const Text('Save Schedule'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recurringProvider);
    final dateFmt = DateFormat('dd MMM yyyy');
    final upcoming = state.items.where((i) => i.isUpcomingReminder).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring Schedules'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(recurringProvider.notifier).loadRecurring(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add_recurring_fab'),
        onPressed: () => _showCreateRecurringDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Recurring'),
      ),
      body: state.isLoading && state.items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : state.items.isEmpty
              ? const Center(
                  child: Text(
                    'No recurring schedules configured yet.\nTap + Add Recurring to automate rent, subscriptions, or salary.',
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                  children: [
                    if (upcoming.isNotEmpty) ...[
                      Card(
                        color: AppColors.warningSoft,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.notifications_active_outlined,
                                    color: AppColors.warningAmber,
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Upcoming Due Reminders',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.navyPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ...upcoming.map(
                                (u) => Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    '• ${u.title} (${MoneyUtils.formatPaise(u.amountPaise)}) due on ${dateFmt.format(u.nextOccurrence)}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.navyPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    ...state.items.map(
                      (item) => _buildRecurringCard(context, ref, item, dateFmt),
                    ),
                  ],
                ),
    );
  }

  Widget _buildRecurringCard(
    BuildContext context,
    WidgetRef ref,
    RecurringExpenseEntity item,
    DateFormat dateFmt,
  ) {
    final isIncome = item.type == 'INCOME';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(
          item.title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        subtitle: Text(
          '${item.categoryName} • ${item.frequency} • Next: ${dateFmt.format(item.nextOccurrence)}',
          style: const TextStyle(fontSize: 12, color: AppColors.lightTextSecondary),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${isIncome ? '+' : '-'}${MoneyUtils.formatPaise(item.amountPaise)}',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: isIncome ? AppColors.emeraldIncome : AppColors.expenseRed,
              ),
            ),
            const SizedBox(width: 6),
            Switch(
              key: Key('toggle_recurring_${item.id}'),
              value: item.isActive,
              onChanged: (val) =>
                  ref.read(recurringProvider.notifier).toggleActive(item.id, val),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Generated Transactions (${item.history.length})',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => ref
                          .read(recurringProvider.notifier)
                          .deleteRecurring(item.id),
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: AppColors.expenseRed,
                      ),
                      label: const Text(
                        'Delete Schedule',
                        style: TextStyle(color: AppColors.expenseRed),
                      ),
                    ),
                  ],
                ),
                if (item.history.isEmpty)
                  const Text(
                    'No occurrences generated yet.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.lightTextSecondary,
                    ),
                  )
                else
                  ...item.history.map(
                    (h) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            dateFmt.format(h.transactionDate),
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            MoneyUtils.formatPaise(h.amountPaise),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

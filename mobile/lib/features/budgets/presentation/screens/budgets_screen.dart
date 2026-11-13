import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/money_utils.dart';
import '../../../categories/domain/entities/category_entity.dart';
import '../../../transactions/presentation/providers/transactions_provider.dart';
import '../../domain/entities/budget_entity.dart';
import '../providers/budgets_provider.dart';

class BudgetsScreen extends ConsumerStatefulWidget {
  const BudgetsScreen({super.key});

  @override
  ConsumerState<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends ConsumerState<BudgetsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(budgetsNotifierProvider.notifier).loadBudgets();
      ref.read(transactionsNotifierProvider.notifier).loadInitialData();
    });
  }

  Future<void> _showBudgetDialog({BudgetEntity? existing}) async {
    final amountController = TextEditingController(
      text: existing != null ? '${existing.budgetPaise ~/ 100}' : '',
    );
    String? selectedCategoryId = existing?.categoryId;
    final expenseCategories = ref
        .read(transactionsNotifierProvider)
        .categoriesForType('EXPENSE');

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(existing != null ? 'Edit Budget' : 'Set Monthly Budget'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String?>(
                  key: const Key('budget_category_dropdown'),
                  value: selectedCategoryId,
                  decoration: const InputDecoration(
                    labelText: 'Budget Scope',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Overall Monthly Budget'),
                    ),
                    ...expenseCategories.map(
                      (CategoryEntity c) => DropdownMenuItem<String?>(
                        value: c.id,
                        child: Text(c.name),
                      ),
                    ),
                  ],
                  onChanged: existing != null
                      ? null
                      : (val) => setDialogState(() => selectedCategoryId = val),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  key: const Key('budget_amount_field'),
                  controller: amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Monthly Limit (₹)',
                    prefixIcon: Icon(Icons.currency_rupee_rounded),
                    hintText: 'e.g. 5000',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                key: const Key('budget_save_button'),
                onPressed: () async {
                  try {
                    final paise =
                        MoneyUtils.parseRupeesToPaise(amountController.text);
                    final ok = await ref
                        .read(budgetsNotifierProvider.notifier)
                        .saveBudget(
                          amountPaise: paise,
                          categoryId: selectedCategoryId,
                        );
                    if (ok && dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  } catch (_) {
                    if (dialogContext.mounted) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a valid positive budget amount'),
                        ),
                      );
                    }
                  }
                },
                child: const Text('Save Budget'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final budgetsState = ref.watch(budgetsNotifierProvider);
    final monthDate =
        DateTime(budgetsState.selectedYear, budgetsState.selectedMonth, 1);
    final monthLabel = DateFormat('MMMM yyyy').format(monthDate);
    final overview = budgetsState.overview;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(budgetsNotifierProvider.notifier).loadBudgets(),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            // Month Switcher
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: () => ref
                          .read(budgetsNotifierProvider.notifier)
                          .changeMonth(-1),
                    ),
                    Text(
                      monthLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: () => ref
                          .read(budgetsNotifierProvider.notifier)
                          .changeMonth(1),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            if (budgetsState.isLoading && overview == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (overview != null) ...[
              if (overview.overallBudget != null) ...[
                _BudgetCard(
                  budget: overview.overallBudget!,
                  onEdit: () =>
                      _showBudgetDialog(existing: overview.overallBudget),
                  onDelete: () => ref
                      .read(budgetsNotifierProvider.notifier)
                      .deleteBudget(overview.overallBudget!.id),
                ),
                const SizedBox(height: AppSpacing.md),
              ] else
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.indigoSoft,
                      child: Icon(
                        Icons.account_balance_wallet_outlined,
                        color: AppColors.indigoAccent,
                      ),
                    ),
                    title: const Text(
                      'No Overall Monthly Budget Set',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'Set an overall cap to get 50%, 75%, 90% and 100% alerts.',
                    ),
                    trailing: TextButton(
                      onPressed: () => _showBudgetDialog(),
                      child: const Text('Set Now'),
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Category Budgets',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (overview.categoryBudgets.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: Center(
                      child: Text(
                        'No category-specific budgets configured for this month.',
                        style: TextStyle(color: AppColors.lightTextSecondary),
                      ),
                    ),
                  ),
                )
              else
                ...overview.categoryBudgets.map(
                  (b) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _BudgetCard(
                      budget: b,
                      onEdit: () => _showBudgetDialog(existing: b),
                      onDelete: () => ref
                          .read(budgetsNotifierProvider.notifier)
                          .deleteBudget(b.id),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add_budget_fab'),
        onPressed: () => _showBudgetDialog(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Set Budget'),
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({
    required this.budget,
    required this.onEdit,
    required this.onDelete,
  });

  final BudgetEntity budget;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final Color statusColor = budget.utilizationPercentage >= 90
        ? AppColors.expenseRed
        : budget.utilizationPercentage >= 75
            ? AppColors.warningAmber
            : AppColors.emeraldIncome;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: budget.color.withValues(alpha: 0.14),
                  child: Icon(Icons.pie_chart_rounded, color: budget.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        budget.categoryName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Limit: ${MoneyUtils.formatPaise(budget.budgetPaise, includeDecimals: false)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${budget.utilizationPercentage}% (${budget.alertLevel})',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: AppColors.expenseRed,
                  ),
                  onPressed: onDelete,
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: (budget.utilizationPercentage.clamp(0, 100)) / 100.0,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
              color: statusColor,
              backgroundColor: AppColors.lightBorder,
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Spent: ${MoneyUtils.formatPaise(budget.spentPaise)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  budget.remainingPaise >= 0
                      ? 'Remaining: ${MoneyUtils.formatPaise(budget.remainingPaise)}'
                      : 'Over by: ${MoneyUtils.formatPaise(-budget.remainingPaise)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: budget.remainingPaise >= 0
                        ? AppColors.lightTextPrimary
                        : AppColors.expenseRed,
                  ),
                ),
              ],
            ),
            if (budget.highestReachedThreshold != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: statusColor,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Alert: Crossed ${budget.highestReachedThreshold}% utilization threshold',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (budget.previousMonthSpentPaise > 0) ...[
              const SizedBox(height: 4),
              Text(
                'Last month: ${MoneyUtils.formatPaise(budget.previousMonthSpentPaise, includeDecimals: false)} (${budget.monthOverMonthChangePercentage >= 0 ? '+' : ''}${budget.monthOverMonthChangePercentage}% MoM)',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.lightTextSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

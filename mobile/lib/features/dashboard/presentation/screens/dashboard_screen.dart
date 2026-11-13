import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/money_utils.dart';
import '../../domain/entities/dashboard_overview_entity.dart';
import '../providers/dashboard_provider.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(dashboardNotifierProvider.notifier).loadOverview();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dashState = ref.watch(dashboardNotifierProvider);
    final monthDate = DateTime(dashState.selectedYear, dashState.selectedMonth, 1);
    final monthLabel = DateFormat('MMMM yyyy').format(monthDate);
    final overview = dashState.overview;

    return RefreshIndicator(
      onRefresh: () => ref.read(dashboardNotifierProvider.notifier).loadOverview(),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // Month Switcher Bar
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
                    key: const Key('dashboard_prev_month_btn'),
                    tooltip: 'Previous Month',
                    icon: const Icon(Icons.chevron_left_rounded),
                    onPressed: () {
                      ref.read(dashboardNotifierProvider.notifier).changeMonth(-1);
                    },
                  ),
                  Text(
                    monthLabel,
                    key: const Key('dashboard_month_label'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    key: const Key('dashboard_next_month_btn'),
                    tooltip: 'Next Month',
                    icon: const Icon(Icons.chevron_right_rounded),
                    onPressed: () {
                      ref.read(dashboardNotifierProvider.notifier).changeMonth(1);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          if (dashState.isLoading && overview == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 64),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (dashState.errorMessage != null && overview == null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.expenseRed,
                      size: 40,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      dashState.errorMessage!,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        ref.read(dashboardNotifierProvider.notifier).loadOverview();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else if (overview != null) ...[
            _HeroFinancialSummaryCard(overview: overview),
            const SizedBox(height: AppSpacing.md),
            _MonthlySpendingChartCard(overview: overview),
            const SizedBox(height: AppSpacing.md),
            _CategoryBreakdownCard(items: overview.categoryBreakdown),
            const SizedBox(height: AppSpacing.md),
            _BudgetUtilizationCard(items: overview.budgetUtilization),
            const SizedBox(height: AppSpacing.md),
            _UpcomingRecurringCard(items: overview.upcomingRecurring),
            const SizedBox(height: AppSpacing.md),
            _RecentTransactionsCard(overview: overview),
          ],
        ],
      ),
    );
  }
}

class _HeroFinancialSummaryCard extends StatelessWidget {
  const _HeroFinancialSummaryCard({required this.overview});

  final DashboardOverviewEntity overview;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.navyPrimary, AppColors.indigoAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Net Monthly Savings',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Savings Rate: ${overview.savingsRatePercentage}%',
                  key: const Key('dashboard_savings_rate_chip'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            MoneyUtils.formatPaise(overview.currentSavingsPaise),
            key: const Key('dashboard_net_savings_text'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Total Income',
                  value: MoneyUtils.formatPaise(
                    overview.totalIncomePaise,
                    includeDecimals: false,
                  ),
                  icon: Icons.south_west_rounded,
                  iconColor: AppColors.emeraldIncome,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricTile(
                  label: 'Total Expenses',
                  value: MoneyUtils.formatPaise(
                    overview.totalExpensePaise,
                    includeDecimals: false,
                  ),
                  icon: Icons.north_east_rounded,
                  iconColor: AppColors.expenseRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  overview.overallBudgetPaise > 0
                      ? 'Remaining Budget (${overview.budgetUtilizationPercentage}% used)'
                      : 'No Overall Monthly Budget Set',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                Text(
                  MoneyUtils.formatPaise(
                    overview.remainingBudgetPaise,
                    includeDecimals: false,
                  ),
                  key: const Key('dashboard_remaining_budget_text'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
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

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: iconColor.withValues(alpha: 0.2),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
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

class _MonthlySpendingChartCard extends StatelessWidget {
  const _MonthlySpendingChartCard({required this.overview});

  final DashboardOverviewEntity overview;

  @override
  Widget build(BuildContext context) {
    final activePoints = overview.dailySpendingSeries
        .where((p) => p.expensePaise > 0 || p.incomePaise > 0)
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Monthly Spending Activity',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'Daily expenses vs income for selected month',
              style: TextStyle(fontSize: 12, color: AppColors.lightTextSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            if (activePoints.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No spending data recorded for this month yet.',
                    style: TextStyle(color: AppColors.lightTextSecondary),
                  ),
                ),
              )
            else
              SizedBox(
                height: 180,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    borderData: FlBorderData(show: false),
                    gridData: const FlGridData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (val, _) => Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'D${val.toInt()}',
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        ),
                      ),
                    ),
                    barGroups: activePoints.take(10).map((point) {
                      final expenseRupees = (point.expensePaise ~/ 100).toDouble();
                      return BarChartGroupData(
                        x: point.day,
                        barRods: [
                          BarChartRodData(
                            toY: expenseRupees > 0 ? expenseRupees : 10,
                            color: AppColors.indigoAccent,
                            width: 12,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoryBreakdownCard extends StatelessWidget {
  const _CategoryBreakdownCard({required this.items});

  final List<CategoryExpenseSummary> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Category-Wise Expense Breakdown',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.md),
            if (items.isEmpty)
              const Text(
                'No expenses categorized this month.',
                style: TextStyle(color: AppColors.lightTextSecondary),
              )
            else
              ...items.map(
                (cat) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: cat.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${cat.categoryName} (${cat.percentage}%)',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          Text(
                            MoneyUtils.formatPaise(cat.amountPaise),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: (cat.percentage.clamp(0, 100)) / 100.0,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(4),
                        color: cat.color,
                        backgroundColor: AppColors.lightBorder,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BudgetUtilizationCard extends StatelessWidget {
  const _BudgetUtilizationCard({required this.items});

  final List<BudgetUtilizationItem> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Budget Utilization Indicators',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.md),
            if (items.isEmpty)
              const Text(
                'No category budgets configured for this month.',
                style: TextStyle(color: AppColors.lightTextSecondary),
              )
            else
              ...items.map((b) {
                final Color barColor = b.utilizationPercentage >= 90
                    ? AppColors.expenseRed
                    : b.utilizationPercentage >= 75
                        ? AppColors.warningAmber
                        : AppColors.emeraldIncome;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            b.categoryName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${MoneyUtils.formatPaise(b.spentPaise, includeDecimals: false)} / ${MoneyUtils.formatPaise(b.budgetPaise, includeDecimals: false)} (${b.utilizationPercentage}%)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: barColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: (b.utilizationPercentage.clamp(0, 100)) / 100.0,
                        minHeight: 7,
                        borderRadius: BorderRadius.circular(4),
                        color: barColor,
                        backgroundColor: AppColors.lightBorder,
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _UpcomingRecurringCard extends StatelessWidget {
  const _UpcomingRecurringCard({required this.items});

  final List<UpcomingRecurringItem> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Upcoming Recurring Payments',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (items.isEmpty)
              const Text(
                'No upcoming recurring payments scheduled.',
                style: TextStyle(color: AppColors.lightTextSecondary),
              )
            else
              ...items.map(
                (item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.indigoSoft,
                    child: Icon(
                      Icons.event_repeat_rounded,
                      color: AppColors.indigoAccent,
                    ),
                  ),
                  title: Text(
                    item.title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Due ${DateFormat('dd MMM yyyy').format(item.nextOccurrence.toLocal())} • ${item.frequency}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Text(
                    MoneyUtils.formatPaise(item.amountPaise),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RecentTransactionsCard extends StatelessWidget {
  const _RecentTransactionsCard({required this.overview});

  final DashboardOverviewEntity overview;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Transactions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (overview.recentTransactions.isEmpty)
              const Text(
                'No transactions in this period.',
                style: TextStyle(color: AppColors.lightTextSecondary),
              )
            else
              ...overview.recentTransactions.map(
                (tx) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: tx.category.color.withValues(alpha: 0.14),
                    child: Icon(tx.category.iconData, color: tx.category.color),
                  ),
                  title: Text(
                    tx.description,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${tx.category.name} • ${DateFormat('dd MMM').format(tx.transactionDate.toLocal())}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Text(
                    '${tx.isExpense ? '-' : '+'}${MoneyUtils.formatPaise(tx.amountPaise)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: tx.isExpense
                          ? AppColors.expenseRed
                          : AppColors.emeraldIncome,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

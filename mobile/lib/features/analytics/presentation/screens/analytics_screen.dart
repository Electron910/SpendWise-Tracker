import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/money_utils.dart';
import '../../domain/entities/analytics_entities.dart';
import '../providers/analytics_provider.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  static const _periods = <MapEntry<String, String>>[
    MapEntry('THIS_WEEK', 'This Week'),
    MapEntry('THIS_MONTH', 'This Month'),
    MapEntry('PREVIOUS_MONTH', 'Prev Month'),
    MapEntry('LAST_3_MONTHS', 'Last 3M'),
    MapEntry('LAST_6_MONTHS', 'Last 6M'),
    MapEntry('CUSTOM', 'Custom'),
  ];

  Color _parseColor(String hex) {
    final cleaned = hex.replaceFirst('#', '');
    if (cleaned.length == 6) {
      return Color(int.parse('FF$cleaned', radix: 16));
    }
    return AppColors.indigoAccent;
  }

  Future<void> _selectCustomRange(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2022),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: DateTimeRange(
        start: now.subtract(const Duration(days: 30)),
        end: now,
      ),
    );
    if (picked != null) {
      await ref.read(analyticsProvider.notifier).selectPeriod(
            'CUSTOM',
            customStart: picked.start,
            customEnd: picked.end,
          );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(analyticsProvider);
    final bundle = state.bundle;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh analytics',
            onPressed: () => ref.read(analyticsProvider.notifier).loadAnalytics(),
          ),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: _periods.map((entry) {
                final isSelected = state.selectedPeriod == entry.key;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    key: Key('analytics_period_${entry.key}'),
                    label: Text(entry.value),
                    selected: isSelected,
                    onSelected: (_) {
                      if (entry.key == 'CUSTOM') {
                        _selectCustomRange(context, ref);
                      } else {
                        ref.read(analyticsProvider.notifier).selectPeriod(entry.key);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: state.isLoading && bundle == null
                ? const Center(child: CircularProgressIndicator())
                : bundle == null
                    ? Center(
                        child: Text(state.errorMessage ?? 'No analytics data available.'),
                      )
                    : RefreshIndicator(
                        onRefresh: () =>
                            ref.read(analyticsProvider.notifier).loadAnalytics(),
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                          children: [
                            _buildSummarySection(bundle),
                            const SizedBox(height: 16),
                            _buildHighlightsRow(bundle),
                            const SizedBox(height: 20),
                            _buildMonthlyIncomeVsExpenseCard(bundle.monthlySeries),
                            const SizedBox(height: 20),
                            _buildCategoryDistributionCard(bundle.categories),
                            const SizedBox(height: 20),
                            _buildDailyTrendCard(bundle.dailyTrend),
                            const SizedBox(height: 20),
                            _buildWeeklyTrendCard(bundle.weeklyTrend),
                            const SizedBox(height: 20),
                            _buildSavingsTrendCard(bundle.monthlySeries),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection(FinancialAnalyticsBundle bundle) {
    final momSign = bundle.monthOverMonthChangePercentage > 0 ? '+' : '';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  bundle.periodLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.indigoAccent,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: bundle.monthOverMonthChangePercentage > 0
                        ? AppColors.expenseRed.withValues(alpha: 0.12)
                        : AppColors.emeraldIncome.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$momSign${bundle.monthOverMonthChangePercentage}% vs prev period',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: bundle.monthOverMonthChangePercentage > 0
                          ? AppColors.expenseRed
                          : AppColors.emeraldIncome,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _SummaryMetricTile(
                    label: 'Total Income',
                    value: MoneyUtils.formatPaise(bundle.totalIncomePaise),
                    color: AppColors.emeraldIncome,
                  ),
                ),
                Expanded(
                  child: _SummaryMetricTile(
                    label: 'Total Expenses',
                    value: MoneyUtils.formatPaise(bundle.totalExpensePaise),
                    color: AppColors.expenseRed,
                  ),
                ),
                Expanded(
                  child: _SummaryMetricTile(
                    label: 'Net Savings',
                    value: MoneyUtils.formatPaise(bundle.netSavingsPaise),
                    color: bundle.netSavingsPaise >= 0
                        ? AppColors.indigoAccent
                        : AppColors.expenseRed,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightsRow(FinancialAnalyticsBundle bundle) {
    return Row(
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Highest Category',
                    style: TextStyle(fontSize: 12, color: AppColors.lightTextSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    bundle.highestSpendingCategoryName ?? 'N/A',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (bundle.highestSpendingCategoryAmountPaise != null)
                    Text(
                      MoneyUtils.formatPaise(bundle.highestSpendingCategoryAmountPaise!),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.expenseRed,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Avg Daily Spend',
                    style: TextStyle(fontSize: 12, color: AppColors.lightTextSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    MoneyUtils.formatPaise(bundle.averageDailySpendingPaise),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const Text(
                    'per day',
                    style: TextStyle(fontSize: 12, color: AppColors.lightTextSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Biggest Expense',
                    style: TextStyle(fontSize: 12, color: AppColors.lightTextSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    bundle.biggestExpenseDescription ?? 'N/A',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (bundle.biggestExpenseAmountPaise != null)
                    Text(
                      MoneyUtils.formatPaise(bundle.biggestExpenseAmountPaise!),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.expenseRed,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMonthlyIncomeVsExpenseCard(List<MonthlySeriesPoint> series) {
    var maxPaise = 100000;
    for (final s in series) {
      if (s.incomePaise > maxPaise) maxPaise = s.incomePaise;
      if (s.expensePaise > maxPaise) maxPaise = s.expensePaise;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Monthly Income vs Expenses',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  maxY: (maxPaise / 100).ceilToDouble() * 1.15,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= series.length) return const SizedBox.shrink();
                          final shortLabel = series[idx].label.split(' ').first;
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(shortLabel, style: const TextStyle(fontSize: 11)),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: List.generate(series.length, (i) {
                    final pt = series[i];
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: pt.incomePaise / 100.0,
                          color: AppColors.emeraldIncome,
                          width: 9,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        BarChartRodData(
                          toY: pt.expensePaise / 100.0,
                          color: AppColors.expenseRed,
                          width: 9,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryDistributionCard(List<CategoryDistributionPoint> categories) {
    if (categories.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No category expenses recorded for this period.'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Category-Wise Expense Distribution',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 190,
              child: PieChart(
                PieChartData(
                  centerSpaceRadius: 42,
                  sectionsSpace: 2,
                  sections: categories.map((cat) {
                    final value = cat.amountPaise / 100.0;
                    return PieChartSectionData(
                      value: value <= 0 ? 1 : value,
                      color: _parseColor(cat.colorHex),
                      title: '${cat.percentage}%',
                      radius: 48,
                      titleStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...categories.map(
              (c) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _parseColor(c.colorHex),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${c.categoryName} (${c.transactionCount})',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    Text(
                      '${MoneyUtils.formatPaise(c.amountPaise)} (${c.percentage}%)',
                      style: const TextStyle(fontWeight: FontWeight.w700),
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

  Widget _buildDailyTrendCard(List<DailyTrendPoint> dailyTrend) {
    final spots = <FlSpot>[];
    for (var i = 0; i < dailyTrend.length; i++) {
      spots.add(FlSpot(i.toDouble(), dailyTrend[i].expensePaise / 100.0));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daily Spending Trend',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 170,
              child: spots.isEmpty
                  ? const Center(child: Text('No daily activity in selected period'))
                  : LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        titlesData: const FlTitlesData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            color: AppColors.indigoAccent,
                            barWidth: 3,
                            dotData: const FlDotData(show: true),
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

  Widget _buildWeeklyTrendCard(List<WeeklyTrendPoint> weeklyTrend) {
    var maxPaise = 100000;
    for (final w in weeklyTrend) {
      if (w.expensePaise > maxPaise) maxPaise = w.expensePaise;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Weekly Spending Trend',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: weeklyTrend.isEmpty
                  ? const Center(child: Text('No weekly data in selected period'))
                  : BarChart(
                      BarChartData(
                        maxY: (maxPaise / 100.0) * 1.2,
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (val, meta) {
                                final idx = val.toInt();
                                if (idx < 0 || idx >= weeklyTrend.length) {
                                  return const SizedBox.shrink();
                                }
                                return Text(
                                  weeklyTrend[idx].weekLabel,
                                  style: const TextStyle(fontSize: 11),
                                );
                              },
                            ),
                          ),
                        ),
                        barGroups: List.generate(weeklyTrend.length, (i) {
                          return BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: weeklyTrend[i].expensePaise / 100.0,
                                color: AppColors.warningAmber,
                                width: 14,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ],
                          );
                        }),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavingsTrendCard(List<MonthlySeriesPoint> series) {
    final spots = List.generate(
      series.length,
      (i) => FlSpot(i.toDouble(), series[i].savingsPaise / 100.0),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Monthly Net Savings Trend',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: spots.isEmpty
                  ? const Center(child: Text('No savings history available'))
                  : LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        titlesData: const FlTitlesData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            color: AppColors.emeraldIncome,
                            barWidth: 3,
                            dotData: const FlDotData(show: true),
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

class _SummaryMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryMetricTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.lightTextSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            color: color,
          ),
        ),
      ],
    );
  }
}

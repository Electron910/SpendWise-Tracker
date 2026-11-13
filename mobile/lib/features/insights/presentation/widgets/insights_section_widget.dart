import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/financial_insight_entity.dart';
import '../providers/insights_provider.dart';

class InsightsSectionWidget extends ConsumerWidget {
  const InsightsSectionWidget({super.key});

  Color _severityColor(String severity) {
    switch (severity) {
      case 'CRITICAL':
        return AppColors.expenseRed;
      case 'WARNING':
        return AppColors.warningAmber;
      case 'POSITIVE':
        return AppColors.emeraldIncome;
      default:
        return AppColors.indigoAccent;
    }
  }

  IconData _severityIcon(String severity) {
    switch (severity) {
      case 'CRITICAL':
        return Icons.error_outline_rounded;
      case 'WARNING':
        return Icons.trending_up_rounded;
      case 'POSITIVE':
        return Icons.trending_down_rounded;
      default:
        return Icons.lightbulb_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(insightsProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.auto_graph_rounded, color: AppColors.indigoAccent, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Deterministic Financial Insights',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  tooltip: 'Refresh insights',
                  onPressed: () => ref.read(insightsProvider.notifier).loadInsights(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (state.isLoading && state.insights.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.insights.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No spending insights available yet for this period.',
                  style: TextStyle(color: AppColors.lightTextSecondary),
                ),
              )
            else
              ...state.insights.map((insight) => _buildInsightTile(insight)),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightTile(FinancialInsightEntity insight) {
    final color = _severityColor(insight.severity);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_severityIcon(insight.severity), color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  insight.title,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 30),
            child: Text(
              'Why: ${insight.explanation}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.lightTextSecondary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

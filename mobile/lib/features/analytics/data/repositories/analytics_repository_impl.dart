import 'package:dio/dio.dart';

import '../../domain/entities/analytics_entities.dart';

class AnalyticsRepositoryImpl {
  final Dio _dio;

  AnalyticsRepositoryImpl(this._dio);

  Future<FinancialAnalyticsBundle> fetchAnalyticsBundle({
    required String period,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final queryParams = <String, dynamic>{
      'period': period,
      if (startDate != null) 'startDate': startDate.toUtc().toIso8601String(),
      if (endDate != null) 'endDate': endDate.toUtc().toIso8601String(),
    };

    final results = await Future.wait([
      _dio.get('/analytics/monthly', queryParameters: {'months': 6}),
      _dio.get('/analytics/categories', queryParameters: queryParams),
      _dio.get('/analytics/trends', queryParameters: queryParams),
    ]);

    final monthlyData = results[0].data['data'] as Map<String, dynamic>;
    final categoriesData = results[1].data['data'] as Map<String, dynamic>;
    final trendsData = results[2].data['data'] as Map<String, dynamic>;

    final summary = trendsData['summary'] as Map<String, dynamic>;
    final periodInfo = trendsData['period'] as Map<String, dynamic>;

    final highestCat = summary['highestSpendingCategory'] as Map<String, dynamic>?;
    final biggestExp = summary['biggestExpense'] as Map<String, dynamic>?;

    return FinancialAnalyticsBundle(
      periodLabel: periodInfo['label'] as String? ?? period,
      totalIncomePaise: int.parse(summary['totalIncomePaise'].toString()),
      totalExpensePaise: int.parse(summary['totalExpensePaise'].toString()),
      netSavingsPaise: int.parse(summary['netSavingsPaise'].toString()),
      averageDailySpendingPaise: int.parse(summary['averageDailySpendingPaise'].toString()),
      monthOverMonthChangePercentage:
          (summary['monthOverMonthChangePercentage'] as num?)?.toInt() ?? 0,
      highestSpendingCategoryName:
          highestCat?['categoryName'] as String? ?? highestCat?['name'] as String?,
      highestSpendingCategoryAmountPaise: highestCat != null
          ? int.parse(highestCat['amountPaise'].toString())
          : null,
      biggestExpenseDescription: biggestExp?['description'] as String?,
      biggestExpenseAmountPaise: biggestExp != null
          ? int.parse(biggestExp['amountPaise'].toString())
          : null,
      monthlySeries: (monthlyData['series'] as List<dynamic>)
          .map((e) => MonthlySeriesPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      categories: (categoriesData['categories'] as List<dynamic>)
          .map((e) => CategoryDistributionPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      dailyTrend: (trendsData['dailyTrend'] as List<dynamic>)
          .map((e) => DailyTrendPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      weeklyTrend: (trendsData['weeklyTrend'] as List<dynamic>)
          .map((e) => WeeklyTrendPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

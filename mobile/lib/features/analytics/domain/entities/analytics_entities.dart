class MonthlySeriesPoint {
  final int month;
  final int year;
  final String label;
  final int incomePaise;
  final int expensePaise;
  final int savingsPaise;
  final int savingsRatePercentage;
  final int momExpenseChangePercentage;

  const MonthlySeriesPoint({
    required this.month,
    required this.year,
    required this.label,
    required this.incomePaise,
    required this.expensePaise,
    required this.savingsPaise,
    required this.savingsRatePercentage,
    required this.momExpenseChangePercentage,
  });

  factory MonthlySeriesPoint.fromJson(Map<String, dynamic> json) {
    return MonthlySeriesPoint(
      month: (json['month'] as num).toInt(),
      year: (json['year'] as num).toInt(),
      label: json['label'] as String? ?? '',
      incomePaise: int.parse(json['incomePaise'].toString()),
      expensePaise: int.parse(json['expensePaise'].toString()),
      savingsPaise: int.parse(json['savingsPaise'].toString()),
      savingsRatePercentage: (json['savingsRatePercentage'] as num?)?.toInt() ?? 0,
      momExpenseChangePercentage: (json['momExpenseChangePercentage'] as num?)?.toInt() ?? 0,
    );
  }
}

class CategoryDistributionPoint {
  final String categoryId;
  final String categoryName;
  final String colorHex;
  final String icon;
  final int amountPaise;
  final int percentage;
  final int transactionCount;

  const CategoryDistributionPoint({
    required this.categoryId,
    required this.categoryName,
    required this.colorHex,
    required this.icon,
    required this.amountPaise,
    required this.percentage,
    required this.transactionCount,
  });

  factory CategoryDistributionPoint.fromJson(Map<String, dynamic> json) {
    return CategoryDistributionPoint(
      categoryId: json['categoryId'] as String,
      categoryName: json['categoryName'] as String,
      colorHex: json['colorHex'] as String? ?? '#4F46E5',
      icon: json['icon'] as String? ?? 'category',
      amountPaise: int.parse(json['amountPaise'].toString()),
      percentage: (json['percentage'] as num).toInt(),
      transactionCount: (json['transactionCount'] as num).toInt(),
    );
  }
}

class DailyTrendPoint {
  final String date;
  final int incomePaise;
  final int expensePaise;

  const DailyTrendPoint({
    required this.date,
    required this.incomePaise,
    required this.expensePaise,
  });

  factory DailyTrendPoint.fromJson(Map<String, dynamic> json) {
    return DailyTrendPoint(
      date: json['date'] as String,
      incomePaise: int.parse(json['incomePaise'].toString()),
      expensePaise: int.parse(json['expensePaise'].toString()),
    );
  }
}

class WeeklyTrendPoint {
  final String weekLabel;
  final int incomePaise;
  final int expensePaise;

  const WeeklyTrendPoint({
    required this.weekLabel,
    required this.incomePaise,
    required this.expensePaise,
  });

  factory WeeklyTrendPoint.fromJson(Map<String, dynamic> json) {
    return WeeklyTrendPoint(
      weekLabel: json['weekLabel'] as String,
      incomePaise: int.parse(json['incomePaise'].toString()),
      expensePaise: int.parse(json['expensePaise'].toString()),
    );
  }
}

class FinancialAnalyticsBundle {
  final String periodLabel;
  final int totalIncomePaise;
  final int totalExpensePaise;
  final int netSavingsPaise;
  final int averageDailySpendingPaise;
  final int monthOverMonthChangePercentage;
  final String? highestSpendingCategoryName;
  final int? highestSpendingCategoryAmountPaise;
  final String? biggestExpenseDescription;
  final int? biggestExpenseAmountPaise;
  final List<MonthlySeriesPoint> monthlySeries;
  final List<CategoryDistributionPoint> categories;
  final List<DailyTrendPoint> dailyTrend;
  final List<WeeklyTrendPoint> weeklyTrend;

  const FinancialAnalyticsBundle({
    required this.periodLabel,
    required this.totalIncomePaise,
    required this.totalExpensePaise,
    required this.netSavingsPaise,
    required this.averageDailySpendingPaise,
    required this.monthOverMonthChangePercentage,
    this.highestSpendingCategoryName,
    this.highestSpendingCategoryAmountPaise,
    this.biggestExpenseDescription,
    this.biggestExpenseAmountPaise,
    required this.monthlySeries,
    required this.categories,
    required this.dailyTrend,
    required this.weeklyTrend,
  });
}

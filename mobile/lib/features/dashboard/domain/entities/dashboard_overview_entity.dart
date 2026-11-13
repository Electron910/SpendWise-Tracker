import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';

class CategoryExpenseSummary extends Equatable {
  const CategoryExpenseSummary({
    required this.categoryId,
    required this.categoryName,
    required this.colorHex,
    required this.icon,
    required this.amountPaise,
    required this.percentage,
    required this.transactionCount,
  });

  final String categoryId;
  final String categoryName;
  final String colorHex;
  final String icon;
  final int amountPaise;
  final int percentage;
  final int transactionCount;

  Color get color {
    final cleaned = colorHex.replaceFirst('#', '');
    final value = int.tryParse('FF$cleaned', radix: 16) ?? 0xFF4F46E5;
    return Color(value);
  }

  factory CategoryExpenseSummary.fromJson(Map<String, dynamic> json) {
    return CategoryExpenseSummary(
      categoryId: json['categoryId'] as String,
      categoryName: json['categoryName'] as String,
      colorHex: (json['colorHex'] as String?) ?? '#4F46E5',
      icon: (json['icon'] as String?) ?? 'category',
      amountPaise: int.parse(json['amountPaise'].toString()),
      percentage: (json['percentage'] as num).toInt(),
      transactionCount: (json['transactionCount'] as num).toInt(),
    );
  }

  @override
  List<Object?> get props => [
        categoryId,
        categoryName,
        colorHex,
        icon,
        amountPaise,
        percentage,
        transactionCount,
      ];
}

class BudgetUtilizationItem extends Equatable {
  const BudgetUtilizationItem({
    required this.budgetId,
    required this.categoryName,
    required this.colorHex,
    required this.budgetPaise,
    required this.spentPaise,
    required this.remainingPaise,
    required this.utilizationPercentage,
    required this.alertLevel,
    this.categoryId,
  });

  final String budgetId;
  final String? categoryId;
  final String categoryName;
  final String colorHex;
  final int budgetPaise;
  final int spentPaise;
  final int remainingPaise;
  final int utilizationPercentage;
  final String alertLevel;

  factory BudgetUtilizationItem.fromJson(Map<String, dynamic> json) {
    return BudgetUtilizationItem(
      budgetId: json['budgetId'] as String,
      categoryId: json['categoryId'] as String?,
      categoryName: json['categoryName'] as String,
      colorHex: (json['colorHex'] as String?) ?? '#4F46E5',
      budgetPaise: int.parse(json['budgetPaise'].toString()),
      spentPaise: int.parse(json['spentPaise'].toString()),
      remainingPaise: int.parse(json['remainingPaise'].toString()),
      utilizationPercentage: (json['utilizationPercentage'] as num).toInt(),
      alertLevel: (json['alertLevel'] as String?) ?? 'SAFE',
    );
  }

  @override
  List<Object?> get props => [
        budgetId,
        categoryId,
        categoryName,
        budgetPaise,
        spentPaise,
        remainingPaise,
        utilizationPercentage,
        alertLevel,
      ];
}

class DailySpendingPoint extends Equatable {
  const DailySpendingPoint({
    required this.day,
    required this.incomePaise,
    required this.expensePaise,
  });

  final int day;
  final int incomePaise;
  final int expensePaise;

  factory DailySpendingPoint.fromJson(Map<String, dynamic> json) {
    return DailySpendingPoint(
      day: (json['day'] as num).toInt(),
      incomePaise: int.parse(json['incomePaise'].toString()),
      expensePaise: int.parse(json['expensePaise'].toString()),
    );
  }

  @override
  List<Object?> get props => [day, incomePaise, expensePaise];
}

class UpcomingRecurringItem extends Equatable {
  const UpcomingRecurringItem({
    required this.id,
    required this.title,
    required this.amountPaise,
    required this.frequency,
    required this.nextOccurrence,
    required this.categoryName,
    required this.colorHex,
    this.merchant,
  });

  final String id;
  final String title;
  final String? merchant;
  final int amountPaise;
  final String frequency;
  final DateTime nextOccurrence;
  final String categoryName;
  final String colorHex;

  factory UpcomingRecurringItem.fromJson(Map<String, dynamic> json) {
    return UpcomingRecurringItem(
      id: json['id'] as String,
      title: json['title'] as String,
      merchant: json['merchant'] as String?,
      amountPaise: int.parse(json['amountPaise'].toString()),
      frequency: json['frequency'] as String,
      nextOccurrence: DateTime.parse(json['nextOccurrence'] as String),
      categoryName: json['categoryName'] as String,
      colorHex: (json['colorHex'] as String?) ?? '#4F46E5',
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        merchant,
        amountPaise,
        frequency,
        nextOccurrence,
        categoryName,
      ];
}

class DashboardOverviewEntity extends Equatable {
  const DashboardOverviewEntity({
    required this.month,
    required this.year,
    required this.totalIncomePaise,
    required this.totalExpensePaise,
    required this.currentSavingsPaise,
    required this.savingsRatePercentage,
    required this.overallBudgetPaise,
    required this.remainingBudgetPaise,
    required this.budgetUtilizationPercentage,
    required this.categoryBreakdown,
    required this.budgetUtilization,
    required this.dailySpendingSeries,
    required this.recentTransactions,
    required this.upcomingRecurring,
  });

  final int month;
  final int year;
  final int totalIncomePaise;
  final int totalExpensePaise;
  final int currentSavingsPaise;
  final int savingsRatePercentage;
  final int overallBudgetPaise;
  final int remainingBudgetPaise;
  final int budgetUtilizationPercentage;
  final List<CategoryExpenseSummary> categoryBreakdown;
  final List<BudgetUtilizationItem> budgetUtilization;
  final List<DailySpendingPoint> dailySpendingSeries;
  final List<TransactionEntity> recentTransactions;
  final List<UpcomingRecurringItem> upcomingRecurring;

  factory DashboardOverviewEntity.fromJson(Map<String, dynamic> json) {
    final period = json['period'] as Map<String, dynamic>;
    final summary = json['summary'] as Map<String, dynamic>;
    final catList = (json['categoryBreakdown'] as List<dynamic>? ?? [])
        .map((e) => CategoryExpenseSummary.fromJson(e as Map<String, dynamic>))
        .toList();
    final budgetList = (json['budgetUtilization'] as List<dynamic>? ?? [])
        .map((e) => BudgetUtilizationItem.fromJson(e as Map<String, dynamic>))
        .toList();
    final dailyList = (json['dailySpendingSeries'] as List<dynamic>? ?? [])
        .map((e) => DailySpendingPoint.fromJson(e as Map<String, dynamic>))
        .toList();
    final recentList = (json['recentTransactions'] as List<dynamic>? ?? [])
        .map((e) => TransactionEntity.fromJson(e as Map<String, dynamic>))
        .toList();
    final recurringList = (json['upcomingRecurring'] as List<dynamic>? ?? [])
        .map((e) => UpcomingRecurringItem.fromJson(e as Map<String, dynamic>))
        .toList();

    return DashboardOverviewEntity(
      month: (period['month'] as num).toInt(),
      year: (period['year'] as num).toInt(),
      totalIncomePaise: int.parse(summary['totalIncomePaise'].toString()),
      totalExpensePaise: int.parse(summary['totalExpensePaise'].toString()),
      currentSavingsPaise: int.parse(summary['currentSavingsPaise'].toString()),
      savingsRatePercentage: (summary['savingsRatePercentage'] as num).toInt(),
      overallBudgetPaise: int.parse(summary['overallBudgetPaise'].toString()),
      remainingBudgetPaise:
          int.parse(summary['remainingBudgetPaise'].toString()),
      budgetUtilizationPercentage:
          (summary['budgetUtilizationPercentage'] as num).toInt(),
      categoryBreakdown: catList,
      budgetUtilization: budgetList,
      dailySpendingSeries: dailyList,
      recentTransactions: recentList,
      upcomingRecurring: recurringList,
    );
  }

  @override
  List<Object?> get props => [
        month,
        year,
        totalIncomePaise,
        totalExpensePaise,
        currentSavingsPaise,
        savingsRatePercentage,
        overallBudgetPaise,
        remainingBudgetPaise,
        budgetUtilizationPercentage,
        categoryBreakdown,
        budgetUtilization,
        dailySpendingSeries,
        recentTransactions,
        upcomingRecurring,
      ];
}

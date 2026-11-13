import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class BudgetEntity extends Equatable {
  const BudgetEntity({
    required this.id,
    required this.categoryName,
    required this.colorHex,
    required this.icon,
    required this.month,
    required this.year,
    required this.budgetPaise,
    required this.spentPaise,
    required this.remainingPaise,
    required this.previousMonthSpentPaise,
    required this.monthOverMonthChangePercentage,
    required this.utilizationPercentage,
    required this.alertThresholds,
    required this.reachedThresholds,
    required this.alertLevel,
    this.categoryId,
    this.highestReachedThreshold,
    this.version = 1,
  });

  final String id;
  final String? categoryId;
  final String categoryName;
  final String colorHex;
  final String icon;
  final int month;
  final int year;
  final int budgetPaise;
  final int spentPaise;
  final int remainingPaise;
  final int previousMonthSpentPaise;
  final int monthOverMonthChangePercentage;
  final int utilizationPercentage;
  final List<int> alertThresholds;
  final List<int> reachedThresholds;
  final int? highestReachedThreshold;
  final String alertLevel; // SAFE, MODERATE, WARNING, CRITICAL, EXCEEDED
  final int version;

  bool get isOverall => categoryId == null;

  Color get color {
    final cleaned = colorHex.replaceFirst('#', '');
    final value = int.tryParse('FF$cleaned', radix: 16) ?? 0xFF4F46E5;
    return Color(value);
  }

  factory BudgetEntity.fromJson(Map<String, dynamic> json) {
    return BudgetEntity(
      id: json['id'] as String,
      categoryId: json['categoryId'] as String?,
      categoryName: json['categoryName'] as String,
      colorHex: (json['colorHex'] as String?) ?? '#4F46E5',
      icon: (json['icon'] as String?) ?? 'category',
      month: (json['month'] as num).toInt(),
      year: (json['year'] as num).toInt(),
      budgetPaise: int.parse(json['budgetPaise'].toString()),
      spentPaise: int.parse(json['spentPaise'].toString()),
      remainingPaise: int.parse(json['remainingPaise'].toString()),
      previousMonthSpentPaise:
          int.parse((json['previousMonthSpentPaise'] ?? '0').toString()),
      monthOverMonthChangePercentage:
          (json['monthOverMonthChangePercentage'] as num? ?? 0).toInt(),
      utilizationPercentage: (json['utilizationPercentage'] as num).toInt(),
      alertThresholds: (json['alertThresholds'] as List<dynamic>? ?? [50, 75, 90, 100])
          .map((e) => (e as num).toInt())
          .toList(),
      reachedThresholds: (json['reachedThresholds'] as List<dynamic>? ?? [])
          .map((e) => (e as num).toInt())
          .toList(),
      highestReachedThreshold: json['highestReachedThreshold'] != null
          ? (json['highestReachedThreshold'] as num).toInt()
          : null,
      alertLevel: (json['alertLevel'] as String?) ?? 'SAFE',
      version: (json['version'] as num? ?? 1).toInt(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        categoryId,
        categoryName,
        month,
        year,
        budgetPaise,
        spentPaise,
        remainingPaise,
        previousMonthSpentPaise,
        monthOverMonthChangePercentage,
        utilizationPercentage,
        alertThresholds,
        reachedThresholds,
        highestReachedThreshold,
        alertLevel,
        version,
      ];
}

class MonthlyBudgetsOverview extends Equatable {
  const MonthlyBudgetsOverview({
    required this.month,
    required this.year,
    required this.totalMonthlyExpensePaise,
    required this.previousMonthExpensePaise,
    required this.categoryBudgets,
    this.overallBudget,
  });

  final int month;
  final int year;
  final int totalMonthlyExpensePaise;
  final int previousMonthExpensePaise;
  final BudgetEntity? overallBudget;
  final List<BudgetEntity> categoryBudgets;

  @override
  List<Object?> get props => [
        month,
        year,
        totalMonthlyExpensePaise,
        previousMonthExpensePaise,
        overallBudget,
        categoryBudgets,
      ];
}

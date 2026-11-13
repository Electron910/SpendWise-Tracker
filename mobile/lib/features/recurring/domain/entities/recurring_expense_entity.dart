class RecurringGeneratedHistoryItem {
  final String id;
  final int amountPaise;
  final DateTime transactionDate;
  final String description;

  const RecurringGeneratedHistoryItem({
    required this.id,
    required this.amountPaise,
    required this.transactionDate,
    required this.description,
  });

  factory RecurringGeneratedHistoryItem.fromJson(Map<String, dynamic> json) {
    return RecurringGeneratedHistoryItem(
      id: json['id'] as String,
      amountPaise: int.parse(json['amountPaise'].toString()),
      transactionDate: DateTime.parse(json['transactionDate'] as String),
      description: json['description'] as String? ?? '',
    );
  }
}

class RecurringExpenseEntity {
  final String id;
  final String categoryId;
  final String categoryName;
  final String categoryColorHex;
  final String categoryIcon;
  final String type; // EXPENSE | INCOME
  final String title;
  final String? merchant;
  final String? description;
  final int amountPaise;
  final String paymentMethod;
  final String frequency; // DAILY | WEEKLY | MONTHLY | YEARLY
  final int intervalCount;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime nextOccurrence;
  final DateTime? lastGeneratedAt;
  final bool isActive;
  final int reminderDays;
  final int daysUntilNext;
  final bool isUpcomingReminder;
  final List<RecurringGeneratedHistoryItem> history;

  const RecurringExpenseEntity({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.categoryColorHex,
    required this.categoryIcon,
    required this.type,
    required this.title,
    this.merchant,
    this.description,
    required this.amountPaise,
    required this.paymentMethod,
    required this.frequency,
    required this.intervalCount,
    required this.startDate,
    this.endDate,
    required this.nextOccurrence,
    this.lastGeneratedAt,
    required this.isActive,
    required this.reminderDays,
    required this.daysUntilNext,
    required this.isUpcomingReminder,
    this.history = const [],
  });

  factory RecurringExpenseEntity.fromJson(Map<String, dynamic> json) {
    return RecurringExpenseEntity(
      id: json['id'] as String,
      categoryId: json['categoryId'] as String,
      categoryName: json['categoryName'] as String? ?? 'Category',
      categoryColorHex: json['categoryColorHex'] as String? ?? '#4F46E5',
      categoryIcon: json['categoryIcon'] as String? ?? 'repeat',
      type: json['type'] as String? ?? 'EXPENSE',
      title: json['title'] as String,
      merchant: json['merchant'] as String?,
      description: json['description'] as String?,
      amountPaise: int.parse(json['amountPaise'].toString()),
      paymentMethod: json['paymentMethod'] as String? ?? 'UPI',
      frequency: json['frequency'] as String? ?? 'MONTHLY',
      intervalCount: (json['intervalCount'] as num?)?.toInt() ?? 1,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate:
          json['endDate'] != null ? DateTime.parse(json['endDate'] as String) : null,
      nextOccurrence: DateTime.parse(json['nextOccurrence'] as String),
      lastGeneratedAt: json['lastGeneratedAt'] != null
          ? DateTime.parse(json['lastGeneratedAt'] as String)
          : null,
      isActive: json['isActive'] as bool? ?? true,
      reminderDays: (json['reminderDays'] as num?)?.toInt() ?? 3,
      daysUntilNext: (json['daysUntilNext'] as num?)?.toInt() ?? 0,
      isUpcomingReminder: json['isUpcomingReminder'] as bool? ?? false,
      history: (json['history'] as List<dynamic>? ?? const [])
          .map(
            (e) =>
                RecurringGeneratedHistoryItem.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

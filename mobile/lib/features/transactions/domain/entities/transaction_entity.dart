import 'package:equatable/equatable.dart';
import '../../../categories/domain/entities/category_entity.dart';

class TransactionEntity extends Equatable {
  const TransactionEntity({
    required this.id,
    required this.categoryId,
    required this.type,
    required this.amountPaise,
    required this.currency,
    required this.description,
    required this.paymentMethod,
    required this.transactionDate,
    required this.category,
    this.merchant,
    this.notes,
    this.isAutoCategorized = false,
    this.categorizationConfidence,
    this.isDemoData = false,
    this.syncStatus = 'SYNCED',
    this.version = 1,
  });

  final String id;
  final String categoryId;
  final String type; // 'EXPENSE' | 'INCOME'
  final int amountPaise;
  final String currency;
  final String? merchant;
  final String description;
  final String? notes;
  final String paymentMethod;
  final DateTime transactionDate;
  final bool isAutoCategorized;
  final int? categorizationConfidence;
  final bool isDemoData;
  final String syncStatus;
  final int version;
  final CategoryEntity category;

  bool get isExpense => type == 'EXPENSE';
  bool get isIncome => type == 'INCOME';

  factory TransactionEntity.fromJson(Map<String, dynamic> json) {
    final rawPaise = json['amountPaise'];
    final parsedPaise = rawPaise is int
        ? rawPaise
        : int.parse(rawPaise.toString());

    return TransactionEntity(
      id: json['id'] as String,
      categoryId: json['categoryId'] as String,
      type: json['type'] as String,
      amountPaise: parsedPaise,
      currency: (json['currency'] as String?) ?? 'INR',
      merchant: json['merchant'] as String?,
      description: json['description'] as String,
      notes: json['notes'] as String?,
      paymentMethod: (json['paymentMethod'] as String?) ?? 'UPI',
      transactionDate: DateTime.parse(json['transactionDate'] as String),
      isAutoCategorized: (json['isAutoCategorized'] as bool?) ?? false,
      categorizationConfidence: json['categorizationConfidence'] as int?,
      isDemoData: (json['isDemoData'] as bool?) ?? false,
      syncStatus: (json['syncStatus'] as String?) ?? 'SYNCED',
      version: (json['version'] as int?) ?? 1,
      category: CategoryEntity.fromJson(
        json['category'] as Map<String, dynamic>,
      ),
    );
  }

  @override
  List<Object?> get props => [
        id,
        categoryId,
        type,
        amountPaise,
        currency,
        merchant,
        description,
        notes,
        paymentMethod,
        transactionDate,
        isAutoCategorized,
        categorizationConfidence,
        isDemoData,
        syncStatus,
        version,
        category,
      ];
}

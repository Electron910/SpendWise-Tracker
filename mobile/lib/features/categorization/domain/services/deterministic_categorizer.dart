import 'package:equatable/equatable.dart';
import '../../../categories/domain/entities/category_entity.dart';

class CategorizationRuleEntity extends Equatable {
  const CategorizationRuleEntity({
    required this.pattern,
    required this.categoryName,
    required this.transactionType,
    this.id,
    this.categoryId,
    this.confidence = 95,
    this.priority = 120,
    this.isUserCorrection = false,
  });

  final String? id;
  final String? categoryId;
  final String pattern;
  final String categoryName;
  final String transactionType;
  final int confidence;
  final int priority;
  final bool isUserCorrection;

  @override
  List<Object?> get props => [
        id,
        categoryId,
        pattern,
        categoryName,
        transactionType,
        confidence,
        priority,
        isUserCorrection,
      ];
}

class CategorizationPrediction extends Equatable {
  const CategorizationPrediction({
    required this.matched,
    required this.categoryName,
    required this.confidence,
    required this.explanation,
    this.categoryId,
    this.matchedPattern,
    this.isUserPreference = false,
  });

  final bool matched;
  final String? categoryId;
  final String categoryName;
  final int confidence;
  final String? matchedPattern;
  final bool isUserPreference;
  final String explanation;

  @override
  List<Object?> get props => [
        matched,
        categoryId,
        categoryName,
        confidence,
        matchedPattern,
        isUserPreference,
        explanation,
      ];
}

/// Deterministic Rule-Based Expense Categorization Engine (Dart)
///
/// Evaluates:
/// 1. User-defined rules and learned user corrections (highest priority).
/// 2. Built-in merchant and description keyword rules.
/// 3. Fallback to 'Other'.
class DeterministicCategorizer {
  const DeterministicCategorizer._();

  static const List<CategorizationRuleEntity> builtInRules = [
    // Food
    CategorizationRuleEntity(pattern: 'SWIGGY', categoryName: 'Food', transactionType: 'EXPENSE', confidence: 96, priority: 120),
    CategorizationRuleEntity(pattern: 'ZOMATO', categoryName: 'Food', transactionType: 'EXPENSE', confidence: 96, priority: 120),
    CategorizationRuleEntity(pattern: 'STARBUCKS', categoryName: 'Food', transactionType: 'EXPENSE', confidence: 94, priority: 115),
    CategorizationRuleEntity(pattern: 'DOMINOS', categoryName: 'Food', transactionType: 'EXPENSE', confidence: 94, priority: 115),
    CategorizationRuleEntity(pattern: 'RESTAURANT', categoryName: 'Food', transactionType: 'EXPENSE', confidence: 85, priority: 100),
    CategorizationRuleEntity(pattern: 'CAFE', categoryName: 'Food', transactionType: 'EXPENSE', confidence: 84, priority: 100),

    // Groceries
    CategorizationRuleEntity(pattern: 'BIGBASKET', categoryName: 'Groceries', transactionType: 'EXPENSE', confidence: 96, priority: 120),
    CategorizationRuleEntity(pattern: 'BLINKIT', categoryName: 'Groceries', transactionType: 'EXPENSE', confidence: 95, priority: 120),
    CategorizationRuleEntity(pattern: 'ZEPTO', categoryName: 'Groceries', transactionType: 'EXPENSE', confidence: 95, priority: 120),
    CategorizationRuleEntity(pattern: 'INSTAMART', categoryName: 'Groceries', transactionType: 'EXPENSE', confidence: 95, priority: 120),
    CategorizationRuleEntity(pattern: 'DMART', categoryName: 'Groceries', transactionType: 'EXPENSE', confidence: 94, priority: 115),

    // Transportation
    CategorizationRuleEntity(pattern: 'UBER', categoryName: 'Transportation', transactionType: 'EXPENSE', confidence: 96, priority: 120),
    CategorizationRuleEntity(pattern: 'OLA', categoryName: 'Transportation', transactionType: 'EXPENSE', confidence: 95, priority: 120),
    CategorizationRuleEntity(pattern: 'RAPIDO', categoryName: 'Transportation', transactionType: 'EXPENSE', confidence: 95, priority: 120),
    CategorizationRuleEntity(pattern: 'METRO', categoryName: 'Transportation', transactionType: 'EXPENSE', confidence: 88, priority: 105),
    CategorizationRuleEntity(pattern: 'PETROL', categoryName: 'Transportation', transactionType: 'EXPENSE', confidence: 90, priority: 110),

    // Subscriptions
    CategorizationRuleEntity(pattern: 'NETFLIX', categoryName: 'Subscriptions', transactionType: 'EXPENSE', confidence: 98, priority: 125),
    CategorizationRuleEntity(pattern: 'SPOTIFY', categoryName: 'Subscriptions', transactionType: 'EXPENSE', confidence: 98, priority: 125),
    CategorizationRuleEntity(pattern: 'YOUTUBE PREMIUM', categoryName: 'Subscriptions', transactionType: 'EXPENSE', confidence: 97, priority: 125),
    CategorizationRuleEntity(pattern: 'HOTSTAR', categoryName: 'Subscriptions', transactionType: 'EXPENSE', confidence: 96, priority: 120),

    // Shopping
    CategorizationRuleEntity(pattern: 'AMAZON', categoryName: 'Shopping', transactionType: 'EXPENSE', confidence: 95, priority: 120),
    CategorizationRuleEntity(pattern: 'FLIPKART', categoryName: 'Shopping', transactionType: 'EXPENSE', confidence: 95, priority: 120),
    CategorizationRuleEntity(pattern: 'MYNTRA', categoryName: 'Shopping', transactionType: 'EXPENSE', confidence: 95, priority: 120),
    CategorizationRuleEntity(pattern: 'NYKAA', categoryName: 'Shopping', transactionType: 'EXPENSE', confidence: 94, priority: 115),

    // Entertainment
    CategorizationRuleEntity(pattern: 'BOOKMYSHOW', categoryName: 'Entertainment', transactionType: 'EXPENSE', confidence: 96, priority: 120),
    CategorizationRuleEntity(pattern: 'PVR', categoryName: 'Entertainment', transactionType: 'EXPENSE', confidence: 95, priority: 120),

    // Healthcare
    CategorizationRuleEntity(pattern: 'APOLLO', categoryName: 'Healthcare', transactionType: 'EXPENSE', confidence: 94, priority: 115),
    CategorizationRuleEntity(pattern: 'PHARMACY', categoryName: 'Healthcare', transactionType: 'EXPENSE', confidence: 92, priority: 110),
    CategorizationRuleEntity(pattern: '1MG', categoryName: 'Healthcare', transactionType: 'EXPENSE', confidence: 95, priority: 120),

    // Utilities
    CategorizationRuleEntity(pattern: 'BESCOM', categoryName: 'Utilities', transactionType: 'EXPENSE', confidence: 96, priority: 120),
    CategorizationRuleEntity(pattern: 'AIRTEL', categoryName: 'Utilities', transactionType: 'EXPENSE', confidence: 93, priority: 115),
    CategorizationRuleEntity(pattern: 'JIO', categoryName: 'Utilities', transactionType: 'EXPENSE', confidence: 93, priority: 115),

    // Travel
    CategorizationRuleEntity(pattern: 'IRCTC', categoryName: 'Travel', transactionType: 'EXPENSE', confidence: 96, priority: 120),
    CategorizationRuleEntity(pattern: 'MAKEMYTRIP', categoryName: 'Travel', transactionType: 'EXPENSE', confidence: 96, priority: 120),
    CategorizationRuleEntity(pattern: 'INDIGO', categoryName: 'Travel', transactionType: 'EXPENSE', confidence: 95, priority: 120),

    // Rent
    CategorizationRuleEntity(pattern: 'HOUSE RENT', categoryName: 'Rent', transactionType: 'EXPENSE', confidence: 96, priority: 120),

    // Income
    CategorizationRuleEntity(pattern: 'SALARY', categoryName: 'Salary', transactionType: 'INCOME', confidence: 97, priority: 125),
    CategorizationRuleEntity(pattern: 'UPWORK', categoryName: 'Freelance', transactionType: 'INCOME', confidence: 96, priority: 120),
    CategorizationRuleEntity(pattern: 'DIVIDEND', categoryName: 'Investments', transactionType: 'INCOME', confidence: 95, priority: 120),
  ];

  static String normalize(String text) {
    return text
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static CategorizationPrediction predict({
    required String transactionType,
    required List<CategoryEntity> availableCategories,
    String? merchant,
    String? description,
    List<CategorizationRuleEntity> userRules = const [],
  }) {
    final normalizedMerchant = normalize(merchant ?? '');
    final normalizedCombined =
        normalize('${merchant ?? ''} ${description ?? ''}');

    final typeCategories = availableCategories
        .where((c) => c.type == transactionType)
        .toList();

    CategoryEntity? resolveCategory(String name, [String? id]) {
      if (id != null) {
        final byId = typeCategories.where((c) => c.id == id);
        if (byId.isNotEmpty) return byId.first;
      }
      final byName = typeCategories.where(
        (c) => c.name.toLowerCase() == name.toLowerCase(),
      );
      return byName.isNotEmpty ? byName.first : null;
    }

    // 1. User rules & learned preferences
    final filteredUserRules = userRules
        .where((r) => r.transactionType == transactionType)
        .toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));

    for (final rule in filteredUserRules) {
      final normPattern = normalize(rule.pattern);
      if (normPattern.isEmpty) continue;
      if (normalizedMerchant.contains(normPattern) ||
          normalizedCombined.contains(normPattern)) {
        final cat = resolveCategory(rule.categoryName, rule.categoryId);
        return CategorizationPrediction(
          matched: true,
          categoryId: cat?.id ?? rule.categoryId,
          categoryName: cat?.name ?? rule.categoryName,
          confidence: rule.confidence,
          matchedPattern: rule.pattern,
          isUserPreference: true,
          explanation: rule.isUserCorrection
              ? 'Learned from your past preference ("${rule.pattern}" -> ${cat?.name ?? rule.categoryName})'
              : 'Matched custom rule "${rule.pattern}" -> ${cat?.name ?? rule.categoryName}',
        );
      }
    }

    // 2. Built-in deterministic merchant rules
    final candidates = builtInRules
        .where((r) => r.transactionType == transactionType)
        .toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));

    for (final rule in candidates) {
      final normPattern = normalize(rule.pattern);
      if (normalizedMerchant.contains(normPattern) ||
          normalizedCombined.contains(normPattern)) {
        final cat = resolveCategory(rule.categoryName);
        return CategorizationPrediction(
          matched: true,
          categoryId: cat?.id,
          categoryName: cat?.name ?? rule.categoryName,
          confidence: rule.confidence,
          matchedPattern: rule.pattern,
          explanation:
              'Auto-detected "${rule.pattern}" -> ${cat?.name ?? rule.categoryName} (${rule.confidence}% confidence)',
        );
      }
    }

    final fallback = resolveCategory('Other') ??
        (typeCategories.isNotEmpty ? typeCategories.first : null);

    return CategorizationPrediction(
      matched: false,
      categoryId: fallback?.id,
      categoryName: fallback?.name ?? 'Other',
      confidence: 40,
      explanation: 'No keyword rule matched; select a category manually.',
    );
  }
}

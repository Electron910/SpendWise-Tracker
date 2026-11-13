import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  const UserEntity({
    required this.id,
    required this.email,
    required this.fullName,
    required this.currency,
    this.themePreference = 'SYSTEM',
    this.isDemoAccount = false,
    this.notifyBudgetAlerts = true,
    this.notifyRecurringBills = true,
    this.notifyMonthlySummary = true,
    this.notifyUnusualSpending = true,
  });

  final String id;
  final String email;
  final String fullName;
  final String currency;
  final String themePreference;
  final bool isDemoAccount;
  final bool notifyBudgetAlerts;
  final bool notifyRecurringBills;
  final bool notifyMonthlySummary;
  final bool notifyUnusualSpending;

  factory UserEntity.fromJson(Map<String, dynamic> json) {
    return UserEntity(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['fullName'] as String,
      currency: (json['currency'] as String?) ?? 'INR',
      themePreference: (json['themePreference'] as String?) ?? 'SYSTEM',
      isDemoAccount: (json['isDemoAccount'] as bool?) ?? false,
      notifyBudgetAlerts: (json['notifyBudgetAlerts'] as bool?) ?? true,
      notifyRecurringBills: (json['notifyRecurringBills'] as bool?) ?? true,
      notifyMonthlySummary: (json['notifyMonthlySummary'] as bool?) ?? true,
      notifyUnusualSpending: (json['notifyUnusualSpending'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'fullName': fullName,
        'currency': currency,
        'themePreference': themePreference,
        'isDemoAccount': isDemoAccount,
        'notifyBudgetAlerts': notifyBudgetAlerts,
        'notifyRecurringBills': notifyRecurringBills,
        'notifyMonthlySummary': notifyMonthlySummary,
        'notifyUnusualSpending': notifyUnusualSpending,
      };

  @override
  List<Object?> get props => [
        id,
        email,
        fullName,
        currency,
        themePreference,
        isDemoAccount,
        notifyBudgetAlerts,
        notifyRecurringBills,
        notifyMonthlySummary,
        notifyUnusualSpending,
      ];
}

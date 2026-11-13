import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise_mobile/core/theme/app_theme.dart';
import 'package:spendwise_mobile/features/recurring/data/repositories/recurring_repository_impl.dart';
import 'package:spendwise_mobile/features/recurring/domain/entities/recurring_expense_entity.dart';
import 'package:spendwise_mobile/features/recurring/presentation/providers/recurring_provider.dart';
import 'package:spendwise_mobile/features/recurring/presentation/screens/recurring_expenses_screen.dart';

class FakeRecurringRepository extends RecurringRepositoryImpl {
  FakeRecurringRepository() : super(Dio());

  bool _isActive = true;

  @override
  Future<List<RecurringExpenseEntity>> fetchRecurringExpenses() async {
    return [
      RecurringExpenseEntity(
        id: 'rec-1',
        categoryId: 'cat-rent',
        categoryName: 'Rent',
        categoryColorHex: '#0EA5E9',
        categoryIcon: 'home',
        type: 'EXPENSE',
        title: 'Monthly House Rent',
        merchant: 'Landlord',
        description: '2BHK Rent',
        amountPaise: 1800000, // ₹18,000.00
        paymentMethod: 'UPI',
        frequency: 'MONTHLY',
        intervalCount: 1,
        startDate: DateTime(2026, 9, 1),
        nextOccurrence: DateTime(2026, 12, 1),
        isActive: _isActive,
        reminderDays: 3,
        daysUntilNext: 2,
        isUpcomingReminder: _isActive,
        history: [
          RecurringGeneratedHistoryItem(
            id: 'tx-1',
            amountPaise: 1800000,
            transactionDate: DateTime(2026, 11, 1),
            description: '2BHK Rent',
          ),
        ],
      ),
    ];
  }

  @override
  Future<RecurringExpenseEntity> toggleActiveStatus({
    required String id,
    required bool isActive,
  }) async {
    _isActive = isActive;
    final list = await fetchRecurringExpenses();
    return list.first;
  }
}

void main() {
  testWidgets(
      'RecurringExpensesScreen renders upcoming due reminders, schedule details, and toggles active status',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recurringRepositoryProvider.overrideWithValue(FakeRecurringRepository()),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const RecurringExpensesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Upcoming Due Reminders'), findsOneWidget);
    expect(find.text('Monthly House Rent'), findsOneWidget);
    expect(find.text('-₹18,000.00'), findsOneWidget);

    await tester.tap(find.byKey(const Key('toggle_recurring_rec-1')));
    await tester.pumpAndSettle();

    expect(find.text('Upcoming Due Reminders'), findsNothing);
  });
}

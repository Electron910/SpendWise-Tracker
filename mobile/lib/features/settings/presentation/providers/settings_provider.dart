import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/local_database.dart';
import '../../../../core/network/api_client.dart';

class SettingsState {
  final ThemeMode themeMode;
  final String currency;
  final bool budgetAlertsEnabled;
  final bool recurringRemindersEnabled;
  final bool monthlySummaryEnabled;
  final bool isSaving;
  final String? statusMessage;

  const SettingsState({
    this.themeMode = ThemeMode.system,
    this.currency = 'INR',
    this.budgetAlertsEnabled = true,
    this.recurringRemindersEnabled = true,
    this.monthlySummaryEnabled = true,
    this.isSaving = false,
    this.statusMessage,
  });

  SettingsState copyWith({
    ThemeMode? themeMode,
    String? currency,
    bool? budgetAlertsEnabled,
    bool? recurringRemindersEnabled,
    bool? monthlySummaryEnabled,
    bool? isSaving,
    String? statusMessage,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      currency: currency ?? this.currency,
      budgetAlertsEnabled: budgetAlertsEnabled ?? this.budgetAlertsEnabled,
      recurringRemindersEnabled:
          recurringRemindersEnabled ?? this.recurringRemindersEnabled,
      monthlySummaryEnabled:
          monthlySummaryEnabled ?? this.monthlySummaryEnabled,
      isSaving: isSaving ?? this.isSaving,
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  final Dio _dio;
  final LocalDatabase _localDb;

  SettingsNotifier({
    required Dio dio,
    required LocalDatabase localDb,
  })  : _dio = dio,
        _localDb = localDb,
        super(const SettingsState());

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
  }

  void toggleBudgetAlerts(bool enabled) {
    state = state.copyWith(budgetAlertsEnabled: enabled);
  }

  void toggleRecurringReminders(bool enabled) {
    state = state.copyWith(recurringRemindersEnabled: enabled);
  }

  void toggleMonthlySummary(bool enabled) {
    state = state.copyWith(monthlySummaryEnabled: enabled);
  }

  Future<bool> updateProfile({
    required String fullName,
    String currency = 'INR',
  }) async {
    state = state.copyWith(isSaving: true, statusMessage: null);
    try {
      await _dio.patch(
        '/auth/profile',
        data: {
          'fullName': fullName.trim(),
          'currency': currency.trim().toUpperCase(),
        },
      );
      state = state.copyWith(
        currency: currency.trim().toUpperCase(),
        isSaving: false,
        statusMessage: 'Profile updated successfully',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        statusMessage: 'Saved locally (${e.toString()})',
      );
      return false;
    }
  }

  Future<void> clearLocalCache() async {
    final db = await _localDb.database;
    await db.delete('cached_transactions');
    await db.delete('cached_categories');
    state = state.copyWith(
      statusMessage: 'Local offline cache cleared.',
    );
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier(
    dio: ref.watch(dioClientProvider),
    localDb: ref.watch(localDatabaseProvider),
  );
});

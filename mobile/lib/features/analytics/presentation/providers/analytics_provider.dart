import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../data/repositories/analytics_repository_impl.dart';
import '../../domain/entities/analytics_entities.dart';

final analyticsRepositoryProvider = Provider<AnalyticsRepositoryImpl>((ref) {
  return AnalyticsRepositoryImpl(ref.watch(dioClientProvider));
});

class AnalyticsState {
  final String selectedPeriod;
  final DateTime? customStartDate;
  final DateTime? customEndDate;
  final FinancialAnalyticsBundle? bundle;
  final bool isLoading;
  final String? errorMessage;

  const AnalyticsState({
    required this.selectedPeriod,
    this.customStartDate,
    this.customEndDate,
    this.bundle,
    this.isLoading = false,
    this.errorMessage,
  });

  AnalyticsState copyWith({
    String? selectedPeriod,
    DateTime? customStartDate,
    DateTime? customEndDate,
    FinancialAnalyticsBundle? bundle,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AnalyticsState(
      selectedPeriod: selectedPeriod ?? this.selectedPeriod,
      customStartDate: customStartDate ?? this.customStartDate,
      customEndDate: customEndDate ?? this.customEndDate,
      bundle: bundle ?? this.bundle,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AnalyticsNotifier extends StateNotifier<AnalyticsState> {
  final AnalyticsRepositoryImpl _repository;

  AnalyticsNotifier(this._repository)
      : super(const AnalyticsState(selectedPeriod: 'THIS_MONTH', isLoading: true)) {
    loadAnalytics();
  }

  Future<void> loadAnalytics() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final bundle = await _repository.fetchAnalyticsBundle(
        period: state.selectedPeriod,
        startDate: state.customStartDate,
        endDate: state.customEndDate,
      );
      state = state.copyWith(bundle: bundle, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> selectPeriod(
    String period, {
    DateTime? customStart,
    DateTime? customEnd,
  }) async {
    state = state.copyWith(
      selectedPeriod: period,
      customStartDate: customStart,
      customEndDate: customEnd,
    );
    await loadAnalytics();
  }
}

final analyticsProvider = StateNotifierProvider<AnalyticsNotifier, AnalyticsState>((ref) {
  return AnalyticsNotifier(ref.watch(analyticsRepositoryProvider));
});

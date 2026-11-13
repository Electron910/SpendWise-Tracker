import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../data/repositories/insights_repository_impl.dart';
import '../../domain/entities/financial_insight_entity.dart';

final insightsRepositoryProvider = Provider<InsightsRepositoryImpl>((ref) {
  return InsightsRepositoryImpl(ref.watch(dioClientProvider));
});

class InsightsState {
  final int month;
  final int year;
  final List<FinancialInsightEntity> insights;
  final bool isLoading;
  final String? errorMessage;

  const InsightsState({
    required this.month,
    required this.year,
    this.insights = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  InsightsState copyWith({
    int? month,
    int? year,
    List<FinancialInsightEntity>? insights,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return InsightsState(
      month: month ?? this.month,
      year: year ?? this.year,
      insights: insights ?? this.insights,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class InsightsNotifier extends StateNotifier<InsightsState> {
  final InsightsRepositoryImpl _repository;

  InsightsNotifier(this._repository)
      : super(
          InsightsState(
            month: DateTime.now().month,
            year: DateTime.now().year,
            isLoading: true,
          ),
        ) {
    loadInsights();
  }

  Future<void> loadInsights({int? month, int? year}) async {
    final targetMonth = month ?? state.month;
    final targetYear = year ?? state.year;
    state = state.copyWith(
      month: targetMonth,
      year: targetYear,
      isLoading: true,
      clearError: true,
    );
    try {
      final list = await _repository.fetchInsights(
        month: targetMonth,
        year: targetYear,
      );
      state = state.copyWith(insights: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }
}

final insightsProvider = StateNotifierProvider<InsightsNotifier, InsightsState>((ref) {
  return InsightsNotifier(ref.watch(insightsRepositoryProvider));
});

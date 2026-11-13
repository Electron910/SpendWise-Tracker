import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/dashboard_repository_impl.dart';
import '../../domain/entities/dashboard_overview_entity.dart';

class DashboardState {
  const DashboardState({
    required this.selectedMonth,
    required this.selectedYear,
    this.isLoading = false,
    this.overview,
    this.errorMessage,
  });

  final int selectedMonth;
  final int selectedYear;
  final bool isLoading;
  final DashboardOverviewEntity? overview;
  final String? errorMessage;

  DashboardState copyWith({
    int? selectedMonth,
    int? selectedYear,
    bool? isLoading,
    DashboardOverviewEntity? overview,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DashboardState(
      selectedMonth: selectedMonth ?? this.selectedMonth,
      selectedYear: selectedYear ?? this.selectedYear,
      isLoading: isLoading ?? this.isLoading,
      overview: overview ?? this.overview,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class DashboardNotifier extends StateNotifier<DashboardState> {
  DashboardNotifier(this._repository)
      : super(
          DashboardState(
            selectedMonth: DateTime.now().month,
            selectedYear: DateTime.now().year,
          ),
        );

  final DashboardRepository _repository;

  Future<void> loadOverview() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final overview = await _repository.getOverview(
        month: state.selectedMonth,
        year: state.selectedYear,
      );
      state = state.copyWith(
        isLoading: false,
        overview: overview,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> changeMonth(int monthOffset) async {
    final nextDate = DateTime(state.selectedYear, state.selectedMonth + monthOffset, 1);
    state = state.copyWith(
      selectedMonth: nextDate.month,
      selectedYear: nextDate.year,
    );
    await loadOverview();
  }
}

final dashboardNotifierProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
  return DashboardNotifier(ref.watch(dashboardRepositoryProvider));
});

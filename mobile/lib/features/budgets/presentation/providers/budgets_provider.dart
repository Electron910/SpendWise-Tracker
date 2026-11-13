import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/budgets_repository_impl.dart';
import '../../domain/entities/budget_entity.dart';

class BudgetsState {
  const BudgetsState({
    required this.selectedMonth,
    required this.selectedYear,
    this.isLoading = false,
    this.overview,
    this.errorMessage,
  });

  final int selectedMonth;
  final int selectedYear;
  final bool isLoading;
  final MonthlyBudgetsOverview? overview;
  final String? errorMessage;

  BudgetsState copyWith({
    int? selectedMonth,
    int? selectedYear,
    bool? isLoading,
    MonthlyBudgetsOverview? overview,
    String? errorMessage,
    bool clearError = false,
  }) {
    return BudgetsState(
      selectedMonth: selectedMonth ?? this.selectedMonth,
      selectedYear: selectedYear ?? this.selectedYear,
      isLoading: isLoading ?? this.isLoading,
      overview: overview ?? this.overview,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class BudgetsNotifier extends StateNotifier<BudgetsState> {
  BudgetsNotifier(this._repository)
      : super(
          BudgetsState(
            selectedMonth: DateTime.now().month,
            selectedYear: DateTime.now().year,
          ),
        );

  final BudgetsRepository _repository;

  Future<void> loadBudgets() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final overview = await _repository.getBudgets(
        month: state.selectedMonth,
        year: state.selectedYear,
      );
      state = state.copyWith(isLoading: false, overview: overview);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> changeMonth(int monthOffset) async {
    final nextDate =
        DateTime(state.selectedYear, state.selectedMonth + monthOffset, 1);
    state = state.copyWith(
      selectedMonth: nextDate.month,
      selectedYear: nextDate.year,
    );
    await loadBudgets();
  }

  Future<bool> saveBudget({
    required int amountPaise,
    String? categoryId,
    List<int> alertThresholds = const [50, 75, 90, 100],
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repository.saveBudget(
        month: state.selectedMonth,
        year: state.selectedYear,
        amountPaise: amountPaise,
        categoryId: categoryId,
        alertThresholds: alertThresholds,
      );
      await loadBudgets();
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  Future<void> deleteBudget(String id) async {
    await _repository.deleteBudget(id);
    await loadBudgets();
  }
}

final budgetsNotifierProvider =
    StateNotifierProvider<BudgetsNotifier, BudgetsState>((ref) {
  return BudgetsNotifier(ref.watch(budgetsRepositoryProvider));
});

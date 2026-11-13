import 'package:dio/dio.dart';

import '../../domain/entities/financial_insight_entity.dart';

class InsightsRepositoryImpl {
  final Dio _dio;

  InsightsRepositoryImpl(this._dio);

  Future<List<FinancialInsightEntity>> fetchInsights({
    required int month,
    required int year,
  }) async {
    final response = await _dio.get(
      '/insights',
      queryParameters: {'month': month, 'year': year},
    );
    final data = response.data['data'] as Map<String, dynamic>;
    final list = data['insights'] as List<dynamic>;
    return list
        .map((e) => FinancialInsightEntity.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

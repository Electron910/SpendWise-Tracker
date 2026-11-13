import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/dashboard_overview_entity.dart';

abstract class DashboardRepository {
  Future<DashboardOverviewEntity> getOverview({
    required int month,
    required int year,
  });
}

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepositoryImpl(dio: ref.watch(dioClientProvider));
});

class DashboardRepositoryImpl implements DashboardRepository {
  DashboardRepositoryImpl({required Dio dio}) : _dio = dio;

  final Dio _dio;

  @override
  Future<DashboardOverviewEntity> getOverview({
    required int month,
    required int year,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/analytics/overview',
      queryParameters: {
        'month': month,
        'year': year,
      },
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    return DashboardOverviewEntity.fromJson(data);
  }
}

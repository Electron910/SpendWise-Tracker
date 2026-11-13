import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/api_constants.dart';
import '../storage/token_storage.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return SecureTokenStorage();
});

final dioClientProvider = Provider<Dio>((ref) {
  final tokenStorage = ref.watch(tokenStorageProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final accessToken = await tokenStorage.getAccessToken();
        if (accessToken != null && accessToken.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $accessToken';
        }
        handler.next(options);
      },
      onError: (DioException error, ErrorInterceptorHandler handler) async {
        final statusCode = error.response?.statusCode;
        final isRefreshCall = error.requestOptions.path.contains('/auth/refresh');
        final isLoginCall = error.requestOptions.path.contains('/auth/login');

        if (statusCode == 401 && !isRefreshCall && !isLoginCall) {
          final refreshToken = await tokenStorage.getRefreshToken();
          if (refreshToken != null && refreshToken.isNotEmpty) {
            try {
              final refreshDio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));
              final response = await refreshDio.post<Map<String, dynamic>>(
                '/auth/refresh',
                data: {'refreshToken': refreshToken},
              );
              final data = response.data?['data'] as Map<String, dynamic>?;
              final tokens = data?['tokens'] as Map<String, dynamic>?;
              if (tokens != null) {
                final newAccess = tokens['accessToken'] as String;
                final newRefresh = tokens['refreshToken'] as String;
                await tokenStorage.saveTokens(
                  accessToken: newAccess,
                  refreshToken: newRefresh,
                );

                // Retry original request with refreshed access token
                final opts = error.requestOptions;
                opts.headers['Authorization'] = 'Bearer $newAccess';
                final retryResponse = await dio.fetch<dynamic>(opts);
                return handler.resolve(retryResponse);
              }
            } catch (refreshError) {
              debugPrint('Token refresh failed: $refreshError');
              await tokenStorage.clearAll();
            }
          }
        }
        handler.next(error);
      },
    ),
  );

  return dio;
});

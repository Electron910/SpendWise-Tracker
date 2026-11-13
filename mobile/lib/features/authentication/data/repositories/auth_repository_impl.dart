import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/token_storage.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    dio: ref.watch(dioClientProvider),
    tokenStorage: ref.watch(tokenStorageProvider),
  );
});

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required Dio dio,
    required TokenStorage tokenStorage,
  })  : _dio = dio,
        _tokenStorage = tokenStorage;

  final Dio _dio;
  final TokenStorage _tokenStorage;

  String _extractErrorMessage(Object error) {
    if (error is DioException) {
      final responseData = error.response?.data;
      if (responseData is Map<String, dynamic>) {
        final errObj = responseData['error'];
        if (errObj is Map<String, dynamic> && errObj['message'] is String) {
          return errObj['message'] as String;
        }
      }
      return error.message ?? 'Network request failed';
    }
    return error.toString();
  }

  @override
  Future<UserEntity?> restoreSession() async {
    final accessToken = await _tokenStorage.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      return null;
    }

    // Attempt live profile check; fall back to cached user profile when offline
    try {
      final response = await _dio.get<Map<String, dynamic>>('/auth/me');
      final data = response.data?['data'] as Map<String, dynamic>?;
      final userJson = data?['user'] as Map<String, dynamic>?;
      if (userJson != null) {
        await _tokenStorage.saveUserJson(userJson);
        return UserEntity.fromJson(userJson);
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _tokenStorage.clearAll();
        return null;
      }
      final cachedJson = await _tokenStorage.getUserJson();
      if (cachedJson != null) {
        return UserEntity.fromJson(cachedJson);
      }
    }
    return null;
  }

  @override
  Future<UserEntity> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {
          'email': email.trim(),
          'password': password,
        },
      );
      final data = response.data!['data'] as Map<String, dynamic>;
      final userJson = data['user'] as Map<String, dynamic>;
      final tokens = data['tokens'] as Map<String, dynamic>;

      await _tokenStorage.saveTokens(
        accessToken: tokens['accessToken'] as String,
        refreshToken: tokens['refreshToken'] as String,
      );
      await _tokenStorage.saveUserJson(userJson);

      return UserEntity.fromJson(userJson);
    } catch (e) {
      throw Exception(_extractErrorMessage(e));
    }
  }

  @override
  Future<UserEntity> register({
    required String fullName,
    required String email,
    required String password,
    String currency = 'INR',
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/register',
        data: {
          'fullName': fullName.trim(),
          'email': email.trim(),
          'password': password,
          'currency': currency,
        },
      );
      final data = response.data!['data'] as Map<String, dynamic>;
      final userJson = data['user'] as Map<String, dynamic>;
      final tokens = data['tokens'] as Map<String, dynamic>;

      await _tokenStorage.saveTokens(
        accessToken: tokens['accessToken'] as String,
        refreshToken: tokens['refreshToken'] as String,
      );
      await _tokenStorage.saveUserJson(userJson);

      return UserEntity.fromJson(userJson);
    } catch (e) {
      throw Exception(_extractErrorMessage(e));
    }
  }

  @override
  Future<String?> requestPasswordReset({required String email}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/forgot-password',
        data: {'email': email.trim()},
      );
      final data = response.data?['data'] as Map<String, dynamic>?;
      return data?['resetCodeForDemoOnly'] as String?;
    } catch (e) {
      throw Exception(_extractErrorMessage(e));
    }
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String resetToken,
    required String newPassword,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/auth/reset-password',
        data: {
          'email': email.trim(),
          'resetToken': resetToken.trim(),
          'newPassword': newPassword,
        },
      );
    } catch (e) {
      throw Exception(_extractErrorMessage(e));
    }
  }

  @override
  Future<void> logout() async {
    try {
      final refreshToken = await _tokenStorage.getRefreshToken();
      await _dio.post<Map<String, dynamic>>(
        '/auth/logout',
        data: {'refreshToken': refreshToken},
      );
    } catch (_) {
      // Ignore network errors during logout and clear local tokens unconditionally
    } finally {
      await _tokenStorage.clearAll();
    }
  }
}

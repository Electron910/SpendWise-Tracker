import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class TokenStorage {
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  });
  Future<String?> getAccessToken();
  Future<String?> getRefreshToken();
  Future<void> saveUserJson(Map<String, dynamic> userJson);
  Future<Map<String, dynamic>?> getUserJson();
  Future<void> clearAll();
}

class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;

  static const String _accessTokenKey = 'spendwise_access_token';
  static const String _refreshTokenKey = 'spendwise_refresh_token';
  static const String _userJsonKey = 'spendwise_cached_user';

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  @override
  Future<String?> getAccessToken() => _storage.read(key: _accessTokenKey);

  @override
  Future<String?> getRefreshToken() => _storage.read(key: _refreshTokenKey);

  @override
  Future<void> saveUserJson(Map<String, dynamic> userJson) async {
    await _storage.write(key: _userJsonKey, value: jsonEncode(userJson));
  }

  @override
  Future<Map<String, dynamic>?> getUserJson() async {
    final raw = await _storage.read(key: _userJsonKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> clearAll() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _userJsonKey);
  }
}

class InMemoryTokenStorage implements TokenStorage {
  String? _accessToken;
  String? _refreshToken;
  Map<String, dynamic>? _userJson;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
  }

  @override
  Future<String?> getAccessToken() async => _accessToken;

  @override
  Future<String?> getRefreshToken() async => _refreshToken;

  @override
  Future<void> saveUserJson(Map<String, dynamic> userJson) async {
    _userJson = Map<String, dynamic>.from(userJson);
  }

  @override
  Future<Map<String, dynamic>?> getUserJson() async => _userJson;

  @override
  Future<void> clearAll() async {
    _accessToken = null;
    _refreshToken = null;
    _userJson = null;
  }
}

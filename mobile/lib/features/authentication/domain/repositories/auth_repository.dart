import '../entities/user_entity.dart';

abstract class AuthRepository {
  Future<UserEntity?> restoreSession();

  Future<UserEntity> login({
    required String email,
    required String password,
  });

  Future<UserEntity> register({
    required String fullName,
    required String email,
    required String password,
    String currency = 'INR',
  });

  Future<String?> requestPasswordReset({required String email});

  Future<void> resetPassword({
    required String email,
    required String resetToken,
    required String newPassword,
  });

  Future<void> logout();
}

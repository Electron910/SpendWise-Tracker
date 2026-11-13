import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise_mobile/core/theme/app_theme.dart';
import 'package:spendwise_mobile/core/utils/money_utils.dart';
import 'package:spendwise_mobile/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:spendwise_mobile/features/authentication/domain/entities/user_entity.dart';
import 'package:spendwise_mobile/features/authentication/domain/repositories/auth_repository.dart';
import 'package:spendwise_mobile/features/authentication/presentation/screens/login_screen.dart';

class FakeAuthRepository implements AuthRepository {
  UserEntity? currentUser;
  bool shouldFailLogin = false;

  @override
  Future<UserEntity?> restoreSession() async => currentUser;

  @override
  Future<UserEntity> login({
    required String email,
    required String password,
  }) async {
    if (shouldFailLogin) {
      throw Exception('Invalid email or password');
    }
    final user = UserEntity(
      id: 'user-1',
      email: email,
      fullName: 'Aarav Sharma',
      currency: 'INR',
      isDemoAccount: email.contains('demo'),
    );
    currentUser = user;
    return user;
  }

  @override
  Future<UserEntity> register({
    required String fullName,
    required String email,
    required String password,
    String currency = 'INR',
  }) async {
    final user = UserEntity(
      id: 'user-2',
      email: email,
      fullName: fullName,
      currency: currency,
    );
    currentUser = user;
    return user;
  }

  @override
  Future<String?> requestPasswordReset({required String email}) async => '123456';

  @override
  Future<void> resetPassword({
    required String email,
    required String resetToken,
    required String newPassword,
  }) async {}

  @override
  Future<void> logout() async {
    currentUser = null;
  }
}

void main() {
  group('MoneyUtils (Integer Paise Precision)', () {
    test('parses rupee strings into integer paise without floating-point math', () {
      expect(MoneyUtils.parseRupeesToPaise('125.50'), 12550);
      expect(MoneyUtils.parseRupeesToPaise('5,000'), 500000);
      expect(MoneyUtils.parseRupeesToPaise('0.05'), 5);
    });

    test('formats paise into Indian numbering currency strings', () {
      expect(MoneyUtils.formatPaise(12550), '₹125.50');
      expect(MoneyUtils.formatPaise(15000000), '₹1,50,000.00');
      expect(MoneyUtils.formatPaise(500000, includeDecimals: false), '₹5,000');
    });

    test('rejects zero or negative amounts', () {
      expect(() => MoneyUtils.parseRupeesToPaise('0'), throwsFormatException);
      expect(() => MoneyUtils.parseRupeesToPaise('-50'), throwsFormatException);
    });
  });

  group('LoginScreen Widget Tests', () {
    testWidgets('validates empty email and short password fields', (tester) async {
      final fakeRepo = FakeAuthRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const LoginScreen(),
          ),
        ),
      );

      final submitBtn = find.byKey(const Key('login_submit_button'));
      await tester.tap(submitBtn);
      await tester.pump();

      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
    });

    testWidgets('displays error banner when credentials are invalid', (tester) async {
      final fakeRepo = FakeAuthRepository()..shouldFailLogin = true;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const LoginScreen(),
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('login_email_field')),
        'wrong@spendwise.app',
      );
      await tester.enterText(
        find.byKey(const Key('login_password_field')),
        'WrongPass123',
      );

      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('Invalid email or password'), findsOneWidget);
    });
  });
}

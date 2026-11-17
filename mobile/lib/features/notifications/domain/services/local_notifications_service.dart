import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationsService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );
    try {
      await _plugin.initialize(initSettings);
      _initialized = true;
    } catch (_) {
      // Safe fallback on desktop/headless environments
    }
  }

  Future<void> showFinancialAlert({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_initialized) {
      await initialize();
    }
    const androidDetails = AndroidNotificationDetails(
      'spendwise_financial_alerts',
      'SpendWise Financial Alerts',
      channelDescription: 'Budget utilization and upcoming recurring bill reminders',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );
    try {
      await _plugin.show(id, title, body, details);
    } catch (_) {
      // Ignore on unsupported desktop test runners
    }
  }
}

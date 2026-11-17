import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/entities/notification_entity.dart';
import '../../domain/services/local_notifications_service.dart';

final localNotificationsServiceProvider = Provider<LocalNotificationsService>((ref) {
  return LocalNotificationsService();
});

class NotificationsRepository {
  final Dio _dio;

  NotificationsRepository(this._dio);

  Future<({int unreadCount, List<NotificationEntity> items})> fetchNotifications() async {
    final response = await _dio.get<Map<String, dynamic>>('/notifications');
    final data = response.data!['data'] as Map<String, dynamic>;
    final list = data['notifications'] as List<dynamic>;
    return (
      unreadCount: (data['unreadCount'] as num?)?.toInt() ?? 0,
      items: list
          .map((e) => NotificationEntity.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<void> markAsRead(String id) async {
    await _dio.patch('/notifications/$id/read');
  }

  Future<void> markAllAsRead() async {
    await _dio.post('/notifications/read-all');
  }
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(ref.watch(dioClientProvider));
});

class NotificationsState {
  final int unreadCount;
  final List<NotificationEntity> items;
  final bool isLoading;
  final String? errorMessage;

  const NotificationsState({
    this.unreadCount = 0,
    this.items = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  NotificationsState copyWith({
    int? unreadCount,
    List<NotificationEntity>? items,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return NotificationsState(
      unreadCount: unreadCount ?? this.unreadCount,
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class NotificationsNotifier extends StateNotifier<NotificationsState> {
  final NotificationsRepository _repository;
  final LocalNotificationsService _localNotifications;

  NotificationsNotifier(this._repository, this._localNotifications)
      : super(const NotificationsState(isLoading: true)) {
    loadNotifications();
  }

  Future<void> loadNotifications() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res = await _repository.fetchNotifications();
      state = state.copyWith(
        unreadCount: res.unreadCount,
        items: res.items,
        isLoading: false,
      );
      if (res.items.isNotEmpty && !res.items.first.isRead) {
        final top = res.items.first;
        await _localNotifications.showFinancialAlert(
          id: top.id.hashCode,
          title: top.title,
          body: top.message,
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> markRead(String id) async {
    try {
      await _repository.markAsRead(id);
      await loadNotifications();
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    try {
      await _repository.markAllAsRead();
      await loadNotifications();
    } catch (_) {}
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, NotificationsState>((ref) {
  return NotificationsNotifier(
    ref.watch(notificationsRepositoryProvider),
    ref.watch(localNotificationsServiceProvider),
  );
});

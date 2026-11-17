import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/notification_entity.dart';
import '../providers/notifications_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  IconData _typeIcon(String type) {
    switch (type) {
      case 'BUDGET_THRESHOLD':
        return Icons.pie_chart_rounded;
      case 'UPCOMING_RECURRING':
        return Icons.event_repeat_rounded;
      case 'UNUSUAL_SPENDING':
        return Icons.warning_amber_rounded;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'BUDGET_THRESHOLD':
        return AppColors.warningAmber;
      case 'UPCOMING_RECURRING':
        return AppColors.indigoAccent;
      case 'UNUSUAL_SPENDING':
        return AppColors.expenseRed;
      default:
        return AppColors.emeraldIncome;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationsProvider);
    final dateFmt = DateFormat('dd MMM yyyy, HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: Text(
          state.unreadCount > 0
              ? 'Notifications (${state.unreadCount} unread)'
              : 'Notifications',
        ),
        actions: [
          if (state.unreadCount > 0)
            TextButton(
              key: const Key('mark_all_notifications_read_button'),
              onPressed: () =>
                  ref.read(notificationsProvider.notifier).markAllRead(),
              child: const Text('Mark all read'),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(notificationsProvider.notifier).loadNotifications(),
          ),
        ],
      ),
      body: state.isLoading && state.items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : state.items.isEmpty
              ? const Center(
                  child: Text(
                    'You are all caught up!\nBudget threshold and recurring bill alerts will appear here.',
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: state.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = state.items[index];
                    return _buildNotificationCard(ref, item, dateFmt);
                  },
                ),
    );
  }

  Widget _buildNotificationCard(
    WidgetRef ref,
    NotificationEntity item,
    DateFormat dateFmt,
  ) {
    final color = _typeColor(item.type);
    return Card(
      color: item.isRead
          ? null
          : AppColors.indigoAccent.withValues(alpha: 0.05),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.14),
          child: Icon(_typeIcon(item.type), color: color, size: 20),
        ),
        title: Text(
          item.title,
          style: TextStyle(
            fontWeight: item.isRead ? FontWeight.w600 : FontWeight.w800,
            fontSize: 14,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(item.message, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 4),
            Text(
              dateFmt.format(item.createdAt.toLocal()),
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
        trailing: item.isRead
            ? const Icon(
                Icons.done_all_rounded,
                size: 18,
                color: AppColors.lightTextSecondary,
              )
            : IconButton(
                key: Key('mark_read_${item.id}'),
                tooltip: 'Mark as read',
                icon: const Icon(
                  Icons.circle,
                  size: 12,
                  color: AppColors.indigoAccent,
                ),
                onPressed: () =>
                    ref.read(notificationsProvider.notifier).markRead(item.id),
              ),
      ),
    );
  }
}

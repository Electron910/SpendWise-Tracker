import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/sync_status.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/money_utils.dart';
import '../providers/sync_provider.dart';

class SyncCenterScreen extends ConsumerWidget {
  const SyncCenterScreen({super.key});

  Color _statusColor(SyncStatusState status) {
    switch (status) {
      case SyncStatusState.synced:
        return AppColors.emeraldIncome;
      case SyncStatusState.syncing:
        return AppColors.indigoAccent;
      case SyncStatusState.pendingSync:
      case SyncStatusState.localOnly:
        return AppColors.warningAmber;
      case SyncStatusState.syncFailed:
      case SyncStatusState.conflict:
        return AppColors.expenseRed;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(syncCenterProvider);
    final dateFmt = DateFormat('dd MMM yyyy, HH:mm:ss');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Sync & Conflicts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh queue',
            onPressed: () =>
                ref.read(syncCenterProvider.notifier).refreshQueueState(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Synchronization Status',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _statusColor(state.overallStatus)
                              .withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          state.overallStatus.value,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: _statusColor(state.overallStatus),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.lastSyncedAt != null
                        ? 'Last synced: ${dateFmt.format(state.lastSyncedAt!.toLocal())}'
                        : 'Last synced: Not yet synchronized',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.lightTextSecondary,
                    ),
                  ),
                  if (state.statusMessage != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      state.statusMessage!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      key: const Key('manual_sync_now_button'),
                      onPressed: state.isSyncing
                          ? null
                          : () => ref
                              .read(syncCenterProvider.notifier)
                              .triggerSync(manual: true),
                      icon: state.isSyncing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_sync_outlined),
                      label: Text(
                        state.isSyncing ? 'Synchronizing...' : 'Sync Now',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Pending Sync Queue (${state.queue.length})',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 8),
          if (state.queue.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      color: AppColors.emeraldIncome,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'All local changes are synchronized with the server.',
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...state.queue.map((item) => _buildQueueItemCard(ref, item, dateFmt)),
        ],
      ),
    );
  }

  Widget _buildQueueItemCard(
    WidgetRef ref,
    PendingSyncQueueItem item,
    DateFormat dateFmt,
  ) {
    final clientMap = jsonDecode(item.payloadJson) as Map<String, dynamic>;
    final clientDesc = clientMap['description'] as String? ?? item.entityId;
    final clientAmountStr = clientMap['amountPaise']?.toString();
    final clientPaise = clientAmountStr != null ? int.tryParse(clientAmountStr) : null;

    Map<String, dynamic>? serverMap;
    if (item.conflictServerJson != null) {
      serverMap = jsonDecode(item.conflictServerJson!) as Map<String, dynamic>;
    }

    final isConflict = item.syncStatus == SyncStatusState.conflict;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${item.action} • $clientDesc',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                Text(
                  item.syncStatus.value,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: _statusColor(item.syncStatus),
                  ),
                ),
              ],
            ),
            if (clientPaise != null) ...[
              const SizedBox(height: 4),
              Text(
                'Local Amount: ${MoneyUtils.formatPaise(clientPaise)} (Base v${item.baseVersion})',
                style: const TextStyle(fontSize: 13),
              ),
            ],
            if (item.retryCount > 0) ...[
              const SizedBox(height: 4),
              Text(
                'Retries: ${item.retryCount}${item.nextRetryAt != null ? ' • Next backoff retry: ${dateFmt.format(item.nextRetryAt!.toLocal())}' : ''}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.lightTextSecondary,
                ),
              ),
            ],
            if (isConflict) ...[
              const Divider(height: 20),
              const Text(
                'Version Conflict Detected',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.expenseRed,
                ),
              ),
              const SizedBox(height: 4),
              if (serverMap != null)
                Text(
                  'Server Version (v${serverMap['version']}): ${serverMap['description']} — ${MoneyUtils.formatPaise(int.parse(serverMap['amountPaise'].toString()))}',
                  style: const TextStyle(fontSize: 13),
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: Key('resolve_keep_server_${item.operationId}'),
                      onPressed: () => ref
                          .read(syncCenterProvider.notifier)
                          .resolveKeepServer(item),
                      child: const Text('Keep Server Version'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      key: Key('resolve_keep_client_${item.operationId}'),
                      onPressed: () => ref
                          .read(syncCenterProvider.notifier)
                          .resolveKeepClient(item),
                      child: const Text('Keep My Edit'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

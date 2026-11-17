import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../categories/presentation/screens/categories_screen.dart';
import '../../../exports/presentation/screens/exports_screen.dart';
import '../../../recurring/presentation/screens/recurring_expenses_screen.dart';
import '../../../sync/presentation/screens/sync_center_screen.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _showEditProfileDialog(
    BuildContext context,
    WidgetRef ref,
    String currentName,
    String currentCurrency,
  ) async {
    final nameCtrl = TextEditingController(text: currentName);
    String selectedCurrency = currentCurrency;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Profile & Currency'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    key: const Key('settings_fullname_input'),
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Full Name'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCurrency,
                    decoration: const InputDecoration(labelText: 'Currency'),
                    items: const [
                      DropdownMenuItem(value: 'INR', child: Text('INR (₹) — Paise')),
                      DropdownMenuItem(value: 'USD', child: Text('USD (\$) — Cents')),
                      DropdownMenuItem(value: 'EUR', child: Text('EUR (€) — Cents')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedCurrency = val);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  key: const Key('settings_save_profile_button'),
                  onPressed: () async {
                    if (nameCtrl.text.trim().length < 2) return;
                    await ref.read(settingsProvider.notifier).updateProfile(
                          fullName: nameCtrl.text.trim(),
                          currency: selectedCurrency,
                        );
                    if (ctx.mounted) {
                      Navigator.of(ctx).pop();
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState.user;
    final settings = ref.watch(settingsProvider);

    final fullName = user?.fullName ?? 'SpendWise User';
    final email = user?.email ?? 'user@spendwise.app';
    final isDemo = user?.isDemoAccount == true;

    return ListView(
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fullName,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            email,
                            style: const TextStyle(
                              color: AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: const Key('edit_profile_button'),
                      tooltip: 'Edit Profile',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _showEditProfileDialog(
                        context,
                        ref,
                        fullName,
                        settings.currency,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    Chip(label: Text('Currency: ${settings.currency} (₹)')),
                    if (isDemo) const Chip(label: Text('Simulated Demo Mode')),
                  ],
                ),
                if (settings.statusMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    settings.statusMessage!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.emeraldIncome,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Appearance & Theme',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 10),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('System'),
                      icon: Icon(Icons.brightness_auto_outlined, size: 16),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text('Light'),
                      icon: Icon(Icons.light_mode_outlined, size: 16),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text('Dark'),
                      icon: Icon(Icons.dark_mode_outlined, size: 16),
                    ),
                  ],
                  selected: {settings.themeMode},
                  onSelectionChanged: (modes) {
                    ref
                        .read(settingsProvider.notifier)
                        .setThemeMode(modes.first);
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
                child: Text(
                  'Notification Preferences',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
              SwitchListTile(
                title: const Text('Budget Threshold Alerts'),
                subtitle: const Text('Notify at 50%, 75%, 90%, and 100% usage'),
                value: settings.budgetAlertsEnabled,
                onChanged: (v) =>
                    ref.read(settingsProvider.notifier).toggleBudgetAlerts(v),
              ),
              SwitchListTile(
                title: const Text('Upcoming Recurring Bills'),
                subtitle: const Text('Remind before rent & subscription due dates'),
                value: settings.recurringRemindersEnabled,
                onChanged: (v) => ref
                    .read(settingsProvider.notifier)
                    .toggleRecurringReminders(v),
              ),
              SwitchListTile(
                title: const Text('Monthly Financial Summary'),
                subtitle: const Text('Monthly savings rate & category digest'),
                value: settings.monthlySummaryEnabled,
                onChanged: (v) =>
                    ref.read(settingsProvider.notifier).toggleMonthlySummary(v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.repeat_rounded),
                title: const Text('Recurring Schedules'),
                subtitle: const Text('Rent, subscriptions, salary & due reminders'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const RecurringExpensesScreen(),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.category_outlined),
                title: const Text('Manage Categories'),
                subtitle: const Text('Default & custom expense/income categories'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CategoriesScreen()),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('CSV Export & Reports'),
                subtitle:
                    const Text('Export transactions & monthly financial reports'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ExportsScreen()),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.cloud_sync_outlined),
                title: const Text('Offline Sync & Conflict Resolution'),
                subtitle: const Text('Inspect sync queue & resolve version conflicts'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SyncCenterScreen()),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                key: const Key('clear_local_cache_tile'),
                leading: const Icon(
                  Icons.cleaning_services_outlined,
                  color: AppColors.expenseRed,
                ),
                title: const Text('Clear Local Offline Cache'),
                subtitle: const Text('Reset cached SQLite records on this device'),
                onTap: () =>
                    ref.read(settingsProvider.notifier).clearLocalCache(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SpendWise v1.0.0+1 — Privacy & Product Principle',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                SizedBox(height: 4),
                Text(
                  'SpendWise is a personal expense tracking and budgeting application. It is NOT a banking application and never connects to real bank accounts or processes payments. All monetary amounts use integer paise (₹1.00 = 100 paise).',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

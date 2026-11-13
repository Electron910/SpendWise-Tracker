import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../categories/presentation/screens/categories_screen.dart';
import '../../../transactions/presentation/screens/transactions_screen.dart';
import '../providers/auth_provider.dart';

class AuthenticatedShellScreen extends ConsumerStatefulWidget {
  const AuthenticatedShellScreen({super.key});

  @override
  ConsumerState<AuthenticatedShellScreen> createState() =>
      _AuthenticatedShellScreenState();
}

class _AuthenticatedShellScreenState
    extends ConsumerState<AuthenticatedShellScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState.user;

    final pages = <Widget>[
      const TransactionsScreen(),
      const CategoriesScreen(),
      _AccountOverviewTab(
        fullName: user?.fullName ?? 'SpendWise User',
        email: user?.email ?? '',
        currency: user?.currency ?? 'INR',
        isDemoAccount: user?.isDemoAccount == true,
      ),
    ];

    final titles = <String>[
      'Transactions',
      'Categories',
      'Account',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_selectedIndex]),
        actions: [
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              await ref.read(authNotifierProvider.notifier).logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (user?.isDemoAccount == true)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 6,
              ),
              color: AppColors.warningSoft,
              child: const Row(
                children: [
                  Icon(
                    Icons.science_outlined,
                    size: 16,
                    color: AppColors.warningAmber,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Simulated Demo Account — Fictional records only, no real bank connections.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.navyPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(child: pages[_selectedIndex]),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Transactions',
          ),
          NavigationDestination(
            icon: Icon(Icons.category_outlined),
            selectedIcon: Icon(Icons.category_rounded),
            label: 'Categories',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _AccountOverviewTab extends StatelessWidget {
  const _AccountOverviewTab({
    required this.fullName,
    required this.email,
    required this.currency,
    required this.isDemoAccount,
  });

  final String fullName;
  final String email;
  final String currency;
  final bool isDemoAccount;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  email,
                  style: const TextStyle(color: AppColors.lightTextSecondary),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    Chip(label: Text('Currency: $currency (₹)')),
                    if (isDemoAccount)
                      const Chip(label: Text('Demo Mode')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

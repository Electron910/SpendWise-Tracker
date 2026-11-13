import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../transactions/data/repositories/transactions_repository_impl.dart';
import '../../../transactions/presentation/providers/transactions_provider.dart';
import '../../domain/entities/category_entity.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txState = ref.watch(transactionsNotifierProvider);
    final expenseCats = txState.categoriesForType('EXPENSE');
    final incomeCats = txState.categoriesForType('INCOME');

    Future<void> showAddDialog(String type) async {
      final controller = TextEditingController();
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Add Custom $type Category'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Category Name',
              hintText: 'e.g. Side Project or Gym',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) return;
                await ref
                    .read(transactionsNotifierProvider.notifier)
                    .addCustomCategory(name: name, type: type);
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Expense Categories'),
              Tab(text: 'Income Categories'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _CategoryList(
                  categories: expenseCats,
                  onAdd: () => showAddDialog('EXPENSE'),
                  onDelete: (id) async {
                    await ref
                        .read(transactionsRepositoryProvider)
                        .deleteCustomCategory(id);
                    await ref
                        .read(transactionsNotifierProvider.notifier)
                        .loadInitialData();
                  },
                ),
                _CategoryList(
                  categories: incomeCats,
                  onAdd: () => showAddDialog('INCOME'),
                  onDelete: (id) async {
                    await ref
                        .read(transactionsRepositoryProvider)
                        .deleteCustomCategory(id);
                    await ref
                        .read(transactionsNotifierProvider.notifier)
                        .loadInitialData();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList({
    required this.categories,
    required this.onAdd,
    required this.onDelete,
  });

  final List<CategoryEntity> categories;
  final VoidCallback onAdd;
  final Future<void> Function(String id) onDelete;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final cat = categories[index];
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: cat.color.withValues(alpha: 0.14),
                child: Icon(cat.iconData, color: cat.color),
              ),
              title: Text(
                cat.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                cat.isSystem ? 'System Default' : 'Custom Category',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.lightTextSecondary,
                ),
              ),
              trailing: cat.isSystem
                  ? const Icon(
                      Icons.lock_outline_rounded,
                      size: 18,
                      color: AppColors.lightTextSecondary,
                    )
                  : IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.expenseRed,
                      ),
                      onPressed: () => onDelete(cat.id),
                    ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: onAdd,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Category'),
      ),
    );
  }
}

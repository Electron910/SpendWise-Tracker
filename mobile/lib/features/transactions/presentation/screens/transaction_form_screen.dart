import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/money_utils.dart';
import '../../../categories/domain/entities/category_entity.dart';
import '../../domain/entities/transaction_entity.dart';
import '../providers/transactions_provider.dart';

class TransactionFormScreen extends ConsumerStatefulWidget {
  const TransactionFormScreen({
    this.existingTransaction,
    super.key,
  });

  final TransactionEntity? existingTransaction;

  @override
  ConsumerState<TransactionFormScreen> createState() =>
      _TransactionFormScreenState();
}

class _TransactionFormScreenState extends ConsumerState<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _selectedType;
  String? _selectedCategoryId;
  late String _selectedPaymentMethod;
  late DateTime _selectedDate;

  final _amountController = TextEditingController();
  final _merchantController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();

  static const List<String> _paymentMethods = [
    'UPI',
    'CASH',
    'DEBIT_CARD',
    'CREDIT_CARD',
    'NET_BANKING',
    'WALLET',
    'BANK_TRANSFER',
    'OTHER',
  ];

  @override
  void initState() {
    super.initState();
    final tx = widget.existingTransaction;
    if (tx != null) {
      _selectedType = tx.type;
      _selectedCategoryId = tx.categoryId;
      _selectedPaymentMethod = tx.paymentMethod;
      _selectedDate = tx.transactionDate;
      final rupees = tx.amountPaise ~/ 100;
      final paise = tx.amountPaise % 100;
      _amountController.text =
          paise == 0 ? '$rupees' : '$rupees.${paise.toString().padLeft(2, '0')}';
      _merchantController.text = tx.merchant ?? '';
      _descriptionController.text = tx.description;
      _notesController.text = tx.notes ?? '';
    } else {
      _selectedType = 'EXPENSE';
      _selectedPaymentMethod = 'UPI';
      _selectedDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _showCreateCategoryDialog() async {
    final nameController = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('New $_selectedType Category'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Category Name (e.g., Pet Care)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              final ok = await ref
                  .read(transactionsNotifierProvider.notifier)
                  .addCustomCategory(name: name, type: _selectedType);
              if (context.mounted) {
                Navigator.of(context).pop(ok);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (created == true && mounted) {
      final cats =
          ref.read(transactionsNotifierProvider).categoriesForType(_selectedType);
      if (cats.isNotEmpty) {
        setState(() => _selectedCategoryId = cats.last.id);
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final availableCategories =
        ref.read(transactionsNotifierProvider).categoriesForType(_selectedType);
    final categoryId = _selectedCategoryId ??
        (availableCategories.isNotEmpty ? availableCategories.first.id : null);

    if (categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }

    final amountPaise = MoneyUtils.parseRupeesToPaise(_amountController.text);
    final notifier = ref.read(transactionsNotifierProvider.notifier);

    bool success;
    if (widget.existingTransaction != null) {
      success = await notifier.editTransaction(
        id: widget.existingTransaction!.id,
        categoryId: categoryId,
        type: _selectedType,
        amountPaise: amountPaise,
        description: _descriptionController.text,
        paymentMethod: _selectedPaymentMethod,
        transactionDate: _selectedDate,
        merchant: _merchantController.text,
        notes: _notesController.text,
        expectedVersion: widget.existingTransaction!.version,
      );
    } else {
      success = await notifier.addTransaction(
        categoryId: categoryId,
        type: _selectedType,
        amountPaise: amountPaise,
        description: _descriptionController.text,
        paymentMethod: _selectedPaymentMethod,
        transactionDate: _selectedDate,
        merchant: _merchantController.text,
        notes: _notesController.text,
      );
    }

    if (success && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final txState = ref.watch(transactionsNotifierProvider);
    final categories = txState.categoriesForType(_selectedType);
    final effectiveCategoryId = _selectedCategoryId != null &&
            categories.any((c) => c.id == _selectedCategoryId)
        ? _selectedCategoryId
        : (categories.isNotEmpty ? categories.first.id : null);

    final isEditing = widget.existingTransaction != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Transaction' : 'Add Transaction'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<String>(
                  key: const Key('tx_type_selector'),
                  segments: const [
                    ButtonSegment(
                      value: 'EXPENSE',
                      label: Text('Expense'),
                      icon: Icon(Icons.arrow_upward_rounded),
                    ),
                    ButtonSegment(
                      value: 'INCOME',
                      label: Text('Income'),
                      icon: Icon(Icons.arrow_downward_rounded),
                    ),
                  ],
                  selected: {_selectedType},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _selectedType = selection.first;
                      _selectedCategoryId = null;
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  key: const Key('tx_amount_field'),
                  controller: _amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Amount (₹)',
                    prefixIcon: Icon(Icons.currency_rupee_rounded),
                    hintText: 'e.g. 450.50',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Amount is required';
                    }
                    try {
                      MoneyUtils.parseRupeesToPaise(value);
                      return null;
                    } catch (_) {
                      return 'Enter a valid positive amount (up to 2 decimals)';
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: const Key('tx_category_dropdown'),
                        value: effectiveCategoryId,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: categories
                            .map(
                              (CategoryEntity cat) => DropdownMenuItem<String>(
                                value: cat.id,
                                child: Text(cat.name),
                              ),
                            )
                            .toList(),
                        onChanged: (val) =>
                            setState(() => _selectedCategoryId = val),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: 'New Custom Category',
                      onPressed: _showCreateCategoryDialog,
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  key: const Key('tx_description_field'),
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    prefixIcon: Icon(Icons.description_outlined),
                    hintText: 'e.g. Dinner order or Monthly salary',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Description is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  key: const Key('tx_merchant_field'),
                  controller: _merchantController,
                  decoration: const InputDecoration(
                    labelText: 'Merchant / Payee (Optional)',
                    prefixIcon: Icon(Icons.storefront_outlined),
                    hintText: 'e.g. Swiggy, Uber, Amazon',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  value: _selectedPaymentMethod,
                  decoration: const InputDecoration(
                    labelText: 'Payment Method',
                    prefixIcon: Icon(Icons.payment_rounded),
                  ),
                  items: _paymentMethods
                      .map(
                        (method) => DropdownMenuItem(
                          value: method,
                          child: Text(method.replaceAll('_', ' ')),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedPaymentMethod = val);
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Transaction Date',
                      prefixIcon: Icon(Icons.calendar_today_rounded),
                    ),
                    child: Text(
                      DateFormat('dd MMM yyyy').format(_selectedDate),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  key: const Key('tx_notes_field'),
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes (Optional)',
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                ElevatedButton(
                  key: const Key('tx_submit_button'),
                  onPressed: txState.isLoading ? null : _submit,
                  child: Text(
                    isEditing ? 'Update Transaction' : 'Save Transaction',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

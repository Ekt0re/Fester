import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../services/supabase/transaction_service.dart';

class TransactionListSheet extends StatefulWidget {
  final List<Map<String, dynamic>> transactions;
  final bool canEdit;
  final VoidCallback? onTransactionUpdated;

  const TransactionListSheet({
    super.key,
    required this.transactions,
    this.canEdit = false,
    this.onTransactionUpdated,
  });

  @override
  State<TransactionListSheet> createState() => _TransactionListSheetState();
}

class _TransactionListSheetState extends State<TransactionListSheet> {
  final TransactionService _transactionService = TransactionService();
  bool _showNonMonetary = false;

  IconData _getIconForType(String? typeName) {
    switch (typeName?.toLowerCase()) {
      case 'drink':
        return Icons.local_bar;
      case 'food':
        return Icons.restaurant;
      case 'ticket':
        return Icons.confirmation_number;
      case 'fine':
        return Icons.gavel;
      case 'sanction':
        return Icons.block;
      case 'report':
        return Icons.warning_amber_rounded;
      case 'refund':
        return Icons.replay;
      case 'fee':
        return Icons.attach_money;
      default:
        return Icons.receipt;
    }
  }

  bool _isPositive(String typeName) {
    return typeName.toLowerCase() != 'refund';
  }

  Future<void> _deleteTransaction(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('transaction_list.delete_title'.tr()),
            content: Text('transaction_list.delete_confirm'.tr()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('transaction_list.cancel'.tr()),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text('transaction_list.delete'.tr()),
              ),
            ],
          ),
    );

    if (confirm == true) {
      try {
        await _transactionService.deleteTransaction(id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('transaction_list.deleted'.tr())),
          );
          widget.onTransactionUpdated?.call();
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${'settings.error_prefix'.tr()} $e')),
          );
        }
      }
    }
  }

  Future<void> _editTransaction(Map<String, dynamic> transaction) async {
    final amountController = TextEditingController(
      text: transaction['amount']?.toString(),
    );
    final descriptionController = TextEditingController(
      text: transaction['description'],
    );

    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('transaction_list.edit_title'.tr()),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  decoration: InputDecoration(
                    labelText: 'transaction_list.amount_label'.tr(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                TextField(
                  controller: descriptionController,
                  decoration: InputDecoration(
                    labelText: 'transaction_list.description_label'.tr(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('transaction_list.cancel'.tr()),
              ),
              TextButton(
                onPressed: () async {
                  try {
                    await _transactionService.updateTransaction(
                      transactionId: transaction['id'],
                      amount: double.tryParse(amountController.text),
                      description: descriptionController.text,
                    );
                    if (context.mounted) {
                      Navigator.pop(context);
                      widget.onTransactionUpdated?.call();
                      Navigator.pop(context);
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${'settings.error_prefix'.tr()} $e'),
                        ),
                      );
                    }
                  }
                },
                child: Text('transaction_list.save'.tr()),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final filteredTransactions =
        widget.transactions.where((t) {
          if (_showNonMonetary) return true;
          final isMonetary =
              t['type']?['is_monetary'] ??
              t['transaction_type']?['is_monetary'] ??
              false;
          return isMonetary == true;
        }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'transaction_list.title'.tr(),
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
              Row(
                children: [
                  Checkbox(
                    value: _showNonMonetary,
                    onChanged:
                        (val) =>
                            setState(() => _showNonMonetary = val ?? false),
                  ),
                  Text(
                    'transaction_list.show_all'.tr(),
                    style: GoogleFonts.outfit(
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          Expanded(
            child:
                filteredTransactions.isEmpty
                    ? Center(
                      child: Text(
                        'transaction_list.empty'.tr(),
                        style: GoogleFonts.outfit(color: Colors.grey),
                      ),
                    )
                    : ListView.builder(
                      itemCount: filteredTransactions.length,
                      itemBuilder: (context, index) {
                        final t = filteredTransactions[index];
                        final type = t['type'] ?? t['transaction_type'] ?? {};
                        final typeName = (type['name'] ?? '').toString();
                        final isMonetary = type['is_monetary'] == true;
                        final amount = (t['amount'] as num?)?.toDouble() ?? 0.0;
                        final date = DateTime.parse(t['created_at']).toLocal();
                        final dateStr = DateFormat('dd/MM HH:mm').format(date);
                        final name = t['name'] ?? typeName;

                        final isPos = _isPositive(typeName);
                        final amountColor = isPos ? Colors.green : Colors.red;
                        final prefix = isPos ? '+' : '-';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey.withOpacity(0.1),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withOpacity(
                                    0.1,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _getIconForType(typeName),
                                  color: theme.colorScheme.primary,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: theme.textTheme.bodyLarge?.color,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      dateStr,
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (isMonetary)
                                    Text(
                                      '$prefix€${amount.toStringAsFixed(2)}',
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: amountColor,
                                      ),
                                    )
                                  else
                                    Text(
                                      'transaction_type.${typeName.toLowerCase()}'
                                          .tr()
                                          .toUpperCase(),
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                ],
                              ),
                              if (widget.canEdit) ...[
                                const SizedBox(width: 8),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert),
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      _editTransaction(t);
                                    } else if (value == 'delete') {
                                      _deleteTransaction(t['id']);
                                    }
                                  },
                                  itemBuilder:
                                      (context) => [
                                        PopupMenuItem(
                                          value: 'edit',
                                          child: Text(
                                            'transaction_list.edit_title'.tr(),
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Text(
                                            'transaction_list.delete'.tr(),
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                      ],
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
          ),

          // Total Balance Footer
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              border: Border(top: BorderSide(color: theme.dividerColor)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'transaction_list.total'.tr(),
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
                Text(
                  '${_calculateTotal(filteredTransactions) >= 0 ? '+' : ''}${_calculateTotal(filteredTransactions).toStringAsFixed(2)} €',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color:
                        _calculateTotal(filteredTransactions) >= 0
                            ? Colors.green
                            : Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _calculateTotal(List<Map<String, dynamic>> transactions) {
    double total = 0;
    for (var t in transactions) {
      final amount = (t['amount'] as num?)?.toDouble() ?? 0.0;
      final quantity = (t['quantity'] as num?)?.toInt() ?? 1;
      total += amount * quantity;
    }
    return total;
  }
}

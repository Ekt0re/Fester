import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';

class TransactionListSheet extends StatelessWidget {
  final List<Map<String, dynamic>> transactions;

  const TransactionListSheet({
    super.key,
    required this.transactions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          Text(
            'Storico Transazioni',
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: transactions.isEmpty
                ? Center(
                    child: Text(
                      'Nessuna transazione trovata',
                      style: GoogleFonts.outfit(color: Colors.grey),
                    ),
                  )
                : ListView.separated(
                    itemCount: transactions.length,
                    separatorBuilder: (context, index) => Divider(color: Colors.grey.shade200),
                    itemBuilder: (context, index) {
                      final t = transactions[index];
                      final type = t['type'] ?? {};
                      final menuItem = t['menu_item'];
                      final name = t['name'] ?? menuItem?['name'] ?? type['name'] ?? 'Unknown';
                      final amount = (t['amount'] as num?)?.toDouble() ?? 0.0;
                      final quantity = (t['quantity'] as num?)?.toInt() ?? 1;
                      final date = DateTime.parse(t['created_at']).toLocal();
                      final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(date);

                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.cardColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.withOpacity(0.2)),
                              ),
                              child: Icon(
                                _getIconForType(type['name']?.toString()),
                                color: colorScheme.primary,
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
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                      color: theme.textTheme.bodyLarge?.color,
                                    ),
                                  ),
                                  Text(
                                    formattedDate,
                                    style: GoogleFonts.outfit(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '€ ${(amount * quantity).toStringAsFixed(2)}',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: theme.textTheme.bodyLarge?.color,
                                  ),
                                ),
                                if (quantity > 1)
                                  Text(
                                    'x$quantity',
                                    style: GoogleFonts.outfit(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForType(String? typeName) {
    switch (typeName?.toLowerCase()) {
      case 'drink':
        return Icons.local_bar;
      case 'food':
        return Icons.restaurant;
      case 'ticket':
        return Icons.confirmation_number;
      case 'fine':
      case 'sanction':
      case 'report':
        return Icons.warning_amber_rounded;
      default:
        return Icons.receipt;
    }
  }
}

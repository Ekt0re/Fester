import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../theme/app_theme.dart';

class StatusHistorySheet extends StatelessWidget {
  final List<Map<String, dynamic>> history;

  const StatusHistorySheet({super.key, required this.history});

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'confermato':
        return AppTheme.statusConfirmed;
      case 'checked_in':
      case 'registrato':
        return Colors.blue;
      case 'inside':
      case 'dentro':
      case 'arrivato':
        return AppTheme.statusConfirmed;
      case 'outside':
      case 'fuori':
        return Colors.orange;
      case 'left':
      case 'uscito':
      case 'partito':
        return AppTheme.statusLeft;
      case 'invited':
      case 'invitato':
      case 'in arrivo':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'confermato':
        return Icons.check_circle_outline;
      case 'checked_in':
      case 'registrato':
        return Icons.how_to_reg;
      case 'inside':
      case 'dentro':
      case 'arrivato':
        return Icons.login;
      case 'outside':
      case 'fuori':
        return Icons.logout;
      case 'left':
      case 'uscito':
      case 'partito':
        return Icons.exit_to_app;
      case 'invited':
      case 'invitato':
      case 'in arrivo':
        return Icons.mail_outline;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
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
            'Cronologia Stati',
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 24),

          Expanded(
            child: history.isEmpty
                ? Center(
                    child: Text(
                      'Nessuna modifica allo stato registrata.',
                      style: GoogleFonts.outfit(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final item = history[index];
                      final statusName = (item['status']?['name'] ?? '').toString();
                      final changedBy = item['changed_by_person'] != null 
                          ? '${item['changed_by_person']['first_name']} ${item['changed_by_person']['last_name']}'
                          : 'Sistema';
                      final date = DateTime.parse(item['created_at']).toLocal();
                      final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(date);
                      
                      final color = _getStatusColor(statusName);
                      final icon = _getStatusIcon(statusName);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.withOpacity(0.1)),
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
                                color: color.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(icon, color: color, size: 24),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    statusName.toUpperCase(),
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: color,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Modificato da: $changedBy',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              dateStr,
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: Colors.grey[500],
                                fontWeight: FontWeight.w500,
                              ),
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
}

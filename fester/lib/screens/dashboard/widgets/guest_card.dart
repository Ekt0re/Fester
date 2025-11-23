import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../theme/app_theme.dart';

class GuestCard extends StatelessWidget {
  final String name;
  final String surname;
  final String idEvent;
  final String statusName;
  final bool isVip;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final VoidCallback onLongPress;
  final VoidCallback onReport;
  final VoidCallback onDrink;

  const GuestCard({
    super.key,
    required this.name,
    required this.surname,
    required this.idEvent,
    required this.statusName,
    this.isVip = false,
    required this.onTap,
    required this.onDoubleTap,
    required this.onLongPress,
    required this.onReport,
    required this.onDrink,
  });

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
      case 'arrivato': // From wireframe
        return AppTheme.statusConfirmed; // Green
      case 'outside':
      case 'fuori':
        return Colors.orange;
      case 'left':
      case 'uscito':
      case 'partito': // From wireframe
        return AppTheme.statusLeft;
      case 'invited':
      case 'invitato':
      case 'in arrivo': // From wireframe
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
    final statusColor = _getStatusColor(statusName);

    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppTheme.primaryLight,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
          border: isVip
              ? Border.all(color: AppTheme.statusVip, width: 2)
              : null,
        ),
        child: Stack(
          children: [
            if (isVip)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.statusVip.withOpacity(0.2),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                    ),
                  ),
                  child: const Icon(Icons.star, color: AppTheme.statusVip, size: 20),
                ),
              ),
            Padding(
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
                              '$name $surname',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'ID: $idEvent',
                              style: GoogleFonts.outfit(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onLongPress: onLongPress,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_getStatusIcon(statusName), color: Colors.white, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                statusName.toUpperCase(),
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: onDrink,
                          icon: const Icon(Icons.local_bar, size: 16),
                          label: const Text('+ Drink'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.2),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: onReport,
                          icon: const Icon(Icons.report_problem, size: 16),
                          label: const Text('Segnala'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.2),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

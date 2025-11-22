import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class ConsumptionGraph extends StatelessWidget {
  final String label;
  final int count;
  final int? maxCount;
  final IconData icon;
  final Color color;
  final VoidCallback? onLongPress;

  const ConsumptionGraph({
    super.key,
    required this.label,
    required this.count,
    this.maxCount,
    required this.icon,
    required this.color,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    double progress = 0.0;
    if (maxCount != null && maxCount! > 0) {
      progress = count / maxCount!;
      if (progress > 1.0) progress = 1.0;
    } else {
      // If no max, just show full circle or some indication? 
      // For now, let's make it full if > 0
      progress = count > 0 ? 1.0 : 0.0;
    }

    Color progressColor = colorScheme.primary;
    if (maxCount != null && count > maxCount!) {
      progressColor = colorScheme.error;
    }

    return GestureDetector(
      onLongPress: onLongPress,
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  value: 1.0, // Background circle
                  strokeWidth: 6,
                  valueColor: AlwaysStoppedAnimation<Color>(theme.dividerColor.withOpacity(0.2)),
                ),
              ),
              SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 6,
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  backgroundColor: Colors.transparent,
                ),
              ),
              Icon(
                icon,
                color: theme.textTheme.bodyLarge?.color?.withOpacity(0.5),
                size: 24,
              ),
              if (count > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: progressColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.cardColor, width: 1.5),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    child: Center(
                      child: Text(
                        '$count',
                        style: GoogleFonts.outfit(
                          color: colorScheme.onPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Colors - Light Mode
  static const Color primaryLight = Color(0xFF8B5CF6); // Modern purple
  static const Color secondaryLight = Color(0xFF10B981); // Emerald green
  static const Color backgroundLight = Color(0xFFF5F7FA);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color errorLight = Color(0xFFBA1A1A);
  static const Color textLight = Color(0xFF1A1C1E);

  // Colors - Dark Mode
  static const Color primaryDark = Color(
    0xFFA78BFA,
  ); // Lighter purple for dark mode
  static const Color secondaryDark = Color(
    0xFF34D399,
  ); // Lighter emerald for dark mode
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color errorDark = Color(0xFFFFB4AB);
  static const Color textDark = Color(0xFFE2E2E6);

  // Status Colors
  static const Color statusConfirmed = Color(0xFF4CAF50);
  static const Color statusLeft = Color(0xFFF44336);
  static const Color statusPending = Color(0xFFFFC107);
  static const Color statusVip = Color(0xFFFFD700);
  static const Color statusCheckedIn = Color(0xFF2196F3); // Blue
  static const Color statusOutside = Color(0xFFFF9800); // Orange
  static const Color statusInvited = Color(0xFF9E9E9E); // Grey

  // Layout Constants
  static const double desktopBreakpoint = 900.0;

  static ThemeData createTheme({
    required bool isDark,
    required Color primary,
    required Color secondary,
    required Color background,
    required Color surface,
    required Color error,
    required Color text,
  }) {
    final brightness = isDark ? Brightness.dark : Brightness.light;
    final baseTextTheme =
        isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: primary,
        secondary: secondary,
        surface: surface,
        error: error,
        onPrimary: isDark ? Colors.black : Colors.white,
        onSecondary: isDark ? Colors.white : Colors.black,
        onSurface: text,
        onError: isDark ? Colors.black : Colors.white,
      ),
      scaffoldBackgroundColor: background,
      textTheme: GoogleFonts.outfitTextTheme(
        baseTextTheme,
      ).apply(bodyColor: text, displayColor: text),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: text,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.outfit(
          color: text,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardTheme(
        color: surface,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        shadowColor: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: isDark ? Colors.black : Colors.white,
          textStyle: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    return createTheme(
      isDark: false,
      primary: primaryLight,
      secondary: secondaryLight,
      background: backgroundLight,
      surface: surfaceLight,
      error: errorLight,
      text: textLight,
    );
  }

  static ThemeData get darkTheme {
    return createTheme(
      isDark: true,
      primary: primaryDark,
      secondary: secondaryDark,
      background: backgroundDark,
      surface: surfaceDark,
      error: errorDark,
      text: textDark,
    );
  }

  // Icon Maps
  static const Map<String, IconData> roleIcons = {
    'admin': Icons.admin_panel_settings,
    'staff': Icons.badge,
    'guest': Icons.person,
    'vip': Icons.star,
    'pr': Icons.people,
  };

  static const Map<String, IconData> transactionIcons = {
    'drink': Icons.local_bar,
    'food': Icons.local_pizza,
    'ticket': Icons.confirmation_number,
    'fine': Icons.money_off,
    'sanction': Icons.gavel,
    'report': Icons.warning,
    'refund': Icons.replay_circle_filled,
    'fee': Icons.monetization_on,
    'note': Icons.notes,
    'entry': Icons.door_front_door,
    'cloakroom': Icons.checkroom,
    'other': Icons.attach_money,
  };

  static const Map<String, IconData> statusIcons = {
    "invited": Icons.person_add,
    "confirmed": Icons.check_circle,
    "checked_in": Icons.check,
    "inside": Icons.home,
    "outside": Icons.exit_to_app,
    "left": Icons.exit_to_app,
    "cancelled": Icons.cancel,
    "banned": Icons.block,
  };

  /// Global method to get status icon based on status string
  static IconData getStatusIcon(String status) {
    return statusIcons[status.toLowerCase()] ?? Icons.help_outline;
  }

  /// Global method to get transaction type icon based on transaction type name
  static IconData getTransactionTypeIcon(String transactionTypeName) {
    final lowerCaseName = transactionTypeName.toLowerCase();

    // Check for exact matches first
    if (transactionIcons.containsKey(lowerCaseName)) {
      return transactionIcons[lowerCaseName]!;
    }

    // Dynamic partial matching - check if any key in transactionIcons is contained in the name
    for (final entry in transactionIcons.entries) {
      if (lowerCaseName.contains(entry.key)) {
        return entry.value;
      }
    }
    // Default icon
    return transactionIcons['other'] ?? Icons.attach_money;
  }

  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return AppTheme.statusConfirmed;
      case 'checked_in':
        return AppTheme.statusCheckedIn;
      case 'inside':
        return AppTheme.statusConfirmed;
      case 'outside':
        return AppTheme.statusOutside;
      case 'left':
        return AppTheme.statusLeft;
      case 'cancelled':
        return AppTheme.statusLeft;
      case 'banned':
        return AppTheme.statusLeft;
      case 'invited':
        return AppTheme.statusInvited;
      default:
        return AppTheme.statusInvited;
    }
  }
}

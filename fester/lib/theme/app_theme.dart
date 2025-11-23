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
  static const Color primaryDark = Color(0xFFA78BFA); // Lighter purple for dark mode
  static const Color secondaryDark = Color(0xFF34D399); // Lighter emerald for dark mode
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

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: primaryLight,
        secondary: secondaryLight,
        surface: surfaceLight,
        error: errorLight,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: textLight,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: backgroundLight,
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme).apply(
        bodyColor: textLight,
        displayColor: textLight,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundLight,
        foregroundColor: textLight,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.outfit(
          color: textLight,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardTheme(
        color: surfaceLight,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        shadowColor: Colors.black.withOpacity(0.1),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryLight,
          foregroundColor: Colors.white,
          textStyle: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLight,
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
          borderSide: const BorderSide(color: primaryLight, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: primaryDark,
        secondary: secondaryDark,
        surface: surfaceDark,
        error: errorDark,
        onPrimary: Colors.black,
        onSecondary: Colors.white,
        onSurface: textDark,
        onError: Colors.black,
      ),
      scaffoldBackgroundColor: backgroundDark,
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).apply(
        bodyColor: textDark,
        displayColor: textDark,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundDark,
        foregroundColor: textDark,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.outfit(
          color: textDark,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardTheme(
        color: surfaceDark,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        shadowColor: Colors.black.withOpacity(0.3),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryDark,
          foregroundColor: Colors.black,
          textStyle: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceDark,
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
          borderSide: const BorderSide(color: primaryDark, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
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
    'entry': Icons.door_front_door,
    'cloakroom': Icons.checkroom,
    'other': Icons.attach_money,
    'report': Icons.warning_amber_rounded,
    'fine': Icons.money_off,
    'sanction': Icons.gavel,
  };

  static const Map<String, IconData> statusIcons = {
    'confirmed': Icons.check_circle_outline,
    'confermato': Icons.check_circle_outline,
    'checked_in': Icons.how_to_reg,
    'registrato': Icons.how_to_reg,
    'inside': Icons.login,
    'dentro': Icons.login,
    'arrivato': Icons.login,
    'outside': Icons.logout,
    'fuori': Icons.logout,
    'left': Icons.exit_to_app,
    'uscito': Icons.exit_to_app,
    'partito': Icons.exit_to_app,
    'invited': Icons.mail_outline,
    'invitato': Icons.mail_outline,
    'in arrivo': Icons.mail_outline,
  };
}

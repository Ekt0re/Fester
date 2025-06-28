import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fester/services/supabase_service.dart';

import 'services/local_database_service.dart';
import 'screens/login_screen.dart';
import 'screens/host_login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/guest_lookup_screen.dart';
import 'screens/guest_profile_screen.dart';
import 'screens/bar_screen.dart';
import 'screens/settings_screen.dart';
import 'providers/auth_provider.dart';
import 'utils/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize local database
  await LocalDatabaseService.initializeHive();
  
  // Initialize settings box
  await LocalDatabaseService.openSettingsBox();

  // Initialize Supabase
  await SupabaseConfig.initSupabase();

  runApp(
    // Wrap app with ProviderScope for Riverpod state management
    const ProviderScope(
      child: FesterApp(),
    ),
  );
}

class FesterApp extends ConsumerWidget {
  const FesterApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return MaterialApp(
      title: 'FESTER - Gestione Eventi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 1,
        ),
        cardTheme: CardTheme(
          color: AppColors.surface,
          elevation: 2,
          shadowColor: AppColors.cardShadow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
        ),
      ),
      initialRoute: authState.user != null ? '/dashboard' : '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/host-login': (context) => const HostLoginScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/guest-lookup': (context) => const GuestLookupScreen(),
        '/guest-profile': (context) => const GuestProfileScreen(),
        '/bar': (context) => const BarScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}

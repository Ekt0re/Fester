// lib/router.dart - Centralized GoRouter configuration
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'Login/login_page.dart';
import 'Login/set_new_password_page.dart';
import 'home_page.dart';
import 'screens/event_selection_screen.dart';
import 'screens/dashboard/event_dashboard_screen.dart';
import 'screens/dashboard/menu_management_screen.dart';
import 'screens/dashboard/staff_list_screen.dart';
import 'screens/dashboard/guest_list_screen.dart';
import 'screens/dashboard/event_settings_screen.dart';
import 'screens/dashboard/global_search_screen.dart';
import 'screens/dashboard/notifications_screen.dart';
import 'screens/dashboard/event_statistics_screen.dart';
import 'screens/dashboard/qr_scanner_screen.dart';
import 'screens/invite_bridge_screen.dart';
import 'services/supabase/deep_link_handler.dart';

/// Global key to access navigator from anywhere
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Router configuration
final GoRouter router = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/',
  debugLogDiagnostics: true,
  redirect: (context, state) {
    final session = Supabase.instance.client.auth.currentSession;
    final isLoggedIn = session != null;
    final isRecovery = DeepLinkHandler.isRecoveryMode;
    final location = state.matchedLocation;

    // Allow recovery flow
    if (isRecovery) return null;

    // Public routes
    final publicRoutes = ['/login', '/set-new-password', '/invite'];
    final isPublicRoute = publicRoutes.any((r) => location.startsWith(r));

    // If not logged in and not on a public route, redirect to login
    if (!isLoggedIn && !isPublicRoute && location != '/') {
      return '/login';
    }

    return null;
  },
  routes: [
    // Splash / Root
    GoRoute(
      path: '/',
      name: 'splash',
      builder: (context, state) => const _SplashRedirect(),
    ),

    // Auth Routes
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/set-new-password',
      name: 'set-new-password',
      builder: (context, state) => const SetNewPasswordPage(),
    ),

    // Home (Legacy compatibility)
    GoRoute(
      path: '/home',
      name: 'home',
      builder: (context, state) => const HomePage(),
    ),

    // Event Selection
    GoRoute(
      path: '/event-selection',
      name: 'event-selection',
      builder: (context, state) => const EventSelectionScreen(),
    ),

    // Create Event (handled by existing screen with its own internal navigation)
    // Will use Navigator.push from EventSelectionScreen

    // Event Dashboard with sub-routes
    GoRoute(
      path: '/event/:eventId',
      name: 'event-dashboard',
      builder: (context, state) {
        final eventId = state.pathParameters['eventId']!;
        return EventDashboardScreen(eventId: eventId);
      },
      routes: [
        GoRoute(
          path: 'menu',
          name: 'event-menu',
          builder: (context, state) {
            final eventId = state.pathParameters['eventId']!;
            final role = state.extra as String?;
            return MenuManagementScreen(
              eventId: eventId,
              currentUserRole: role,
            );
          },
        ),
        GoRoute(
          path: 'staff',
          name: 'event-staff',
          builder: (context, state) {
            final eventId = state.pathParameters['eventId']!;
            final role = state.extra as String?;
            return StaffListScreen(eventId: eventId, currentUserRole: role);
          },
        ),
        GoRoute(
          path: 'guests',
          name: 'event-guests',
          builder: (context, state) {
            final eventId = state.pathParameters['eventId']!;
            return GuestListScreen(eventId: eventId);
          },
        ),
        GoRoute(
          path: 'settings',
          name: 'event-settings',
          builder: (context, state) {
            final eventId = state.pathParameters['eventId']!;
            return EventSettingsScreen(eventId: eventId);
          },
        ),
        GoRoute(
          path: 'search',
          name: 'event-search',
          builder: (context, state) {
            final eventId = state.pathParameters['eventId']!;
            final role = state.extra as String?;
            return GlobalSearchScreen(eventId: eventId, currentUserRole: role);
          },
        ),
        GoRoute(
          path: 'notifications',
          name: 'event-notifications',
          builder: (context, state) {
            final eventId = state.pathParameters['eventId']!;
            return NotificationsScreen(eventId: eventId);
          },
        ),
        GoRoute(
          path: 'statistics',
          name: 'event-statistics',
          builder: (context, state) {
            final eventId = state.pathParameters['eventId']!;
            return EventStatisticsScreen(eventId: eventId);
          },
        ),
        GoRoute(
          path: 'qr-scanner',
          name: 'event-qr-scanner',
          builder: (context, state) {
            final eventId = state.pathParameters['eventId']!;
            final role = state.extra as String?;
            return QRScannerScreen(eventId: eventId, currentUserRole: role);
          },
        ),
      ],
    ),

    // Invite Bridge Routes
    GoRoute(
      path: '/invite',
      name: 'invite-bridge',
      builder: (context, state) => const InviteBridgeScreen(),
    ),
    GoRoute(
      path: '/invite/staff/:eventId/:userId',
      name: 'invite-staff-event',
      builder: (context, state) {
        final eventId = state.pathParameters['eventId']!;
        final userId = state.pathParameters['userId']!;
        return InviteBridgeScreen(
          inviteType: 'staff',
          targetId: userId,
          eventId: eventId,
        );
      },
    ),
    GoRoute(
      path: '/invite/staff/:userId',
      name: 'invite-staff',
      builder: (context, state) {
        final userId = state.pathParameters['userId']!;
        return InviteBridgeScreen(inviteType: 'staff', targetId: userId);
      },
    ),
    GoRoute(
      path: '/JoinEvent/:userId',
      name: 'join-event-legacy',
      redirect: (context, state) {
        final userId = state.pathParameters['userId']!;
        return '/invite/staff/$userId';
      },
    ),
  ],
  errorBuilder:
      (context, state) => Scaffold(
        appBar: AppBar(title: const Text('Pagina non trovata')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Errore: ${state.error?.message ?? "Pagina non trovata"}'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/'),
                child: const Text('Torna alla Home'),
              ),
            ],
          ),
        ),
      ),
);

/// Simple splash that triggers redirect logic
class _SplashRedirect extends StatefulWidget {
  const _SplashRedirect();

  @override
  State<_SplashRedirect> createState() => _SplashRedirectState();
}

class _SplashRedirectState extends State<_SplashRedirect> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndRedirect();
  }

  Future<void> _checkAuthAndRedirect() async {
    // Artificial delay for splash effect
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      // Check for last visited event
      try {
        final prefs = await SharedPreferences.getInstance();
        final lastEventId = prefs.getString('last_event_id');

        if (lastEventId != null && lastEventId.isNotEmpty) {
          // Verify if the event still exists/user has access (optional but good practice)
          // For now, we trust the ID and let the dashboard handle 404/permissions if needed
          if (mounted) {
            context.go('/event/$lastEventId');
            return;
          }
        }
      } catch (e) {
        // Ignore errors reading prefs
      }

      if (mounted) context.go('/event-selection');
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFE8F0FE),
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

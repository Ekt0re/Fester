import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import 'mobile_nav_bar.dart';

class MobileLayout extends StatelessWidget {
  final Widget child;

  const MobileLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < AppTheme.desktopBreakpoint;

        // Get eventId from state if present
        final state = GoRouterState.of(context);
        final eventId = state.pathParameters['eventId'];
        final extra = state.extra;
        final String? userRole = extra is String ? extra : null;

        // Determine if we should show the navbar (e.g., hide on login)
        final bool showNavBar =
            isMobile &&
            !state.matchedLocation.startsWith('/login') &&
            !state.matchedLocation.startsWith('/set-new-password') &&
            state.matchedLocation != '/';

        if (!showNavBar) {
          return child;
        }

        return Scaffold(
          body: child,
          extendBody: true, // Allows content to be behind the navbar if needed
          bottomNavigationBar: MobileNavBar(
            key: ValueKey('mobile_nav_${eventId ?? "none"}'),
            eventId: eventId,
            userRole: userRole,
          ),
        );
      },
    );
  }
}

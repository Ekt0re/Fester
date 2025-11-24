import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_links/app_links.dart';
import 'package:url_strategy/url_strategy.dart';
import 'package:universal_platform/universal_platform.dart';
import 'Login/login_page.dart';
import 'home_page.dart';
import 'services/SupabaseServicies/supabase_config.dart';
import 'services/SupabaseServicies/deep_link_handler.dart';
import 'services/SupabaseServicies/event_service.dart';
import 'Login/set_new_password_page.dart';
import 'screens/event_selection_screen.dart';
import 'screens/dashboard/event_dashboard_screen.dart';
import 'screens/profile/staff_profile_screen.dart';
import 'screens/dashboard/guest_list_screen.dart';
import 'screens/dashboard/menu_management_screen.dart';
import 'screens/dashboard/staff_list_screen.dart';
import 'screens/dashboard/event_settings_screen.dart';
import 'screens/dashboard/global_search_screen.dart';
import 'screens/dashboard/notifications_screen.dart';
import 'screens/dashboard/event_statistics_screen.dart';
import 'screens/dashboard/qr_scanner_screen.dart';
import 'package:logger/logger.dart';

import 'theme/app_theme.dart';
import 'providers/theme_provider.dart';

// Helper function to load staff profile data
Future<Map<String, dynamic>> _loadStaffProfile(
  String eventId,
  String staffUserId,
) async {
  final eventService = EventService();
  final staffList = await eventService.getEventStaff(eventId);
  final eventStaff = staffList.firstWhere(
    (s) => s.staffUserId == staffUserId,
    orElse: () => throw Exception('Staff member not found'),
  );

  return {
    'screen': StaffProfileScreen(eventStaff: eventStaff, eventId: eventId),
  };
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setPathUrlStrategy(); // Rimuove il # dagli URL
  await SupabaseConfig.initialize();
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  final String initialRoute;
  const MyApp({super.key, this.initialRoute = '/'});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Fester 3.0',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          initialRoute: initialRoute,
          routes: {
            '/': (context) => const SplashScreen(),
            '/home': (context) => const HomePage(),
            '/event-selection': (context) => const EventSelectionScreen(),
            '/login': (context) => const LoginPage(),
            '/set-new-password': (context) => const SetNewPasswordPage(),
            '/event-detail': (context) {
              final eventId =
                  ModalRoute.of(context)!.settings.arguments as String;
              return EventDashboardScreen(eventId: eventId);
            },
          },
          onGenerateRoute: (settings) {
            if (settings.name != null && settings.name!.startsWith('/event/')) {
              final uri = Uri.parse(settings.name!);
              if (uri.pathSegments.length >= 2 &&
                  uri.pathSegments[0] == 'event') {
                final eventId = uri.pathSegments[1];

                // Handle sub-routes
                if (uri.pathSegments.length > 2) {
                  final page = uri.pathSegments[2];
                  switch (page) {
                    case 'menu':
                      return MaterialPageRoute(
                        settings: settings,
                        builder:
                            (context) => MenuManagementScreen(eventId: eventId),
                      );
                    case 'staff':
                      return MaterialPageRoute(
                        settings: settings,
                        builder: (context) => StaffListScreen(eventId: eventId),
                      );
                    case 'guests':
                      return MaterialPageRoute(
                        settings: settings,
                        builder: (context) => GuestListScreen(eventId: eventId),
                      );
                    case 'settings':
                      return MaterialPageRoute(
                        settings: settings,
                        builder:
                            (context) => EventSettingsScreen(eventId: eventId),
                      );
                    case 'search':
                      return MaterialPageRoute(
                        settings: settings,
                        builder:
                            (context) => GlobalSearchScreen(eventId: eventId),
                      );
                    case 'notifications':
                      return MaterialPageRoute(
                        settings: settings,
                        builder:
                            (context) => NotificationsScreen(eventId: eventId),
                      );
                    case 'statistics':
                      return MaterialPageRoute(
                        settings: settings,
                        builder:
                            (context) =>
                                EventStatisticsScreen(eventId: eventId),
                      );
                    case 'qr-scanner':
                      return MaterialPageRoute(
                        settings: settings,
                        builder: (context) => QRScannerScreen(eventId: eventId),
                      );
                  }
                }

                // Default to dashboard if no sub-route or unknown sub-route
                return MaterialPageRoute(
                  settings: settings,
                  builder: (context) => EventDashboardScreen(eventId: eventId),
                );
              }
            }

            if (settings.name == '/staff-profile') {
              final args = settings.arguments as Map<String, dynamic>?;
              if (args != null) {
                final eventId = args['eventId'] as String;
                final staffUserId = args['staffUserId'] as String;

                return MaterialPageRoute(
                  settings: settings,
                  builder:
                      (context) => FutureBuilder(
                        future: _loadStaffProfile(eventId, staffUserId),
                        builder: (
                          context,
                          AsyncSnapshot<Map<String, dynamic>> snapshot,
                        ) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Scaffold(
                              body: Center(child: CircularProgressIndicator()),
                            );
                          }

                          if (snapshot.hasError || !snapshot.hasData) {
                            return Scaffold(
                              appBar: AppBar(title: const Text('Errore')),
                              body: Center(
                                child: Text(
                                  'Errore caricamento profilo: ${snapshot.error}',
                                ),
                              ),
                            );
                          }

                          final data = snapshot.data!;
                          return data['screen'] as Widget;
                        },
                      ),
                );
              }
            }

            return MaterialPageRoute(
              builder: (context) => const SplashScreen(),
            );
          },
        );
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      colors: false,
      printEmojis: false,
      printTime: false,
    ),
  );
  StreamSubscription? _sub;
  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    // Abilita gestione automatica dei deep link (sia web sia mobile se serve)
    DeepLinkHandler().initialize(context);
    final supabase = SupabaseConfig.client;

    String? initialLink;
    try {
      final uri = await AppLinks().getInitialLink();
      initialLink = uri?.toString();
      _logger.d('[DEBUG] initialLink: $initialLink');
    } catch (e, st) {
      _logger.e('[ERROR] getInitialLink failed:', error: e, stackTrace: st);
    }

    final queryParams = Uri.base.queryParameters;

    // BLOCCA getSessionFromUrl se siamo in recovery mode (controlla flag globale PRIMA)
    bool isRecoveryMode =
        DeepLinkHandler.isRecoveryMode ||
        queryParams['type'] == 'recovery' ||
        (initialLink != null &&
            Uri.parse(initialLink).queryParameters['type'] == 'recovery');

    if (isRecoveryMode) {
      _logger.i('[NAV] Recovery mode attivo - skippo TUTTO getSessionFromUrl');
    }

    if (UniversalPlatform.isWeb) {
      // Se il link è scaduto o già usato, mostra un messaggio e rimanda al login
      if (queryParams['error_code'] == 'otp_expired') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Il link utilizzato è scaduto o non più valido. Richiedi un nuovo reset password o registrazione.',
              ),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.of(context).pushReplacementNamed('/login');
        });
        return;
      }
      // NON processare session se siamo in recovery
      if (!isRecoveryMode) {
        final search = Uri.base.query;
        _logger.d('[DEBUG] Web query: $search');
        if (search.contains('code=') ||
            search.contains('access_token=') ||
            search.contains('error=')) {
          try {
            _logger.d(
              '[DEBUG] Web: trovati parametri auth, provo getSessionFromUrl',
            );
            await supabase.auth.getSessionFromUrl(Uri.base);
          } catch (err, st) {
            _logger.e(
              '[ERROR] Web getSessionFromUrl:',
              error: err,
              stackTrace: st,
            );
          }
        } else {
          _logger.d(
            '[DEBUG] Web: nessun parametro magico trovato, skippa getSessionFromUrl',
          );
        }
      } else {
        _logger.i(
          '[DEBUG] Web: recovery mode rilevato, skippo getSessionFromUrl',
        );
      }
    } else if (initialLink != null && !isRecoveryMode) {
      // MOBILE/DESKTOP: gestisce automatico magic/reset ecc. MA NON recovery
      try {
        _logger.d(
          '[DEBUG] Mobile/Desktop: provo getSessionFromUrl con initialLink',
        );
        await supabase.auth.getSessionFromUrl(Uri.parse(initialLink));
      } catch (err, st) {
        _logger.e(
          '[ERROR] Mobile/Desktop getSessionFromUrl:',
          error: err,
          stackTrace: st,
        );
      }
    } else if (isRecoveryMode) {
      _logger.i(
        '[DEBUG] Mobile/Desktop: recovery mode rilevato, skippo getSessionFromUrl',
      );
    }

    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    // BLOCCA TOTALE se recovery mode attivo (flag globale)
    if (DeepLinkHandler.isRecoveryMode) {
      _logger.i(
        '[NAV] SplashScreen: recovery mode attivo - BLOCCATO redirect a /home o /login',
      );
      return;
    }

    // Pattern: non navigare MAI nessuna pagina se già su set-new-password (o altri recovery)!
    final currentRoute = ModalRoute.of(context)?.settings.name;
    if (currentRoute == '/set-new-password') {
      _logger.i(
        '[NAV] SplashScreen: già su set-new-password - BLOCCATO redirect',
      );
      return;
    }

    final session = supabase.auth.currentSession;
    _logger.d('[DEBUG] session auth: $session');
    if (session != null) {
      Navigator.of(context).pushReplacementNamed('/event-selection');
    } else {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFE8F0FE),
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

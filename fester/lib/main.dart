import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uni_links/uni_links.dart';
import 'package:url_strategy/url_strategy.dart';
import 'package:universal_platform/universal_platform.dart';
import 'Login/login_page.dart';
import 'home_page.dart';
import 'services/SupabaseServicies/supabase_config.dart';
import 'services/SupabaseServicies/deep_link_handler.dart';
import 'Login/set_new_password_page.dart';
import 'screens/event_selection_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setPathUrlStrategy(); // Rimuove il # dagli URL
  await SupabaseConfig.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  final String initialRoute;
  const MyApp({super.key, this.initialRoute = '/'});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fester 3.0',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialRoute: initialRoute,
      routes: {
        '/': (context) => const SplashScreen(),
        '/home': (context) => const HomePage(),
        '/event-selection': (context) => const EventSelectionScreen(),
        '/login': (context) => const LoginPage(),
        '/set-new-password': (context) => const SetNewPasswordPage(),
      },
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => const SplashScreen(),
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
      initialLink = await getInitialLink();
      print('[DEBUG] initialLink: $initialLink');
    } catch (e, st) {
      print('[ERROR] getInitialLink failed: $e\n$st');
    }

    final queryParams = Uri.base.queryParameters;

    // BLOCCA getSessionFromUrl se siamo in recovery mode (controlla flag globale PRIMA)
    bool isRecoveryMode = DeepLinkHandler.isRecoveryMode ||
                          queryParams['type'] == 'recovery' || 
                          (initialLink != null && Uri.parse(initialLink).queryParameters['type'] == 'recovery');
    
    if (isRecoveryMode) {
      print('[NAV] Recovery mode attivo - skippo TUTTO getSessionFromUrl');
    }
    
    if (UniversalPlatform.isWeb) {
      // Se il link è scaduto o già usato, mostra un messaggio e rimanda al login
      if (queryParams['error_code'] == 'otp_expired') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Il link utilizzato è scaduto o non più valido. Richiedi un nuovo reset password o registrazione.'),
            backgroundColor: Colors.red,
          ));
          Navigator.of(context).pushReplacementNamed('/login');
        });
        return;
      }
      // NON processare session se siamo in recovery
      if (!isRecoveryMode) {
        final search = Uri.base.query;
        print('[DEBUG] Web query: $search');
        if (search.contains('code=') || search.contains('access_token=') || search.contains('error=')) {
          try {
            print('[DEBUG] Web: trovati parametri auth, provo getSessionFromUrl');
            await supabase.auth.getSessionFromUrl(Uri.base);
          } catch (err, st) {
            print('[ERROR] Web getSessionFromUrl: $err\n$st');
          }
        } else {
          print('[DEBUG] Web: nessun parametro magico trovato, skippa getSessionFromUrl');
        }
      } else {
        print('[DEBUG] Web: recovery mode rilevato, skippo getSessionFromUrl');
      }
    } else if (initialLink != null && !isRecoveryMode) {
      // MOBILE/DESKTOP: gestisce automatico magic/reset ecc. MA NON recovery
      try {
        print('[DEBUG] Mobile/Desktop: provo getSessionFromUrl con initialLink');
        await supabase.auth.getSessionFromUrl(Uri.parse(initialLink));
      } catch (err, st) {
        print('[ERROR] Mobile/Desktop getSessionFromUrl: $err\n$st');
      }
    } else if (isRecoveryMode) {
      print('[DEBUG] Mobile/Desktop: recovery mode rilevato, skippo getSessionFromUrl');
    }

    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;
    
    // BLOCCA TOTALE se recovery mode attivo (flag globale)
    if (DeepLinkHandler.isRecoveryMode) {
      print('[NAV] SplashScreen: recovery mode attivo - BLOCCATO redirect a /home o /login');
      return;
    }
    
    // Pattern: non navigare MAI nessuna pagina se già su set-new-password (o altri recovery)!
    final currentRoute = ModalRoute.of(context)?.settings.name;
    if (currentRoute == '/set-new-password') {
      print('[NAV] SplashScreen: già su set-new-password - BLOCCATO redirect');
      return;
    }
    
    final session = supabase.auth.currentSession;
    print('[DEBUG] session auth: $session');
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

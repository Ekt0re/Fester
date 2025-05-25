import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fester_frontend/screens/login_screen.dart';
import 'package:fester_frontend/screens/register_screen.dart';
import 'package:fester_frontend/screens/home_screen.dart';
import 'package:fester_frontend/screens/event_detail_screen.dart';
import 'package:fester_frontend/screens/create_event_screen.dart';
import 'package:fester_frontend/screens/edit_event_screen.dart';
import 'package:fester_frontend/screens/guest_list_screen.dart';
import 'package:fester_frontend/screens/checkin_screen.dart';
import 'package:fester_frontend/screens/qr_scanner_screen.dart';
import 'package:fester_frontend/screens/add_guest_screen.dart';
import 'package:fester_frontend/blocs/auth/auth_bloc.dart';
import 'package:fester_frontend/blocs/event/event_bloc.dart';
import 'package:fester_frontend/config/env_config.dart';
import 'package:fester_frontend/services/api_service.dart';
import 'package:logging/logging.dart';
import 'dart:async';

final logger = Logger('main');

void main() async {
  try {
    // Inizializzazione nella stessa zona
    runZonedGuarded(() async {
      WidgetsFlutterBinding.ensureInitialized();
      logger.info('🚀 Starting application...');
      logger.info('Initializing WidgetsFlutterBinding...');
      logger.info('✅ WidgetsFlutterBinding initialized');

      logger.info('Loading environment configuration...');
      await EnvConfig.init();
      logger.info('✅ EnvConfig loaded: ${EnvConfig.supabaseUrl}');

      logger.info('Initializing Supabase...');
      await Supabase.initialize(
        url: EnvConfig.supabaseUrl,
        anonKey: EnvConfig.supabaseAnonKey,
      );
      logger.info('✅ Supabase initialized');

      logger.info('Starting Flutter app...');
      runApp(const MyApp());
      logger.info('✅ Flutter app started');
    }, (error, stack) {
      logger.severe(' Flutter error: $error');
      logger.severe(' Stack trace: $stack');
    });
  } catch (e, stack) {
    logger.severe('Fatal error during initialization: $e');
    logger.severe('Stack trace: $stack');
    rethrow;
  }
}

final GoRouter _router = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/events/create',
      builder: (context, state) => const CreateEventScreen(),
    ),
    GoRoute(
      path: '/events/:eventId',
      builder: (context, state) {
        final eventId = state.pathParameters['eventId'] ?? '';
        return EventDetailScreen(eventId: eventId);
      },
    ),
    GoRoute(
      path: '/events/:eventId/edit',
      builder: (context, state) {
        final eventId = state.pathParameters['eventId'] ?? '';
        return EditEventScreen(eventId: eventId);
      },
    ),
    GoRoute(
      path: '/events/:eventId/guests',
      builder: (context, state) {
        final eventId = state.pathParameters['eventId'] ?? '';
        return GuestListScreen(eventId: eventId);
      },
    ),
    GoRoute(
      path: '/events/:eventId/guests/add',
      builder: (context, state) {
        final eventId = state.pathParameters['eventId'] ?? '';
        return AddGuestScreen(eventId: eventId);
      },
    ),
    GoRoute(
      path: '/events/:eventId/checkin',
      builder: (context, state) {
        final eventId = state.pathParameters['eventId'] ?? '';
        return CheckinScreen(eventId: eventId);
      },
    ),
    GoRoute(
      path: '/events/:eventId/qr-scanner',
      builder: (context, state) {
        final eventId = state.pathParameters['eventId'] ?? '';
        return QrScannerScreen(eventId: eventId);
      },
    ),
  ],
);

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final apiService = ApiService();
    
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (context) => AuthBloc(apiService: apiService),
        ),
        BlocProvider<EventBloc>(
          create: (context) => EventBloc(),
        ),
      ],
      child: MaterialApp.router(
        title: EnvConfig.appName,
        debugShowCheckedModeBanner: EnvConfig.isDebug,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          fontFamily: 'Roboto',
        ),
        routerConfig: _router,
      ),
    );
  }
}

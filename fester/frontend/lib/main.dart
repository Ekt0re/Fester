import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fester_frontend/screens/login_screen.dart';
import 'package:fester_frontend/screens/register_screen.dart';
import 'package:fester_frontend/screens/home_screen.dart';
import 'package:fester_frontend/screens/event_detail_screen.dart';
import 'package:fester_frontend/screens/create_event_screen.dart';
import 'package:fester_frontend/screens/guest_list_screen.dart';
import 'package:fester_frontend/screens/checkin_screen.dart';
import 'package:fester_frontend/screens/qr_scanner_screen.dart';
import 'package:fester_frontend/blocs/auth/auth_bloc.dart';
import 'package:fester_frontend/blocs/event/event_bloc.dart';
import 'package:fester_frontend/config/env_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inizializza le variabili di ambiente
  await EnvConfig.init();
  
  // Inizializza Supabase
  await Supabase.initialize(
    url: EnvConfig.supabaseUrl,
    anonKey: EnvConfig.supabaseAnonKey,
    debug: EnvConfig.isDebug,
  );

  runApp(const MyApp());
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
      path: '/events/:eventId/guests',
      builder: (context, state) {
        final eventId = state.pathParameters['eventId'] ?? '';
        return GuestListScreen(eventId: eventId);
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
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (context) => AuthBloc(),
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

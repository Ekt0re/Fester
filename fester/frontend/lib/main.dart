import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fester/screens/login_screen.dart';
import 'package:fester/screens/register_screen.dart';
import 'package:fester/screens/home_screen.dart';
import 'package:fester/screens/event_detail_screen.dart';
import 'package:fester/screens/create_event_screen.dart';
import 'package:fester/screens/guest_list_screen.dart';
import 'package:fester/screens/checkin_screen.dart';
import 'package:fester/screens/qr_scanner_screen.dart';
import 'package:fester/blocs/auth/auth_bloc.dart';
import 'package:fester/blocs/event/event_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inizializza Supabase
  await Supabase.initialize(
    url: 'https://tzrjlnvdeqmmlnivoszq.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR6cmpsbnZkZXFtbWxuaXZvc3pxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDgxMDY0MDksImV4cCI6MjA2MzY4MjQwOX0.ZKSaOK62VlWSnYFZKTu-ry7TcsID9JoYFJ3oR9bA0TU',
  );
  
  runApp(FesterApp());
}

class FesterApp extends StatelessWidget {
  FesterApp({Key? key}) : super(key: key);

  // Router per la navigazione
  final _router = GoRouter(
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
        path: '/events/:id',
        builder: (context, state) {
          final eventId = state.pathParameters['id'] ?? '';
          return EventDetailScreen(eventId: eventId);
        },
      ),
      GoRoute(
        path: '/events/:id/guests',
        builder: (context, state) {
          final eventId = state.pathParameters['id'] ?? '';
          return GuestListScreen(eventId: eventId);
        },
      ),
      GoRoute(
        path: '/events/:id/checkin',
        builder: (context, state) {
          final eventId = state.pathParameters['id'] ?? '';
          return CheckinScreen(eventId: eventId);
        },
      ),
      GoRoute(
        path: '/events/:id/qr-scanner',
        builder: (context, state) {
          final eventId = state.pathParameters['id'] ?? '';
          return QrScannerScreen(eventId: eventId);
        },
      ),
    ],
    redirect: (context, state) {
      // Controlla l'autenticazione
      final isLoggedIn = Supabase.instance.client.auth.currentSession != null;
      final isLoginRoute = state.matchedLocation == '/login' || state.matchedLocation == '/register';

      if (!isLoggedIn && !isLoginRoute) {
        return '/login';
      }

      if (isLoggedIn && isLoginRoute) {
        return '/home';
      }

      return null;
    },
  );

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => AuthBloc()),
        BlocProvider(create: (context) => EventBloc()),
      ],
      child: MaterialApp.router(
        title: 'Fester - Gestione Eventi',
        theme: ThemeData(
          primarySwatch: Colors.deepPurple,
          useMaterial3: true,
          fontFamily: 'Roboto',
        ),
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Eventi
abstract class AuthEvent {}

class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;

  AuthLoginRequested({required this.email, required this.password});
}

class AuthRegisterRequested extends AuthEvent {
  final String email;
  final String password;
  final String nome;
  final String cognome;

  AuthRegisterRequested({
    required this.email, 
    required this.password,
    required this.nome,
    required this.cognome
  });
}

class AuthLogoutRequested extends AuthEvent {}

class AuthCheckRequested extends AuthEvent {}

// Stati
abstract class AuthState {}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final User user;
  
  AuthAuthenticated({required this.user});
}

class AuthUnauthenticated extends AuthState {}

class AuthFailure extends AuthState {
  final String message;
  
  AuthFailure({required this.message});
}

// BLoC
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final supabase = Supabase.instance.client;
  final secureStorage = const FlutterSecureStorage();

  AuthBloc() : super(AuthInitial()) {
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthCheckRequested>(_onCheckRequested);
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      final response = await supabase.auth.signInWithPassword(
        email: event.email,
        password: event.password,
      );

      if (response.user != null) {
        // Salva il token JWT
        await secureStorage.write(
          key: 'auth_token',
          value: response.session?.accessToken,
        );
        emit(AuthAuthenticated(user: response.user!));
      } else {
        emit(AuthFailure(message: 'Errore durante il login'));
      }
    } catch (error) {
      emit(AuthFailure(message: 'Errore durante il login: ${error.toString()}'));
    }
  }

  Future<void> _onRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      final response = await supabase.auth.signUp(
        email: event.email,
        password: event.password,
        data: {
          'nome': event.nome,
          'cognome': event.cognome,
        },
      );

      if (response.user != null) {
        // Salva il token JWT
        await secureStorage.write(
          key: 'auth_token',
          value: response.session?.accessToken,
        );
        emit(AuthAuthenticated(user: response.user!));
      } else {
        emit(AuthFailure(message: 'Errore durante la registrazione'));
      }
    } catch (error) {
      emit(AuthFailure(message: 'Errore durante la registrazione: ${error.toString()}'));
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      await supabase.auth.signOut();
      await secureStorage.delete(key: 'auth_token');
      emit(AuthUnauthenticated());
    } catch (error) {
      emit(AuthFailure(message: 'Errore durante il logout: ${error.toString()}'));
    }
  }

  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      final session = supabase.auth.currentSession;
      
      if (session != null) {
        emit(AuthAuthenticated(user: session.user));
      } else {
        // Prova a recuperare il token dal secure storage
        final token = await secureStorage.read(key: 'auth_token');
        
        if (token != null) {
          // TODO: Implementare refresh token
          emit(AuthUnauthenticated());
        } else {
          emit(AuthUnauthenticated());
        }
      }
    } catch (error) {
      emit(AuthUnauthenticated());
    }
  }
} 
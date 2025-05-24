import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fester_frontend/config/env_config.dart';
import 'package:fester_frontend/services/api_service.dart';
import 'package:fester_frontend/utils/logger.dart';

part 'auth_event.dart';
part 'auth_state.dart';

/// Bloc per la gestione dell'autenticazione
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final ApiService _apiService = ApiService();
  final Logger _logger = const Logger('AuthBloc');
  
  /// Costruttore che inizializza lo stato iniziale
  AuthBloc() : super(const AuthInitial()) {
    on<AuthInitializeRequested>(_onInitialize);
    on<AuthLoginRequested>(_onLogin);
    on<AuthRegisterRequested>(_onRegister);
    on<AuthLogoutRequested>(_onLogout);
    on<AuthCheckStatusRequested>(_onCheckStatus);
  }
  
  /// Gestisce l'evento di inizializzazione
  Future<void> _onInitialize(
    AuthInitializeRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final hasToken = await _apiService.hasAuthToken();
      if (hasToken) {
        emit(const AuthAuthenticated());
      } else {
        emit(const AuthUnauthenticated());
      }
    } catch (e) {
      emit(AuthError(message: 'Errore durante l\'inizializzazione: $e'));
    }
  }
  
  /// Gestisce l'evento di login
  Future<void> _onLogin(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: event.email,
        password: event.password,
      );
      
      if (response.session != null) {
        final token = response.session!.accessToken;
        await _apiService.saveAuthToken(token);
        
        if (EnvConfig.isDebug) {
          _logger.debug('Login effettuato con successo');
        }
        
        emit(const AuthAuthenticated());
      } else {
        emit(const AuthError(message: 'Errore durante il login'));
      }
    } on AuthException catch (e) {
      emit(AuthError(message: e.message));
    } catch (e) {
      emit(AuthError(message: 'Errore durante il login: $e'));
    }
  }
  
  /// Gestisce l'evento di registrazione
  Future<void> _onRegister(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      // Registrazione utente su Supabase
      final response = await Supabase.instance.client.auth.signUp(
        email: event.email,
        password: event.password,
        data: {
          'nome': event.nome,
          'cognome': event.cognome,
        },
      );
      
      if (response.user != null) {
        final token = response.session?.accessToken;
        if (token != null) {
          await _apiService.saveAuthToken(token);
        }
        
        // Registrazione dati aggiuntivi utente tramite API
        await _apiService.post('/utenti', data: {
          'nome': event.nome,
          'cognome': event.cognome,
          'email': event.email,
        });
        
        if (EnvConfig.isDebug) {
          _logger.debug('Registrazione effettuata con successo');
        }
        
        emit(const AuthAuthenticated());
      } else {
        emit(const AuthError(message: 'Errore durante la registrazione'));
      }
    } on AuthException catch (e) {
      emit(AuthError(message: e.message));
    } catch (e) {
      emit(AuthError(message: 'Errore durante la registrazione: $e'));
    }
  }
  
  /// Gestisce l'evento di logout
  Future<void> _onLogout(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await Supabase.instance.client.auth.signOut();
      await _apiService.clearAuthToken();
      
      if (EnvConfig.isDebug) {
        _logger.debug('Logout effettuato con successo');
      }
      
      emit(const AuthUnauthenticated());
    } catch (e) {
      emit(AuthError(message: 'Errore durante il logout: $e'));
    }
  }
  
  /// Gestisce l'evento di verifica dello stato di autenticazione
  Future<void> _onCheckStatus(
    AuthCheckStatusRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final hasToken = await _apiService.hasAuthToken();
      final session = Supabase.instance.client.auth.currentSession;
      
      if (hasToken && session != null) {
        emit(const AuthAuthenticated());
      } else {
        await _apiService.clearAuthToken();
        emit(const AuthUnauthenticated());
      }
    } catch (e) {
      emit(AuthError(message: 'Errore durante la verifica dello stato: $e'));
    }
  }
} 
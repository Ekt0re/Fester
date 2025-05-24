import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:fester_frontend/services/api_service.dart';

part 'auth_event.dart';
part 'auth_state.dart';

/// Bloc per la gestione dell'autenticazione
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final ApiService _apiService;

  AuthBloc({required ApiService apiService})
      : _apiService = apiService,
        super(AuthInitial()) {
    on<AuthLoginRequested>(_onAuthLoginRequested);
    on<AuthRegisterRequested>(_onAuthRegisterRequested);
    on<AuthLogoutRequested>(_onAuthLogoutRequested);
    on<AuthCheckRequested>(_onAuthCheckRequested);
  }

  Future<void> _onAuthLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final result = await _apiService.login(
        event.email,
        event.password,
      );

      if (result['success'] == true && result['user'] != null) {
        emit(AuthAuthenticated(user: result['user']));
      } else {
        emit(AuthError(message: result['message'] ?? 'Errore durante il login'));
      }
    } catch (e) {
      emit(AuthError(message: 'Errore di connessione: ${e.toString()}'));
    }
  }

  Future<void> _onAuthRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final result = await _apiService.register(
        event.nome,
        event.cognome,
        event.email,
        event.password,
      );

      if (result['success'] == true) {
        emit(AuthRegistrationSuccess(message: result['message'] ?? 'Registrazione completata'));
      } else {
        emit(AuthError(message: result['message'] ?? 'Errore durante la registrazione'));
      }
    } catch (e) {
      emit(AuthError(message: 'Errore di connessione: ${e.toString()}'));
    }
  }

  Future<void> _onAuthLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _apiService.clearAuthToken();
      emit(AuthUnauthenticated());
    } catch (e) {
      emit(AuthError(message: 'Errore durante il logout: ${e.toString()}'));
    }
  }

  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final hasToken = await _apiService.hasAuthToken();
      if (hasToken) {
        // Qui potremmo verificare la validità del token chiamando un endpoint protetto
        // Per ora consideriamo valido il token se presente
        emit(const AuthAuthenticated(user: const {}));
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (e) {
      emit(AuthError(message: 'Errore durante il controllo dell\'autenticazione: ${e.toString()}'));
    }
  }
} 
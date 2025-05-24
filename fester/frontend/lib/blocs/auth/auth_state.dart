part of 'auth_bloc.dart';

/// Classe base per gli stati di autenticazione
abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Stato iniziale dell'autenticazione
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// Stato durante il caricamento dell'autenticazione
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// Stato quando l'utente è autenticato
class AuthAuthenticated extends AuthState {
  const AuthAuthenticated();
}

/// Stato quando l'utente non è autenticato
class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// Stato di errore dell'autenticazione
class AuthError extends AuthState {
  final String message;

  const AuthError({required this.message});

  @override
  List<Object?> get props => [message];
} 
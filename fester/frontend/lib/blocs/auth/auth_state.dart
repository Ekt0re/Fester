part of 'auth_bloc.dart';

/// Classe base per gli stati di autenticazione
abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Stato iniziale dell'autenticazione
class AuthInitial extends AuthState {}

/// Stato durante il caricamento dell'autenticazione
class AuthLoading extends AuthState {}

/// Stato quando l'utente è autenticato
class AuthAuthenticated extends AuthState {
  final Map<String, dynamic> user;

  const AuthAuthenticated({required this.user});

  @override
  List<Object?> get props => [user];
}

/// Stato quando l'utente non è autenticato
class AuthUnauthenticated extends AuthState {}

/// Stato quando la registrazione è completata con successo
class AuthRegistrationSuccess extends AuthState {
  final String message;

  const AuthRegistrationSuccess({required this.message});

  @override
  List<Object?> get props => [message];
}

/// Stato di errore dell'autenticazione
class AuthError extends AuthState {
  final String message;

  const AuthError({required this.message});

  @override
  List<Object?> get props => [message];
} 
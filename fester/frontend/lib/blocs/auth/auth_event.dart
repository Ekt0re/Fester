part of 'auth_bloc.dart';

/// Classe base per gli eventi di autenticazione
abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Evento per inizializzare l'autenticazione
class AuthInitializeRequested extends AuthEvent {
  const AuthInitializeRequested();
}

/// Evento per la richiesta di login
class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;

  const AuthLoginRequested({
    required this.email,
    required this.password,
  });

  @override
  List<Object?> get props => [email, password];
}

/// Evento per la richiesta di registrazione
class AuthRegisterRequested extends AuthEvent {
  final String nome;
  final String cognome;
  final String email;
  final String password;

  const AuthRegisterRequested({
    required this.nome,
    required this.cognome,
    required this.email,
    required this.password,
  });

  @override
  List<Object?> get props => [nome, cognome, email, password];
}

/// Evento per la richiesta di logout
class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

/// Evento per verificare lo stato di autenticazione
class AuthCheckStatusRequested extends AuthEvent {
  const AuthCheckStatusRequested();
} 
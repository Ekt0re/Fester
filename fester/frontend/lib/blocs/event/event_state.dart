part of 'event_bloc.dart';

/// Stati per il blocco Eventi
abstract class EventState extends Equatable {
  const EventState();

  @override
  List<Object> get props => [];
}

/// Stato iniziale
class EventInitial extends EventState {
  const EventInitial();
}

/// Stato di caricamento
class EventLoading extends EventState {
  const EventLoading();
}

/// Stato quando gli eventi sono stati caricati con successo
class EventsLoadSuccess extends EventState {
  final List<Event> events;

  const EventsLoadSuccess({required this.events});

  @override
  List<Object> get props => [events];
}

/// Stato quando i dettagli di un evento sono stati caricati con successo
class EventDetailsLoaded extends EventState {
  final Event event;

  const EventDetailsLoaded({required this.event});

  @override
  List<Object> get props => [event];
}

/// Stato quando gli ospiti di un evento sono stati caricati con successo
class EventGuestsLoaded extends EventState {
  final List<Guest> guests;

  const EventGuestsLoaded({required this.guests});

  @override
  List<Object> get props => [guests];
}

/// Stato quando un'operazione è completata con successo
class EventOperationSuccess extends EventState {
  final String message;

  const EventOperationSuccess({required this.message});

  @override
  List<Object> get props => [message];
}

/// Stato quando c'è un errore
class EventError extends EventState {
  final String message;

  const EventError({required this.message});

  @override
  List<Object> get props => [message];
}

/// Classe per rappresentare un ospite
class Guest extends Equatable {
  final String id;
  final String nome;
  final String cognome;
  final String email;
  final bool isPresent;
  final DateTime? checkinTime;

  const Guest({
    required this.id,
    required this.nome,
    required this.cognome,
    required this.email,
    required this.isPresent,
    this.checkinTime,
  });

  @override
  List<Object?> get props => [id, nome, cognome, email, isPresent, checkinTime];
}

/// Classe per un fallimento nel caricamento degli eventi
class EventFailure extends EventState {
  final String message;

  const EventFailure({required this.message});

  @override
  List<Object> get props => [message];
} 
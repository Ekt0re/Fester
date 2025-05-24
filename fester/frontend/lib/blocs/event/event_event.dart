part of 'event_bloc.dart';

/// Eventi per il blocco Eventi
abstract class EventEvent extends Equatable {
  const EventEvent();

  @override
  List<Object?> get props => [];
}

/// Evento per richiedere tutti gli eventi
class EventsFetchRequested extends EventEvent {
  const EventsFetchRequested();
}

/// Evento per richiedere i dettagli di un evento
class EventDetailsRequested extends EventEvent {
  final String eventId;

  const EventDetailsRequested({required this.eventId});

  @override
  List<Object?> get props => [eventId];
}

/// Evento per richiedere gli ospiti di un evento
class EventGuestsRequested extends EventEvent {
  final String eventId;

  const EventGuestsRequested({required this.eventId});

  @override
  List<Object?> get props => [eventId];
}

/// Evento per richiedere il check-in di un ospite
class EventGuestCheckinRequested extends EventEvent {
  final String eventId;
  final String guestId;

  const EventGuestCheckinRequested({
    required this.eventId,
    required this.guestId,
  });

  @override
  List<Object?> get props => [eventId, guestId];
}

/// Evento per creare un nuovo evento
class EventCreateRequested extends EventEvent {
  final Map<String, dynamic> eventData;

  const EventCreateRequested({required this.eventData});

  @override
  List<Object?> get props => [eventData];
}

/// Evento per aggiornare un evento
class EventUpdateRequested extends EventEvent {
  final String eventId;
  final Map<String, dynamic> eventData;

  const EventUpdateRequested({
    required this.eventId,
    required this.eventData,
  });

  @override
  List<Object?> get props => [eventId, eventData];
}

/// Evento per eliminare un evento
class EventDeleteRequested extends EventEvent {
  final String eventId;

  const EventDeleteRequested({required this.eventId});

  @override
  List<Object?> get props => [eventId];
} 
part of 'event_bloc.dart';

/// Eventi per il blocco Events
abstract class EventEvent extends Equatable {
  const EventEvent();

  @override
  List<Object> get props => [];
}

/// Evento per caricare tutti gli eventi
class EventsFetchRequested extends EventEvent {
  const EventsFetchRequested();
}

/// Evento per caricare i dettagli di un evento
class EventDetailsRequested extends EventEvent {
  final String eventId;

  const EventDetailsRequested({required this.eventId});

  @override
  List<Object> get props => [eventId];
}

/// Evento per caricare gli ospiti di un evento
class EventGuestsRequested extends EventEvent {
  final String eventId;

  const EventGuestsRequested({required this.eventId});

  @override
  List<Object> get props => [eventId];
}

/// Evento per registrare il check-in di un ospite
class EventGuestCheckinRequested extends EventEvent {
  final String eventId;
  final String guestId;

  const EventGuestCheckinRequested({
    required this.eventId,
    required this.guestId,
  });

  @override
  List<Object> get props => [eventId, guestId];
}

/// Evento per creare un nuovo evento
class EventCreateRequested extends EventEvent {
  final Map<String, dynamic> eventData;

  const EventCreateRequested({required this.eventData});

  @override
  List<Object> get props => [eventData];
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
  List<Object> get props => [eventId, eventData];
}

/// Evento per eliminare un evento
class EventDeleteRequested extends EventEvent {
  final String eventId;

  const EventDeleteRequested({required this.eventId});

  @override
  List<Object> get props => [eventId];
}

/// Evento per unirsi a un evento tramite codice
class JoinEventRequested extends EventEvent {
  final String code;

  const JoinEventRequested({required this.code});

  @override
  List<Object> get props => [code];
}

/// Evento per aggiungere un ospite a un evento
class AddGuestRequested extends EventEvent {
  final String eventId;
  final Map<String, dynamic> guestData;

  const AddGuestRequested({
    required this.eventId,
    required this.guestData,
  });

  @override
  List<Object> get props => [eventId, guestData];
}

/// Evento per importare più ospiti da file CSV
class ImportGuestsRequested extends EventEvent {
  final String eventId;
  final List<Map<String, dynamic>> guestsData;

  const ImportGuestsRequested({
    required this.eventId,
    required this.guestsData,
  });

  @override
  List<Object> get props => [eventId, guestsData];
} 
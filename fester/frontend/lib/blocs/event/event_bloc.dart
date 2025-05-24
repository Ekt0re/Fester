import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:fester_frontend/services/api_service.dart';

part 'event_event.dart';
part 'event_state.dart';

/// Bloc per la gestione degli eventi
class EventBloc extends Bloc<EventEvent, EventState> {
  final ApiService _apiService = ApiService();
  
  /// Costruttore che inizializza lo stato iniziale
  EventBloc() : super(const EventInitial()) {
    on<EventsFetchRequested>(_onEventsFetched);
    on<EventDetailsRequested>(_onEventDetailsRequested);
    on<EventGuestsRequested>(_onEventGuestsRequested);
    on<EventGuestCheckinRequested>(_onEventGuestCheckinRequested);
    on<EventCreateRequested>(_onEventCreateRequested);
    on<EventUpdateRequested>(_onEventUpdateRequested);
    on<EventDeleteRequested>(_onEventDeleteRequested);
    on<JoinEventRequested>(_onJoinEventRequested);
  }
  
  /// Gestisce l'evento di recupero di tutti gli eventi
  Future<void> _onEventsFetched(
    EventsFetchRequested event,
    Emitter<EventState> emit,
  ) async {
    emit(const EventLoading());
    try {
      final result = await _apiService.getEvents();
      
      if (result['success']) {
        final List<dynamic> data = result['data']['data'];
        final events = data.map((e) => Map<String, dynamic>.from(e)).toList();
        
        emit(EventsLoadSuccess(events: events));
      } else {
        emit(EventError(message: result['message'] ?? 'Errore nel caricamento degli eventi'));
      }
    } catch (e) {
      emit(EventError(message: 'Errore nel caricamento degli eventi: $e'));
    }
  }
  
  /// Gestisce l'evento di recupero dei dettagli di un evento
  Future<void> _onEventDetailsRequested(
    EventDetailsRequested event,
    Emitter<EventState> emit,
  ) async {
    emit(const EventLoading());
    try {
      final response = await _apiService.get('/eventi/${event.eventId}');
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = response.data['data'];
        
        emit(EventDetailsLoaded(event: data));
      } else {
        emit(const EventError(message: 'Errore nel caricamento dei dettagli dell\'evento'));
      }
    } catch (e) {
      emit(EventError(message: 'Errore nel caricamento dei dettagli dell\'evento: $e'));
    }
  }
  
  /// Gestisce l'evento di recupero degli ospiti di un evento
  Future<void> _onEventGuestsRequested(
    EventGuestsRequested event,
    Emitter<EventState> emit,
  ) async {
    emit(const EventLoading());
    try {
      final response = await _apiService.get('/eventi/${event.eventId}/ospiti');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['data'];
        
        final guests = data.map((item) {
          return Guest(
            id: item['id'],
            nome: item['nome'],
            cognome: item['cognome'],
            email: item['email'],
            isPresent: item['presente'] ?? false,
            checkinTime: item['check_in_time'] != null 
                ? DateTime.parse(item['check_in_time']) 
                : null,
          );
        }).toList();
        
        emit(EventGuestsLoaded(guests: guests));
      } else {
        emit(const EventError(message: 'Errore nel caricamento degli ospiti'));
      }
    } catch (e) {
      emit(EventError(message: 'Errore nel caricamento degli ospiti: $e'));
    }
  }
  
  /// Gestisce l'evento di check-in di un ospite
  Future<void> _onEventGuestCheckinRequested(
    EventGuestCheckinRequested event,
    Emitter<EventState> emit,
  ) async {
    try {
      // Ottieni lo stato attuale per conservare i dati degli ospiti
      final currentState = state;
      List<Guest> currentGuests = [];
      
      if (currentState is EventGuestsLoaded) {
        currentGuests = [...currentState.guests];
      } else {
        emit(const EventLoading());
      }
      
      final response = await _apiService.put(
        '/eventi/${event.eventId}/ospiti/${event.guestId}/checkin',
      );
      
      if (response.statusCode == 200) {
        if (currentGuests.isNotEmpty) {
          // Aggiorna solo l'ospite che ha fatto il check-in
          final updatedGuests = currentGuests.map((guest) {
            if (guest.id == event.guestId) {
              return Guest(
                id: guest.id,
                nome: guest.nome,
                cognome: guest.cognome,
                email: guest.email,
                isPresent: true,
                checkinTime: DateTime.now(),
              );
            }
            return guest;
          }).toList();
          
          emit(EventGuestsLoaded(guests: updatedGuests));
        } else {
          // Se non abbiamo ancora gli ospiti, li carichiamo di nuovo
          add(EventGuestsRequested(eventId: event.eventId));
        }
      } else {
        emit(const EventError(message: 'Errore durante il check-in dell\'ospite'));
      }
    } catch (e) {
      emit(EventError(message: 'Errore durante il check-in dell\'ospite: $e'));
    }
  }
  
  /// Gestisce l'evento di creazione di un nuovo evento
  Future<void> _onEventCreateRequested(
    EventCreateRequested event,
    Emitter<EventState> emit,
  ) async {
    emit(const EventLoading());
    try {
      // Aggiungi i campi mancanti
      final eventData = {
        ...event.eventData,
        'stato': 'attivo',
      };
      
      final result = await _apiService.createEvent(eventData);
      
      if (result['success']) {
        // Emetti lo stato di successo
        emit(const EventOperationSuccess(message: 'Evento creato con successo'));
        // Aggiorna la lista degli eventi
        add(const EventsFetchRequested());
      } else {
        emit(EventError(message: result['message'] ?? 'Errore nella creazione dell\'evento'));
      }
    } catch (e) {
      emit(EventError(message: 'Errore nella creazione dell\'evento: $e'));
    }
  }
  
  /// Gestisce l'evento di aggiornamento di un evento
  Future<void> _onEventUpdateRequested(
    EventUpdateRequested event,
    Emitter<EventState> emit,
  ) async {
    emit(const EventLoading());
    try {
      final response = await _apiService.put(
        '/eventi/${event.eventId}',
        data: event.eventData,
      );
      
      if (response.statusCode == 200) {
        // Emetti lo stato di successo
        emit(const EventOperationSuccess(message: 'Evento aggiornato con successo'));
        // Aggiorna i dettagli dell'evento
        add(EventDetailsRequested(eventId: event.eventId));
      } else {
        emit(const EventError(message: 'Errore nell\'aggiornamento dell\'evento'));
      }
    } catch (e) {
      emit(EventError(message: 'Errore nell\'aggiornamento dell\'evento: $e'));
    }
  }
  
  /// Gestisce l'evento di eliminazione di un evento
  Future<void> _onEventDeleteRequested(
    EventDeleteRequested event,
    Emitter<EventState> emit,
  ) async {
    emit(const EventLoading());
    try {
      final response = await _apiService.delete('/eventi/${event.eventId}');
      
      if (response.statusCode == 200) {
        // Emetti lo stato di successo
        emit(const EventOperationSuccess(message: 'Evento eliminato con successo'));
        // Aggiorna la lista degli eventi
        add(const EventsFetchRequested());
      } else {
        emit(const EventError(message: 'Errore nell\'eliminazione dell\'evento'));
      }
    } catch (e) {
      emit(EventError(message: 'Errore nell\'eliminazione dell\'evento: $e'));
    }
  }
  
  /// Gestisce l'evento di partecipazione a un evento tramite codice
  Future<void> _onJoinEventRequested(
    JoinEventRequested event,
    Emitter<EventState> emit,
  ) async {
    emit(const EventLoading());
    try {
      final response = await _apiService.post(
        '/eventi/join',
        data: {'codice': event.code},
      );
      
      if (response.statusCode == 200) {
        emit(const EventOperationSuccess(message: 'Partecipazione all\'evento confermata'));
        // Aggiorna la lista degli eventi
        add(const EventsFetchRequested());
      } else {
        emit(const EventError(message: 'Codice evento non valido'));
      }
    } catch (e) {
      emit(EventError(message: 'Errore durante la partecipazione all\'evento: $e'));
    }
  }
} 
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:fester_frontend/models/event.dart';
import 'package:fester_frontend/services/api_service.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'event_event.dart';
part 'event_state.dart';

class EventBloc extends Bloc<EventEvent, EventState> {
  final ApiService _apiService = ApiService();
  final _logger = Logger('EventBloc');

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
    on<AddGuestRequested>(_onAddGuestRequested);
    on<ImportGuestsRequested>(_onImportGuestsRequested);
  }

  /// Gestisce l'evento di creazione di un nuovo evento
  Future<void> _onEventCreateRequested(
    EventCreateRequested event,
    Emitter<EventState> emit,
  ) async {
    emit(const EventLoading());
    try {
      // Verifica che l'utente sia autenticato
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        emit(const EventError(message: 'Utente non autenticato'));
        return;
      }

      _logger.info('Creazione evento con dati: ${event.eventData}');
      _logger.info('Data e ora ricevuta: ${event.eventData['date_time']}');

      // Prepara i dati dell'evento seguendo lo schema Supabase e le nuove policy
      final eventData = {
        'name': event.eventData['name'],
        'place': event.eventData['place'],
        'date_time': event.eventData['date_time'],
        'rules': event.eventData['rules'] ?? [],
        'state': 'draft',
        'created_by': user.id,
      };

      _logger.info('Dati evento preparati: $eventData');
      _logger.info('Data e ora formattata: ${eventData['date_time']}');

      // Chiamata API che internamente userà Supabase
      final response = await _apiService.post('/api/events', data: eventData);
      
      _logger.info('Risposta creazione evento: ${response.data}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = response.data;
        
        if (responseData != null) {
          // Se la risposta è una lista, prendi il primo elemento
          final eventJson = responseData is List ? responseData.first : responseData;
          final createdEvent = Event.fromJson(eventJson);
          
          // Crea il record event_users
          final eventUserData = {
            'event_id': createdEvent.id,
            'auth_user_id': user.id,
            'role': 'organizer'
          };

          _logger.info('Creazione event_user con dati: $eventUserData');
          
          await _apiService.post('/api/event_users', data: eventUserData);

          emit(const EventOperationSuccess(message: 'Evento creato con successo'));
          // Aggiorna la lista degli eventi
          add(const EventsFetchRequested());
        } else {
          emit(const EventError(message: 'Formato risposta non valido'));
        }
      } else {
        final errorMessage = response.data?['error']?['message'] ?? 'Errore nella creazione dell\'evento';
        emit(EventError(message: errorMessage));
      }
    } catch (e, stackTrace) {
      _logger.severe('Errore nella creazione dell\'evento: $e\n$stackTrace');
      emit(EventError(message: 'Errore nella creazione dell\'evento: $e'));
    }
  }

  /// Gestisce l'evento di recupero di tutti gli eventi
  Future<void> _onEventsFetched(
    EventsFetchRequested event,
    Emitter<EventState> emit,
  ) async {
    emit(const EventLoading());
    try {
      // Usa parametri query per filtrare secondo le policy
      final response = await _apiService.get(
        '/api/events',
        queryParameters: {
          'select': '*',
          'order': 'date_time.desc',
        },
      );
      
      _logger.info('Risposta get eventi: ${response.data}');
      
      if (response.statusCode == 200) {
        final responseData = response.data;
        if (responseData != null) {
          // Handle case where data is already a list
          if (responseData is List) {
            final events = responseData.map((e) => Event.fromJson(e)).toList();
            emit(EventsLoadSuccess(events: events));
          } else if (responseData is Map && responseData['data'] != null) {
            final List<dynamic> data = responseData['data'];
            final events = data.map((e) => Event.fromJson(e)).toList();
            emit(EventsLoadSuccess(events: events));
          } else {
            emit(const EventError(message: 'Formato risposta non valido'));
          }
        }
      } else {
        final errorMessage = response.data?['error']?['message'] ?? 'Errore nel caricamento degli eventi';
        emit(EventError(message: errorMessage));
      }
    } catch (e, stackTrace) {
      _logger.severe('Errore nel caricamento degli eventi: $e\n$stackTrace');
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
      final response = await _apiService.get('/api/events/${event.eventId}');
      
      if (response.statusCode == 200) {
        final responseData = response.data;
        if (responseData != null && responseData['data'] != null) {
          final eventData = Event.fromJson(responseData['data']);
          emit(EventDetailsLoaded(event: eventData));
        } else {
          emit(const EventError(message: 'Formato risposta non valido'));
        }
      } else {
        final errorMessage = response.data?['error']?['message'] ?? 'Errore nel caricamento dei dettagli dell\'evento';
        emit(EventError(message: errorMessage));
      }
    } catch (e, stackTrace) {
      _logger.severe('Errore nel caricamento dei dettagli dell\'evento: $e\n$stackTrace');
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
      // Utilizza direttamente il metodo getEventGuests invece della chiamata HTTP
      final result = await _apiService.getEventGuests(event.eventId);
      
      if (result['success'] == true) {
        final rawData = result['data'] ?? [];
        
        // Mappa i dati al modello Guest
        final List<Guest> guests = (rawData as List).map((item) => Guest(
          id: item['id'] ?? '',
          nome: item['nome'] ?? item['auth_user_id'] ?? '',  // Utilizziamo auth_user_id se nome non esiste
          cognome: item['cognome'] ?? item['role'] ?? '',    // Utilizziamo role se cognome non esiste
          email: item['email'] ?? '',
          isPresent: item['check_in_time'] != null,  // L'ospite è presente se ha un timestamp di check-in
          checkinTime: item['check_in_time'] != null 
              ? DateTime.parse(item['check_in_time']) 
              : null,
        )).toList();
        
        emit(EventGuestsLoaded(guests: guests));
      } else {
        emit(EventError(message: result['message'] ?? 'Errore nel caricamento degli ospiti'));
      }
    } catch (e, stackTrace) {
      _logger.severe('Errore nel caricamento degli ospiti: $e\n$stackTrace');
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
      
      // Aggiorna direttamente con il metodo updateGuestStatus
      final result = await _apiService.updateGuestStatus(event.guestId, 'present');
      
      if (result['success'] == true) {
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
        emit(EventError(message: result['message'] ?? 'Errore durante il check-in dell\'ospite'));
      }
    } catch (e) {
      _logger.severe('Errore durante il check-in dell\'ospite: $e');
      emit(EventError(message: 'Errore durante il check-in dell\'ospite: $e'));
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
        '/api/events/${event.eventId}',
        data: event.eventData,
      );
      
      if (response.statusCode == 200) {
        // Emetti lo stato di successo indipendentemente dalla struttura della risposta
        emit(const EventOperationSuccess(message: 'Evento aggiornato con successo'));
        // Aggiorna i dettagli dell'evento
        add(EventDetailsRequested(eventId: event.eventId));
      } else {
        String errorMessage = 'Errore nell\'aggiornamento dell\'evento';
        if (response.data is Map) {
          final dataMap = response.data as Map;
          if (dataMap.containsKey('error') && dataMap['error'] is Map) {
            final errorMap = dataMap['error'] as Map;
            if (errorMap.containsKey('message')) {
              errorMessage = errorMap['message'].toString();
            }
          }
        }
        emit(EventError(message: errorMessage));
      }
    } catch (e, stackTrace) {
      _logger.severe('Errore nell\'aggiornamento dell\'evento: $e\n$stackTrace');
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
      // Soft delete - aggiorna lo stato invece di eliminare
      final response = await _apiService.put(
        '/api/events/${event.eventId}',
        data: {'stato': 'cancelled'},
      );
      
      if (response.statusCode == 200) {
        final responseData = response.data;
        if (responseData['success'] == true || responseData.containsKey('id')) {
          // Emetti lo stato di successo
          emit(const EventOperationSuccess(message: 'Evento eliminato con successo'));
          // Aggiorna la lista degli eventi
          add(const EventsFetchRequested());
        } else {
          final errorMessage = responseData['error']?['message'] ?? 'Errore nell\'eliminazione dell\'evento';
          emit(EventError(message: errorMessage));
        }
      } else {
        final errorMessage = response.data['error']?['message'] ?? 'Errore nell\'eliminazione dell\'evento';
        emit(EventError(message: errorMessage));
      }
    } catch (e) {
      _logger.severe('Errore nell\'eliminazione dell\'evento: $e');
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
        '/api/events/join',
        data: {'codice': event.code},
      );
      
      if (response.statusCode == 200) {
        final responseData = response.data;
        if (responseData['success'] == true) {
          emit(const EventOperationSuccess(message: 'Partecipazione all\'evento confermata'));
          // Aggiorna la lista degli eventi
          add(const EventsFetchRequested());
        } else {
          final errorMessage = responseData['error']?['message'] ?? 'Codice evento non valido';
          emit(EventError(message: errorMessage));
        }
      } else {
        final errorMessage = response.data['error']?['message'] ?? 'Codice evento non valido';
        emit(EventError(message: errorMessage));
      }
    } catch (e) {
      _logger.severe('Errore durante la partecipazione all\'evento: $e');
      emit(EventError(message: 'Errore durante la partecipazione all\'evento: $e'));
    }
  }

  /// Gestisce l'evento di aggiunta di un ospite
  Future<void> _onAddGuestRequested(
    AddGuestRequested event,
    Emitter<EventState> emit,
  ) async {
    emit(const EventLoading());
    try {
      final result = await _apiService.addGuest(event.eventId, event.guestData);
      
      if (result['success'] == true) {
        emit(const EventOperationSuccess(message: 'Ospite aggiunto con successo'));
        // Ricarica la lista degli ospiti
        add(EventGuestsRequested(eventId: event.eventId));
      } else {
        emit(EventError(message: result['message'] ?? 'Errore nell\'aggiunta dell\'ospite'));
      }
    } catch (e, stackTrace) {
      _logger.severe('Errore nell\'aggiunta dell\'ospite: $e\n$stackTrace');
      emit(EventError(message: 'Errore nell\'aggiunta dell\'ospite: $e'));
    }
  }

  /// Gestisce l'evento di importazione di più ospiti
  Future<void> _onImportGuestsRequested(
    ImportGuestsRequested event,
    Emitter<EventState> emit,
  ) async {
    emit(const EventLoading());
    try {
      int successCount = 0;
      int failCount = 0;
      
      for (final guestData in event.guestsData) {
        final result = await _apiService.addGuest(event.eventId, guestData);
        if (result['success'] == true) {
          successCount++;
        } else {
          failCount++;
        }
      }
      
      if (successCount > 0) {
        String message = 'Importati $successCount ospiti con successo';
        if (failCount > 0) {
          message += ' ($failCount non importati)';
        }
        
        emit(EventOperationSuccess(message: message));
        // Ricarica la lista degli ospiti
        add(EventGuestsRequested(eventId: event.eventId));
      } else {
        emit(const EventError(message: 'Nessun ospite importato. Verifica il formato del file.'));
      }
    } catch (e, stackTrace) {
      _logger.severe('Errore nell\'importazione degli ospiti: $e\n$stackTrace');
      emit(EventError(message: 'Errore nell\'importazione degli ospiti: $e'));
    }
  }
}
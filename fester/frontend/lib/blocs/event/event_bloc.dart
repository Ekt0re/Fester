import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Eventi
abstract class EventEvent {}

class EventsFetchRequested extends EventEvent {}

class EventDetailRequested extends EventEvent {
  final String eventId;

  EventDetailRequested({required this.eventId});
}

class EventCreateRequested extends EventEvent {
  final String nome;
  final String luogo;
  final DateTime dataOra;
  final Map<String, dynamic>? regole;

  EventCreateRequested({
    required this.nome,
    required this.luogo,
    required this.dataOra,
    this.regole,
  });
}

class EventUpdateRequested extends EventEvent {
  final String eventId;
  final String nome;
  final String luogo;
  final DateTime dataOra;
  final Map<String, dynamic>? regole;
  final String? stato;

  EventUpdateRequested({
    required this.eventId,
    required this.nome,
    required this.luogo,
    required this.dataOra,
    this.regole,
    this.stato,
  });
}

class EventDeleteRequested extends EventEvent {
  final String eventId;

  EventDeleteRequested({required this.eventId});
}

// Stati
abstract class EventState {}

class EventInitial extends EventState {}

class EventLoading extends EventState {}

class EventsLoadSuccess extends EventState {
  final List<Map<String, dynamic>> events;

  EventsLoadSuccess({required this.events});
}

class EventDetailLoadSuccess extends EventState {
  final Map<String, dynamic> event;

  EventDetailLoadSuccess({required this.event});
}

class EventOperationSuccess extends EventState {
  final String message;

  EventOperationSuccess({required this.message});
}

class EventFailure extends EventState {
  final String message;

  EventFailure({required this.message});
}

// BLoC
class EventBloc extends Bloc<EventEvent, EventState> {
  final supabase = Supabase.instance.client;
  final dio = Dio();
  final secureStorage = const FlutterSecureStorage();
  final String apiBaseUrl = 'http://localhost:5000/api';

  EventBloc() : super(EventInitial()) {
    on<EventsFetchRequested>(_onEventsFetchRequested);
    on<EventDetailRequested>(_onEventDetailRequested);
    on<EventCreateRequested>(_onEventCreateRequested);
    on<EventUpdateRequested>(_onEventUpdateRequested);
    on<EventDeleteRequested>(_onEventDeleteRequested);
    
    // Inizializza i headers per Dio
    _setupDioHeaders();
  }

  Future<void> _setupDioHeaders() async {
    final token = await secureStorage.read(key: 'auth_token');
    if (token != null) {
      dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }

  Future<void> _onEventsFetchRequested(
    EventsFetchRequested event,
    Emitter<EventState> emit,
  ) async {
    emit(EventLoading());

    try {
      await _setupDioHeaders();
      final response = await dio.get('$apiBaseUrl/events');

      if (response.statusCode == 200) {
        final data = response.data['data'] as List;
        final events = data.map((event) => event as Map<String, dynamic>).toList();
        emit(EventsLoadSuccess(events: events));
      } else {
        emit(EventFailure(message: 'Errore durante il caricamento degli eventi'));
      }
    } catch (error) {
      emit(EventFailure(message: 'Errore durante il caricamento degli eventi: ${error.toString()}'));
    }
  }

  Future<void> _onEventDetailRequested(
    EventDetailRequested event,
    Emitter<EventState> emit,
  ) async {
    emit(EventLoading());

    try {
      await _setupDioHeaders();
      final response = await dio.get('$apiBaseUrl/events/${event.eventId}');

      if (response.statusCode == 200) {
        final eventData = response.data['data'] as Map<String, dynamic>;
        emit(EventDetailLoadSuccess(event: eventData));
      } else {
        emit(EventFailure(message: 'Errore durante il caricamento dei dettagli dell\'evento'));
      }
    } catch (error) {
      emit(EventFailure(message: 'Errore durante il caricamento dei dettagli dell\'evento: ${error.toString()}'));
    }
  }

  Future<void> _onEventCreateRequested(
    EventCreateRequested event,
    Emitter<EventState> emit,
  ) async {
    emit(EventLoading());

    try {
      await _setupDioHeaders();
      final response = await dio.post(
        '$apiBaseUrl/events',
        data: {
          'nome': event.nome,
          'luogo': event.luogo,
          'data_ora': event.dataOra.toIso8601String(),
          'regole': event.regole ?? {},
        },
      );

      if (response.statusCode == 201) {
        emit(EventOperationSuccess(message: 'Evento creato con successo'));
      } else {
        emit(EventFailure(message: 'Errore durante la creazione dell\'evento'));
      }
    } catch (error) {
      emit(EventFailure(message: 'Errore durante la creazione dell\'evento: ${error.toString()}'));
    }
  }

  Future<void> _onEventUpdateRequested(
    EventUpdateRequested event,
    Emitter<EventState> emit,
  ) async {
    emit(EventLoading());

    try {
      await _setupDioHeaders();
      final response = await dio.put(
        '$apiBaseUrl/events/${event.eventId}',
        data: {
          'nome': event.nome,
          'luogo': event.luogo,
          'data_ora': event.dataOra.toIso8601String(),
          'regole': event.regole,
          'stato': event.stato,
        },
      );

      if (response.statusCode == 200) {
        emit(EventOperationSuccess(message: 'Evento aggiornato con successo'));
      } else {
        emit(EventFailure(message: 'Errore durante l\'aggiornamento dell\'evento'));
      }
    } catch (error) {
      emit(EventFailure(message: 'Errore durante l\'aggiornamento dell\'evento: ${error.toString()}'));
    }
  }

  Future<void> _onEventDeleteRequested(
    EventDeleteRequested event,
    Emitter<EventState> emit,
  ) async {
    emit(EventLoading());

    try {
      await _setupDioHeaders();
      final response = await dio.delete('$apiBaseUrl/events/${event.eventId}');

      if (response.statusCode == 200) {
        emit(EventOperationSuccess(message: 'Evento eliminato con successo'));
      } else {
        emit(EventFailure(message: 'Errore durante l\'eliminazione dell\'evento'));
      }
    } catch (error) {
      emit(EventFailure(message: 'Errore durante l\'eliminazione dell\'evento: ${error.toString()}'));
    }
  }
} 
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:fester_frontend/config/env_config.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Servizio per le chiamate API
class ApiService {
  late final SupabaseClient _supabase;
  final _logger = Logger('ApiService');
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String _jwtSecret = 'zVZUDH7YqfDdw8AV7bm0SMsGG9mCGUiA9SnA5D5AD9TjtSfqoZ3VbTqTwV+BglavDyH/lC1EFXcntCXJEReP/g==';
  
  FlutterSecureStorage get storage => _storage;

  ApiService() {
    _supabase = Supabase.instance.client;
    _initializeSupabase();
  }

  Future<void> _initializeSupabase() async {
    try {
      final token = await _storage.read(key: 'token');
      if (token != null) {
        await _supabase.auth.setSession(token);
      }
    } catch (e) {
      _logger.severe('Errore inizializzazione Supabase: $e');
    }
  }

  /// Verifica se esiste un token di autenticazione salvato
  Future<bool> hasAuthToken() async {
    try {
      final token = await _storage.read(key: 'token');
      return token != null && token.isNotEmpty;
    } catch (e) {
      _logger.severe('Errore verifica token: $e');
      return false;
    }
  }

  /// Ottiene il token di autenticazione corrente
  Future<String?> getAuthToken() async {
    try {
      return await _storage.read(key: 'token');
    } catch (e) {
      _logger.severe('Errore lettura token: $e');
      return null;
    }
  }

  /// Effettua una richiesta GET
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final segments = path.replaceAll('/api/', '').split('/');
      final tableName = segments[0];
      
      // Gestione delle richieste di ospiti (events/id/guests)
      if (segments.length > 2 && segments[2] == 'guests') {
        final eventId = segments[1];
        try {
          final data = await _supabase
              .from('event_users')
              .select()
              .eq('event_id', eventId);
          
          return Response(
            data: data.isEmpty ? [] : data,
            statusCode: 200,
          );
        } catch (e) {
          // In caso di errore ritorna una lista vuota invece di un errore
          _logger.warning('Nessun ospite trovato: $e');
          return Response(
            data: [],
            statusCode: 200,
          );
        }
      }
      // Se abbiamo un ID specifico (es. /api/events/123)
      else if (segments.length > 1 && segments[1].isNotEmpty) {
        final id = segments[1];
        try {
          final data = await _supabase
              .from(tableName)
              .select()
              .eq('id', id)
              .single();
          
          return Response(
            data: {'data': data},
            statusCode: 200,
          );
        } catch (e) {
          // Se non trova il record, restituisci un messaggio specifico
          if (e is PostgrestException && e.code == 'PGRST116') {
            return Response(
              data: {'error': {'message': 'Elemento non trovato'}},
              statusCode: 404,
            );
          }
          throw e;
        }
      } else {
        // Richiesta generica per tutti gli elementi
        final data = await _supabase
            .from(tableName)
            .select();
        
        return Response(
          data: data,
          statusCode: 200,
        );
      }
    } catch (e) {
      return _handleError(e);
    }
  }
  
  /// Effettua una richiesta POST
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final tableName = path.replaceAll('/api/', '');
      final response = await _supabase
          .from(tableName)
          .insert(data)
          .select();
      
      return Response(
        data: response,
        statusCode: 201,
      );
    } catch (e) {
      return _handleError(e);
    }
  }
  
  /// Effettua una richiesta PUT
  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final segments = path.replaceAll('/api/', '').split('/');
      final tableName = segments[0];
      
      // Se abbiamo un ID specifico (es. /api/events/123)
      if (segments.length > 1 && segments[1].isNotEmpty) {
        final id = segments[1];
        
        final response = await _supabase
            .from(tableName)
            .update(data)
            .eq('id', id)
            .select();
        
        return Response(
          data: response,
          statusCode: 200,
        );
      } else {
        // Aggiornamento generico (caso raro)
        final response = await _supabase
            .from(tableName)
            .update(data)
            .select();
        
        return Response(
          data: response,
          statusCode: 200,
        );
      }
    } catch (e) {
      return _handleError(e);
    }
  }
  
  /// Effettua una richiesta DELETE
  Future<Response> delete(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final tableName = path.replaceAll('/api/', '');
      final response = await _supabase
          .from(tableName)
          .delete()
          .select();
      
      return Response(
        data: response,
        statusCode: 200,
      );
    } catch (e) {
      return _handleError(e);
    }
  }
  
  /// Gestisce gli errori delle richieste
  Response _handleError(dynamic error) {
    _logger.severe('Errore API: $error');
    if (error is PostgrestException) {
      final message = error.message ?? 'Errore sconosciuto';
      final code = error.code ?? '500';
      return Response(
        data: {'error': {'message': message}},
        statusCode: int.parse(code),
      );
    }
    return Response(
      data: {'error': {'message': error.toString()}},
      statusCode: 500,
    );
  }

  /// Salva il token di autenticazione
  Future<void> saveAuthToken(String token) async {
    await _storage.write(key: 'token', value: token);
    await _supabase.auth.refreshSession();
  }
  
  /// Elimina il token di autenticazione
  Future<void> clearAuthToken() async {
    await _storage.delete(key: 'token');
    await _supabase.auth.signOut();
  }

  // Debug: Verifica connessione al backend
  Future<bool> testConnection() async {
    try {
      final data = await _supabase.from('test').select();
      _logger.info('Test connessione: $data');
      return true;
    } catch (e) {
      _logger.severe('Errore connessione al backend: $e');
      return false;
    }
  }

  // Autenticazione
  Future<Map<String, dynamic>> register(String nome, String cognome, String email, String password) async {
    try {
      if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
        return {
          'success': false,
          'message': 'Inserisci un indirizzo email valido'
        };
      }
      
      if (password.length < 6) {
        return {
          'success': false,
          'message': 'La password deve contenere almeno 6 caratteri'
        };
      }
      
      if (nome.isEmpty || cognome.isEmpty) {
        return {
          'success': false,
          'message': 'Nome e cognome sono obbligatori'
        };
      }
      
      _logger.info('Tentativo di registrazione con: $email');
      
      final data = await _supabase.from('auth').insert({
        'nome': nome.trim(),
        'cognome': cognome.trim(),
        'email': email.trim().toLowerCase(),
        'password': password,
      }).select();
      
      return {
        'success': true,
        'data': data
      };
    } catch (e) {
      _logger.severe('Errore registrazione: $e');
      
      if (e is PostgrestException) {
        _logger.severe('Dettagli errore Supabase: ${e.message}');
        _logger.severe('Codice status: ${e.code}');
        
        if (e.code == '400') {
          if (e.message.contains('email already registered') ?? false) {
            return {
              'success': false,
              'message': 'L\'email is already registered'
            };
          } else if (e.message.contains('invalid email') ?? false) {
            return {
              'success': false,
              'message': 'Invalid email format'
            };
          } else if (e.message.contains('password') ?? false) {
            return {
              'success': false,
              'message': 'Password does not meet security requirements'
            };
          }
        }
        
        return {
          'success': false,
          'message': e.message ?? 'Errore sconosciuto'
        };
      }
      
      return {
        'success': false,
        'message': 'Errore durante la registrazione: $e'
      };
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      _logger.info('Tentativo di login con: $email');
      final response = await _supabase.auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      
      if (response.session != null && response.user != null) {
        return {
          'success': true,
          'user': response.user!.toJson(),
          'token': response.session!.accessToken,
        };
      }
      
      return {
        'success': false,
        'message': 'Credenziali non valide'
      };
    } catch (e) {
      _logger.severe('Errore login: $e');
      return {
        'success': false,
        'message': 'Errore durante il login: ${e.toString()}'
      };
    }
  }

  // Eventi
  Future<Map<String, dynamic>> getEvents() async {
    try {
      _logger.info('Caricamento eventi...');
      
      // Check if user is authenticated
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return {
          'success': false, 
          'message': 'Utente non autenticato',
          'data': []
        };
      }
      
      final data = await _supabase
          .from('events')
          .select()
          .eq('created_by', user.id); // Filter by current user
      
      _logger.info('Eventi caricati: ${data.length}');
      return {
        'success': true, 
        'data': data,
        'count': data.length
      };
    } catch (e) {
      _logger.severe('Errore caricamento eventi: $e');
      return {
        'success': false, 
        'message': 'Errore: ${_getErrorMessage(e)}',
        'data': []
      };
    }
  }

  Future<Map<String, dynamic>> getEventDetails(String eventId) async {
    try {
      final data = await _supabase.from('events').select().eq('id', eventId);
      return {'success': true, 'data': data};
    } catch (e) {
      return {'success': false, 'message': 'Errore: ${_getErrorMessage(e)}'};
    }
  }

  Future<Map<String, dynamic>> createEvent(Map<String, dynamic> eventData) async {
    try {
      // Check if user is authenticated
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return {
          'success': false,
          'message': 'Utente non autenticato'
        };
      }
      
      // Add user ID to event data using correct column name
      final dataWithUser = {
        ...eventData,
        'created_by': user.id,
        'stato': 'active', // Stato di default
        'created_at': DateTime.now().toIso8601String(),
      };
      
      _logger.info('Creazione evento: $dataWithUser');
      
      final result = await _supabase
          .from('events')
          .insert([dataWithUser]) // Wrap in array as per documentation
          .select()
          .single();
      
      return {
        'success': true,
        'data': result,
        'message': 'Evento creato con successo'
      };
    } catch (e) {
      _logger.severe('Errore creazione evento: $e');
      
      if (e is PostgrestException) {
        if (e.code == '42501') {
          return {
            'success': false,
            'message': 'Permessi insufficienti. Verifica le policy RLS.'
          };
        } else if (e.code == '23505') {
          return {
            'success': false,
            'message': 'Evento già esistente con questi dati.'
          };
        }
      }
      
      return {
        'success': false,
        'message': 'Errore: ${_getErrorMessage(e)}'
      };
    }
  }

  Future<Map<String, dynamic>> updateEvent(String eventId, Map<String, dynamic> eventData) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return {
          'success': false,
          'message': 'Utente non autenticato'
        };
      }
      
      final data = await _supabase
          .from('events')
          .update(eventData)
          .eq('id', eventId)
          .eq('created_by', user.id) // Ensure user can only update their own events
          .select();
      
      return {
        'success': true, 
        'data': data,
        'message': 'Evento aggiornato con successo'
      };
    } catch (e) {
      return {
        'success': false, 
        'message': 'Errore: ${_getErrorMessage(e)}'
      };
    }
  }

  Future<Map<String, dynamic>> deleteEvent(String eventId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return {
          'success': false,
          'message': 'Utente non autenticato'
        };
      }
      
      await _supabase
          .from('events')
          .delete()
          .eq('id', eventId)
          .eq('created_by', user.id); // Ensure user can only delete their own events
      
      return {
        'success': true, 
        'message': 'Evento eliminato con successo'
      };
    } catch (e) {
      return {
        'success': false, 
        'message': 'Errore: ${_getErrorMessage(e)}'
      };
    }
  }

  // Ospiti
  Future<Map<String, dynamic>> getEventGuests(String eventId) async {
    try {
      final data = await _supabase.from('event_users').select().eq('event_id', eventId);
      return {'success': true, 'data': data.isEmpty ? [] : data};
    } catch (e) {
      // Ritorna una lista vuota in caso di errore
      _logger.warning('Errore caricamento ospiti: $e');
      return {'success': true, 'data': []};
    }
  }

  Future<Map<String, dynamic>> addGuest(String eventId, Map<String, dynamic> guestData) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return {
          'success': false,
          'message': 'Utente non autenticato'
        };
      }
      
      // Verifichiamo che l'utente abbia accesso all'evento
      final eventAccess = await _supabase
          .from('events')
          .select()
          .eq('id', eventId)
          .eq('created_by', user.id);
      
      if (eventAccess.isEmpty) {
        return {
          'success': false,
          'message': 'Non hai i permessi per modificare questo evento'
        };
      }
      
      // Utilizza l'auth_user_id fornito o quello corrente se non specificato
      final authUserId = guestData['auth_user_id'] ?? user.id;
      final role = guestData['role'] ?? 'guest';
      
      // Prepara i dati per la tabella event_users
      final userData = {
        'event_id': eventId,
        'auth_user_id': authUserId,
        'role': role,
      };
      
      // Cerca prima se esiste già un record con questo event_id e auth_user_id
      final existingRecords = await _supabase
          .from('event_users')
          .select()
          .eq('event_id', eventId)
          .eq('auth_user_id', authUserId);
      
      // Se esiste già, usa upsert per aggiornarlo invece di crearne uno nuovo
      if (existingRecords.isNotEmpty) {
        // Aggiorna l'elemento esistente
        final data = await _supabase
          .from('event_users')
          .update(userData)
          .eq('event_id', eventId)
          .eq('auth_user_id', authUserId)
          .select();
        
        return {'success': true, 'data': data, 'message': 'Ospite aggiornato'};
      } else {
        // Inserisci nuovo record
        final data = await _supabase.from('event_users').insert(userData).select();
        return {'success': true, 'data': data, 'message': 'Ospite aggiunto con successo'};
      }
    } catch (e) {
      _logger.severe('Errore aggiunta ospite: $e');
      return {'success': false, 'message': 'Errore: ${_getErrorMessage(e)}'};
    }
  }

  Future<Map<String, dynamic>> updateGuestStatus(String guestId, String status) async {
    try {
      // Aggiorniamo il campo check_in_time invece di is_present
      final data = await _supabase
        .from('event_users')
        .update({
          'check_in_time': status == 'present' ? DateTime.now().toIso8601String() : null
        })
        .eq('id', guestId)
        .select();
      
      return {'success': true, 'data': data};
    } catch (e) {
      _logger.severe('Errore aggiornamento stato ospite: $e');
      return {'success': false, 'message': 'Errore: ${_getErrorMessage(e)}'};
    }
  }

  Future<Map<String, dynamic>> deleteGuest(String guestId) async {
    try {
      await _supabase
        .from('event_users')
        .delete()
        .eq('id', guestId);
      
      return {'success': true, 'message': 'Ospite eliminato con successo'};
    } catch (e) {
      _logger.severe('Errore eliminazione ospite: $e');
      return {'success': false, 'message': 'Errore: ${_getErrorMessage(e)}'};
    }
  }

  // Gestione errori
  String _getErrorMessage(dynamic error) {
    if (error is PostgrestException) {
      return error.message ?? 'Errore sconosciuto';
    }
    return error.toString();
  }

  // Aggiungo anche un metodo helper per verificare le RLS policies
  Future<bool> checkRLSPolicies() async {
    try {
      await _supabase
          .from('events')
          .select()
          .limit(1);
      return true;
    } catch (e) {
      _logger.warning('RLS Policy check failed: $e');
      return false;
    }
  }
}

/// Classe per mantenere compatibilità con il vecchio codice
class Response {
  final dynamic data;
  final int statusCode;

  Response({
    required this.data,
    required this.statusCode,
  });
} 
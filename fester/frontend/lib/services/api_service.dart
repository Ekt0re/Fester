import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:fester_frontend/config/env_config.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

/// Servizio per le chiamate API
class ApiService {
  late final Dio _dio;
  final String _baseUrl = EnvConfig.apiUrl;
  final _logger = Logger('ApiService');
  final _storage = const FlutterSecureStorage();

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Aggiungi il token di autenticazione se presente
        final token = await _storage.read(key: 'token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
    ));

    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      requestHeader: true,
      responseHeader: true,
      error: true,
    ));
  }

  /// Configura il certificato SSL per le chiamate sicure
  Future<void> _configureSsl() async {
    try {
      if (kIsWeb) {
        // Per il web, usa l'adapter predefinito
        return;
      }
      
      // Per app mobile
      if (Platform.isAndroid || Platform.isIOS) {
        final cert = await rootBundle.load('assets/certificates/prod-ca-2021.crt');
        final SecurityContext context = SecurityContext.defaultContext;
        context.setTrustedCertificatesBytes(cert.buffer.asUint8List());
        
        // Configura HttpClient personalizzato per Dio
        _dio.httpClientAdapter = IOHttpClientAdapter(
          createHttpClient: () {
            return HttpClient(context: context);
          },
        );
      }
      
      // Per il web non è necessario configurare il certificato,
      // viene gestito dal browser
    } catch (e) {
      print('Errore configurazione SSL: $e');
    }
  }

  /// Effettua una richiesta GET
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
      );
    } catch (e) {
      return _handleError(e);
    }
  }
  
  /// Effettua una richiesta POST
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
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
    Options? options,
  }) async {
    try {
      return await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } catch (e) {
      return _handleError(e);
    }
  }
  
  /// Effettua una richiesta DELETE
  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } catch (e) {
      return _handleError(e);
    }
  }
  
  /// Gestisce gli errori delle richieste
  Future<Response> _handleError(dynamic error) async {
    if (error is DioException) {
      if (error.response != null) {
        // Errore con risposta dal server
        return error.response!;
      } else {
        // Errore di connessione o timeout
        throw Exception('Errore di connessione: ${error.message}');
      }
    } else {
      // Altro tipo di errore
      throw Exception('Errore sconosciuto: $error');
    }
  }
  
  /// Salva il token di autenticazione
  Future<void> saveAuthToken(String token) async {
    await _storage.write(key: 'token', value: token);
  }
  
  /// Elimina il token di autenticazione
  Future<void> clearAuthToken() async {
    await _storage.delete(key: 'token');
  }
  
  /// Verifica se esiste un token di autenticazione
  Future<bool> hasAuthToken() async {
    final token = await _storage.read(key: 'token');
    return token != null && token.isNotEmpty;
  }

  // Debug: Verifica connessione al backend
  Future<bool> testConnection() async {
    try {
      final response = await _dio.get('$_baseUrl/api/test');
      _logger.info('Test connessione: ${response.data}');
      return response.statusCode == 200;
    } catch (e) {
      _logger.severe('Errore connessione al backend: $e');
      return false;
    }
  }

  // Autenticazione
  Future<Map<String, dynamic>> register(String nome, String cognome, String email, String password) async {
    try {
      // Validate input data
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
      _logger.info('URL: $_baseUrl/api/auth/register');
      _logger.info('Dati inviati: {nome: $nome, cognome: $cognome, email: $email, password: [hidden]}');
      
      final response = await _dio.post(
        '/api/auth/register',
        data: {
          'nome': nome.trim(),
          'cognome': cognome.trim(),
          'email': email.trim().toLowerCase(),
          'password': password,
        },
      );
      
      _logger.info('Codice risposta: ${response.statusCode}');
      _logger.info('Risposta registrazione: ${response.data}');
      
      if (response.statusCode == 201) {
        return response.data;
      } else {
        return {
          'success': false,
          'message': response.data['message'] ?? 'Errore durante la registrazione'
        };
      }
    } catch (e) {
      _logger.severe('Errore registrazione: $e');
      
      if (e is DioException) {
        _logger.severe('Dettagli errore Dio: ${e.response?.data}');
        _logger.severe('Codice status: ${e.response?.statusCode}');
        _logger.severe('Messaggio: ${e.response?.data['message']}');
        
        // Handle specific error cases
        if (e.response?.statusCode == 400) {
          if (e.response?.data?.contains('email already registered')) {
            return {
              'success': false,
              'message': 'L\'email is already registered'
            };
          } else if (e.response?.data?.contains('invalid email')) {
            return {
              'success': false,
              'message': 'Invalid email format'
            };
          } else if (e.response?.data?.contains('password')) {
            return {
              'success': false,
              'message': 'Password does not meet security requirements'
            };
          }
        }
        
        return {
          'success': false,
          'message': e.response?.data['message'] ?? 'Errore durante la registrazione: ${e.message}'
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
      final response = await _dio.post(
        '/api/auth/login',
        data: {
          'email': email.trim().toLowerCase(),
          'password': password,
        },
      );
      _logger.info('Risposta login: ${response.data}');
      
      if (response.statusCode == 200 && response.data != null) {
        if (response.data['success'] == true && response.data['data'] != null) {
          final token = response.data['data']['token'];
          if (token != null) {
            await saveAuthToken(token);
            return {
              'success': true,
              'user': response.data['data']['user'],
              'token': token,
            };
          }
        }
      }
      
      return {
        'success': false,
        'message': response.data?['message'] ?? 'Errore durante il login: risposta non valida'
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
      final response = await _dio.get('$_baseUrl/api/eventi');
      if (response.statusCode == 200) {
        return {'success': true, 'data': response.data};
      }
      return {'success': false, 'message': 'Impossibile recuperare gli eventi'};
    } catch (e) {
      return {'success': false, 'message': 'Errore: ${_getErrorMessage(e)}'};
    }
  }

  Future<Map<String, dynamic>> getEventDetails(String eventId) async {
    try {
      final response = await _dio.get('$_baseUrl/api/eventi/$eventId');
      if (response.statusCode == 200) {
        return {'success': true, 'data': response.data};
      }
      return {'success': false, 'message': 'Impossibile recuperare i dettagli dell\'evento'};
    } catch (e) {
      return {'success': false, 'message': 'Errore: ${_getErrorMessage(e)}'};
    }
  }

  Future<Map<String, dynamic>> createEvent(Map<String, dynamic> eventData) async {
    try {
      _logger.info('Creazione evento: $eventData');
      final response = await _dio.post(
        '/api/eventi',
        data: eventData,
      );
      
      _logger.info('Risposta creazione evento: ${response.data}');
      
      if (response.statusCode == 201) {
        return {
          'success': true,
          'data': response.data['data'],
          'message': 'Evento creato con successo'
        };
      }
      
      return {
        'success': false,
        'message': response.data['error']?['message'] ?? 'Impossibile creare l\'evento'
      };
    } catch (e) {
      _logger.severe('Errore creazione evento: $e');
      if (e is DioException && e.response?.data != null) {
        return {
          'success': false,
          'message': e.response?.data['error']?['message'] ?? 'Errore durante la creazione dell\'evento'
        };
      }
      return {
        'success': false,
        'message': 'Errore: ${_getErrorMessage(e)}'
      };
    }
  }

  Future<Map<String, dynamic>> updateEvent(String eventId, Map<String, dynamic> eventData) async {
    try {
      final response = await _dio.put(
        '$_baseUrl/api/eventi/$eventId',
        data: eventData,
      );
      if (response.statusCode == 200) {
        return {'success': true, 'data': response.data};
      }
      return {'success': false, 'message': 'Impossibile aggiornare l\'evento'};
    } catch (e) {
      return {'success': false, 'message': 'Errore: ${_getErrorMessage(e)}'};
    }
  }

  Future<Map<String, dynamic>> deleteEvent(String eventId) async {
    try {
      final response = await _dio.delete('$_baseUrl/api/eventi/$eventId');
      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Evento eliminato con successo'};
      }
      return {'success': false, 'message': 'Impossibile eliminare l\'evento'};
    } catch (e) {
      return {'success': false, 'message': 'Errore: ${_getErrorMessage(e)}'};
    }
  }

  // Ospiti
  Future<Map<String, dynamic>> getEventGuests(String eventId) async {
    try {
      final response = await _dio.get('$_baseUrl/api/ospiti/evento/$eventId');
      if (response.statusCode == 200) {
        return {'success': true, 'data': response.data};
      }
      return {'success': false, 'message': 'Impossibile recuperare gli ospiti'};
    } catch (e) {
      return {'success': false, 'message': 'Errore: ${_getErrorMessage(e)}'};
    }
  }

  Future<Map<String, dynamic>> addGuest(String eventId, Map<String, dynamic> guestData) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/api/ospiti',
        data: {...guestData, 'eventoId': eventId},
      );
      if (response.statusCode == 201) {
        return {'success': true, 'data': response.data};
      }
      return {'success': false, 'message': 'Impossibile aggiungere l\'ospite'};
    } catch (e) {
      return {'success': false, 'message': 'Errore: ${_getErrorMessage(e)}'};
    }
  }

  Future<Map<String, dynamic>> updateGuestStatus(String guestId, String status) async {
    try {
      final response = await _dio.patch(
        '$_baseUrl/api/ospiti/$guestId/status',
        data: {'status': status},
      );
      if (response.statusCode == 200) {
        return {'success': true, 'data': response.data};
      }
      return {'success': false, 'message': 'Impossibile aggiornare lo stato dell\'ospite'};
    } catch (e) {
      return {'success': false, 'message': 'Errore: ${_getErrorMessage(e)}'};
    }
  }

  Future<Map<String, dynamic>> deleteGuest(String guestId) async {
    try {
      final response = await _dio.delete('$_baseUrl/api/ospiti/$guestId');
      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Ospite eliminato con successo'};
      }
      return {'success': false, 'message': 'Impossibile eliminare l\'ospite'};
    } catch (e) {
      return {'success': false, 'message': 'Errore: ${_getErrorMessage(e)}'};
    }
  }

  // Gestione errori
  String _getErrorMessage(dynamic error) {
    if (error is DioException) {
      if (error.response != null) {
        try {
          final message = error.response?.data['error']['message'];
          return message ?? error.message ?? 'Errore sconosciuto';
        } catch (_) {
          return error.message ?? 'Errore sconosciuto';
        }
      }
      return error.message ?? 'Errore di connessione';
    }
    return error.toString();
  }

  void _handleAuthError() async {
    // Gestione logout per token scaduto
    await clearAuthToken();
    // Qui potresti utilizzare un event bus o navigare alla pagina di login
  }
} 
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fester_frontend/config/env_config.dart';

/// Servizio per le chiamate API
class ApiService {
  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  /// Costruttore che inizializza il client Dio
  ApiService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: EnvConfig.apiUrl,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );
    
    // Aggiungi l'interceptor per il token di autenticazione
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: 'auth_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) {
          if (error.response?.statusCode == 401) {
            // Token scaduto o non valido, gestire logout
          }
          return handler.next(error);
        },
      ),
    );
    
    // Aggiungi l'interceptor per il logging in modalità debug
    if (EnvConfig.isDebug) {
      _dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
        ),
      );
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
    await _storage.write(key: 'auth_token', value: token);
  }
  
  /// Elimina il token di autenticazione
  Future<void> clearAuthToken() async {
    await _storage.delete(key: 'auth_token');
  }
  
  /// Verifica se esiste un token di autenticazione
  Future<bool> hasAuthToken() async {
    final token = await _storage.read(key: 'auth_token');
    return token != null && token.isNotEmpty;
  }
} 
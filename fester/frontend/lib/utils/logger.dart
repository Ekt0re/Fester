import 'package:flutter/foundation.dart';
import 'package:fester_frontend/config/env_config.dart';

/// Classe utility per il logging nell'applicazione.
/// Fornisce metodi per registrare messaggi di log con diversi livelli di gravità.
class Logger {
  /// Nome del modulo o componente che sta effettuando il logging
  final String module;

  /// Costruttore che richiede il nome del modulo
  const Logger(this.module);

  /// Registra un messaggio di debug
  void debug(String message) {
    if (EnvConfig.isDebug) {
      _log('DEBUG', message);
    }
  }

  /// Registra un messaggio informativo
  void info(String message) {
    _log('INFO', message);
  }

  /// Registra un messaggio di avviso
  void warning(String message) {
    _log('WARNING', message);
  }

  /// Registra un messaggio di errore
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    _log('ERROR', message);
    
    if (error != null) {
      _log('ERROR', 'Exception: $error');
    }
    
    if (stackTrace != null && EnvConfig.isDebug) {
      _log('ERROR', 'StackTrace: $stackTrace');
    }
  }

  /// Metodo interno per formattare e stampare il log
  void _log(String level, String message) {
    // In un'app di produzione, questo potrebbe inviare i log a:
    // - Un servizio di logging remoto
    // - Crashlytics
    // - Un file locale
    // - Una console di monitoraggio
    
    // Per ora, usiamo debugPrint che è più sicuro di print
    // in quanto non lancia eccezioni in fase di produzione
    debugPrint('[$level] [$module] $message');
  }
} 
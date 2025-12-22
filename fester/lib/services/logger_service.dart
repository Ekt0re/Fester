import 'package:flutter/foundation.dart';

/// Servizio di logging centralizzato per Fester.
///
/// In modalità debug: stampa tutti i log su console con timestamp e livello.
/// In modalità release: logga solo errori (opzionalmente su servizio esterno).
class LoggerService {
  static const String _appTag = 'Fester';

  /// Log informativo - per eventi normali dell'applicazione
  static void info(String message, {String? tag}) {
    if (kDebugMode) {
      final prefix = tag != null ? '[$tag]' : '[$_appTag]';
      debugPrint('ℹ️ $prefix $message');
    }
  }

  /// Log di warning - per situazioni anomale ma non critiche
  static void warning(String message, {String? tag, Object? error}) {
    if (kDebugMode) {
      final prefix = tag != null ? '[$tag]' : '[$_appTag]';
      debugPrint(
        '⚠️ $prefix $message${error != null ? ' | Error: $error' : ''}',
      );
    }
  }

  /// Log di errore - per errori e eccezioni
  static void error(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final prefix = tag != null ? '[$tag]' : '[$_appTag]';

    if (kDebugMode) {
      debugPrint('❌ $prefix $message');
      if (error != null) {
        debugPrint('   Error: $error');
      }
      if (stackTrace != null) {
        debugPrint('   StackTrace: $stackTrace');
      }
    } else {
      // In release mode, potremmo inviare a un servizio di crash reporting
      // come Firebase Crashlytics, Sentry, ecc.
      // Per ora loggiamo solo errori critici
      // FirebaseCrashlytics.instance.recordError(error, stackTrace);
    }
  }

  /// Log di debug - per informazioni dettagliate durante lo sviluppo
  static void debug(String message, {String? tag}) {
    if (kDebugMode) {
      final prefix = tag != null ? '[$tag]' : '[$_appTag]';
      debugPrint('🔍 $prefix $message');
    }
  }
}

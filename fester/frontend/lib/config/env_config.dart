import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Classe che gestisce l'accesso alle variabili di ambiente
class EnvConfig {
  /// Inizializza e carica le variabili di ambiente dal file .env
  static Future<void> init() async {
    await dotenv.load();
  }

  /// Restituisce l'URL base per le chiamate API
  static String get apiUrl => 'http://localhost:3000';

  /// Restituisce l'URL di Supabase
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';

  /// Restituisce la chiave anonima di Supabase
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  /// Restituisce il nome dell'applicazione
  static String get appName => dotenv.env['APP_NAME'] ?? 'Fester';

  /// Restituisce la versione dell'applicazione
  static String get appVersion => dotenv.env['APP_VERSION'] ?? '1.0.0';

  /// Indica se l'applicazione è in modalità debug
  static bool get isDebug => dotenv.env['DEBUG']?.toLowerCase() == 'true';

  /// Restituisce l'ambiente corrente (development, staging, production)
  static String get environment => dotenv.env['ENV'] ?? 'development';

  /// Indica se l'applicazione è in ambiente di sviluppo
  static bool get isDevelopment => environment == 'development';

  /// Indica se l'applicazione è in ambiente di staging
  static bool get isStaging => environment == 'staging';

  /// Indica se l'applicazione è in ambiente di produzione
  static bool get isProduction => environment == 'production';
} 
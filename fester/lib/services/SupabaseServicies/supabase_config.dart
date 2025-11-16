// lib/config/supabase_config.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class SupabaseConfig {
  static const String supabaseUrl = 'https://tzrjlnvdeqmmlnivoszq.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_eFPKG8kUCxXFvrx_x7bBLQ_7TaKcVSY';

  // Redirect URLs for authentication
  static const String redirectUrl = 'http://localhost:3000';
  static const String authCallbackPath = '/auth/callback';
  static const String resetPasswordPath = '/auth/reset-password';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        autoRefreshToken: true,
        //persistSession: true,
      ),
      realtimeClientOptions: const RealtimeClientOptions(
        logLevel: kDebugMode ? RealtimeLogLevel.info : RealtimeLogLevel.error,
      ),
      storageOptions: const StorageClientOptions(retryAttempts: 3),
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}

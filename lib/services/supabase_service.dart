import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String _supabaseUrl = 'https://tzrjlnvdeqmmlnivoszq.supabase.co';
  static const String _supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR6cmpsbnZkZXFtbWxuaXZvc3pxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDgxMDY0MDksImV4cCI6MjA2MzY4MjQwOX0.ZKSaOK62VlWSnYFZKTu-ry7TcsID9JoYFJ3oR9bA0TU';

  static Future<void> initSupabase() async {
    await Supabase.initialize(
      url: _supabaseUrl,
      anonKey: _supabaseAnonKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;

  // Authentication methods
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? username,
  }) async {
    return await client.auth.signUp(
      email: email,
      password: password,
      data: username != null ? {'username': username} : null,
    );
  }

  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  static User? get currentUser => client.auth.currentUser;

  static Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;
}

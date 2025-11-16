// lib/services/supabase_auth.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Get current user
  User? get currentUser => _supabase.auth.currentUser;

  // Get current session
  Session? get currentSession => _supabase.auth.currentSession;

  // Stream of auth state changes
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  /// Sign up with email and password
  /// Creates both auth.users and staff_user records via trigger
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required DateTime? dateOfBirth,
    String? phone,
    String? redirectTo,
  }) async {
    try {
      final userMetadata = {
        'first_name': firstName,
        'last_name': lastName,
        'full_name': '$firstName $lastName',
        'date_of_birth': dateOfBirth?.toIso8601String().split('T').first, // Formato YYYY-MM-DD
        if (phone != null) 'phone': phone,
        'is_active': true,
      };

      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: userMetadata,
        emailRedirectTo: redirectTo ?? 'io.fester.app://auth/callback?mode=signup',
      );

      return response;
    } catch (e) {
      Logger().e('Errore durante la registrazione: $e');
      rethrow;
    }
  }

  /// Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Sign in with magic link (passwordless)
  Future<void> signInWithMagicLink({
    required String email,
    String? redirectTo,
  }) async {
    try {
      await _supabase.auth.signInWithOtp(
        email: email,
        emailRedirectTo: redirectTo ?? 'io.fester.app://auth/callback?mode=magiclink',
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      rethrow;
    }
  }

  /// Reset password - sends email with reset link
  Future<void> resetPassword({
    required String email,
    String? redirectTo,
  }) async {
    try {
      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: redirectTo ?? 'io.fester.app://auth/callback?mode=recovery',
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Update password (requires current session)
  Future<UserResponse> updatePassword({required String newPassword}) async {
    try {
      final response = await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Resend email verification
  Future<void> resendVerificationEmail({
    required String email,
    String? redirectTo,
  }) async {
    try {
      await _supabase.auth.resend(
        type: OtpType.signup,
        email: email,
        emailRedirectTo: redirectTo ?? 'io.fester.app://auth/callback?mode=signup',
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Update user metadata
  Future<UserResponse> updateUserMetadata({
    String? firstName,
    String? lastName,
    String? phone,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final data = <String, dynamic>{};

      if (firstName != null) data['first_name'] = firstName;
      if (lastName != null) data['last_name'] = lastName;
      if (firstName != null && lastName != null) {
        data['full_name'] = '$firstName $lastName';
      }
      if (phone != null) data['phone'] = phone;
      if (additionalData != null) data.addAll(additionalData);

      final response = await _supabase.auth.updateUser(
        UserAttributes(data: data),
      );

      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Update user email (requires password confirmation)
  Future<UserResponse> updateEmail({required String newEmail}) async {
    try {
      final response = await _supabase.auth.updateUser(
        UserAttributes(email: newEmail),
      );

      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Verify OTP (for email confirmation, password reset, etc.)
  Future<AuthResponse> verifyOtp({
    required String email,
    required String token,
    required OtpType type,
  }) async {
    try {
      final response = await _supabase.auth.verifyOTP(
        email: email,
        token: token,
        type: type,
      );

      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Check if user email is verified
  bool get isEmailVerified {
    final user = currentUser;
    if (user == null) return false;

    return user.emailConfirmedAt != null;
  }

  /// Get user ID
  String? get userId => currentUser?.id;

  /// Check if user is authenticated
  bool get isAuthenticated => currentUser != null;

  /// Handle deep link authentication (for email verification, password reset)
  Future<void> handleDeepLink(Uri uri) async {
    try {
      // Supabase automatically handles the deep link if configured properly
      // This method can be used for custom handling if needed
      await _supabase.auth.getSessionFromUrl(uri);
    } catch (e) {
      rethrow;
    }
  }

  /// Refresh session
  Future<AuthResponse> refreshSession() async {
    try {
      final response = await _supabase.auth.refreshSession();
      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Delete user account (requires current session)
  Future<void> deleteAccount() async {
    try {
      // Note: This requires admin privileges or specific RLS policies
      // You may need to implement this through a Supabase Edge Function
      final userId = currentUser?.id;
      if (userId == null) throw Exception('No user logged in');

      // First sign out
      await signOut();

      // Then call your edge function or RPC to delete the user
      // await _supabase.functions.invoke('delete-user');
    } catch (e) {
      rethrow;
    }
  }
}


/*
Gestione completa dell'autenticazione:

✅ Sign up con email/password
✅ Sign in (email/password e magic link)
✅ Reset password
✅ Verifica email (resend verification)
✅ Update profilo utente e email
✅ Gestione OTP
✅ Sign out
✅ Refresh session

 */
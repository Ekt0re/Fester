// lib/utils/deep_link_handler.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'package:logger/logger.dart';

class DeepLinkHandler {
  static final DeepLinkHandler _instance = DeepLinkHandler._internal();
  factory DeepLinkHandler() => _instance;
  DeepLinkHandler._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  StreamSubscription<AuthState>? _authSubscription;
  
  // Flag globale per recovery mode - BLOCCA qualsiasi redirect automatico
  static bool _isRecoveryMode = false;
  static bool get isRecoveryMode => _isRecoveryMode;
  static void setRecoveryMode(bool value) {
    _isRecoveryMode = value;
    debugPrint('[NAV] Recovery mode: $_isRecoveryMode');
  }

  static final Logger _logger = Logger(printer: PrettyPrinter(methodCount: 0, colors: false, printEmojis: false, printTime: false));

  /// Initialize deep link handling
  void initialize(BuildContext context) {
    // Listen to auth state changes
    _authSubscription = _supabase.auth.onAuthStateChange.listen(
      (data) {
        final event = data.event;
        final session = data.session;

        switch (event) {
          case AuthChangeEvent.signedIn:
            _logger.i("[EVENT] signedIn");
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _handleSignedIn(context, session);
            });
            break;
          case AuthChangeEvent.signedOut:
            _logger.i("[EVENT] signedOut");
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _handleSignedOut(context);
            });
            break;
          case AuthChangeEvent.passwordRecovery:
            _logger.i("[EVENT] passwordRecovery");
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _handlePasswordRecovery(context, session);
            });
            break;
          case AuthChangeEvent.tokenRefreshed:
            _logger.i("Token refreshed");
            break;
          case AuthChangeEvent.userUpdated:
            _logger.i("User updated");
            break;
          default:
            _logger.i("[EVENT] (other): $event");
        }
      },
      onError: (error) {
        _logger.e('Auth state change error: $error');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_isContextMounted(context)) return;
          _showErrorSnackBar(context, 'Authentication error: $error');
        });
      },
    );
  }

  /// Handle signed in event
  void _handleSignedIn(BuildContext context, Session? session) {
    if (session == null) return;
    _logger.i('User signed in:  [34m${session.user.email} [0m');
    if (!_isContextMounted(context)) return;

    // BLOCCA TOTALE se siamo in recovery mode (flag globale)
    if (isRecoveryMode) {
      _logger.i('[NAV] SignedIn BLOCCATO: recovery mode attivo');
      return;
    }

    // BLOCCA redirect a /home se siamo in recovery mode
    final currentRoute = ModalRoute.of(context)?.settings.name;
    if (currentRoute == '/set-new-password') {
      _logger.i('[NAV] SignedIn BLOCCATO: già su set-new-password');
      return;
    }

    // Controlla anche i parametri URL per recovery
    try {
      final uri = Uri.base;
      if (uri.queryParameters['type'] == 'recovery') {
        _logger.i("[NAV] SignedIn BLOCCATO: type=recovery nell'URL");
        return;
      }
    } catch (e) {
      // Ignora errori di parsing URI
    }

    // Navigate to event selection screen
    if (!_isContextMounted(context)) return;
    Navigator.of(context).pushReplacementNamed('/event-selection');

    _showSuccessSnackBar(context, 'Successfully signed in!');
  }

  /// Handle signed out event
  void _handleSignedOut(BuildContext context) {
    _logger.i('User signed out');
    if (!_isContextMounted(context)) return;
    Navigator.of(context).pushReplacementNamed('/login');
  }

  /// Handle password recovery flow
  void _handlePasswordRecovery(BuildContext context, Session? session) async {
    // SETTA FLAG GLOBALE - BLOCCA TUTTI I REDIRECT AUTOMATICI
    setRecoveryMode(true);
    
    // BLOCCA se già nella schermata del reset
    if (ModalRoute.of(context)?.settings.name == '/set-new-password') {
      return;
    }
    // Evita signOut: solo redirect
    if (!_isContextMounted(context)) return;
    Navigator.of(context).pushReplacementNamed('/set-new-password');
    _showInfoSnackBar(context, 'Imposta la nuova password');
  }

  /// Handle incoming deep link manually
  Future<void> handleDeepLink(BuildContext context, Uri uri) async {
    try {
      _logger.i('Handling deep link: $uri');

      // Check if it's an auth callback
      if (uri.path.contains('auth/callback')) {
        await _handleAuthCallback(context, uri);
      } else if (uri.path.contains('auth/reset-password')) {
        await _handleResetPasswordCallback(context, uri);
      } else if (uri.path.contains('auth/verify')) {
        await _handleEmailVerification(context, uri);
      } else {
        _logger.w('Unknown deep link path: ${uri.path}');
      }
    } catch (e) {
      _logger.e('Error handling deep link: $e');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isContextMounted(context)) return;
        _showErrorSnackBar(context, 'Failed to process link: $e');
      });
    }
  }

  /// Handle auth callback (email verification, magic link)
  Future<void> _handleAuthCallback(BuildContext context, Uri uri) async {
    try {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isContextMounted(context)) return;
        _showSuccessSnackBar(context, 'Email verified successfully!');
        Navigator.of(context).pushReplacementNamed('/event-selection');
      });
    } catch (e) {
      _logger.e('Auth callback error: $e');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isContextMounted(context)) return;
        _showErrorSnackBar(context, 'Failed to verify email: $e');
      });
    }
  }

  /// Handle password reset callback
  Future<void> _handleResetPasswordCallback(BuildContext context, Uri uri) async {
    try {
      // SETTA FLAG PRIMA di getSessionFromUrl per bloccare signedIn event
      setRecoveryMode(true);
      await _supabase.auth.getSessionFromUrl(uri);
      // Solo redirect (NO signOut)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isContextMounted(context)) return;
        Navigator.of(context).pushReplacementNamed('/set-new-password');
        _showInfoSnackBar(context, 'Imposta la nuova password');
      });
    } catch (e) {
      _logger.e('Password reset callback error: $e');
      setRecoveryMode(false); // Reset flag se errore
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isContextMounted(context)) return;
        _showErrorSnackBar(context, 'Link reset password non valido o scaduto');
      });
    }
  }

  /// Handle email verification
  Future<void> _handleEmailVerification(BuildContext context, Uri uri) async {
    try {
      final token = uri.queryParameters['token'];
      final email = uri.queryParameters['email'];

      if (token == null || email == null) {
        throw Exception('Invalid verification link');
      }

      await _supabase.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.signup,
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isContextMounted(context)) return;
        _showSuccessSnackBar(context, 'Email verified! You can now sign in.');
        Navigator.of(context).pushReplacementNamed('/login');
      });
    } catch (e) {
      _logger.e('Email verification error: $e');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isContextMounted(context)) return;
        _showErrorSnackBar(context, 'Failed to verify email: $e');
      });
    }
  }

  /// Show success snackbar
  void _showSuccessSnackBar(BuildContext context, String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isContextMounted(context)) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    });
  }

  /// Show error snackbar
  void _showErrorSnackBar(BuildContext context, String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isContextMounted(context)) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    });
  }

  /// Show info snackbar
  void _showInfoSnackBar(BuildContext context, String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isContextMounted(context)) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 3),
        ),
      );
    });
  }

  /// Dispose resources
  void dispose() {
    _authSubscription?.cancel();
  }

  // Helpers contestuali di sicurezza post-async gap
  bool _isContextMounted(BuildContext context) {
    try {
      // Per StatelessWidget context non ha mounted, ma context.owner dovrebbe esistere: workaround robusto
      final element = context as Element;
      return element.mounted;
    } catch (_) {
      // Se non so verificarlo, si presume vero per retrocompatibilità
      return true;
    }
  }
}

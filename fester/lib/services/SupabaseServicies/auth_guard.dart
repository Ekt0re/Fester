// lib/utils/auth_guard.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

/// Widget that requires authentication to display its child
class AuthGuard extends StatelessWidget {
  final Widget child;
  final Widget? fallback;

  const AuthGuard({required this.child, this.fallback, super.key});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      return fallback ?? const Center(child: CircularProgressIndicator());
    }

    return child;
  }
}

/// Middleware to check authentication before navigating
class AuthMiddleware {
  static Future<bool> checkAuth(BuildContext context) async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      Navigator.of(context).pushReplacementNamed('/login');
      return false;
    }

    return true;
  }

  static Future<bool> checkEmailVerified(BuildContext context) async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      Navigator.of(context).pushReplacementNamed('/login');
      return false;
    }

    if (user.emailConfirmedAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please verify your email address first'),
          backgroundColor: Colors.orange,
        ),
      );
      Navigator.of(context).pushReplacementNamed('/verify-email');
      return false;
    }

    return true;
  }
}

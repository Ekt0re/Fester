import 'package:fester/services/SupabaseServicies/supabase_auth.dart';
import 'package:flutter/material.dart';
import 'login_page.dart';

class RegistrationConfirmationPage extends StatelessWidget {
  final String email; // aggiunto

  const RegistrationConfirmationPage({super.key, required this.email});

  Future<void> _resendConfirmationEmail(BuildContext context) async {
    try {
      await AuthService().resendVerificationEmail(
        email: email,
      ); // passa l'email
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Email inviata nuovamente! Controlla la tua casella.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore nell\'invio dell\'email: ${e.toString()}'),
            backgroundColor: Colors.red.shade400,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                color: theme.cardTheme.color,
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'FESTER 3.0',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'ORGANIZZA LA TUA FESTA!',
                        style: theme.textTheme.bodySmall?.copyWith(
                          letterSpacing: 1.2,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 50),
                      Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Icon(
                          Icons.email_outlined,
                          size: 100,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 30),
                      Text(
                        'Conferma il tuo account',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Ti abbiamo inviato un\'email di conferma.\nClicca sul link per attivare il tuo account.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.5,
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 40),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (_) => const LoginPage()),
                              (route) => false,
                            );
                          },
                          child: const Text('Accedi'),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: () => _resendConfirmationEmail(context),
                        child: Text(
                          'Non hai ricevuto l\'email? Rinvia',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
    return Scaffold(
      backgroundColor: const Color(0xFFE8F0FE),
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: const Color(0xFFB8D4F1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'FESTER 3.0',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'ORGANIZZA LA TUA FESTA!',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF4A4A4A),
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 50),
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(80),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Icon(
                  Icons.email_outlined,
                  size: 100,
                  color: Color(0xFF5B8BC9),
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'Conferma il tuo account',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Ti abbiamo inviato un\'email di conferma.\nClicca sul link per attivare il tuo account.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF4A4A4A),
                  height: 1.5,
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5B8BC9),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Accedi',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => _resendConfirmationEmail(context),
                child: const Text(
                  'Non hai ricevuto l\'email? Rinvia',
                  style: TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:fester/services/SupabaseServicies/supabase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;
import 'registration_confirmation_page.dart';

class RegisterStep3Page extends StatefulWidget {
  final String firstName;
  final String lastName;
  final DateTime dateOfBirth;
  final String email;
  final String phone;

  const RegisterStep3Page({
    super.key,
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
    required this.email,
    required this.phone,
  });

  @override
  State<RegisterStep3Page> createState() => _RegisterStep3PageState();
}

class _RegisterStep3PageState extends State<RegisterStep3Page> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptTerms = false;
  bool _isLoading = false;

  final AuthService _authService = AuthService();

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    print('🔍 Validating form...');
    if (!_formKey.currentState!.validate()) {
      print('❌ Form validation failed');
      return;
    }

    if (!_acceptTerms) {
      print('❌ Terms not accepted');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Devi accettare i termini e condizioni'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    print('✅ Form validation successful');
    setState(() => _isLoading = true);

    try {
      print('🚀 Starting registration process...');
      print('📧 Email: ${widget.email}');
      print('👤 Name: ${widget.firstName} ${widget.lastName}');
      print('📅 Date of Birth: ${widget.dateOfBirth}');
      print('📱 Phone: ${widget.phone}');

      final authResponse = await _authService.signUp(
        email: widget.email,
        password: _passwordController.text,
        firstName: widget.firstName,
        lastName: widget.lastName,
        dateOfBirth: widget.dateOfBirth,
        phone: widget.phone,
      );

      print('🎉 Registration response received');
      
      if (authResponse.user == null) {
        print('❌ Auth response contains no user data');
        throw Exception('Impossibile creare l\'utente. Riprova più tardi.');
      }

      print('👤 User created with ID: ${authResponse.user?.id}');
      print('📬 Confirmation email sent to: ${authResponse.user?.email}');

      if (mounted) {
        print('🔄 Navigating to confirmation page');
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => RegistrationConfirmationPage(email: widget.email),
          ),
          (route) => false,
        );
      }
    } catch (e, stackTrace) {
      print('❌ Registration error:');
      print('Error type: ${e.runtimeType}');
      print('Error message: $e');
      print('Stack trace: $stackTrace');

      String errorMessage = 'Errore durante la registrazione';

      if (e is AuthException) {
        print('🔍 AuthException details:');
        print('Status code: ${e.statusCode}');
        print('Message: ${e.message}');
        
        if (e.statusCode == '400') {
          if (e.message.contains('already registered') || 
              e.message.contains('already in use')) {
            errorMessage = 'Email già registrata';
          } else if (e.message.contains('password')) {
            errorMessage = 'La password non rispetta i requisiti di sicurezza';
          } else if (e.message.contains('email')) {
            errorMessage = 'Indirizzo email non valido';
          }
        } else if (e.statusCode == '422') {
          errorMessage = 'Dati non validi. Controlla i campi inseriti.';
        }
      } else if (e.toString().contains('host lookup failed') || 
                 e.toString().contains('Connection failed')) {
        errorMessage = 'Errore di connessione. Verifica la tua connessione internet.';
      }

      print('📢 Showing error to user: $errorMessage');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red.shade400,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F0FE),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: const Color(0xFFB8D4F1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'FESTER 3.0',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 50),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      hintText: 'Password',
                      filled: true,
                      fillColor: Colors.white.withAlpha(230),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed:
                            () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty)
                        return 'Inserisci una password';
                      if (value.length < 8)
                        return 'La password deve essere di almeno 8 caratteri';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      hintText: 'Conferma Password',
                      filled: true,
                      fillColor: Colors.white.withAlpha(230),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed:
                            () => setState(
                              () =>
                                  _obscureConfirmPassword =
                                      !_obscureConfirmPassword,
                            ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty)
                        return 'Conferma la password';
                      if (value != _passwordController.text)
                        return 'Le password non corrispondono';
                      return null;
                    },
                  ),
                  Row(
                    children: [
                      Checkbox(
                        value: _acceptTerms,
                        onChanged:
                            (value) =>
                                setState(() => _acceptTerms = value ?? false),
                        activeColor: const Color(0xFF5B8BC9),
                      ),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF1A1A1A),
                            ),
                            children: [
                              const TextSpan(text: 'Accetto i '),
                              TextSpan(
                                text: 'termini e condizioni',
                                style: const TextStyle(
                                  color: Color(0xFF5B8BC9),
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                                recognizer:
                                    TapGestureRecognizer()
                                      ..onTap = () {
                                        /* mostra termini */
                                      },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleRegister,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5B8BC9),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child:
                          _isLoading
                              ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                              : const Text(
                                'Crea Account',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      '< Back',
                      style: TextStyle(
                        fontSize: 16,
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
    );
  }
}

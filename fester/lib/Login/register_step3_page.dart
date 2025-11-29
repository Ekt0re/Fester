import 'package:fester/services/SupabaseServicies/supabase_auth.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;
import 'registration_confirmation_page.dart';
import 'package:logger/logger.dart';
import 'package:url_launcher/url_launcher.dart';

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
  final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      colors: false,
      printEmojis: false,
      printTime: false,
    ),
  );

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    _logger.i('🔍 Validating form...');
    if (!_formKey.currentState!.validate()) {
      _logger.w('❌ Form validation failed');
      return;
    }

    if (!_acceptTerms) {
      _logger.w('❌ Terms not accepted');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('register.terms_error'.tr()),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    _logger.i('✅ Form validation successful');
    setState(() => _isLoading = true);

    try {
      _logger.i('🚀 Starting registration process...');
      _logger.d('📧 Email:  [4m${widget.email} [0m');
      _logger.d('👤 Name: ${widget.firstName} ${widget.lastName}');
      _logger.d('📅 Date of Birth: ${widget.dateOfBirth}');
      _logger.d('📱 Phone: ${widget.phone}');

      final authResponse = await _authService.signUp(
        email: widget.email,
        password: _passwordController.text,
        firstName: widget.firstName,
        lastName: widget.lastName,
        dateOfBirth: widget.dateOfBirth,
        phone: widget.phone,
      );

      _logger.i('🎉 Registration response received');

      if (authResponse.user == null) {
        _logger.e('❌ Auth response contains no user data');
        throw Exception('register.error_create_user'.tr());
      }

      _logger.i('👤 User created with ID: ${authResponse.user?.id}');
      _logger.i('📬 Confirmation email sent to: ${authResponse.user?.email}');

      if (mounted) {
        _logger.i('🔄 Navigating to confirmation page');
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => RegistrationConfirmationPage(email: widget.email),
          ),
          (route) => false,
        );
      }
    } catch (e, stackTrace) {
      _logger.e('❌ Registration error:', error: e, stackTrace: stackTrace);
      _logger.e('Error type: ${e.runtimeType}');
      _logger.e('Error message: $e');
      _logger.t('Stack trace: $stackTrace');

      String errorMessage = 'register.error_generic'.tr();

      if (e is AuthException) {
        _logger.w('🔍 AuthException details:');
        _logger.w('Status code: ${e.statusCode}');
        _logger.w('Message: ${e.message}');

        if (e.statusCode == '400') {
          if (e.message.contains('already registered') ||
              e.message.contains('already in use')) {
            errorMessage = 'register.error_email_exists'.tr();
          } else if (e.message.contains('password')) {
            errorMessage = 'register.error_password_security'.tr();
          } else if (e.message.contains('email')) {
            errorMessage = 'register.error_email_invalid'.tr();
          }
        } else if (e.statusCode == '422') {
          errorMessage = 'register.error_invalid_data'.tr();
        }
      } else if (e.toString().contains('host lookup failed') ||
          e.toString().contains('Connection failed')) {
        errorMessage = 'register.error_connection'.tr();
      }

      _logger.w('📢 Showing error to user: $errorMessage');

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

  _launchURL() async {
    final Uri url = Uri.parse(
      'https://github.com/Ekt0re/Fester/blob/5e20be71f6fc756eaea696c95c6a863e6a8df5ac/Utility/Terms/Fester%20Terms%20Privacy%20Md.pdf',
    );
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
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
                  child: Form(
                    key: _formKey,
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
                          'register.subtitle'.tr(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            letterSpacing: 1.2,
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(height: 50),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: theme.textTheme.bodyLarge,
                          decoration: InputDecoration(
                            labelText: 'login.password_label'.tr(),
                            prefixIcon: const Icon(Icons.lock_outline),
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
                            if (value == null || value.isEmpty) {
                              return 'login.password_error_empty'.tr();
                            }
                            if (value.length < 8) {
                              return 'register.password_error_length'.tr();
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          style: theme.textTheme.bodyLarge,
                          decoration: InputDecoration(
                            labelText: 'register.confirm_password_label'.tr(),
                            prefixIcon: const Icon(Icons.lock_outline),
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
                            if (value == null || value.isEmpty) {
                              return 'register.confirm_password_error_empty'
                                  .tr();
                            }
                            if (value != _passwordController.text) {
                              return 'register.confirm_password_error_match'
                                  .tr();
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Checkbox(
                              value: _acceptTerms,
                              onChanged:
                                  (value) => setState(
                                    () => _acceptTerms = value ?? false,
                                  ),
                              activeColor: theme.colorScheme.primary,
                            ),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: theme.textTheme.bodyMedium,
                                  children: [
                                    TextSpan(text: 'register.terms_agree'.tr()),
                                    TextSpan(
                                      text: 'register.terms_link'.tr(),
                                      style: TextStyle(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                        decoration: TextDecoration.underline,
                                      ),
                                      recognizer:
                                          TapGestureRecognizer()
                                            ..onTap = () {
                                              _launchURL();
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
                                    : Text(
                                      'register.create_account_button'.tr(),
                                    ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'forgot_password.back_button'.tr(),
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
      ),
    );
  }
}

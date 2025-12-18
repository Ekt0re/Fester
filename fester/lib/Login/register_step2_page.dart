import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../utils/validation_utils.dart';
import 'register_step3_page.dart';

class RegisterStep2Page extends StatefulWidget {
  final String firstName;
  final String lastName;
  final DateTime dateOfBirth;

  const RegisterStep2Page({
    super.key,
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
  });

  @override
  State<RegisterStep2Page> createState() => _RegisterStep2PageState();
}

class _RegisterStep2PageState extends State<RegisterStep2Page> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _goToNextStep() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => RegisterStep3Page(
              firstName: widget.firstName,
              lastName: widget.lastName,
              dateOfBirth: widget.dateOfBirth,
              email: _emailController.text.trim(),
              phone: _phoneController.text.trim(),
            ),
      ),
    );
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
                          'common.app_title'.tr(),
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
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'register.step2_title'.tr(),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: theme.textTheme.bodyLarge,
                          decoration: InputDecoration(
                            labelText: 'login.email_label'.tr(),
                            prefixIcon: const Icon(Icons.email_outlined),
                          ),
                          validator:
                              (value) =>
                                  FormValidator.validateEmail(value)?.tr(),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          style: theme.textTheme.bodyLarge,
                          decoration: InputDecoration(
                            labelText: 'register.phone_label'.tr(),
                            prefixIcon: const Icon(Icons.phone_outlined),
                          ),
                          validator:
                              (value) =>
                                  FormValidator.validatePhone(value)?.tr(),
                        ),
                        const SizedBox(height: 40),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _goToNextStep,
                            child: Text('register.next_button'.tr()),
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

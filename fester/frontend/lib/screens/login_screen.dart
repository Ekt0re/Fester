import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fester_frontend/blocs/auth/auth_bloc.dart';
import 'package:fester_frontend/config/env_config.dart';
import 'package:reactive_forms/reactive_forms.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final form = FormGroup({
    'email': FormControl<String>(
      value: '',
      validators: [Validators.required, Validators.email],
    ),
    'password': FormControl<String>(
      value: '',
      validators: [Validators.required, Validators.minLength(6)],
    ),
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            context.go('/home');
          } else if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        builder: (context, state) {
          return SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 60),
                    Text(
                      EnvConfig.appName,
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Gestione eventi semplificata',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 60),
                    ReactiveForm(
                      formGroup: form,
                      child: Column(
                        children: [
                          ReactiveTextField<String>(
                            formControlName: 'email',
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email),
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validationMessages: {
                              'required': (error) => 'L\'email è obbligatoria',
                              'email': (error) => 'Inserisci un\'email valida',
                            },
                          ),
                          const SizedBox(height: 16),
                          ReactiveTextField<String>(
                            formControlName: 'password',
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Password',
                              prefixIcon: Icon(Icons.lock),
                              border: OutlineInputBorder(),
                            ),
                            validationMessages: {
                              'required': (error) => 'La password è obbligatoria',
                              'minLength': (error) => 'La password deve avere almeno 6 caratteri',
                            },
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: state is AuthLoading
                                  ? null
                                  : () {
                                      if (form.valid) {
                                        final email = form.control('email').value.toString();
                                        final password = form.control('password').value.toString();
                                        
                                        context.read<AuthBloc>().add(
                                          AuthLoginRequested(
                                            email: email,
                                            password: password,
                                          ),
                                        );
                                      } else {
                                        form.markAllAsTouched();
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: state is AuthLoading
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : const Text(
                                      'ACCEDI',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Non hai un account?'),
                        TextButton(
                          onPressed: () {
                            context.push('/register');
                          },
                          child: const Text('Registrati'),
                        ),
                      ],
                    ),
                    if (EnvConfig.isDevelopment) ...[
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(
                        'Ambiente: ${EnvConfig.environment.toUpperCase()}',
                        style: const TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        'API URL: ${EnvConfig.apiUrl}',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
} 
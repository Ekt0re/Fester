import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fester/blocs/auth/auth_bloc.dart';
import 'package:reactive_forms/reactive_forms.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final form = FormGroup({
      'email': FormControl<String>(
        validators: [Validators.required, Validators.email],
      ),
      'password': FormControl<String>(
        validators: [Validators.required, Validators.minLength(6)],
      ),
    });

    return Scaffold(
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            // Naviga alla home in caso di autenticazione riuscita
            context.go('/home');
          } else if (state is AuthFailure) {
            // Mostra errore
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo o titolo
                  const Icon(
                    Icons.event,
                    size: 80,
                    color: Colors.deepPurple,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'FESTER',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const Text(
                    'Gestione Eventi',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Form di login
                  ReactiveForm(
                    formGroup: form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
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
                            'required': (error) => 'Email obbligatoria',
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
                            'required': (error) => 'Password obbligatoria',
                            'minLength': (error) =>
                                'La password deve essere di almeno 6 caratteri',
                          },
                        ),
                        const SizedBox(height: 24),
                        BlocBuilder<AuthBloc, AuthState>(
                          builder: (context, state) {
                            return ElevatedButton(
                              onPressed: state is AuthLoading
                                  ? null
                                  : () {
                                      if (form.valid) {
                                        final email = form.control('email').value as String;
                                        final password = form.control('password').value as String;
                                        
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
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: state is AuthLoading
                                  ? const CircularProgressIndicator()
                                  : const Text(
                                      'ACCEDI',
                                      style: TextStyle(fontSize: 16),
                                    ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      context.go('/register');
                    },
                    child: const Text('Non hai un account? Registrati'),
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
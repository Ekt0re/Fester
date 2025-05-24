import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fester/blocs/auth/auth_bloc.dart';
import 'package:reactive_forms/reactive_forms.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final form = FormGroup({
      'nome': FormControl<String>(
        validators: [Validators.required],
      ),
      'cognome': FormControl<String>(
        validators: [Validators.required],
      ),
      'email': FormControl<String>(
        validators: [Validators.required, Validators.email],
      ),
      'password': FormControl<String>(
        validators: [Validators.required, Validators.minLength(6)],
      ),
      'confermaPassword': FormControl<String>(),
    }, validators: [
      Validators.mustMatch('password', 'confermaPassword', 
        error: {'mismatch': true}),
    ]);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrazione'),
      ),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            // Naviga alla home in caso di registrazione riuscita
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
                  // Titolo
                  const Text(
                    'Crea un account',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Form di registrazione
                  ReactiveForm(
                    formGroup: form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: ReactiveTextField<String>(
                                formControlName: 'nome',
                                decoration: const InputDecoration(
                                  labelText: 'Nome',
                                  border: OutlineInputBorder(),
                                ),
                                validationMessages: {
                                  'required': (error) => 'Nome obbligatorio',
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ReactiveTextField<String>(
                                formControlName: 'cognome',
                                decoration: const InputDecoration(
                                  labelText: 'Cognome',
                                  border: OutlineInputBorder(),
                                ),
                                validationMessages: {
                                  'required': (error) => 'Cognome obbligatorio',
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
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
                        const SizedBox(height: 16),
                        ReactiveTextField<String>(
                          formControlName: 'confermaPassword',
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Conferma Password',
                            prefixIcon: Icon(Icons.lock_outline),
                            border: OutlineInputBorder(),
                          ),
                          validationMessages: {
                            'mismatch': (error) => 'Le password non coincidono',
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
                                        final nome = form.control('nome').value as String;
                                        final cognome = form.control('cognome').value as String;
                                        final email = form.control('email').value as String;
                                        final password = form.control('password').value as String;
                                        
                                        context.read<AuthBloc>().add(
                                          AuthRegisterRequested(
                                            nome: nome,
                                            cognome: cognome,
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
                                      'REGISTRATI',
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
                      context.go('/login');
                    },
                    child: const Text('Hai già un account? Accedi'),
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
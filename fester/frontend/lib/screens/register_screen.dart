import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fester_frontend/blocs/auth/auth_bloc.dart';
import 'package:fester_frontend/config/env_config.dart';
import 'package:reactive_forms/reactive_forms.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final form = FormGroup({
    'nome': FormControl<String>(
      value: '',
      validators: [Validators.required],
    ),
    'cognome': FormControl<String>(
      value: '',
      validators: [Validators.required],
    ),
    'email': FormControl<String>(
      value: '',
      validators: [Validators.required, Validators.email],
    ),
    'password': FormControl<String>(
      value: '',
      validators: [Validators.required, Validators.minLength(6)],
    ),
    'conferma_password': FormControl<String>(
      value: '',
      validators: [Validators.required],
    ),
  }, validators: [
      Validators.mustMatch('password', 'conferma_password')
  ]);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrazione'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.deepPurple),
      ),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthRegistrationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.green,
              ),
            );
            // Redirect alla pagina di login dopo 2 secondi
            Future.delayed(const Duration(seconds: 2), () {
              context.go('/login');
            });
          } else if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
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
                    Text(
                      EnvConfig.appName,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Crea un nuovo account',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    ReactiveForm(
                      formGroup: form,
                      child: Column(
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
                                    'required': (error) => 'Il nome è obbligatorio',
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
                                    'required': (error) => 'Il cognome è obbligatorio',
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
                          const SizedBox(height: 16),
                          ReactiveTextField<String>(
                            formControlName: 'conferma_password',
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Conferma Password',
                              prefixIcon: Icon(Icons.lock),
                              border: OutlineInputBorder(),
                            ),
                            validationMessages: {
                              'required': (error) => 'La conferma password è obbligatoria',
                              'mustMatch': (error) => 'Le password non coincidono',
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
                                        final nome = form.control('nome').value.toString();
                                        final cognome = form.control('cognome').value.toString();
                                        final email = form.control('email').value.toString();
                                        final password = form.control('password').value.toString();
                                        
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
                                backgroundColor: Colors.deepPurple,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: state is AuthLoading
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : const Text(
                                      'REGISTRATI',
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
                        const Text('Hai già un account?'),
                        TextButton(
                          onPressed: () {
                            context.go('/login');
                          },
                          child: const Text('Accedi'),
                        ),
                      ],
                    ),
                    if (EnvConfig.isDevelopment) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(
                        'Ambiente: ${EnvConfig.environment.toUpperCase()}',
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
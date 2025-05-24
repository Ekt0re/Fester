import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:reactive_forms/reactive_forms.dart';

class AddGuestScreen extends StatefulWidget {
  final String eventId;

  const AddGuestScreen({Key? key, required this.eventId}) : super(key: key);

  @override
  State<AddGuestScreen> createState() => _AddGuestScreenState();
}

class _AddGuestScreenState extends State<AddGuestScreen> {
  final dio = Dio();
  final secureStorage = const FlutterSecureStorage();
  final String apiBaseUrl = 'http://localhost:5000/api';
  
  bool isLoading = false;
  String? error;
  bool isSuccess = false;
  
  late final FormGroup form;
  
  @override
  void initState() {
    super.initState();
    _setupDioHeaders();
    _initForm();
  }
  
  void _initForm() {
    form = FormGroup({
      'nome': FormControl<String>(
        validators: [Validators.required],
      ),
      'cognome': FormControl<String>(
        validators: [Validators.required],
      ),
      'email': FormControl<String>(
        validators: [Validators.email],
      ),
      'telefono': FormControl<String>(),
      'note': FormControl<String>(),
    });
  }
  
  Future<void> _setupDioHeaders() async {
    final token = await secureStorage.read(key: 'auth_token');
    if (token != null) {
      dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }
  
  Future<void> _submitForm() async {
    if (form.invalid) {
      form.markAllAsTouched();
      return;
    }
    
    setState(() {
      isLoading = true;
      error = null;
    });
    
    try {
      final response = await dio.post(
        '$apiBaseUrl/events/${widget.eventId}/guests',
        data: form.value,
      );
      
      if (!mounted) return;
      
      if (response.statusCode == 201) {
        setState(() {
          isSuccess = true;
          isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ospite aggiunto con successo')),
        );
        
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.of(context).pop(true);
          }
        });
      } else {
        setState(() {
          error = 'Errore durante l\'aggiunta dell\'ospite';
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        error = 'Errore: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aggiungi Ospite'),
      ),
      body: isSuccess
          ? _buildSuccessState()
          : ReactiveForm(
              formGroup: form,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Form fields
                    ReactiveTextField<String>(
                      formControlName: 'nome',
                      decoration: const InputDecoration(
                        labelText: 'Nome *',
                        border: OutlineInputBorder(),
                      ),
                      validationMessages: {
                        'required': (error) => 'Il nome è obbligatorio',
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    ReactiveTextField<String>(
                      formControlName: 'cognome',
                      decoration: const InputDecoration(
                        labelText: 'Cognome *',
                        border: OutlineInputBorder(),
                      ),
                      validationMessages: {
                        'required': (error) => 'Il cognome è obbligatorio',
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    ReactiveTextField<String>(
                      formControlName: 'email',
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validationMessages: {
                        'email': (error) => 'Inserisci un indirizzo email valido',
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    ReactiveTextField<String>(
                      formControlName: 'telefono',
                      decoration: const InputDecoration(
                        labelText: 'Telefono',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    
                    ReactiveTextField<String>(
                      formControlName: 'note',
                      decoration: const InputDecoration(
                        labelText: 'Note',
                        border: OutlineInputBorder(),
                        hintText: 'Informazioni aggiuntive, preferenze, allergie, ecc.',
                      ),
                      minLines: 3,
                      maxLines: 5,
                    ),
                    const SizedBox(height: 24),
                    
                    // Error message
                    if (error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        color: Colors.red.shade100,
                        child: Text(
                          error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    // Submit button
                    ElevatedButton(
                      onPressed: isLoading ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('AGGIUNGI OSPITE'),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Cancel button
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('ANNULLA'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
  
  Widget _buildSuccessState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle,
            color: Colors.green,
            size: 80,
          ),
          SizedBox(height: 24),
          Text(
            'Ospite aggiunto con successo!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Ritorno alla lista ospiti...',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
} 
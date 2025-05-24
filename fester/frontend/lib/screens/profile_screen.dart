import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:reactive_forms/reactive_forms.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final dio = Dio();
  final secureStorage = const FlutterSecureStorage();
  final String apiBaseUrl = 'http://localhost:5000/api';
  
  bool isLoading = true;
  bool isSaving = false;
  String? error;
  
  Map<String, dynamic> userData = {};
  late final FormGroup form;
  
  @override
  void initState() {
    super.initState();
    _setupDioHeaders();
    _fetchUserData();
  }
  
  void _initForm() {
    form = FormGroup({
      'nome': FormControl<String>(
        value: userData['nome'],
        validators: [Validators.required],
      ),
      'cognome': FormControl<String>(
        value: userData['cognome'],
        validators: [Validators.required],
      ),
      'email': FormControl<String>(
        value: userData['email'],
        validators: [Validators.required, Validators.email],
      ),
      'telefono': FormControl<String>(
        value: userData['telefono'],
      ),
    });
  }
  
  Future<void> _setupDioHeaders() async {
    final token = await secureStorage.read(key: 'auth_token');
    if (token != null) {
      dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }
  
  Future<void> _fetchUserData() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    
    try {
      final response = await dio.get(
        '$apiBaseUrl/utenti/profilo',
      );
      
      if (response.statusCode == 200) {
        setState(() {
          userData = response.data['data'];
          isLoading = false;
        });
        _initForm();
      } else {
        setState(() {
          error = 'Errore durante il caricamento del profilo';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Errore: ${e.toString()}';
        isLoading = false;
      });
    }
  }
  
  Future<void> _updateProfile() async {
    if (form.invalid) {
      form.markAllAsTouched();
      return;
    }
    
    setState(() {
      isSaving = true;
      error = null;
    });
    
    try {
      final response = await dio.put(
        '$apiBaseUrl/utenti/profilo',
        data: form.value,
      );
      
      if (response.statusCode == 200) {
        setState(() {
          userData = response.data['data'];
          isSaving = false;
        });
        
        // Mostra un messaggio di successo solo se il widget è ancora montato
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profilo aggiornato con successo')),
          );
        }
      } else {
        setState(() {
          error = 'Errore durante l\'aggiornamento del profilo';
          isSaving = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Errore: ${e.toString()}';
        isSaving = false;
      });
    }
  }
  
  Future<void> _logout() async {
    await secureStorage.delete(key: 'auth_token');
    
    // Redirect to login page
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Il Mio Profilo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? _buildErrorState()
              : ReactiveForm(
                  formGroup: form,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Avatar
                        Center(
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 50,
                                backgroundColor: Colors.blue.shade100,
                                child: Text(
                                  _getInitials(),
                                  style: const TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (!isLoading && userData.isNotEmpty) ...[
                                Text(
                                  '${userData['nome']} ${userData['cognome']}',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  userData['email'] ?? '',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 32),
                        const Divider(),
                        const SizedBox(height: 16),
                        
                        // Form fields
                        const Text(
                          'Informazioni Personali',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        ReactiveTextField<String>(
                          formControlName: 'nome',
                          decoration: const InputDecoration(
                            labelText: 'Nome',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person),
                          ),
                          validationMessages: {
                            'required': (error) => 'Il nome è obbligatorio',
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        ReactiveTextField<String>(
                          formControlName: 'cognome',
                          decoration: const InputDecoration(
                            labelText: 'Cognome',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person),
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
                            prefixIcon: Icon(Icons.email),
                          ),
                          readOnly: true, // L'email non può essere modificata
                          validationMessages: {
                            'required': (error) => 'L\'email è obbligatoria',
                            'email': (error) => 'Inserisci un indirizzo email valido',
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        ReactiveTextField<String>(
                          formControlName: 'telefono',
                          decoration: const InputDecoration(
                            labelText: 'Telefono',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.phone),
                          ),
                          keyboardType: TextInputType.phone,
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
                        
                        // Update button
                        ElevatedButton(
                          onPressed: isSaving ? null : _updateProfile,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: isSaving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('AGGIORNA PROFILO'),
                        ),
                        
                        const SizedBox(height: 32),
                        const Divider(),
                        const SizedBox(height: 16),
                        
                        // Account settings
                        const Text(
                          'Impostazioni Account',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        ListTile(
                          leading: const Icon(Icons.lock),
                          title: const Text('Cambia Password'),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            // Navigate to change password screen
                          },
                        ),
                        
                        ListTile(
                          leading: const Icon(Icons.notifications),
                          title: const Text('Notifiche'),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            // Navigate to notifications settings
                          },
                        ),
                        
                        ListTile(
                          leading: const Icon(Icons.delete, color: Colors.red),
                          title: const Text(
                            'Elimina Account',
                            style: TextStyle(color: Colors.red),
                          ),
                          onTap: () {
                            _showDeleteAccountDialog();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
  
  String _getInitials() {
    if (userData.isEmpty) return '';
    
    final nome = userData['nome'] as String?;
    final cognome = userData['cognome'] as String?;
    
    if (nome != null && nome.isNotEmpty && cognome != null && cognome.isNotEmpty) {
      return '${nome[0]}${cognome[0]}'.toUpperCase();
    } else if (nome != null && nome.isNotEmpty) {
      return nome[0].toUpperCase();
    } else {
      return 'U';
    }
  }
  
  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red.shade300,
            size: 60,
          ),
          const SizedBox(height: 16),
          Text(
            error ?? 'Si è verificato un errore',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchUserData,
            child: const Text('Riprova'),
          ),
        ],
      ),
    );
  }
  
  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conferma eliminazione'),
        content: const Text(
          'Sei sicuro di voler eliminare il tuo account? Questa azione non può essere annullata e tutti i tuoi dati verranno rimossi permanentemente.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('ANNULLA'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Implementare eliminazione account
              // _deleteAccount();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('ELIMINA'),
          ),
        ],
      ),
    );
  }
} 
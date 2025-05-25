import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fester_frontend/blocs/event/event_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';

class AddGuestScreen extends StatefulWidget {
  final String eventId;

  const AddGuestScreen({Key? key, required this.eventId}) : super(key: key);

  @override
  State<AddGuestScreen> createState() => _AddGuestScreenState();
}

class _AddGuestScreenState extends State<AddGuestScreen> {
  bool _isLoading = false;
  bool _isImportMode = false;
  List<Map<String, dynamic>> _importedGuests = [];
  bool _hasImportedData = false;

  late final FormGroup form = FormGroup({
    'nome': FormControl<String>(
      validators: [Validators.required],
    ),
    'cognome': FormControl<String>(
      validators: [Validators.required],
    ),
    'email': FormControl<String>(
      validators: [Validators.required, Validators.email],
    ),
    'role': FormControl<String>(
      value: 'guest',
      validators: [Validators.required],
    ),
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isImportMode ? 'Importa Ospiti' : 'Aggiungi Ospite'),
        actions: [
          IconButton(
            icon: Icon(_isImportMode ? Icons.person_add : Icons.upload_file),
            tooltip: _isImportMode ? 'Aggiungi manualmente' : 'Importa da file',
            onPressed: () {
              setState(() {
                _isImportMode = !_isImportMode;
              });
            },
          ),
        ],
      ),
      body: BlocListener<EventBloc, EventState>(
        listener: (context, state) {
          if (state is EventOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
            // Torna alla lista degli ospiti
            context.pop();
          } else if (state is EventError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
            setState(() {
              _isLoading = false;
            });
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _isImportMode ? _buildImportView() : _buildSingleGuestForm(),
        ),
      ),
    );
  }

  Widget _buildSingleGuestForm() {
    return ReactiveForm(
      formGroup: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Informazioni Ospite',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Nome
          ReactiveTextField<String>(
            formControlName: 'nome',
            decoration: const InputDecoration(
              labelText: 'Nome *',
              prefixIcon: Icon(Icons.person),
              border: OutlineInputBorder(),
            ),
            validationMessages: {
              'required': (error) => 'Il nome è obbligatorio',
            },
          ),
          const SizedBox(height: 16),
          
          // Cognome
          ReactiveTextField<String>(
            formControlName: 'cognome',
            decoration: const InputDecoration(
              labelText: 'Cognome *',
              prefixIcon: Icon(Icons.person),
              border: OutlineInputBorder(),
            ),
            validationMessages: {
              'required': (error) => 'Il cognome è obbligatorio',
            },
          ),
          const SizedBox(height: 16),
          
          // Email
          ReactiveTextField<String>(
            formControlName: 'email',
            decoration: const InputDecoration(
              labelText: 'Email *',
              prefixIcon: Icon(Icons.email),
              border: OutlineInputBorder(),
            ),
            validationMessages: {
              'required': (error) => 'L\'email è obbligatoria',
              'email': (error) => 'Inserisci un indirizzo email valido',
            },
          ),
          const SizedBox(height: 16),
          
          // Ruolo
          ReactiveDropdownField<String>(
            formControlName: 'role',
            decoration: const InputDecoration(
              labelText: 'Ruolo *',
              prefixIcon: Icon(Icons.badge),
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'guest',
                child: Text('Ospite'),
              ),
              DropdownMenuItem(
                value: 'staff',
                child: Text('Staff'),
              ),
              DropdownMenuItem(
                value: 'organizer',
                child: Text('Organizzatore'),
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          // Pulsante aggiungi
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _addSingleGuest,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('AGGIUNGI OSPITE'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Importa Ospiti da CSV',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Seleziona un file CSV con le seguenti colonne: nome, cognome, email, ruolo (opzionale)',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 24),
        
        if (!_hasImportedData)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.upload_file,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _pickCsvFile,
                  icon: const Icon(Icons.file_upload),
                  label: const Text('SELEZIONA FILE CSV'),
                ),
              ],
            ),
          )
        else
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Ospiti trovati: ${_importedGuests.length}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _importedGuests = [];
                          _hasImportedData = false;
                        });
                      },
                      icon: const Icon(Icons.clear),
                      label: const Text('ANNULLA'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                // Lista ospiti importati
                Expanded(
                  child: ListView.builder(
                    itemCount: _importedGuests.length,
                    itemBuilder: (context, index) {
                      final guest = _importedGuests[index];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              guest['nome'].substring(0, 1).toUpperCase(),
                            ),
                          ),
                          title: Text('${guest['nome']} ${guest['cognome']}'),
                          subtitle: Text(guest['email']),
                          trailing: Text(
                            _translateRole(guest['role']),
                            style: TextStyle(
                              color: _getRoleColor(guest['role']),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Pulsante importa
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _importGuests,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : const Text('IMPORTA TUTTI GLI OSPITI'),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _addSingleGuest() {
    if (form.valid) {
      setState(() {
        _isLoading = true;
      });
      
      final guestData = {
        'nome': form.control('nome').value,
        'cognome': form.control('cognome').value,
        'email': form.control('email').value,
        'role': form.control('role').value,
        'auth_user_id': null, // Sarà generato automaticamente
      };
      
      context.read<EventBloc>().add(
        AddGuestRequested(
          eventId: widget.eventId,
          guestData: guestData,
        ),
      );
    } else {
      form.markAllAsTouched();
    }
  }

  Future<void> _pickCsvFile() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      
      if (result != null) {
        final file = File(result.files.single.path!);
        final content = await file.readAsString();
        
        final csv = const CsvToListConverter().convert(content);
        
        if (csv.isNotEmpty) {
          final List<Map<String, dynamic>> guests = [];
          
          // Assume prima riga come intestazione
          for (int i = 1; i < csv.length; i++) {
            final row = csv[i];
            if (row.length >= 3) {
              guests.add({
                'nome': row[0],
                'cognome': row[1],
                'email': row[2],
                'role': row.length > 3 ? row[3] : 'guest',
              });
            }
          }
          
          setState(() {
            _importedGuests = guests;
            _hasImportedData = true;
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore durante l\'importazione: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _importGuests() {
    if (_importedGuests.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nessun ospite da importare'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    context.read<EventBloc>().add(
      ImportGuestsRequested(
        eventId: widget.eventId,
        guestsData: _importedGuests,
      ),
    );
  }

  String _translateRole(String role) {
    switch (role) {
      case 'guest':
        return 'Ospite';
      case 'staff':
        return 'Staff';
      case 'organizer':
        return 'Organizzatore';
      default:
        return 'Ospite';
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'guest':
        return Colors.blue;
      case 'staff':
        return Colors.green;
      case 'organizer':
        return Colors.purple;
      default:
        return Colors.blue;
    }
  }
} 
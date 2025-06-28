import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/supabase_service.dart';
import '../utils/app_colors.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/custom_button.dart';
import '../models/event.dart';
import '../models/user.dart' as local;
import '../services/local_database_service.dart';
import '../providers/auth_provider.dart';

class RegisterAsHostButton extends ConsumerStatefulWidget {
  const RegisterAsHostButton({super.key});

  @override
  ConsumerState<RegisterAsHostButton> createState() => _RegisterAsHostButtonState();
}

class _RegisterAsHostButtonState extends ConsumerState<RegisterAsHostButton> {
  final TextEditingController _eventNameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  bool _isLoading = false;

  @override
  void dispose() {
    _eventNameController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDate),
    );
    
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  void _showCreateEventDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.event_available, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              'Crea Nuovo Evento',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Nome evento
                  CustomTextField(
                    controller: _eventNameController,
                    label: 'Nome Evento',
                    icon: Icons.celebration,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Inserisci il nome dell\'evento';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Luogo
                  CustomTextField(
                    controller: _locationController,
                    label: 'Luogo',
                    icon: Icons.location_on,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Inserisci il luogo dell\'evento';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Descrizione
                  CustomTextField(
                    controller: _descriptionController,
                    label: 'Descrizione (opzionale)',
                    icon: Icons.description,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  
                  // Selettore data
                  Card(
                    color: AppColors.surface,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.calendar_today, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Data e Ora Evento',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextButton.icon(
                                  onPressed: _selectDate,
                                  icon: const Icon(Icons.calendar_month),
                                  label: Text(
                                    '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                                  ),
                                ),
                              ),
                              Expanded(
                                child: TextButton.icon(
                                  onPressed: _selectTime,
                                  icon: const Icon(Icons.access_time),
                                  label: Text(
                                    '${_selectedDate.hour.toString().padLeft(2, '0')}:${_selectedDate.minute.toString().padLeft(2, '0')}',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
            child: const Text('Annulla'),
          ),
          CustomButton(
            text: 'CREA EVENTO',
            onPressed: _isLoading ? null : _createEventAndRegisterHost,
            isLoading: _isLoading,
          ),
        ],
      ),
    );
  }

  Future<void> _createEventAndRegisterHost() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authState = ref.read(authProvider);
      final currentUser = authState.user;

      if (currentUser == null) {
        _showErrorMessage('Devi essere autenticato per creare un evento');
        return;
      }

      final supabase = SupabaseConfig.client;
      final supabaseUser = supabase.auth.currentUser;

      if (supabaseUser == null) {
        _showErrorMessage('Sessione Supabase non valida');
        return;
      }

      // Step 1: Crea il nuovo evento con il modello aggiornato
      final newEvent = Event(
        name: _eventNameController.text.trim(),
        date: _selectedDate,
        location: _locationController.text.trim(),
        description: _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
        hostId: supabaseUser.id,
        maxGuests: 50,
        status: 'active',
      );

      // Step 2: Inserisci in Supabase usando toSupabaseJson
      final eventResponse = await supabase
          .from('events')
          .insert(newEvent.toSupabaseJson())
          .select()
          .single();

      // Step 3: Crea l'evento locale con l'ID da Supabase
      final eventWithId = Event(
        id: eventResponse['id'].toString(),
        name: newEvent.name,
        date: newEvent.date,
        location: newEvent.location,
        description: newEvent.description,
        hostId: newEvent.hostId,
        maxGuests: newEvent.maxGuests,
        status: newEvent.status,
      );

      // Step 4: Salva l'evento localmente
      await LocalDatabaseService.openEventBox();
      final eventBox = await LocalDatabaseService.openEventBox();
      await eventBox.put(eventWithId.id, eventWithId);

      // Step 5: Aggiorna il profilo utente in Supabase
      await supabase
          .from('profiles')
          .update({'role': 'host', 'event_id': eventWithId.id})
          .eq('id', supabaseUser.id);
      
      // Step 6: Aggiorna l'utente locale con il nuovo eventId e ruolo
      final localUserWithEventId = local.User(
        id: currentUser.id,
        username: currentUser.username,
        passwordHash: currentUser.passwordHash,
        role: local.UserRole.host,
        eventId: eventWithId.id,
      );
      
      await LocalDatabaseService.saveCurrentUser(localUserWithEventId);
      ref.read(authProvider.notifier).reloadUserFromStorage(); // Ricarica utente nello stato
      
      // Chiudi il popup
      if (!mounted) return;
      Navigator.of(context).pop();

      // Mostra conferma
      _showSuccessMessage('Evento creato e ruolo Host assegnato!');

      // Clear controllers
      _clearControllers();

    } catch (error) {
      _showErrorMessage('Errore nella creazione dell\'evento: $error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _showErrorMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _clearControllers() {
    _eventNameController.clear();
    _locationController.clear();
    _descriptionController.clear();
    setState(() {
      _selectedDate = DateTime.now().add(const Duration(days: 1));
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    
    return CustomButton(
      text: 'REGISTRATI COME HOST',
      icon: Icons.star,
      backgroundColor: AppColors.primary,
      onPressed: authState.isAuthenticated ? _showCreateEventDialog : _showLoginPrompt,
    );
  }

  void _showLoginPrompt() {
    Navigator.of(context).pushNamed('/host-login');
  }
} 
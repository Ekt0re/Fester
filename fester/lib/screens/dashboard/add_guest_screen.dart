import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../profile/widgets/transaction_list_sheet.dart';
import '../../services/SupabaseServicies/person_service.dart';
import '../../services/SupabaseServicies/participation_service.dart';
import '../../theme/app_theme.dart';

class AddGuestScreen extends StatefulWidget {
  final String eventId;
  final String? personId;
  final Map<String, dynamic>? initialData;

  const AddGuestScreen({
    super.key,
    required this.eventId,
    this.personId,
    this.initialData,
  });

  @override
  State<AddGuestScreen> createState() => _AddGuestScreenState();
}

class _AddGuestScreenState extends State<AddGuestScreen> {
  final _formKey = GlobalKey<FormState>();
  final PersonService _personService = PersonService();
  final ParticipationService _participationService = ParticipationService();
  
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  
  DateTime? _dateOfBirth;
  int _selectedRoleId = 2; // Default fallback
  int _selectedStatusId = 1; // Default fallback
  bool _isLoading = true;
  
  List<Map<String, dynamic>> _roles = [];
  List<Map<String, dynamic>> _statuses = [];

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;
    _firstNameController = TextEditingController(text: data?['first_name']);
    _lastNameController = TextEditingController(text: data?['last_name']);
    _emailController = TextEditingController(text: data?['email']);
    _phoneController = TextEditingController(text: data?['phone']);
    
    if (data?['date_of_birth'] != null) {
      _dateOfBirth = DateTime.tryParse(data!['date_of_birth']);
    }
    
    _loadFormData();
  }

  Future<void> _loadFormData() async {
    try {
      final roles = await _participationService.getRoles();
      final statuses = await _participationService.getParticipationStatuses();
      
      if (mounted) {
        setState(() {
          _roles = roles;
          _statuses = statuses;
          
          // Set initial values from data or defaults
          final initialRoleId = widget.initialData?['role_id'];
          final initialStatusId = widget.initialData?['status_id'];

          // Verify if initial values exist in fetched lists, otherwise use defaults or first available
          if (initialRoleId != null && _roles.any((r) => r['id'] == initialRoleId)) {
            _selectedRoleId = initialRoleId;
          } else if (_roles.isNotEmpty) {
             // If default 2 is not in list, pick first
             if (!_roles.any((r) => r['id'] == _selectedRoleId)) {
               _selectedRoleId = _roles.first['id'];
             }
          }

          if (initialStatusId != null && _statuses.any((s) => s['id'] == initialStatusId)) {
            _selectedStatusId = initialStatusId;
          } else if (_statuses.isNotEmpty) {
             if (!_statuses.any((s) => s['id'] == _selectedStatusId)) {
               _selectedStatusId = _statuses.first['id'];
             }
          }
          
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore caricamento dati: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<String> _generateNextIdEvent() async {
    try {
      final participations = await _participationService.getEventParticipations(widget.eventId);
      int maxId = 0;
      for (var participation in participations) {
        final person = participation['person'];
        if (person != null && person['id_event'] != null) {
          final idEvent = person['id_event'].toString();
          final numId = int.tryParse(idEvent);
          if (numId != null && numId > maxId) {
            maxId = numId;
          }
        }
      }
      return (maxId + 1).toString();
    } catch (e) {
      return '1';
    }
  }

  Future<void> _saveGuest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (widget.personId != null) {
        // Update existing person
        await _personService.updatePerson(
          personId: widget.personId!,
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
          phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          dateOfBirth: _dateOfBirth,
        );
        
        // Update Participation (Role & Status)
        final participationId = widget.initialData?['participation_id'];
        if (participationId != null) {
           await _participationService.updateParticipation(
             participationId: participationId,
             roleId: _selectedRoleId,
             statusId: _selectedStatusId,
           );
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ospite aggiornato con successo!')),
          );
          Navigator.pop(context, true);
        }
      } else {
        // Create new person
        final idEvent = await _generateNextIdEvent();

        final person = await _personService.createPerson(
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
          phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          dateOfBirth: _dateOfBirth,
          idEvent: idEvent,
        );

        await _participationService.createParticipation(
          personId: person['id'],
          eventId: widget.eventId,
          statusId: _selectedStatusId,
          roleId: _selectedRoleId,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ospite aggiunto con successo!')),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore durante il salvataggio: $e')),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: AppTheme.primaryLight,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _dateOfBirth) {
      setState(() {
        _dateOfBirth = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.primary,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: theme.colorScheme.onPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.personId != null ? 'Modifica Ospite' : 'Aggiungi Ospite',
          style: GoogleFonts.outfit(
            color: theme.colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // First Name
                    _buildTextField(
                      controller: _firstNameController,
                      label: 'Nome',
                      hint: 'Inserisci il nome',
                      icon: Icons.person_outline,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Il nome è obbligatorio';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Last Name
                    _buildTextField(
                      controller: _lastNameController,
                      label: 'Cognome',
                      hint: 'Inserisci il cognome',
                      icon: Icons.person,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Il cognome è obbligatorio';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Email
                    _buildTextField(
                      controller: _emailController,
                      label: 'Email (opzionale)',
                      hint: 'esempio@email.com',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                          if (!emailRegex.hasMatch(value)) {
                            return 'Email non valida';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Phone
                    _buildTextField(
                      controller: _phoneController,
                      label: 'Telefono (opzionale)',
                      hint: '+39 123 456 7890',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),

                    // Date of Birth
                    InkWell(
                      onTap: _selectDate,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.outline.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.cake_outlined,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _dateOfBirth == null
                                    ? 'Data di nascita (opzionale)'
                                    : '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}',
                                style: GoogleFonts.outfit(
                                  color: _dateOfBirth == null
                                      ? theme.colorScheme.onSurface.withOpacity(0.5)
                                      : theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                            if (_dateOfBirth != null)
                              IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () => setState(() => _dateOfBirth = null),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Role Dropdown
                    if (_roles.isNotEmpty)
                      _buildDropdown(
                        label: 'Ruolo',
                        value: _selectedRoleId,
                        icon: Icons.star_outline,
                        items: _roles,
                        onChanged: (value) {
                          setState(() => _selectedRoleId = value!);
                        },
                      ),
                    const SizedBox(height: 16),

                    // Status Dropdown
                    if (_statuses.isNotEmpty)
                      _buildDropdown(
                        label: 'Stato',
                        value: _selectedStatusId,
                        icon: Icons.pending_outlined,
                        items: _statuses,
                        onChanged: (value) {
                          setState(() => _selectedStatusId = value!);
                        },
                      ),
                    // Transaction Management Button (Only if editing)
                    if (widget.personId != null) ...[
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () {
                          // We need to fetch transactions first or pass them.
                          // Since we don't have them here, we'll open the sheet and let it handle it?
                          // But TransactionListSheet expects a list.
                          // We should probably fetch them here or modify TransactionListSheet.
                          // Given the constraint, let's fetch them quickly or just pass empty and let it load?
                          // Actually, the user wants to open it "con già spuntata la checkbox 'mostra tutto'".
                          // We can pass a flag to TransactionListSheet to fetch data if empty?
                          // Or better, fetch here.
                          _openTransactionList();
                        },
                        icon: Icon(Icons.receipt_long, color: theme.colorScheme.primary),
                        label: Text(
                          'Gestisci Transazioni',
                          style: GoogleFonts.outfit(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: theme.colorScheme.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 32),

                    // Save Button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveGuest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Salva Ospite',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  void _openTransactionList() async {
    // Fetch transactions
    setState(() => _isLoading = true);
    try {
      final participationId = widget.initialData?['participation_id'];
      if (participationId != null) {
        final transactions = await _personService.getPersonTransactions(participationId);
        if (mounted) {
           setState(() => _isLoading = false);
           showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => TransactionListSheet(
              transactions: transactions,
              canEdit: true, // Always true here as it's admin/staff area
              onTransactionUpdated: () {
                // Refresh transactions if needed, but we might just close
                // Or refresh the list locally if we keep it open
                // For now, just refresh the list
                _openTransactionList(); 
              },
            ),
          );
        }
      } else {
         setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore caricamento transazioni: $e')),
        );
      }
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    final theme = Theme.of(context);

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: theme.colorScheme.primary),
        filled: true,
        fillColor: theme.colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.colorScheme.primary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
      ),
      style: GoogleFonts.outfit(),
    );
  }

  Widget _buildDropdown({
    required String label,
    required int value,
    required IconData icon,
    required List<Map<String, dynamic>> items,
    required void Function(int?) onChanged,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: value,
                    isExpanded: true,
                    items: items.map((item) {
                      return DropdownMenuItem<int>(
                        value: item['id'] as int,
                        child: Text(
                          item['name'] as String,
                          style: GoogleFonts.outfit(),
                        ),
                      );
                    }).toList(),
                    onChanged: onChanged,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

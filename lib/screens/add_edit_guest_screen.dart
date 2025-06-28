import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/guest.dart';
import '../providers/guest_provider.dart';
import '../utils/app_colors.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/custom_button.dart';
import '../providers/auth_provider.dart';

class AddEditGuestScreen extends ConsumerStatefulWidget {
  final Guest? guest; // null = aggiungi, non-null = modifica
  
  const AddEditGuestScreen({
    super.key,
    this.guest,
  });

  @override
  ConsumerState<AddEditGuestScreen> createState() => _AddEditGuestScreenState();
}

class _AddEditGuestScreenState extends ConsumerState<AddEditGuestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _codeController = TextEditingController();
  final _qrCodeController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _eventIdController = TextEditingController();
  final _invitedByController = TextEditingController(); // usato solo per dropdown display
  String? _selectedInvitedByGuestId;
  
  GuestStatus _selectedStatus = GuestStatus.notArrived;
  int _drinksCount = 0;
  List<String> _flags = [];
  bool _isLoading = false;
  
  // Flag disponibili per gli ospiti
  final List<String> _availableFlags = [
    'VIP',
    'Staff',
    'Fotografo',
    'Security',
    'Catering',
    'DJ/Music',
    'Sponsor',
    'Media',
    'Famiglia',
    'Amico',
    'Lavoro',
    'Università',
  ];

  @override
  void initState() {
    super.initState();
    
    if (widget.guest != null) {
      // Modalità modifica - precompila i campi
      _nameController.text = widget.guest!.name;
      _surnameController.text = widget.guest!.surname;
      _codeController.text = widget.guest!.code;
      _qrCodeController.text = widget.guest!.qrCode;
      _barcodeController.text = widget.guest!.barcode;
      _eventIdController.text = widget.guest!.eventId;
      _selectedStatus = widget.guest!.status;
      _drinksCount = widget.guest!.drinksCount;
      _flags = List.from(widget.guest!.flags);
      _selectedInvitedByGuestId = widget.guest!.invitedBy;
    } else {
      // Modalità aggiungi - valori di default basati sull'utente corrente
      final authState = ref.read(authProvider);
      _eventIdController.text = authState.user?.eventId ?? '1';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _codeController.dispose();
    _qrCodeController.dispose();
    _barcodeController.dispose();
    _eventIdController.dispose();
    _invitedByController.dispose();
    super.dispose();
  }

  Future<void> _saveGuest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final guestData = Guest(
        id: widget.guest?.id,
        name: _nameController.text.trim(),
        surname: _surnameController.text.trim(),
        code: _codeController.text.trim(),
        qrCode: _qrCodeController.text.trim(),
        barcode: _barcodeController.text.trim(),
        status: _selectedStatus,
        drinksCount: _drinksCount,
        flags: _flags,
        invitedBy: _selectedInvitedByGuestId,
        eventId: _eventIdController.text.trim(),
        lastUpdated: DateTime.now(),
      );

      if (widget.guest == null) {
        // Aggiungi nuovo ospite
        await ref.read(guestProvider.notifier).addGuest(guestData);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Ospite ${guestData.name} ${guestData.surname} aggiunto!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        // Modifica ospite esistente
        await ref.read(guestProvider.notifier).updateGuest(guestData);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Ospite ${guestData.name} ${guestData.surname} modificato!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }

      if (mounted) {
        Navigator.of(context).pop(true); // Ritorna true per indicare successo
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Errore: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _incrementDrinks() async {
    // Controlla se mostrare avvisi prima di incrementare
    final shouldShowWarning = _drinksCount >= 2 || _flags.isNotEmpty; // Mostra warning a partire da 3 drink
    
    if (shouldShowWarning) {
      final confirmed = await _showDrinkConfirmation();
      if (!confirmed) return; // Annullato dall'utente
    }
    
    // Incrementa il contatore
    setState(() => _drinksCount++);
    
    if (mounted) {
      // Mostra messaggio di successo
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Drink incrementato a $_drinksCount'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<bool> _showDrinkConfirmation() async {
    final warnings = <String>[];
    final guestName = _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : 'Ospite';
    
    // Controlla numero bevande (avviso a partire da 3 drink)
    if (_drinksCount >= 2) {
      warnings.add('⚠️ Avrà consumato ${_drinksCount + 1} bevande');
    }
    
    // Controlla flags/segnalazioni
    if (_flags.isNotEmpty) {
      warnings.add('🚩 Tag/Categorie attive:');
      for (final flag in _flags) {
        warnings.add('   • $flag');
      }
    }
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Conferma Incremento'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vuoi incrementare il contatore drink per $guestName?',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...warnings.map((warning) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                warning,
                style: TextStyle(
                  color: warning.startsWith('🚩') || warning.startsWith('   •') 
                      ? AppColors.error 
                      : Colors.orange,
                ),
              ),
            )),
            if (warnings.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withAlpha(100)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Verifica che sia appropriato incrementare il contatore',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Conferma'),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.guest != null;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Modifica Ospite' : 'Aggiungi Ospite'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header informativo
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha((0.1 * 255).toInt()),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withAlpha((0.3 * 255).toInt())),
                ),
                child: Row(
                  children: [
                    Icon(
                      isEditing ? Icons.edit : Icons.person_add,
                      color: AppColors.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing ? 'Modifica dati ospite' : 'Nuovo ospite',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          Text(
                            isEditing 
                                ? 'Aggiorna le informazioni dell\'ospite esistente'
                                : 'Compila tutti i campi per aggiungere un nuovo ospite',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),

              // Dati personali
              Text(
                '👤 Dati Personali',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),

              CustomTextField(
                controller: _nameController,
                label: 'Nome *',
                icon: Icons.person,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Il nome è obbligatorio';
                  }
                  if (value.trim().length < 2) {
                    return 'Il nome deve essere di almeno 2 caratteri';
                  }
                  return null;
                },
                onChanged: (value) {},
              ),
              
              const SizedBox(height: 16),

              CustomTextField(
                controller: _surnameController,
                label: 'Cognome *',
                icon: Icons.person_outline,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Il cognome è obbligatorio';
                  }
                  if (value.trim().length < 2) {
                    return 'Il cognome deve essere di almeno 2 caratteri';
                  }
                  return null;
                },
                onChanged: (value) {},
              ),

              const SizedBox(height: 24),

              // Codici identificativi
              Text(
                '🔍 Codici Identificativi',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),

              CustomTextField(
                controller: _codeController,
                label: 'Codice Ospite *',
                icon: Icons.qr_code,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Il codice ospite è obbligatorio';
                  }
                  return null;
                },
                onChanged: (value) {},
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: _qrCodeController,
                      label: 'QR Code',
                      icon: Icons.qr_code_scanner,
                      onChanged: (value) {},
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomTextField(
                      controller: _barcodeController,
                      label: 'Barcode',
                      icon: Icons.barcode_reader,
                      onChanged: (value) {},
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Status e contatori
              Text(
                '📊 Status e Contatori',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),

              // Status dropdown
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.inputBorder),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonFormField<GuestStatus>(
                  value: _selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'Status Ospite',
                    prefixIcon: Icon(Icons.flag),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  items: GuestStatus.values.map((status) => DropdownMenuItem(
                    value: status,
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: status == GuestStatus.arrived 
                                ? AppColors.success
                                : status == GuestStatus.left
                                    ? AppColors.warning
                                    : AppColors.textSecondary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(_getStatusText(status)),
                      ],
                    ),
                  )).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedStatus = value);
                    }
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Drinks counter
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.inputBorder),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.local_drink),
                        const SizedBox(width: 12),
                        const Text('Drink Consumati:'),
                        const Spacer(),
                        if (_drinksCount >= 3) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.withAlpha(25),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orange.withAlpha(100)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.warning, color: Colors.orange, size: 16),
                                SizedBox(width: 4),
                                Text(
                                  'Limite consigliato',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        IconButton(
                          onPressed: _drinksCount > 0 
                              ? () => setState(() => _drinksCount--)
                              : null,
                          icon: const Icon(Icons.remove_circle),
                          color: AppColors.error,
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: _drinksCount >= 3 
                                ? Colors.orange.withAlpha(25)
                                : AppColors.background,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _drinksCount >= 3 
                                  ? Colors.orange.withAlpha(100)
                                  : AppColors.inputBorder,
                            ),
                          ),
                          child: Text(
                            '$_drinksCount',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: _drinksCount >= 3 ? Colors.orange : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          onPressed: _incrementDrinks,
                          icon: const Icon(Icons.add_circle),
                          color: AppColors.success,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Flags
              Text(
                '🏷️ Tag / Categorie',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableFlags.map((flag) {
                  final isSelected = _flags.contains(flag);
                  return FilterChip(
                    label: Text(flag),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _flags.add(flag);
                        } else {
                          _flags.remove(flag);
                        }
                      });
                    },
                    selectedColor: AppColors.primary.withAlpha((0.2 * 255).toInt()),
                    checkmarkColor: AppColors.primary,
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // Informazioni evento
              Text(
                '🎉 Informazioni Evento',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _buildInvitedByDropdown(ref),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomTextField(
                      controller: _eventIdController,
                      label: 'ID Evento',
                      icon: Icons.event,
                      enabled: false, // Non modificabile
                      onChanged: (value) {},
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Pulsanti azione
              Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      text: 'Annulla',
                      onPressed: () => Navigator.of(context).pop(),
                      isOutlined: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: CustomButton(
                      text: isEditing ? 'Salva Modifiche' : 'Aggiungi Ospite',
                      onPressed: _saveGuest,
                      isLoading: _isLoading,
                      icon: isEditing ? Icons.save : Icons.person_add,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  String _getStatusText(GuestStatus status) {
    switch (status) {
      case GuestStatus.notArrived:
        return 'Non Arrivato';
      case GuestStatus.arrived:
        return 'Arrivato';
      case GuestStatus.left:
        return 'Partito';
    }
  }

  Widget _buildInvitedByDropdown(WidgetRef ref) {
    final guests = ref.watch(guestProvider).guests;
    final items = [
      const DropdownMenuItem<String>(
        value: null,
        child: Text('Nessuno'),
      ),
      ...guests.map((g) => DropdownMenuItem<String>(
            value: g.id,
            child: Text('${g.name} ${g.surname} (${g.code})'),
          ))
    ];

    return DropdownButtonFormField<String?>(
      value: _selectedInvitedByGuestId,
      decoration: const InputDecoration(
        labelText: 'Invitato da',
        prefixIcon: Icon(Icons.person_add),
      ),
      items: items,
      onChanged: (value) {
        setState(() => _selectedInvitedByGuestId = value);
      },
    );
  }
} 
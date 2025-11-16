// lib/screens/create_event/create_event_flow.dart
import 'package:fester/screens/create_event/staff_management_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import '../../services/SupabaseServicies/event_service.dart';
import 'create_menu_screen.dart';
import '../event_selection_screen.dart';

class CreateEventFlow extends StatefulWidget {
  const CreateEventFlow({Key? key}) : super(key: key);

  @override
  State<CreateEventFlow> createState() => _CreateEventFlowState();
}

class _CreateEventFlowState extends State<CreateEventFlow> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  List<StaffMember> _staffMembers = [];

  // Dati raccolti attraverso il flusso
  String? _eventName;
  String? _eventDescription;
  DateTime? _startDate;
  TimeOfDay? _startTime;
  DateTime? _endDate;
  TimeOfDay? _endTime;
  String? _location;
  int? _maxParticipants;
  int? _ageRestriction;
  int? _maxDrinksPerPerson;

  bool _menuCreated = false;
  String?
  _createdEventId; // Salva l'ID evento dopo la creazione per ricaricare il menu

  // Dati menù salvati in memoria (prima della creazione evento)
  String? _menuName;
  String? _menuDescription;
  List<Map<String, dynamic>>? _menuItemsData;

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _createEvent() async {
    if (_eventName == null || _startDate == null || _startTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Compila i campi obbligatori')),
      );
      return;
    }

    try {
      final eventService = EventService();

      // 1. Crea l'evento
      final event = await eventService.createEvent(
        name: _eventName!,
        description: _eventDescription,
      );

      setState(() {
        _createdEventId = event.id; // Salva l'ID per ricaricare il menu
      });

      // 2. Combina data e ora
      final startDateTime = DateTime(
        _startDate!.year,
        _startDate!.month,
        _startDate!.day,
        _startTime!.hour,
        _startTime!.minute,
      );

      DateTime? endDateTime;
      if (_endDate != null && _endTime != null) {
        endDateTime = DateTime(
          _endDate!.year,
          _endDate!.month,
          _endDate!.day,
          _endTime!.hour,
          _endTime!.minute,
        );
      }

      // 3. Crea le impostazioni dell'evento
      await eventService.upsertEventSettings(
        eventId: event.id,
        startAt: startDateTime,
        endAt: endDateTime,
        location: _location,
        maxParticipants: _maxParticipants,
        ageRestriction: _ageRestriction,
        defaultMaxDrinksPerPerson: _maxDrinksPerPerson,
        allowGuests: true,
        lateEntryAllowed: true,
        idCheckRequired: _ageRestriction != null && _ageRestriction! > 0,
      );

      // 4. Crea e associa il menu all'evento (personalizzato o vuoto)
      try {
        final supabase = Supabase.instance.client;
        final userId = supabase.auth.currentUser?.id;
        if (userId != null) {
          String menuName;
          String? menuDescription;

          if (_menuCreated && _menuName != null) {
            // Menu personalizzato (già creato in memoria)
            menuName = _menuName!;
            menuDescription = _menuDescription;
          } else {
            // Menu vuoto di default
            menuName = 'Menu di $_eventName';
            menuDescription = 'Menu principale per $_eventName';
          }

          // Crea il menu associato all'evento
          final menuResponse =
              await supabase
                  .from('menu')
                  .insert({
                    'event_id': event.id,
                    'name': menuName,
                    'description': menuDescription,
                    'created_by': userId,
                  })
                  .select()
                  .single();

          final menuId = menuResponse['id'] as String;

          // Se c'è un menu personalizzato, inserisci i menu items
          if (_menuCreated &&
              _menuItemsData != null &&
              _menuItemsData!.isNotEmpty) {
            final itemsToInsert =
                _menuItemsData!.map((item) {
                  return {
                    'menu_id': menuId,
                    'transaction_type_id': item['transaction_type_id'] as int,
                    'name': item['name'] as String,
                    'description': item['description'] as String?,
                    'price': item['price'] as double,
                    'is_available': true,
                    'sort_order': _menuItemsData!.indexOf(item),
                    'available_quantity': item['available_quantity'] as int?,
                  };
                }).toList();

            if (itemsToInsert.isNotEmpty) {
              await supabase.from('menu_item').insert(itemsToInsert);
            }
          }
        }
      } catch (e) {
        // Log errore ma non bloccare la creazione evento
        debugPrint('Errore creazione menu: $e');
      }

        //Creazione Staff x Evento
      for (final member in _staffMembers) {
        try {
          // First, get or create the user by email
          final userResponse = await Supabase.instance.client
            .from('profiles')
            .select('id')
            .eq('email', member.email)
            .maybeSingle();

          if (userResponse == null) {
            // If user doesn't exist, you might want to create them or skip
            debugPrint('User with email ${member.email} not found');
            continue;
          }

          await Supabase.instance.client.from('event_staff').upsert({
            'event_id': event.id,
            'user_id': userResponse['id'],
            'role': member.role,
            'assigned_by': Supabase.instance.client.auth.currentUser?.id,
          });
        } catch (e) {
          debugPrint('Error assigning staff ${member.email}: $e');
          // Continue with the next staff member even if one fails
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Evento creato con successo!')),
        );
        // Torna alla schermata di selezione eventi e ricarica
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const EventSelectionScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFB8D4E8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFB8D4E8),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'FESTER 3.0',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Progress indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
            child: Row(
              children: List.generate(
                4,
                (index) => Expanded(
                  child: Container(
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color:
                          index <= _currentPage
                              ? Colors.black87
                              : Colors.black26,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ),

          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (page) => setState(() => _currentPage = page),
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _Step1BasicInfo(
                  eventName: _eventName,
                  description: _eventDescription,
                  onNameChanged: (val) => setState(() => _eventName = val),
                  onDescriptionChanged:
                      (val) => setState(() => _eventDescription = val),
                  onNext: _nextPage,
                ),
                _Step2DateTime(
                  startDate: _startDate,
                  startTime: _startTime,
                  endDate: _endDate,
                  endTime: _endTime,
                  location: _location,
                  maxParticipants: _maxParticipants,
                  onStartDateChanged: (val) => setState(() => _startDate = val),
                  onStartTimeChanged: (val) => setState(() => _startTime = val),
                  onEndDateChanged: (val) => setState(() => _endDate = val),
                  onEndTimeChanged: (val) => setState(() => _endTime = val),
                  onLocationChanged: (val) => setState(() => _location = val),
                  onMaxParticipantsChanged:
                      (val) => setState(() => _maxParticipants = val),
                  onNext: _nextPage,
                  onBack: _previousPage,
                ),
                _Step3Staff(
                  eventId: _createdEventId ?? '',
                  initialStaff: _staffMembers,
                  onStaffUpdated: (staff) => setState(() => _staffMembers = staff),
                  onNext: _nextPage,
                  onBack: _previousPage,
                ),
                _Step4Settings(
                  eventId: _createdEventId,
                  menuCreated: _menuCreated,
                  ageRestriction: _ageRestriction,
                  maxDrinksPerPerson: _maxDrinksPerPerson,
                  onAgeRestrictionChanged:
                      (val) => setState(() => _ageRestriction = val),
                  onMaxDrinksChanged:
                      (val) => setState(() => _maxDrinksPerPerson = val),
                  onMenuCreated: (menuName, menuDescription, menuItems) {
                    setState(() {
                      _menuCreated = true;
                      _menuName = menuName;
                      _menuDescription = menuDescription;
                      _menuItemsData = menuItems;
                    });
                  },
                  onComplete: _createEvent,
                  onBack: _previousPage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// STEP 1: Informazioni base
class _Step1BasicInfo extends StatelessWidget {
  final String? eventName;
  final String? description;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onDescriptionChanged;
  final VoidCallback onNext;

  const _Step1BasicInfo({
    required this.eventName,
    required this.description,
    required this.onNameChanged,
    required this.onDescriptionChanged,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'ORGANIZZA LA TUA FESTA!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'CREA LA TUA FESTA!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),

          _InputField(
            label: 'NOME EVENTO',
            hint: 'Es: Festa di Capodanno 2025',
            initialValue: eventName,
            onChanged: onNameChanged,
          ),
          const SizedBox(height: 16),

          _InputField(
            label: 'Descrizione',
            hint: 'Descrivi il tuo evento...',
            initialValue: description,
            onChanged: onDescriptionChanged,
            maxLines: 4,
          ),
          const SizedBox(height: 32),

          ElevatedButton(
            onPressed:
                eventName != null && eventName!.isNotEmpty ? onNext : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.black87,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Avanti', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 120),

          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Indietro',
              style: TextStyle(color: Colors.black54, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}

// STEP 2: Data, ora e dettagli
class _Step2DateTime extends StatelessWidget {
  final DateTime? startDate;
  final TimeOfDay? startTime;
  final DateTime? endDate;
  final TimeOfDay? endTime;
  final String? location;
  final int? maxParticipants;
  final ValueChanged<DateTime?> onStartDateChanged;
  final ValueChanged<TimeOfDay?> onStartTimeChanged;
  final ValueChanged<DateTime?> onEndDateChanged;
  final ValueChanged<TimeOfDay?> onEndTimeChanged;
  final ValueChanged<String> onLocationChanged;
  final ValueChanged<int?> onMaxParticipantsChanged;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _Step2DateTime({
    required this.startDate,
    required this.startTime,
    required this.endDate,
    required this.endTime,
    required this.location,
    required this.maxParticipants,
    required this.onStartDateChanged,
    required this.onStartTimeChanged,
    required this.onEndDateChanged,
    required this.onEndTimeChanged,
    required this.onLocationChanged,
    required this.onMaxParticipantsChanged,
    required this.onNext,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final canProceed = startDate != null && startTime != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'ORGANIZZA LA TUA FESTA!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'DICHIARAZIONE DI RESPONSABILITA\'',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),

          _DateTimeField(
            label: 'Data e Ora evento',
            date: startDate,
            time: startTime,
            onDateChanged: onStartDateChanged,
            onTimeChanged: onStartTimeChanged,
          ),
          const SizedBox(height: 16),

          _InputField(
            label: 'Location (opzionale)',
            hint: 'Dove si svolge l\'evento?',
            initialValue: location,
            onChanged: onLocationChanged,
          ),
          const SizedBox(height: 16),

          _InputField(
            label: 'Numero massimo persone (opzionale)',
            hint: 'Es: 100',
            initialValue: maxParticipants?.toString(),
            keyboardType: TextInputType.number,
            onChanged: (val) {
              final parsed = int.tryParse(val);
              onMaxParticipantsChanged(parsed);
            },
          ),
          const SizedBox(height: 32),

          ElevatedButton(
            onPressed: canProceed ? onNext : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.black87,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Avanti', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 16),

          TextButton(
            onPressed: onBack,
            child: const Text(
              'Indietro',
              style: TextStyle(color: Colors.black54, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}

// STEP 3: Gestione Staff
class _Step3Staff extends StatefulWidget {
  final String eventId;
  final List<StaffMember> initialStaff;
  final Function(List<StaffMember>) onStaffUpdated;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _Step3Staff({
    required this.eventId,
    required this.initialStaff,
    required this.onStaffUpdated,
    required this.onNext,
    required this.onBack,
  });

  @override
  _Step3StaffState createState() => _Step3StaffState();
}

class _Step3StaffState extends State<_Step3Staff> {
  String? _inviteLink;
  bool _isLoading = true;
  late List<StaffMember> _staffList;


  @override
  void initState() {
    super.initState();
    _staffList = List.from(widget.initialStaff);
    _loadInviteLink();
  }

  Future<void> _loadInviteLink() async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        throw Exception('Utente non autenticato');
      }

      setState(() {
        _inviteLink = 'http://localhost:3000/JoinEvent/$userId';
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Errore nel caricamento del link di invito'),
          ),
        );
      }
    }
  }

  Future<void> _copyInviteLink() async {
    if (_inviteLink != null) {
      await Clipboard.setData(ClipboardData(text: _inviteLink!));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Link copiato negli appunti!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'ORGANIZZA LA TUA FESTA!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'GESTISCI LO STAFF',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey[300]!),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Link di invito Staff',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: SelectableText(
                            _inviteLink ?? 'Nessun link disponibile',
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed:
                              _inviteLink != null ? _copyInviteLink : null,
                          icon: const Icon(Icons.copy, size: 18),
                          label: const Text('Copia link'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: Colors.black87,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          OutlinedButton.icon(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StaffManagementScreen(
                    initialStaff: _staffList,
                    onStaffUpdated: (updatedList) {
                      setState(() {
                        _staffList = updatedList;
                      });
                      widget.onStaffUpdated(updatedList);
                    },
                  ),
                ),
              );
            },
            icon: const Icon(Icons.person_add, size: 20),
            label: const Text('Aggiungi manualmente staff'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.white.withOpacity(0.7),
              side: const BorderSide(color: Colors.black26),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 32),

          ElevatedButton(
            onPressed: widget.onNext,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.black87,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Avanti', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 16),

          TextButton(
            onPressed: widget.onBack,
            child: const Text(
              'Indietro',
              style: TextStyle(color: Colors.black54, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}

// STEP 4: Impostazioni personalizzate
class _Step4Settings extends StatelessWidget {
  final String? eventId;
  final bool menuCreated;
  final int? ageRestriction;
  final int? maxDrinksPerPerson;
  final ValueChanged<int?> onAgeRestrictionChanged;
  final ValueChanged<int?> onMaxDrinksChanged;
  final Function(
    String menuName,
    String? menuDescription,
    List<Map<String, dynamic>> menuItems,
  )
  onMenuCreated;
  final VoidCallback onComplete;
  final VoidCallback onBack;

  const _Step4Settings({
    this.eventId,
    required this.menuCreated,
    required this.ageRestriction,
    required this.maxDrinksPerPerson,
    required this.onAgeRestrictionChanged,
    required this.onMaxDrinksChanged,
    required this.onMenuCreated,
    required this.onComplete,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'ORGANIZZA LA TUA FESTA!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Personalizza la tua festa!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),

          // Pulsante crea menù - sempre disponibile (menù creato prima dell'evento)
          OutlinedButton(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => CreateMenuScreen(
                        eventId: eventId, // Passa eventId se disponibile
                      ),
                ),
              );
              if (result != null && result is Map<String, dynamic>) {
                onMenuCreated(
                  result['menuName'] as String,
                  result['menuDescription'] as String?,
                  result['menuItems'] as List<Map<String, dynamic>>,
                );
              }
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor:
                  menuCreated
                      ? Colors.green.withOpacity(0.2)
                      : Colors.white.withOpacity(0.7),
              side: BorderSide(
                color: menuCreated ? Colors.green : Colors.black26,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  menuCreated ? 'Menù creato ✓' : 'Crea menù e preziario',
                  style: TextStyle(
                    color: menuCreated ? Colors.green : Colors.black87,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _InputField(
            label: 'Età minima (opzionale)',
            hint: 'Es: 18',
            initialValue: ageRestriction?.toString(),
            keyboardType: TextInputType.number,
            onChanged: (val) {
              final parsed = int.tryParse(val);
              onAgeRestrictionChanged(parsed);
            },
          ),
          const SizedBox(height: 16),

          _InputField(
            label: 'Numero massimo di drink (opzionale)',
            hint: 'Es: 5',
            initialValue: maxDrinksPerPerson?.toString(),
            keyboardType: TextInputType.number,
            onChanged: (val) {
              final parsed = int.tryParse(val);
              onMaxDrinksChanged(parsed);
            },
          ),
          const SizedBox(height: 32),

          ElevatedButton(
            onPressed: onComplete,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.black87,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Crea Evento', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 16),

          TextButton(
            onPressed: onBack,
            child: const Text(
              'Indietro',
              style: TextStyle(color: Colors.black54, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}

// Widget riutilizzabili
class _InputField extends StatefulWidget {
  final String label;
  final String hint;
  final String? initialValue;
  final ValueChanged<String> onChanged;
  final int maxLines;
  final TextInputType? keyboardType;

  const _InputField({
    required this.label,
    required this.hint,
    this.initialValue,
    required this.onChanged,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  State<_InputField> createState() => _InputFieldState();
}

class _InputFieldState extends State<_InputField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _controller.addListener(() {
      widget.onChanged(_controller.text);
    });
  }

  @override
  void didUpdateWidget(_InputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue &&
        widget.initialValue != _controller.text) {
      _controller.text = widget.initialValue ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.black12),
          ),
          child: TextField(
            controller: _controller,
            keyboardType: widget.keyboardType,
            maxLines: widget.maxLines,
            decoration: InputDecoration(
              hintText: widget.hint,
              contentPadding: const EdgeInsets.all(16),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }
}

class _DateTimeField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final TimeOfDay? time;
  final ValueChanged<DateTime?> onDateChanged;
  final ValueChanged<TimeOfDay?> onTimeChanged;

  const _DateTimeField({
    required this.label,
    required this.date,
    required this.time,
    required this.onDateChanged,
    required this.onTimeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: date ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  onDateChanged(picked);
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Text(
                    date != null
                        ? '${date!.day}/${date!.month}/${date!.year}'
                        : 'Seleziona data',
                    style: TextStyle(
                      color: date != null ? Colors.black87 : Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: time ?? TimeOfDay.now(),
                  );
                  onTimeChanged(picked);
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Text(
                    time != null
                        ? '${time!.hour.toString().padLeft(2, '0')}:${time!.minute.toString().padLeft(2, '0')}'
                        : 'Seleziona ora',
                    style: TextStyle(
                      color: time != null ? Colors.black87 : Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

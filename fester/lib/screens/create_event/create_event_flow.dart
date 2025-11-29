// lib/screens/create_event/create_event_flow.dart
import 'package:fester/screens/create_event/staff_management_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../services/SupabaseServicies/event_service.dart';
import '../../services/SupabaseServicies/models/event_staff.dart';
import 'create_menu_screen.dart';
import '../event_selection_screen.dart';

class CreateEventFlow extends StatefulWidget {
  const CreateEventFlow({super.key});

  @override
  State<CreateEventFlow> createState() => _CreateEventFlowState();
}

class _CreateEventFlowState extends State<CreateEventFlow> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  List<EventStaff> _staffMembers = [];

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
        SnackBar(content: Text('create_event.complete_fields'.tr())),
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
            menuName = 'create_event.menu_title'.tr().replaceAll('{}', _eventName!);
            menuDescription = 'create_event.menu_description'.tr().replaceAll('{}', _eventName!);
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
        debugPrint('create_event.menu_creation_error'.tr().replaceAll('{}', e.toString()));
      }

      // 5. Creazione Staff x Evento
      for (final member in _staffMembers) {
        try {
          // Mappa il ruolo locale (Staff1/2/3) al ruolo DB (staff1/staff2/staff3)
          String dbRoleName;
          switch (member.roleId) {
            case 3:
              dbRoleName = 'staff3';
              break;
            case 2:
              dbRoleName = 'staff2';
              break;
            case 1:
            default:
              dbRoleName = 'staff1';
              break;
          }

          // Ottieni l'ID del ruolo
          final roleResponse =
              await Supabase.instance.client
                  .from('role')
                  .select('id')
                  .eq('name', dbRoleName)
                  .maybeSingle();

          if (roleResponse == null) {
            debugPrint('create_event.role_not_found'.tr().replaceAll('{}', dbRoleName));
            continue;
          }

          // Inserisci in event_staff (solo mail, il trigger collegherà l'utente se esiste)
          await Supabase.instance.client.from('event_staff').insert({
            'event_id': event.id,
            'role_id': roleResponse['id'],
            'mail': member.mail,
            'assigned_by': Supabase.instance.client.auth.currentUser?.id,
          });
        } catch (e) {
          debugPrint('create_event.staff_assign_error'.tr().replaceAll('{}', member.mail.toString()).replaceAll('{}', e.toString()));
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('create_event.event_created_success'.tr())),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('create_event.error'.tr().replaceAll('{}', e.toString()))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'create_event.app_title'.tr(),
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
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
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface.withOpacity(0.2),
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
                  onStaffUpdated:
                      (staff) => setState(() => _staffMembers = staff),
                  onNext: _nextPage,
                  onBack: _previousPage,
                ),
                _Step4Settings(
                  eventId: _createdEventId,
                  menuCreated: _menuCreated,
                  menuName: _menuName,
                  menuDescription: _menuDescription,
                  menuItemsData: _menuItemsData,
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
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'create_event.organize_party'.tr(),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
              letterSpacing: 1.2,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'create_event.create_party'.tr(),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 32),

          _InputField(
            label: 'create_event.event_name_label'.tr(),
            hint: 'create_event.event_name_hint'.tr(),
            initialValue: eventName,
            onChanged: onNameChanged,
          ),
          const SizedBox(height: 16),

          _InputField(
            label: 'create_event.description_label'.tr(),
            hint: 'create_event.description_hint'.tr(),
            initialValue: description,
            onChanged: onDescriptionChanged,
            maxLines: 4,
          ),
          const SizedBox(height: 32),

          ElevatedButton(
            onPressed:
                eventName != null && eventName!.isNotEmpty ? onNext : null,
            child: Text('create_event.next'.tr()),
          ),
          const SizedBox(height: 120),

          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'create_event.back'.tr(),
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
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
    final theme = Theme.of(context);
    final canProceed = startDate != null && startTime != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'create_event.organize_party'.tr(),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
              letterSpacing: 1.2,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'create_event.disclaimer_title'.tr(),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 32),

          _DateTimeField(
            label: 'create_event.date_time_label'.tr(),
            date: startDate,
            time: startTime,
            onDateChanged: onStartDateChanged,
            onTimeChanged: onStartTimeChanged,
          ),
          const SizedBox(height: 16),

          _InputField(
            label: 'create_event.location_optional'.tr(),
            hint: 'create_event.location_hint'.tr(),
            initialValue: location,
            onChanged: onLocationChanged,
          ),
          const SizedBox(height: 16),

          _InputField(
            label: 'create_event.max_people_optional'.tr(),
            hint: 'create_event.max_people_hint'.tr(),
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
            child: Text('create_event.next'.tr()),
          ),
          const SizedBox(height: 16),

          TextButton(
            onPressed: onBack,
            child: Text(
              'create_event.back'.tr(),
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
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
  final List<EventStaff> initialStaff;
  final Function(List<EventStaff>) onStaffUpdated;
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
  late List<EventStaff> _staffList;

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
        throw Exception('create_event.user_not_authenticated'.tr());
      }

      setState(() {
        _inviteLink = 'http://localhost:3000/JoinEvent/$userId';
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('create_event.invite_link_load_error'.tr()),
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
          SnackBar(content: Text('create_event.link_copied'.tr())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'create_event.organize_party'.tr(),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
              letterSpacing: 1.2,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'create_event.manage_staff'.tr(),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),

          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: theme.colorScheme.outline.withOpacity(0.3),
              ),
            ),
            color: theme.cardTheme.color,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'create_event.staff_invite_link'.tr(),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
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
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: theme.colorScheme.outline.withOpacity(0.3),
                            ),
                          ),
                          child: SelectableText(
                            _inviteLink ?? 'create_event.no_link_available'.tr(),
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed:
                              _inviteLink != null ? _copyInviteLink : null,
                          icon: const Icon(Icons.copy, size: 18),
                          label: Text('create_event.copy_link'.tr()),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
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
                  builder:
                      (context) => StaffManagementScreen(
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
            icon: Icon(
              Icons.person_add,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            label: Text(
              'create_event.add_staff_manually'.tr(),
              style: TextStyle(color: theme.colorScheme.onSurface),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: theme.cardTheme.color,
              side: BorderSide(color: theme.colorScheme.outline),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 32),

          ElevatedButton(onPressed: widget.onNext, child: Text('create_event.next'.tr())),
          const SizedBox(height: 16),

          TextButton(
            onPressed: widget.onBack,
            child: Text(
              'create_event.back'.tr(),
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
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
  final String? menuName;
  final String? menuDescription;
  final List<Map<String, dynamic>>? menuItemsData;
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
    this.menuName,
    this.menuDescription,
    this.menuItemsData,
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
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'create_event.organize_party'.tr(),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
              letterSpacing: 1.2,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'create_event.customize_party'.tr(),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
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
                        initialMenuName: menuName,
                        initialMenuDescription: menuDescription,
                        initialMenuItems: menuItemsData,
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
                      ? theme.colorScheme.secondary.withOpacity(0.1)
                      : theme.cardTheme.color,
              side: BorderSide(
                color:
                    menuCreated
                        ? theme.colorScheme.secondary
                        : theme.colorScheme.outline,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  menuCreated ? '${'create_event.edit_menu'.tr()} ✓' : 'create_event.create_menu_pricing'.tr(),
                  style: TextStyle(
                    color:
                        menuCreated
                            ? theme.colorScheme.secondary
                            : theme.colorScheme.onSurface,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _InputField(
            label: 'create_event.min_age_optional'.tr(),
            hint: 'create_event.min_age_hint'.tr(),
            initialValue: ageRestriction?.toString(),
            keyboardType: TextInputType.number,
            onChanged: (val) {
              final parsed = int.tryParse(val);
              onAgeRestrictionChanged(parsed);
            },
          ),
          const SizedBox(height: 16),

          _InputField(
            label: 'create_event.max_drinks_optional'.tr(),
            hint: 'create_event.max_drinks_hint'.tr(),
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
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('create_event.create_event'.tr(), style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 16),

          TextButton(
            onPressed: onBack,
            child: Text(
              'create_event.back'.tr(),
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                fontSize: 16,
              ),
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
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.3),
            ),
          ),
          child: TextField(
            controller: _controller,
            keyboardType: widget.keyboardType,
            maxLines: widget.maxLines,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.3),
              ),
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
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
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
                    builder: (context, child) {
                      return Theme(
                        data: theme.copyWith(
                          colorScheme: theme.colorScheme.copyWith(
                            primary: theme.colorScheme.primary,
                            onPrimary: theme.colorScheme.onPrimary,
                            surface: theme.colorScheme.surface,
                            onSurface: theme.colorScheme.onSurface,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  onDateChanged(picked);
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    date != null
                        ? '${date!.day}/${date!.month}/${date!.year}'
                        : 'create_event.select_date'.tr(),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color:
                          date != null
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.onSurface.withOpacity(0.5),
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
                    builder: (context, child) {
                      return Theme(
                        data: theme.copyWith(
                          colorScheme: theme.colorScheme.copyWith(
                            primary: theme.colorScheme.primary,
                            onPrimary: theme.colorScheme.onPrimary,
                            surface: theme.colorScheme.surface,
                            onSurface: theme.colorScheme.onSurface,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  onTimeChanged(picked);
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    time != null
                        ? '${time!.hour.toString().padLeft(2, '0')}:${time!.minute.toString().padLeft(2, '0')}'
                        : 'create_event.select_time'.tr(),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color:
                          time != null
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.onSurface.withOpacity(0.5),
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

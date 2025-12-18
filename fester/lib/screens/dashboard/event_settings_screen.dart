import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase/event_service.dart';
import '../../services/supabase/people_counter_service.dart';
import '../create_event/location_selection_screen.dart';
import 'package:latlong2/latlong.dart';
import '../../utils/location_helper.dart';

class EventSettingsScreen extends StatefulWidget {
  final String eventId;

  const EventSettingsScreen({super.key, required this.eventId});

  @override
  State<EventSettingsScreen> createState() => _EventSettingsScreenState();
}

class _EventSettingsScreenState extends State<EventSettingsScreen> {
  final _supabase = Supabase.instance.client;
  final _eventService = EventService();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;

  // Controllers
  final _maxParticipantsController = TextEditingController();
  final _locationController = TextEditingController();
  String? _locationCoordsPart;
  final _ageRestrictionController = TextEditingController();
  final _maxDrinksController = TextEditingController();
  final _maxWarningsController = TextEditingController();

  // State
  bool _allowGuests = true;
  bool _lateEntryAllowed = true;
  bool _idCheckRequired = false;
  bool _specificPeopleCounting = false; // New state
  DateTime? _startAt;
  DateTime? _endAt;

  String? _settingsId;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _maxParticipantsController.dispose();
    _locationController.dispose();
    _ageRestrictionController.dispose();
    _maxDrinksController.dispose();
    _maxWarningsController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final response =
          await _supabase
              .from('event_settings')
              .select()
              .eq('event_id', widget.eventId)
              .maybeSingle();

      if (response != null) {
        _settingsId = response['id'];
        _maxParticipantsController.text =
            response['max_participants']?.toString() ?? '';
        final rawLocation = response['location'] ?? '';
        _parseLocation(rawLocation);
        _locationController.text = _getNamePart(rawLocation);
        _ageRestrictionController.text =
            response['age_restriction']?.toString() ?? '';
        _maxDrinksController.text =
            response['default_max_drinks_per_person']?.toString() ?? '';
        _maxWarningsController.text =
            response['max_warnings_before_ban']?.toString() ?? '3';

        _allowGuests = response['allow_guests'] ?? true;
        _lateEntryAllowed = response['late_entry_allowed'] ?? true;
        _idCheckRequired = response['id_check_required'] ?? false;
        _specificPeopleCounting = response['specific_people_counting'] ?? false;

        if (response['start_at'] != null) {
          _startAt = DateTime.parse(response['start_at']);
        }
        if (response['end_at'] != null) {
          _endAt = DateTime.parse(response['end_at']);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'event_settings.load_error'.tr()}$e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final data = {
        'max_participants':
            _maxParticipantsController.text.isEmpty
                ? null
                : int.parse(_maxParticipantsController.text),
        'location': _buildFinalLocationString(),
        'age_restriction':
            _ageRestrictionController.text.isEmpty
                ? null
                : int.parse(_ageRestrictionController.text),
        'default_max_drinks_per_person':
            _maxDrinksController.text.isEmpty
                ? null
                : int.parse(_maxDrinksController.text),
        'max_warnings_before_ban':
            _maxWarningsController.text.isEmpty
                ? 3
                : int.parse(_maxWarningsController.text),
        'allow_guests': _allowGuests,
        'late_entry_allowed': _lateEntryAllowed,
        'id_check_required': _idCheckRequired,
        'specific_people_counting': _specificPeopleCounting,
        'start_at': _startAt?.toIso8601String(),
        'end_at': _endAt?.toIso8601String(),
      };

      if (_settingsId != null) {
        await _supabase
            .from('event_settings')
            .update(data)
            .eq('id', _settingsId!);
      } else {
        data['event_id'] = widget.eventId;
        data['created_by'] = _supabase.auth.currentUser!.id;
        await _supabase.from('event_settings').insert(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('event_settings.save_success'.tr())),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'event_settings.save_error'.tr()}$e')),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _archiveEvent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('event_settings.archive_event'.tr()),
            content: Text('event_settings.archive_confirmation'.tr()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('event_settings.cancel'.tr()),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text('event_settings.archive'.tr()),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      setState(() => _isSaving = true);
      try {
        await _eventService.deleteEvent(widget.eventId);

        if (mounted) {
          // Navigate back to event selection and clear stack
          context.go('/event-selection');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${'event_settings.error'.tr()}$e')),
          );
        }
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(title: Text('event_settings.title'.tr())),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('event_settings.title'.tr()),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveSettings,
              child: Text('event_settings.save'.tr()),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSectionTitle(theme, 'event_settings.general_info'.tr()),
            _buildLocationField(theme),
            const SizedBox(height: 16),

            _buildDateTimeField(
              context: context,
              label: 'event_settings.start_date'.tr(),
              value: _startAt,
              onChanged: (date) => setState(() => _startAt = date),
            ),
            const SizedBox(height: 16),

            _buildDateTimeField(
              context: context,
              label: 'event_settings.end_date'.tr(),
              value: _endAt,
              onChanged: (date) => setState(() => _endAt = date),
            ),
            const SizedBox(height: 24),

            _buildSectionTitle(theme, 'event_settings.limits_capacity'.tr()),
            _buildTextField(
              controller: _maxParticipantsController,
              label: 'event_settings.max_participants'.tr(),
              hint: 'event_settings.unlimited_hint'.tr(),
              icon: Icons.people,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            _buildTextField(
              controller: _maxDrinksController,
              label: 'event_settings.max_drinks'.tr(),
              hint: 'event_settings.unlimited_hint'.tr(),
              icon: Icons.local_bar,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),

            _buildSectionTitle(theme, 'event_settings.security'.tr()),
            _buildTextField(
              controller: _ageRestrictionController,
              label: 'event_settings.min_age'.tr(),
              hint: 'event_settings.age_hint'.tr(),
              icon: Icons.cake,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            _buildTextField(
              controller: _maxWarningsController,
              label: 'event_settings.max_warnings'.tr(),
              hint: '3',
              icon: Icons.warning,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            _buildSwitchTile(
              theme: theme,
              title: 'event_settings.id_check'.tr(),
              value: _idCheckRequired,
              onChanged: (val) => setState(() => _idCheckRequired = val),
            ),
            const SizedBox(height: 24),

            _buildSectionTitle(theme, 'event_settings.permissions'.tr()),
            _buildSwitchTile(
              theme: theme,
              title: 'event_settings.allow_guests'.tr(),
              subtitle: 'event_settings.allow_guests_subtitle'.tr(),
              value: _allowGuests,
              onChanged: (val) => setState(() => _allowGuests = val),
            ),
            const SizedBox(height: 8),

            _buildSwitchTile(
              theme: theme,
              title: 'event_settings.late_entry'.tr(),
              value: _lateEntryAllowed,
              onChanged: (val) => setState(() => _lateEntryAllowed = val),
            ),
            const SizedBox(height: 8),
            const SizedBox(height: 8),
            _buildSwitchTile(
              theme: theme,
              title: 'Conteggio Persone Specifico',
              subtitle: 'Attiva il conteggio nominativo per aree',
              value: _specificPeopleCounting,
              onChanged: _onSpecificPeopleCountingChanged,
            ),
            const SizedBox(height: 32),

            _buildSectionTitle(theme, 'event_settings.danger_zone'.tr()),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.error.withOpacity(0.5),
                ),
              ),
              child: ListTile(
                leading: Icon(Icons.archive, color: theme.colorScheme.error),
                title: Text(
                  'event_settings.archive_event'.tr(),
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text('event_settings.archive_subtitle'.tr()),
                onTap: _archiveEvent,
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    final theme = Theme.of(context);
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: theme.cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildDateTimeField({
    required BuildContext context,
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime?> onChanged,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (date != null) {
          if (!context.mounted) return;
          final time = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.fromDateTime(value ?? DateTime.now()),
          );
          if (time != null) {
            onChanged(
              DateTime(date.year, date.month, date.day, time.hour, time.minute),
            );
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: theme.colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(
                    value != null
                        ? '${value.day}/${value.month}/${value.year} ${value.hour}:${value.minute.toString().padLeft(2, '0')}'
                        : 'event_settings.not_set'.tr(),
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onSpecificPeopleCountingChanged(bool val) async {
    // Determine if we are disabling or enabling, but usually reset is relevant for both or primarily when switching modes?
    // User said: "appear popup when activating / deactivating... ask if desired to reset current state".
    // "If pressed yes, delete counts etc and associated people".

    final shouldReset = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              "Reset Conteggi?",
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
            content: const Text(
              "Vuoi resettare lo stato attuale del conteggio? \n\n"
              "Se selezioni 'Sì', tutti i contatori verranno azzerati e le persone verranno rimosse dalle aree.\n"
              "Le aree stesse NON verranno eliminate.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false), // No reset
                child: const Text("No, mantieni"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true), // Yes reset
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Colors.white,
                ),
                child: const Text("Sì, resetta tutto"),
              ),
            ],
          ),
    );

    if (shouldReset == true) {
      // Perform reset
      try {
        // We need an instance of PeopleCounterService.
        // It's not instantiated in this class yet.
        // Assuming we can instantiate it on the fly or add it to state.
        final peopleCounterService = PeopleCounterService();
        await peopleCounterService.resetEventCounts(widget.eventId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Conteggi resettati con successo")),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Errore durante il reset: $e")),
          );
        }
      }
    }

    // Update the setting state regardless of reset choice (unless we want to cancel toggle? assumed "apply toggle")
    if (mounted) {
      setState(() => _specificPeopleCounting = val);
    }
  }

  Widget _buildSwitchTile({
    required ThemeData theme,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SwitchListTile(
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle) : null,
        value: value,
        onChanged: onChanged,
        activeColor: theme.colorScheme.primary,
      ),
    );
  }

  void _parseLocation(String? location) {
    if (location == null || location.isEmpty) {
      _locationCoordsPart = null;
      return;
    }
    final coords = LocationHelper.getCoordinates(location);
    if (coords != null) {
      _locationCoordsPart = LocationHelper.formatLocation('', coords)
          .replaceAll(LocationHelper.nameTagStart, '')
          .replaceAll(
            LocationHelper.nameTagEnd,
            '',
          ); // Keep just the POS part for internal tracking if needed, or better yet, store the coords object?
      // Actually, let's just keep _locationCoordsPart as the string representation of coordinates for simplicity with existing code structure
      // or ideally, refactor to store LatLng? _currentCoords;
      // Let's stick to minimal changes: store the [POS]...[/POS] string
      _locationCoordsPart =
          '${LocationHelper.posTagStart}${coords.latitude},${coords.longitude}${LocationHelper.posTagEnd}';
    } else {
      _locationCoordsPart = null;
    }
  }

  String _getNamePart(String? location) {
    return LocationHelper.getName(location);
  }

  String? _buildFinalLocationString() {
    final name = _locationController.text.trim();
    LatLng? coords;
    if (_locationCoordsPart != null) {
      coords = LocationHelper.getCoordinates(_locationCoordsPart);
    }

    if (name.isEmpty && coords == null) return null;
    return LocationHelper.formatLocation(name, coords);
  }

  Future<void> _selectOnMap() async {
    LatLng? initialPoint;
    if (_locationCoordsPart != null) {
      initialPoint = LocationHelper.getCoordinates(_locationCoordsPart);
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => LocationSelectionScreen(initialLocation: initialPoint),
      ),
    );

    if (result != null && result is Map) {
      final coords = result['coords'] as LatLng;
      final name = result['name'] as String;

      setState(() {
        _locationCoordsPart =
            '${LocationHelper.posTagStart}${coords.latitude},${coords.longitude}${LocationHelper.posTagEnd}';
        if (name.isNotEmpty && name != 'Selected Location') {
          _locationController.text = name;
        }
      });
    } else if (result != null && result is LatLng) {
      // Fallback for legacy return if any
      setState(() {
        _locationCoordsPart =
            '${LocationHelper.posTagStart}${result.latitude},${result.longitude}${LocationHelper.posTagEnd}';
      });
    }
  }

  Widget _buildLocationField(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _locationController,
                decoration: InputDecoration(
                  labelText: 'event_settings.location'.tr(),
                  hintText: 'event_settings.location_hint'.tr(),
                  prefixIcon: const Icon(Icons.location_on),
                  filled: true,
                  fillColor: theme.cardTheme.color,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: _selectOnMap,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.map,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
        if (_locationCoordsPart != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 12),
            child: Text(
              'create_event.location_selected_on_map'.tr(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }
}

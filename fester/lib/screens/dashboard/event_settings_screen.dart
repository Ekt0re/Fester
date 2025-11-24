import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EventSettingsScreen extends StatefulWidget {
  final String eventId;

  const EventSettingsScreen({super.key, required this.eventId});

  @override
  State<EventSettingsScreen> createState() => _EventSettingsScreenState();
}

class _EventSettingsScreenState extends State<EventSettingsScreen> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;

  // Controllers
  final _maxParticipantsController = TextEditingController();
  final _locationController = TextEditingController();
  final _ageRestrictionController = TextEditingController();
  final _maxDrinksController = TextEditingController();
  final _maxWarningsController = TextEditingController();

  // State
  bool _allowGuests = true;
  bool _lateEntryAllowed = true;
  bool _idCheckRequired = false;
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
        _locationController.text = response['location'] ?? '';
        _ageRestrictionController.text =
            response['age_restriction']?.toString() ?? '';
        _maxDrinksController.text =
            response['default_max_drinks_per_person']?.toString() ?? '';
        _maxWarningsController.text =
            response['max_warnings_before_ban']?.toString() ?? '3';

        _allowGuests = response['allow_guests'] ?? true;
        _lateEntryAllowed = response['late_entry_allowed'] ?? true;
        _idCheckRequired = response['id_check_required'] ?? false;

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
          SnackBar(content: Text('Errore caricamento impostazioni: $e')),
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
        'location':
            _locationController.text.isEmpty ? null : _locationController.text,
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
          const SnackBar(content: Text('Impostazioni salvate con successo!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Errore salvataggio: $e')));
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(title: const Text('Impostazioni Evento')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Impostazioni Evento'),
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
            TextButton(onPressed: _saveSettings, child: const Text('Salva')),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSectionTitle(theme, 'Informazioni Generali'),
            _buildTextField(
              controller: _locationController,
              label: 'Location',
              hint: 'Es: Via Roma 123, Milano',
              icon: Icons.location_on,
            ),
            const SizedBox(height: 16),

            _buildDateTimeField(
              context: context,
              label: 'Data Inizio',
              value: _startAt,
              onChanged: (date) => setState(() => _startAt = date),
            ),
            const SizedBox(height: 16),

            _buildDateTimeField(
              context: context,
              label: 'Data Fine',
              value: _endAt,
              onChanged: (date) => setState(() => _endAt = date),
            ),
            const SizedBox(height: 24),

            _buildSectionTitle(theme, 'Limiti e Capacità'),
            _buildTextField(
              controller: _maxParticipantsController,
              label: 'Massimo Partecipanti',
              hint: 'Lascia vuoto per illimitato',
              icon: Icons.people,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            _buildTextField(
              controller: _maxDrinksController,
              label: 'Massimo Drink per Persona',
              hint: 'Lascia vuoto per illimitato',
              icon: Icons.local_bar,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),

            _buildSectionTitle(theme, 'Sicurezza'),
            _buildTextField(
              controller: _ageRestrictionController,
              label: 'Età Minima',
              hint: 'Es: 18',
              icon: Icons.cake,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            _buildTextField(
              controller: _maxWarningsController,
              label: 'Massimo Warning prima del Ban',
              hint: '3',
              icon: Icons.warning,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            _buildSwitchTile(
              theme: theme,
              title: 'Controllo Documento Richiesto',
              value: _idCheckRequired,
              onChanged: (val) => setState(() => _idCheckRequired = val),
            ),
            const SizedBox(height: 24),

            _buildSectionTitle(theme, 'Permessi'),
            _buildSwitchTile(
              theme: theme,
              title: 'Consenti Ospiti',
              subtitle: 'I partecipanti possono invitare ospiti',
              value: _allowGuests,
              onChanged: (val) => setState(() => _allowGuests = val),
            ),
            const SizedBox(height: 8),

            _buildSwitchTile(
              theme: theme,
              title: 'Ingresso Tardivo Consentito',
              value: _lateEntryAllowed,
              onChanged: (val) => setState(() => _lateEntryAllowed = val),
            ),
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
                        : 'Non impostato',
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
}

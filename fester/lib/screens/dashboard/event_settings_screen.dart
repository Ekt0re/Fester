import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/SupabaseServicies/event_service.dart';

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
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil('/event-selection', (route) => false);
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
            _buildTextField(
              controller: _locationController,
              label: 'event_settings.location'.tr(),
              hint: 'event_settings.location_hint'.tr(),
              icon: Icons.location_on,
            ),
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

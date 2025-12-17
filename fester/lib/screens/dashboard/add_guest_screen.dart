import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import '../profile/widgets/transaction_list_sheet.dart';
import '../../services/supabase/person_service.dart';
import '../../services/supabase/participation_service.dart';
import '../../services/supabase/gruppo_service.dart';
import '../../services/supabase/sottogruppo_service.dart';
import '../../services/supabase/models/gruppo.dart';
import '../../services/supabase/models/sottogruppo.dart';
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
  final GruppoService _gruppoService = GruppoService();
  final SottogruppoService _sottogruppoService = SottogruppoService();

  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _codiceFiscaleController;
  late TextEditingController _indirizzoController;
  late TextEditingController _localIdController;
  late TextEditingController _invitedBySearchController;

  DateTime? _dateOfBirth;
  int _selectedRoleId = 2; // Default fallback
  int _selectedStatusId = 1; // Default fallback
  bool _isLoading = true;

  List<Map<String, dynamic>> _roles = [];
  List<Map<String, dynamic>> _statuses = [];
  List<Gruppo> _gruppi = [];
  List<Sottogruppo> _sottogruppi = [];

  int? _selectedGruppoId;
  int? _selectedSottogruppoId;
  String? _selectedInvitedById;
  String? _selectedInvitedByName;
  String? _selectedInvitedByType;

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;
    final person = data?['person'];

    _firstNameController = TextEditingController(
      text: person?['first_name'] ?? data?['first_name'],
    );
    _lastNameController = TextEditingController(
      text: person?['last_name'] ?? data?['last_name'],
    );
    _emailController = TextEditingController(
      text: person?['email'] ?? data?['email'],
    );
    _phoneController = TextEditingController(
      text: person?['phone'] ?? data?['phone'],
    );
    _codiceFiscaleController = TextEditingController(
      text: person?['codice_fiscale'],
    );
    _indirizzoController = TextEditingController(text: person?['indirizzo']);
    _localIdController = TextEditingController(
      text: data?['local_id']?.toString(),
    );
    _invitedBySearchController = TextEditingController();

    if ((person?['date_of_birth'] ?? data?['date_of_birth']) != null) {
      _dateOfBirth = DateTime.tryParse(
        person?['date_of_birth'] ?? data!['date_of_birth'],
      );
    }

    _selectedGruppoId = person?['gruppo_id'];
    _selectedSottogruppoId = person?['sottogruppo_id'];
    _selectedInvitedById = data?['invited_by'];

    _loadFormData();
  }

  Future<void> _loadFormData() async {
    try {
      final results = await Future.wait([
        _participationService.getRoles(),
        _participationService.getParticipationStatuses(),
        _gruppoService.getGruppiForEvent(widget.eventId),
      ]);

      final roles = results[0] as List<Map<String, dynamic>>;
      final statuses = results[1] as List<Map<String, dynamic>>;
      final gruppi = results[2] as List<Gruppo>;

      // Load sottogruppi if a gruppo is selected
      List<Sottogruppo> sottogruppi = [];
      if (_selectedGruppoId != null) {
        sottogruppi = await _sottogruppoService.getSottogruppiForGruppo(
          _selectedGruppoId!,
        );
      }

      // Load invited_by name if ID exists
      if (_selectedInvitedById != null) {
        try {
          final searchResults = await _personService.searchPeopleAndStaff(
            widget.eventId,
            _selectedInvitedById!,
          );
          if (searchResults.isNotEmpty) {
            final person = searchResults.first;
            _selectedInvitedByName =
                '${person['first_name']} ${person['last_name']}';
            _selectedInvitedByType =
                person['type'] == 'staff' ? 'Staff' : 'Ospite';
          }
        } catch (e) {
          // Ignore error, leave name as null
        }
      }

      if (mounted) {
        setState(() {
          _roles = roles;
          _statuses = statuses;
          _gruppi = gruppi;
          _sottogruppi = sottogruppi;

          // Set initial values from data or defaults
          final initialRoleId = widget.initialData?['role_id'];
          final initialStatusId = widget.initialData?['status_id'];

          if (initialRoleId != null &&
              _roles.any((r) => r['id'] == initialRoleId)) {
            _selectedRoleId = initialRoleId;
          } else if (_roles.isNotEmpty) {
            if (!_roles.any((r) => r['id'] == _selectedRoleId)) {
              _selectedRoleId = _roles.first['id'];
            }
          }

          if (initialStatusId != null &&
              _statuses.any((s) => s['id'] == initialStatusId)) {
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${'add_guest.data_load_error'.tr()}$e')));
      }
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _codiceFiscaleController.dispose();
    _indirizzoController.dispose();
    _localIdController.dispose();
    _invitedBySearchController.dispose();
    super.dispose();
  }

  Future<String> _generateNextIdEvent() async {
    try {
      final participations = await _participationService.getEventParticipations(
        widget.eventId,
      );
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
          email:
              _emailController.text.trim().isEmpty
                  ? null
                  : _emailController.text.trim(),
          phone:
              _phoneController.text.trim().isEmpty
                  ? null
                  : _phoneController.text.trim(),
          dateOfBirth: _dateOfBirth,
          codiceFiscale:
              _codiceFiscaleController.text.trim().isEmpty
                  ? null
                  : _codiceFiscaleController.text.trim(),
          indirizzo:
              _indirizzoController.text.trim().isEmpty
                  ? null
                  : _indirizzoController.text.trim(),
          gruppoId: _selectedGruppoId,
          sottogruppoId: _selectedSottogruppoId,
        );

        // Update Participation (Role & Status, local_id, invited_by)
        final participationId =
            widget.initialData?['participation_id'] ??
            widget.initialData?['id'];
        if (participationId != null) {
          final localIdValue =
              _localIdController.text.trim().isEmpty
                  ? null
                  : int.tryParse(_localIdController.text.trim());

          await _participationService.updateParticipation(
            participationId: participationId,
            roleId: _selectedRoleId,
            statusId: _selectedStatusId,
            localId: localIdValue,
            invitedBy: _selectedInvitedById,
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('add_guest.guest_updated'.tr())),
          );
          Navigator.pop(context, true);
        }
      } else {
        // Create new person
        final idEvent = await _generateNextIdEvent();

        final person = await _personService.createPerson(
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          email:
              _emailController.text.trim().isEmpty
                  ? null
                  : _emailController.text.trim(),
          phone:
              _phoneController.text.trim().isEmpty
                  ? null
                  : _phoneController.text.trim(),
          dateOfBirth: _dateOfBirth,
          codiceFiscale:
              _codiceFiscaleController.text.trim().isEmpty
                  ? null
                  : _codiceFiscaleController.text.trim(),
          indirizzo:
              _indirizzoController.text.trim().isEmpty
                  ? null
                  : _indirizzoController.text.trim(),
          gruppoId: _selectedGruppoId,
          sottogruppoId: _selectedSottogruppoId,
          idEvent: idEvent,
        );

        final localIdValue =
            _localIdController.text.trim().isEmpty
                ? null
                : int.tryParse(_localIdController.text.trim());

        await _participationService.createParticipation(
          personId: person['id'],
          eventId: widget.eventId,
          statusId: _selectedStatusId,
          roleId: _selectedRoleId,
          invitedBy: _selectedInvitedById,
          localId: localIdValue,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('add_guest.guest_added'.tr())),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'add_guest.save_error'.tr()}$e')),
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

  Future<void> _onGruppoChanged(int? gruppoId) async {
    setState(() {
      _selectedGruppoId = gruppoId;
      _selectedSottogruppoId = null;
      _sottogruppi = [];
    });

    if (gruppoId != null) {
      try {
        final sottogruppi = await _sottogruppoService.getSottogruppiForGruppo(
          gruppoId,
        );
        if (mounted) {
          setState(() {
            _sottogruppi = sottogruppi;
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${'add_guest.subgroup_load_error'.tr()}$e')),
          );
        }
      }
    }
  }

  Future<void> _createNewGruppo() async {
    final textController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('add_guest.create_group_dialog_title'.tr()),
            content: TextField(
              controller: textController,
              decoration: InputDecoration(
                labelText: 'add_guest.group_name_label'.tr(),
                hintText: 'add_guest.group_name_hint'.tr(),
              ),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('common.cancel'.tr()),
              ),
              TextButton(
                onPressed:
                    () => Navigator.pop(context, textController.text.trim()),
                child: Text('add_guest.create'.tr()),
              ),
            ],
          ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        final gruppo = await _gruppoService.createGruppo(
          name: result,
          eventId: widget.eventId,
        );

        if (mounted) {
          setState(() {
            _gruppi.add(gruppo);
            _selectedGruppoId = gruppo.id;
            _sottogruppi = [];
            _selectedSottogruppoId = null;
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${'add_guest.group_create_error'.tr()}$e')),
          );
        }
      }
    }
  }

  Future<void> _createNewSottogruppo() async {
    if (_selectedGruppoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('add_guest.select_group_first'.tr())),
      );
      return;
    }

    final textController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('add_guest.create_subgroup_dialog_title'.tr()),
            content: TextField(
              controller: textController,
              decoration: InputDecoration(
                labelText: 'add_guest.subgroup_name_label'.tr(),
                hintText: 'add_guest.subgroup_name_hint'.tr(),
              ),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('common.cancel'.tr()),
              ),
              TextButton(
                onPressed:
                    () => Navigator.pop(context, textController.text.trim()),
                child: Text('add_guest.create'.tr()),
              ),
            ],
          ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        final sottogruppo = await _sottogruppoService.createSottogruppo(
          name: result,
          gruppoId: _selectedGruppoId!,
          eventId: widget.eventId,
        );

        if (mounted) {
          setState(() {
            _sottogruppi.add(sottogruppo);
            _selectedSottogruppoId = sottogruppo.id;
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${'add_guest.subgroup_create_error'.tr()}$e')),
          );
        }
      }
    }
  }

  Future<void> _searchInvitedBy() async {
    final searchController = TextEditingController();
    List<Map<String, dynamic>> searchResults = [];
    bool isSearching = false;

    await showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              // Real-time search as user types
              void performSearch(String query) async {
                if (query.trim().isEmpty) {
                  setDialogState(() {
                    searchResults = [];
                    isSearching = false;
                  });
                  return;
                }

                setDialogState(() => isSearching = true);

                try {
                  final results = await _personService.searchPeopleAndStaff(
                    widget.eventId,
                    query.trim(),
                  );
                  if (searchController.text.trim() == query.trim()) {
                    setDialogState(() {
                      searchResults = results;
                      isSearching = false;
                    });
                  }
                } catch (e) {
                  if (searchController.text.trim() == query.trim()) {
                    setDialogState(() => isSearching = false);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${'add_guest.search_error'.tr()}$e')),
                      );
                    }
                  }
                }
              }

              return AlertDialog(
                title: Text('add_guest.search_inviter_title'.tr()),
                content: SizedBox(
                  width: 500,
                  height: 400,
                  child: Column(
                    children: [
                      TextField(
                        controller: searchController,
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: 'add_guest.search_label'.tr(),
                          hintText: 'add_guest.search_hint'.tr(),
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: performSearch, // Real-time search
                      ),
                      const SizedBox(height: 16),
                      if (isSearching)
                        const Expanded(
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      if (!isSearching && searchResults.isNotEmpty)
                        Expanded(
                          child: ListView.builder(
                            itemCount: searchResults.length,
                            itemBuilder: (context, index) {
                              final person = searchResults[index];
                              final fullName =
                                  '${person['first_name']} ${person['last_name']}';
                              final type =
                                  person['type'] == 'staff'
                                      ? 'Staff'
                                      : 'Ospite';
                              final subtitle =
                                  person['email'] ?? person['phone'] ?? 'N/A';

                              return Card(
                                child: ListTile(
                                  leading: CircleAvatar(
                                    child: Text(
                                      type[0],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    fullName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text('$type • $subtitle'),
                                  trailing: const Icon(
                                    Icons.arrow_forward_ios,
                                    size: 16,
                                  ),
                                  onTap: () {
                                    setState(() {
                                      _selectedInvitedById = person['id'];
                                      _selectedInvitedByName = fullName;
                                      _selectedInvitedByType = type;
                                    });
                                    Navigator.pop(context);
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      if (!isSearching &&
                          searchResults.isEmpty &&
                          searchController.text.isNotEmpty)
                        Expanded(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'add_guest.no_results'.tr(),
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (searchController.text.isEmpty)
                        Expanded(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.person_search,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'add_guest.start_typing'.tr(),
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('common.close'.tr()),
                  ),
                ],
              );
            },
          ),
    );
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
          widget.personId != null ? 'add_guest.edit_guest'.tr() : 'add_guest.add_guest'.tr(),
          style: GoogleFonts.outfit(
            color: theme.colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth > 900;
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child:
                          isDesktop
                              ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Left Column: Personal Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        _buildSectionTitle(
                                          theme,
                                          'add_guest.personal_info'.tr(),
                                        ),
                                        _buildTextField(
                                          controller: _firstNameController,
                                          label: 'add_guest.name'.tr(),
                                          hint: 'add_guest.name_hint'.tr(),
                                          icon: Icons.person_outline,
                                          validator: (value) {
                                            if (value == null ||
                                                value.trim().isEmpty) {
                                              return 'add_guest.name_required'.tr();
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 16),
                                        _buildTextField(
                                          controller: _lastNameController,
                                          label: 'add_guest.surname'.tr(),
                                          hint: 'add_guest.surname_hint'.tr(),
                                          icon: Icons.person,
                                          validator: (value) {
                                            if (value == null ||
                                                value.trim().isEmpty) {
                                              return 'add_guest.surname_required'.tr();
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 16),
                                        _buildTextField(
                                          controller: _emailController,
                                          label: 'add_guest.email_optional'.tr(),
                                          hint: 'add_guest.email_hint'.tr(),
                                          icon: Icons.email_outlined,
                                          keyboardType:
                                              TextInputType.emailAddress,
                                          validator: (value) {
                                            if (value != null &&
                                                value.isNotEmpty) {
                                              final emailRegex = RegExp(
                                                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                              );
                                              if (!emailRegex.hasMatch(value)) {
                                                return 'add_guest.email_invalid'.tr();
                                              }
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 16),
                                        _buildTextField(
                                          controller: _phoneController,
                                          label: 'add_guest.phone_optional'.tr(),
                                          hint: 'add_guest.phone_hint'.tr(),
                                          icon: Icons.phone_outlined,
                                          keyboardType: TextInputType.phone,
                                        ),
                                        const SizedBox(height: 16),
                                        InkWell(
                                          onTap: _selectDate,
                                          child: Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.surface,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: theme.colorScheme.outline
                                                    .withOpacity(0.3),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.cake_outlined,
                                                  color:
                                                      theme.colorScheme.primary,
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(
                                                    _dateOfBirth == null
                                                        ? 'add_guest.birth_date_optional'.tr()
                                                        : '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}',
                                                    style: GoogleFonts.outfit(
                                                      color:
                                                          _dateOfBirth == null
                                                              ? theme
                                                                  .colorScheme
                                                                  .onSurface
                                                                  .withOpacity(
                                                                    0.5,
                                                                  )
                                                              : theme
                                                                  .colorScheme
                                                                  .onSurface,
                                                    ),
                                                  ),
                                                ),
                                                if (_dateOfBirth != null)
                                                  IconButton(
                                                    icon: const Icon(
                                                      Icons.clear,
                                                    ),
                                                    onPressed:
                                                        () => setState(
                                                          () =>
                                                              _dateOfBirth =
                                                                  null,
                                                        ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        _buildTextField(
                                          controller: _codiceFiscaleController,
                                          label: 'add_guest.fiscal_code_optional'.tr(),
                                          hint: 'add_guest.fiscal_code_hint'.tr(),
                                          icon: Icons.badge_outlined,
                                        ),
                                        const SizedBox(height: 16),
                                        _buildTextField(
                                          controller: _indirizzoController,
                                          label: 'add_guest.address_optional'.tr(),
                                          hint: 'add_guest.address_hint'.tr(),
                                          icon: Icons.home_outlined,
                                          maxLines: 2,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 32),
                                  // Right Column: Event Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        _buildSectionTitle(
                                          theme,
                                          'add_guest.event_details'.tr(),
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: _buildGruppoDropdown(
                                                    theme,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.add_circle_outline,
                                                  ),
                                                  color:
                                                      theme.colorScheme.primary,
                                                  onPressed: _createNewGruppo,
                                                  tooltip: 'add_guest.create_new_group'.tr(),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        if (_selectedGruppoId != null)
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child:
                                                        _buildSottogruppoDropdown(
                                                          theme,
                                                        ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  IconButton(
                                                    icon: const Icon(
                                                      Icons.add_circle_outline,
                                                    ),
                                                    color:
                                                        theme
                                                            .colorScheme
                                                            .primary,
                                                    onPressed:
                                                        _createNewSottogruppo,
                                                    tooltip:
                                                        'add_guest.create_new_subgroup'.tr(),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 16),
                                            ],
                                          ),
                                        _buildTextField(
                                          controller: _localIdController,
                                          label: 'add_guest.local_id_optional'.tr(),
                                          hint: 'add_guest.local_id_hint'.tr(),
                                          icon:
                                              Icons
                                                  .confirmation_number_outlined,
                                          keyboardType: TextInputType.number,
                                        ),
                                        const SizedBox(height: 16),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'add_guest.invited_by_optional'.tr(),
                                              style: GoogleFonts.outfit(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: theme
                                                    .colorScheme
                                                    .onSurface
                                                    .withOpacity(0.7),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            InkWell(
                                              onTap: _searchInvitedBy,
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  16,
                                                ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      theme.colorScheme.surface,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: theme
                                                        .colorScheme
                                                        .outline
                                                        .withOpacity(0.3),
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.person_search,
                                                      color:
                                                          theme
                                                              .colorScheme
                                                              .primary,
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Text(
                                                        _selectedInvitedByName !=
                                                                null
                                                            ? '$_selectedInvitedByName ($_selectedInvitedByType)'
                                                            : 'add_guest.search_person'.tr(),
                                                        style: GoogleFonts.outfit(
                                                          color:
                                                              _selectedInvitedByName ==
                                                                      null
                                                                  ? theme
                                                                      .colorScheme
                                                                      .onSurface
                                                                      .withOpacity(
                                                                        0.5,
                                                                      )
                                                                  : theme
                                                                      .colorScheme
                                                                      .onSurface,
                                                        ),
                                                      ),
                                                    ),
                                                    if (_selectedInvitedById !=
                                                        null)
                                                      IconButton(
                                                        icon: const Icon(
                                                          Icons.clear,
                                                        ),
                                                        onPressed: () {
                                                          setState(() {
                                                            _selectedInvitedById =
                                                                null;
                                                            _selectedInvitedByName =
                                                                null;
                                                            _selectedInvitedByType =
                                                                null;
                                                          });
                                                        },
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        if (_roles.isNotEmpty)
                                          _buildDropdown(
                                            label: 'add_guest.role'.tr(),
                                            value: _selectedRoleId,
                                            icon: Icons.star_outline,
                                            items: _roles,
                                            onChanged: (value) {
                                              setState(
                                                () => _selectedRoleId = value!,
                                              );
                                            },
                                          ),
                                        const SizedBox(height: 16),
                                        if (_statuses.isNotEmpty)
                                          _buildDropdown(
                                            label: 'add_guest.status'.tr(),
                                            value: _selectedStatusId,
                                            icon: Icons.pending_outlined,
                                            items: _statuses,
                                            onChanged: (value) {
                                              setState(
                                                () =>
                                                    _selectedStatusId = value!,
                                              );
                                            },
                                          ),
                                        if (widget.personId != null) ...[
                                          const SizedBox(height: 16),
                                          OutlinedButton.icon(
                                            onPressed: _openTransactionList,
                                            icon: Icon(
                                              Icons.receipt_long,
                                              color: theme.colorScheme.primary,
                                            ),
                                            label: Text(
                                              'add_guest.manage_transactions'.tr(),
                                              style: GoogleFonts.outfit(
                                                color:
                                                    theme.colorScheme.primary,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 16,
                                                  ),
                                              side: BorderSide(
                                                color:
                                                    theme.colorScheme.primary,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 32),
                                        ElevatedButton(
                                          onPressed:
                                              _isLoading ? null : _saveGuest,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                theme.colorScheme.primary,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 16,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                          child: Text(
                                            'add_guest.save_guest'.tr(),
                                            style: GoogleFonts.outfit(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color:
                                                  theme.colorScheme.onPrimary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                              : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // First Name
                                  _buildTextField(
                                    controller: _firstNameController,
                                    label: 'add_guest.name'.tr(),
                                    hint: 'add_guest.name_hint'.tr(),
                                    icon: Icons.person_outline,
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'add_guest.name_required'.tr();
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  // Last Name
                                  _buildTextField(
                                    controller: _lastNameController,
                                    label: 'add_guest.surname'.tr(),
                                    hint: 'add_guest.surname_hint'.tr(),
                                    icon: Icons.person,
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'add_guest.surname_required'.tr();
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  // Email
                                  _buildTextField(
                                    controller: _emailController,
                                    label: 'add_guest.email_optional'.tr(),
                                    hint: 'add_guest.email_hint'.tr(),
                                    icon: Icons.email_outlined,
                                    keyboardType: TextInputType.emailAddress,
                                    validator: (value) {
                                      if (value != null && value.isNotEmpty) {
                                        final emailRegex = RegExp(
                                          r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                        );
                                        if (!emailRegex.hasMatch(value)) {
                                          return 'add_guest.email_invalid'.tr();
                                        }
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  // Phone
                                  _buildTextField(
                                    controller: _phoneController,
                                    label: 'add_guest.phone_optional'.tr(),
                                    hint: 'add_guest.phone_hint'.tr(),
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
                                          color: theme.colorScheme.outline
                                              .withOpacity(0.3),
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
                                                  ? 'add_guest.birth_date_optional'.tr()
                                                  : '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}',
                                              style: GoogleFonts.outfit(
                                                color:
                                                    _dateOfBirth == null
                                                        ? theme
                                                            .colorScheme
                                                            .onSurface
                                                            .withOpacity(0.5)
                                                        : theme
                                                            .colorScheme
                                                            .onSurface,
                                              ),
                                            ),
                                          ),
                                          if (_dateOfBirth != null)
                                            IconButton(
                                              icon: const Icon(Icons.clear),
                                              onPressed:
                                                  () => setState(
                                                    () => _dateOfBirth = null,
                                                  ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Codice Fiscale
                                  _buildTextField(
                                    controller: _codiceFiscaleController,
                                    label: 'add_guest.fiscal_code_optional'.tr(),
                                    hint: 'add_guest.fiscal_code_hint'.tr(),
                                    icon: Icons.badge_outlined,
                                  ),
                                  const SizedBox(height: 16),

                                  // Indirizzo
                                  _buildTextField(
                                    controller: _indirizzoController,
                                    label: 'add_guest.address_optional'.tr(),
                                    hint: 'add_guest.address_hint'.tr(),
                                    icon: Icons.home_outlined,
                                    maxLines: 2,
                                  ),
                                  const SizedBox(height: 16),

                                  // Gruppo Dropdown
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildGruppoDropdown(theme),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.add_circle_outline,
                                            ),
                                            color: theme.colorScheme.primary,
                                            onPressed: _createNewGruppo,
                                            tooltip: 'add_guest.create_new_group'.tr(),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  // Sottogruppo Dropdown
                                  if (_selectedGruppoId != null)
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _buildSottogruppoDropdown(
                                                theme,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.add_circle_outline,
                                              ),
                                              color: theme.colorScheme.primary,
                                              onPressed: _createNewSottogruppo,
                                              tooltip: 'add_guest.create_new_subgroup'.tr(),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                      ],
                                    ),

                                  // Local ID
                                  _buildTextField(
                                    controller: _localIdController,
                                    label: 'add_guest.local_id_optional'.tr(),
                                    hint: 'add_guest.local_id_hint'.tr(),
                                    icon: Icons.confirmation_number_outlined,
                                    keyboardType: TextInputType.number,
                                  ),
                                  const SizedBox(height: 16),

                                  // Invited By
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'add_guest.invited_by_optional'.tr(),
                                        style: GoogleFonts.outfit(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: theme.colorScheme.onSurface
                                              .withOpacity(0.7),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      InkWell(
                                        onTap: _searchInvitedBy,
                                        child: Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.surface,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: theme.colorScheme.outline
                                                  .withOpacity(0.3),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.person_search,
                                                color:
                                                    theme.colorScheme.primary,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  _selectedInvitedByName != null
                                                      ? '$_selectedInvitedByName ($_selectedInvitedByType)'
                                                      : 'add_guest.search_person'.tr(),
                                                  style: GoogleFonts.outfit(
                                                    color:
                                                        _selectedInvitedByName ==
                                                                null
                                                            ? theme
                                                                .colorScheme
                                                                .onSurface
                                                                .withOpacity(
                                                                  0.5,
                                                                )
                                                            : theme
                                                                .colorScheme
                                                                .onSurface,
                                                  ),
                                                ),
                                              ),
                                              if (_selectedInvitedById != null)
                                                IconButton(
                                                  icon: const Icon(Icons.clear),
                                                  onPressed: () {
                                                    setState(() {
                                                      _selectedInvitedById =
                                                          null;
                                                      _selectedInvitedByName =
                                                          null;
                                                      _selectedInvitedByType =
                                                          null;
                                                    });
                                                  },
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  // Role Dropdown
                                  if (_roles.isNotEmpty)
                                    _buildDropdown(
                                      label: 'add_guest.role'.tr(),
                                      value: _selectedRoleId,
                                      icon: Icons.star_outline,
                                      items: _roles,
                                      onChanged: (value) {
                                        setState(
                                          () => _selectedRoleId = value!,
                                        );
                                      },
                                    ),
                                  const SizedBox(height: 16),

                                  // Status Dropdown
                                  if (_statuses.isNotEmpty)
                                    _buildDropdown(
                                      label: 'add_guest.status'.tr(),
                                      value: _selectedStatusId,
                                      icon: Icons.pending_outlined,
                                      items: _statuses,
                                      onChanged: (value) {
                                        setState(
                                          () => _selectedStatusId = value!,
                                        );
                                      },
                                    ),
                                  // Transaction Management Button (Only if editing)
                                  if (widget.personId != null) ...[
                                    const SizedBox(height: 16),
                                    OutlinedButton.icon(
                                      onPressed: () {
                                        _openTransactionList();
                                      },
                                      icon: Icon(
                                        Icons.receipt_long,
                                        color: theme.colorScheme.primary,
                                      ),
                                      label: Text(
                                        'add_guest.manage_transactions'.tr(),
                                        style: GoogleFonts.outfit(
                                          color: theme.colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        side: BorderSide(
                                          color: theme.colorScheme.primary,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],

                                  const SizedBox(height: 32),

                                  // Save Button
                                  ElevatedButton(
                                    onPressed: _isLoading ? null : _saveGuest,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          theme.colorScheme.primary,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Text(
                                      'add_guest.save_guest'.tr(),
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
                  );
                },
              ),
    );
  }

  void _openTransactionList() async {
    // Fetch transactions
    setState(() => _isLoading = true);
    try {
      final participationId = widget.initialData?['participation_id'];
      if (participationId != null) {
        final transactions = await _personService.getPersonTransactions(
          participationId,
        );
        if (mounted) {
          setState(() => _isLoading = false);
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder:
                (context) => TransactionListSheet(
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
          SnackBar(content: Text('${'add_guest.transaction_load_error'.tr()}$e')),
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
    int? maxLines,
  }) {
    final theme = Theme.of(context);

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines ?? 1,
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
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
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
                    items:
                        items.map((item) {
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

  Widget _buildGruppoDropdown(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gruppo (opzionale)',
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
              Icon(Icons.group_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    value: _selectedGruppoId,
                    isExpanded: true,
                    hint: Text('Seleziona gruppo', style: GoogleFonts.outfit()),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Nessun gruppo'),
                      ),
                      ..._gruppi.map((gruppo) {
                        return DropdownMenuItem<int?>(
                          value: gruppo.id,
                          child: Text(gruppo.name, style: GoogleFonts.outfit()),
                        );
                      }),
                    ],
                    onChanged: _onGruppoChanged,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSottogruppoDropdown(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sottogruppo (opzionale)',
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
              Icon(Icons.people_outline, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    value: _selectedSottogruppoId,
                    isExpanded: true,
                    hint: Text(
                      'Seleziona sottogruppo',
                      style: GoogleFonts.outfit(),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Nessun sottogruppo'),
                      ),
                      ..._sottogruppi.map((sottogruppo) {
                        return DropdownMenuItem<int?>(
                          value: sottogruppo.id,
                          child: Text(
                            sottogruppo.name,
                            style: GoogleFonts.outfit(),
                          ),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedSottogruppoId = value;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}

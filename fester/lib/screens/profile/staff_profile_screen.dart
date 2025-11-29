import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/SupabaseServicies/event_service.dart';
import '../../services/SupabaseServicies/staff_user_service.dart';
import '../../services/SupabaseServicies/models/event_staff.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../theme/app_theme.dart';

class StaffProfileScreen extends StatefulWidget {
  final EventStaff eventStaff;
  final String eventId;

  const StaffProfileScreen({
    super.key,
    required this.eventStaff,
    required this.eventId,
  });

  @override
  State<StaffProfileScreen> createState() => _StaffProfileScreenState();
}

class _StaffProfileScreenState extends State<StaffProfileScreen> {
  final EventService _eventService = EventService();
  late EventStaff _currentStaff;
  bool _isLoading = false;
  bool _canEdit = false;
  bool _isMe = false;

  @override
  void initState() {
    super.initState();
    _currentStaff = widget.eventStaff;
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      setState(() {
        _isMe = userId == _currentStaff.staffUserId;
      });

      try {
        final staffList = await _eventService.getEventStaff(widget.eventId);
        final userStaff = staffList.firstWhere(
          (s) => s.staffUserId == userId,
          orElse:
              () => EventStaff(
                id: '',
                eventId: '',
                staffUserId: '',
                roleId: 0,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
        );

        if (userStaff.roleName?.toLowerCase() == 'admin' ||
            userStaff.roleName?.toLowerCase() == 'staff3') {
          setState(() {
            _canEdit = true;
          });
        }
      } catch (_) {}
    }
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('person_profile.launch_error'.tr())),
        );
      }
    }
  }

  Future<void> _removeStaff() async {
    if (_currentStaff.staffUserId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${'settings.error_prefix'.tr()} ID staff mancante'),
          ),
        );
      }
      return;
    }

    // Prevent admin from removing themselves
    if (_isMe && _currentStaff.roleName?.toLowerCase() == 'admin') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Non puoi rimuoverti da un evento se sei Admin. Degrada il tuo ruolo prima o chiedi a un altro admin.',
            ),
          ),
        );
      }
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('staff.remove_title'.tr()),
            content: Text(
              'Sei sicuro di voler rimuovere ${_currentStaff.staff?.firstName} dallo staff?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('settings.reset_dialog.cancel'.tr()),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text('staff.remove_confirm'.tr()),
              ),
            ],
          ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _eventService.removeStaffFromEvent(
          eventId: widget.eventId,
          staffUserId: _currentStaff.staffUserId!,
        );
        if (mounted) {
          Navigator.pop(context); // Go back to list
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${'settings.error_prefix'.tr()} rimozione staff: $e',
              ),
            ),
          );
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _uploadProfileImage() async {
    final staffUser = _currentStaff.staff;
    if (staffUser == null) {
      debugPrint('[DEBUG] _uploadProfileImage: staffUser is null');
      return;
    }

    debugPrint(
      '[DEBUG] _uploadProfileImage: Starting image upload for user ${staffUser.id}',
    );

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 50,
      );

      if (image == null) {
        debugPrint('[DEBUG] _uploadProfileImage: No image selected');
        return;
      }

      debugPrint('[DEBUG] _uploadProfileImage: Image selected: ${image.path}');
      setState(() => _isLoading = true);

      final bytes = await image.readAsBytes();
      debugPrint(
        '[DEBUG] _uploadProfileImage: Image bytes read: ${bytes.length} bytes',
      );

      final staffService = StaffUserService();

      final imageUrl = await staffService.uploadProfileImage(
        userId: staffUser.id,
        filePath: image.path,
        fileBytes: bytes,
      );

      debugPrint(
        '[DEBUG] _uploadProfileImage: Image uploaded successfully: $imageUrl',
      );

      if (!mounted) return;

      // Update local state immediately to avoid race conditions with DB propagation
      setState(() {
        if (_currentStaff.staff != null) {
          final updatedStaffUser = _currentStaff.staff!.copyWith(
            imagePath: imageUrl,
          );
          _currentStaff = _currentStaff.copyWith(staff: updatedStaffUser);
        }
        _isLoading = false;
      });

      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('staff.image_updated'.tr())));
    } catch (e, stackTrace) {
      debugPrint('[ERROR] _uploadProfileImage: $e');
      debugPrint('[ERROR] Stack trace: $stackTrace');
      if (!mounted) return;
      setState(() => _isLoading = false);
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore caricamento immagine: $e')),
      );
    }
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Elimina Account'),
            content: const Text(
              'Sei sicuro di voler eliminare il tuo account? Questa azione è irreversibile e verrai rimosso da tutti gli eventi.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annulla'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Elimina'),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final staffUser = _currentStaff.staff;
      if (staffUser == null) return;

      debugPrint(
        '[DEBUG] _deleteAccount: Deleting account for user ${staffUser.id}',
      );

      final staffService = StaffUserService();
      await staffService.deactivateStaffUser(staffUser.id);

      debugPrint('[DEBUG] _deleteAccount: Account deleted successfully');

      if (!mounted) return;

      // ignore: use_build_context_synchronously
      Navigator.of(context).popUntil((route) => route.isFirst);

      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account eliminato con successo')),
      );
    } catch (e, stackTrace) {
      debugPrint('[ERROR] _deleteAccount: $e');
      debugPrint('[ERROR] Stack trace: $stackTrace');
      if (!mounted) return;
      setState(() => _isLoading = false);
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore eliminazione account: $e')),
      );
    }
  }

  Future<void> _editRole() async {
    if (!_canEdit || _currentStaff.staffUserId == null) return;

    debugPrint(
      '[DEBUG] _editRole: Starting role edit for user ${_currentStaff.staffUserId}',
    );
    debugPrint(
      '[DEBUG] _editRole: Current role: ${_currentStaff.roleName} (id: ${_currentStaff.roleId})',
    );

    final roles = ['admin', 'staff1', 'staff2', 'staff3'];
    final roleIds = {'admin': 1, 'staff1': 4, 'staff2': 5, 'staff3': 6};

    final currentRoleIndex =
        roles.indexed
            .firstWhere(
              (r) =>
                  r.$2.toLowerCase() ==
                  (_currentStaff.roleName?.toLowerCase() ?? 'staff1'),
              orElse: () => (0, 'staff1'),
            )
            .$1;

    debugPrint('[DEBUG] _editRole: Current role index: $currentRoleIndex');

    int selectedRoleIndex = currentRoleIndex;

    final result = await showDialog<int>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: Text('staff_profile.edit_role'.tr()),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children:
                        roles
                            .asMap()
                            .entries
                            .map(
                              (entry) => RadioListTile<int>(
                                title: Text('roles.${entry.value}'.tr()),
                                value: entry.key,
                                groupValue: selectedRoleIndex,
                                onChanged: (value) {
                                  if (value != null) {
                                    setDialogState(
                                      () => selectedRoleIndex = value,
                                    );
                                  }
                                },
                              ),
                            )
                            .toList(),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('common.cancel'.tr()),
                    ),
                    TextButton(
                      onPressed:
                          () => Navigator.pop(context, selectedRoleIndex),
                      child: Text('common.confirm'.tr()),
                    ),
                  ],
                ),
          ),
    );

    if (result == null || result == currentRoleIndex) {
      debugPrint(
        '[DEBUG] _editRole: Role change cancelled or same role selected',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final newRoleId = roleIds[roles[result]]!;
      debugPrint(
        '[DEBUG] _editRole: Updating role from ${_currentStaff.roleName} (${_currentStaff.roleId}) to ${roles[result]} ($newRoleId)',
      );

      await _eventService.updateStaffRole(
        eventId: widget.eventId,
        staffUserId: _currentStaff.staffUserId!,
        newRoleId: newRoleId,
      );

      debugPrint('[DEBUG] _editRole: Role updated successfully in database');

      if (!mounted) return;

      // Reload staff data
      final updatedStaffList = await _eventService.getEventStaff(
        widget.eventId,
      );
      final updatedStaff = updatedStaffList.firstWhere(
        (s) => s.staffUserId == _currentStaff.staffUserId,
        orElse: () => _currentStaff,
      );

      debugPrint(
        '[DEBUG] _editRole: Staff data reloaded, new role: ${updatedStaff.roleName} (id: ${updatedStaff.roleId})',
      );

      setState(() {
        _currentStaff = updatedStaff;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('staff_profile.role_updated'.tr())),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('[ERROR] _editRole: $e');
      debugPrint('[ERROR] Stack trace: $stackTrace');
      if (!mounted) return;
      setState(() => _isLoading = false);
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${'staff_profile.error_update_role'.tr()} $e')),
      );
    }
  }

  Future<void> _editProfile() async {
    final staffUser = _currentStaff.staff;
    if (staffUser == null) return;

    debugPrint(
      '[DEBUG] _editProfile: Opening edit dialog for user ${staffUser.id}',
    );

    final firstNameController = TextEditingController(
      text: staffUser.firstName,
    );
    final lastNameController = TextEditingController(text: staffUser.lastName);
    final phoneController = TextEditingController(text: staffUser.phone);
    final emailController = TextEditingController(text: staffUser.email);
    DateTime? selectedDate = staffUser.dateOfBirth;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setModalState) => Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                    top: 24,
                    left: 24,
                    right: 24,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'staff_profile.edit_profile'.tr(),
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: firstNameController,
                          decoration: InputDecoration(
                            labelText: 'staff_profile.first_name'.tr(),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: lastNameController,
                          decoration: InputDecoration(
                            labelText: 'staff_profile.last_name'.tr(),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: emailController,
                          decoration: InputDecoration(
                            labelText: 'staff_profile.email'.tr(),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: phoneController,
                          decoration: InputDecoration(
                            labelText: 'staff_profile.phone'.tr(),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 16),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate:
                                  selectedDate ??
                                  DateTime.now().subtract(
                                    const Duration(days: 365 * 18),
                                  ),
                              firstDate: DateTime(1900),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setModalState(() => selectedDate = picked);
                            }
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'staff_profile.date_of_birth'.tr(),
                              border: OutlineInputBorder(),
                              suffixIcon: Icon(Icons.calendar_today),
                            ),
                            child: Text(
                              selectedDate != null
                                  ? '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}'
                                  : 'staff_profile.select_date'.tr(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              debugPrint(
                                '[DEBUG] _editProfile: Saving profile changes',
                              );
                              setState(() => _isLoading = true);
                              // Close the bottom sheet first
                              if (mounted) Navigator.pop(context);

                              try {
                                final staffService = StaffUserService();
                                final updatedStaffUser = await staffService
                                    .updateStaffUser(
                                      userId: staffUser.id,
                                      firstName: firstNameController.text,
                                      lastName: lastNameController.text,
                                      email: emailController.text,
                                      phone: phoneController.text,
                                      dateOfBirth: selectedDate,
                                    );

                                debugPrint(
                                  '[DEBUG] _editProfile: Profile updated successfully',
                                );

                                if (!mounted) return;

                                setState(() {
                                  _currentStaff = _currentStaff.copyWith(
                                    staff: updatedStaffUser,
                                  );
                                  _isLoading = false;
                                });

                                // ignore: use_build_context_synchronously
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'staff_profile.profile_updated'.tr(),
                                    ),
                                  ),
                                );
                              } catch (e, stackTrace) {
                                debugPrint('[ERROR] _editProfile: $e');
                                debugPrint('[ERROR] Stack trace: $stackTrace');
                                if (!mounted) return;
                                // ignore: use_build_context_synchronously
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '${'common.error_update'.tr()}: $e',
                                    ),
                                  ),
                                );
                                setState(() => _isLoading = false);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: Text('common.save'.tr()),
                          ),
                        ),
                        if (_isMe) ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                _deleteAccount();
                              },
                              icon: const Icon(
                                Icons.delete_forever,
                                color: Colors.red,
                              ),
                              label: Text('staff_profile.delete_account'.tr()),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
          ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    IconData icon,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: theme.colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final staffUser = _currentStaff.staff;
    final roleName = _currentStaff.roleName ?? 'Unknown';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: theme.textTheme.bodyLarge?.color,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_isMe)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: _editProfile,
            ),
          if (_canEdit && (!_isMe || roleName.toLowerCase() != 'admin'))
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _removeStaff,
            ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth > 900;

                  if (isDesktop) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(32),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Column: Profile Card
                          Expanded(
                            flex: 1,
                            child: Container(
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                color: theme.cardTheme.color,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: theme.colorScheme.outline.withOpacity(
                                    0.2,
                                  ),
                                ),
                              ),
                              child: Column(
                                children: [
                                  // Avatar
                                  Stack(
                                    children: [
                                      CircleAvatar(
                                        key: ValueKey(
                                          staffUser?.imagePath ?? 'default',
                                        ),
                                        radius: 80,
                                        backgroundColor: theme
                                            .colorScheme
                                            .primary
                                            .withOpacity(0.1),
                                        backgroundImage:
                                            (staffUser?.imagePath != null &&
                                                    staffUser!
                                                        .imagePath!
                                                        .isNotEmpty)
                                                ? NetworkImage(
                                                      staffUser.imagePath!,
                                                    )
                                                    as ImageProvider
                                                : null,
                                        child:
                                            (staffUser?.imagePath == null ||
                                                    staffUser!
                                                        .imagePath!
                                                        .isEmpty)
                                                ? Text(
                                                  (staffUser?.firstName ??
                                                          '?')[0]
                                                      .toUpperCase(),
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 60,
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        theme
                                                            .colorScheme
                                                            .primary,
                                                  ),
                                                )
                                                : null,
                                      ),
                                      if (_isMe)
                                        Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: InkWell(
                                            onTap:
                                                _isMe
                                                    ? _uploadProfileImage
                                                    : null,
                                            child: Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color:
                                                    theme.colorScheme.primary,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color:
                                                      theme
                                                          .scaffoldBackgroundColor,
                                                  width: 3,
                                                ),
                                              ),
                                              child: const Icon(
                                                Icons.camera_alt,
                                                color: Colors.white,
                                                size: 24,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 32),

                                  // Name & Role
                                  Text(
                                    '${staffUser?.firstName} ${staffUser?.lastName}',
                                    style: GoogleFonts.outfit(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: theme.textTheme.bodyLarge?.color,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: InkWell(
                                      onTap:
                                          _canEdit && !_isMe ? _editRole : null,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            AppTheme.roleIcons[roleName
                                                    .toLowerCase()] ??
                                                Icons.badge,
                                            size: 20,
                                            color: theme.colorScheme.primary,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'roles.${roleName.toLowerCase()}'
                                                .tr()
                                                .toUpperCase(),
                                            style: GoogleFonts.outfit(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: theme.colorScheme.primary,
                                            ),
                                          ),
                                          if (_canEdit && !_isMe) ...[
                                            const SizedBox(width: 4),
                                            Icon(
                                              Icons.edit,
                                              size: 16,
                                              color: theme.colorScheme.primary,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 48),
                          // Right Column: Details
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'staff_profile.contact_details'.tr(),
                                  style: GoogleFonts.outfit(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: theme.textTheme.bodyLarge?.color,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                _buildInfoRow(
                                  'staff_profile.email'.tr(),
                                  staffUser?.email ?? 'N/A',
                                  Icons.email_outlined,
                                  theme,
                                ),
                                _buildInfoRow(
                                  'staff_profile.phone'.tr(),
                                  staffUser?.phone ?? 'N/A',
                                  Icons.phone_outlined,
                                  theme,
                                ),
                                _buildInfoRow(
                                  'staff_profile.date_of_birth'.tr(),
                                  staffUser?.dateOfBirth != null
                                      ? '${staffUser!.dateOfBirth!.day}/${staffUser.dateOfBirth!.month}/${staffUser.dateOfBirth!.year}'
                                      : 'N/A',
                                  Icons.cake_outlined,
                                  theme,
                                ),
                                _buildInfoRow(
                                  'staff_profile.member_since'.tr(),
                                  '${_currentStaff.createdAt.day}/${_currentStaff.createdAt.month}/${_currentStaff.createdAt.year}',
                                  Icons.calendar_today_outlined,
                                  theme,
                                ),
                                const SizedBox(height: 32),
                                if (_isMe) ...[
                                  Text(
                                    'staff_profile.actions'.tr(),
                                    style: GoogleFonts.outfit(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: theme.textTheme.bodyLarge?.color,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: _editProfile,
                                      icon: const Icon(Icons.edit),
                                      label: Text(
                                        'staff_profile.edit_profile'.tr(),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  } else {
                    // Mobile Layout
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          // Avatar
                          Stack(
                            children: [
                              CircleAvatar(
                                key: ValueKey(
                                  staffUser?.imagePath ?? 'default',
                                ),
                                radius: 60,
                                backgroundColor: theme.colorScheme.primary
                                    .withOpacity(0.1),
                                backgroundImage:
                                    (staffUser?.imagePath != null &&
                                            staffUser!.imagePath!.isNotEmpty)
                                        ? NetworkImage(staffUser.imagePath!)
                                            as ImageProvider
                                        : null,
                                child:
                                    (staffUser?.imagePath == null ||
                                            staffUser!.imagePath!.isEmpty)
                                        ? Text(
                                          (staffUser?.firstName ?? '?')[0]
                                              .toUpperCase(),
                                          style: GoogleFonts.outfit(
                                            fontSize: 40,
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.primary,
                                          ),
                                        )
                                        : null,
                              ),
                              if (_isMe)
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: InkWell(
                                    onTap: _isMe ? _uploadProfileImage : null,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: theme.scaffoldBackgroundColor,
                                          width: 2,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Name & Role
                          Text(
                            '${staffUser?.firstName} ${staffUser?.lastName}',
                            style: GoogleFonts.outfit(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: theme.textTheme.bodyLarge?.color,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: InkWell(
                              onTap: _canEdit && !_isMe ? _editRole : null,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    AppTheme.roleIcons[roleName
                                            .toLowerCase()] ??
                                        Icons.badge,
                                    size: 16,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'roles.${roleName.toLowerCase()}'
                                        .tr()
                                        .toUpperCase(),
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  if (_canEdit && !_isMe) ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.edit,
                                      size: 14,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Info Cards
                          _buildInfoRow(
                            'staff_profile.email'.tr(),
                            staffUser?.email ?? 'N/A',
                            Icons.email_outlined,
                            theme,
                          ),
                          _buildInfoRow(
                            'staff_profile.phone'.tr(),
                            staffUser?.phone ?? 'N/A',
                            Icons.phone_outlined,
                            theme,
                          ),
                          _buildInfoRow(
                            'staff_profile.date_of_birth'.tr(),
                            staffUser?.dateOfBirth != null
                                ? '${staffUser!.dateOfBirth!.day}/${staffUser.dateOfBirth!.month}/${staffUser.dateOfBirth!.year}'
                                : 'N/A',
                            Icons.cake_outlined,
                            theme,
                          ),
                          _buildInfoRow(
                            'staff_profile.member_since'.tr(),
                            '${_currentStaff.createdAt.day}/${_currentStaff.createdAt.month}/${_currentStaff.createdAt.year}',
                            Icons.calendar_today_outlined,
                            theme,
                          ),

                          const SizedBox(height: 32),
                          if (_isMe) ...[
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _deleteAccount,
                                icon: const Icon(Icons.delete_forever),
                                label: Text(
                                  'staff_profile.delete_account'.tr(),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Contact Actions
                          if (staffUser?.email != null)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed:
                                    () => _launchUrl(
                                      'mailto:${staffUser!.email}',
                                    ),
                                icon: const Icon(Icons.mail),
                                label: Text('staff_profile.send_email'.tr()),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                              ),
                            ),
                          if (staffUser?.phone != null) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed:
                                    () => _launchUrl('tel:${staffUser!.phone}'),
                                icon: const Icon(Icons.phone),
                                label: Text('staff_profile.call'.tr()),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }
                },
              ),
    );
  }
}

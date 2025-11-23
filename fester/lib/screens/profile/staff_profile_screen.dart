import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/SupabaseServicies/event_service.dart';
import '../../services/SupabaseServicies/staff_user_service.dart';
import '../../services/SupabaseServicies/models/event_staff.dart';
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
        final userStaff = staffList.firstWhere((s) => s.staffUserId == userId, orElse: () => EventStaff(id: '', eventId: '', staffUserId: '', roleId: 0, createdAt: DateTime.now(), updatedAt: DateTime.now()));
        
        if (userStaff.roleName?.toLowerCase() == 'admin' || userStaff.roleName?.toLowerCase() == 'staff3') {
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
             const SnackBar(content: Text('Impossibile aprire il link')),
        );
      }
    }
  }

  Future<void> _removeStaff() async {
    if (_currentStaff.staffUserId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore: ID staff mancante')),
        );
      }
      return;
    }

    // Prevent admin from removing themselves
    if (_isMe && _currentStaff.roleName?.toLowerCase() == 'admin') {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Non puoi rimuoverti da un evento se sei Admin. Degrada il tuo ruolo prima o chiedi a un altro admin.')),
        );
      }
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rimuovi Staff'),
        content: Text('Sei sicuro di voler rimuovere ${_currentStaff.staff?.firstName} dallo staff?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annulla')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Rimuovi'),
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
            SnackBar(content: Text('Errore rimozione staff: $e')),
          );
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _uploadProfileImage() async {
    final staffUser = _currentStaff.staff;
    if (staffUser == null) {
      print('[DEBUG] _uploadProfileImage: staffUser is null');
      return;
    }

    print('[DEBUG] _uploadProfileImage: Starting image upload for user ${staffUser.id}');

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image == null) {
        print('[DEBUG] _uploadProfileImage: No image selected');
        return;
      }

      print('[DEBUG] _uploadProfileImage: Image selected: ${image.path}');
      setState(() => _isLoading = true);

      final bytes = await image.readAsBytes();
      print('[DEBUG] _uploadProfileImage: Image bytes read: ${bytes.length} bytes');
      
      final staffService = StaffUserService();
      final imageUrl = await staffService.uploadProfileImage(
        userId: staffUser.id,
        filePath: image.path,
        fileBytes: bytes,
      );

      print('[DEBUG] _uploadProfileImage: Image uploaded successfully: $imageUrl');

      if (!mounted) return;
      
      // Reload staff data
      final updatedStaffList = await _eventService.getEventStaff(widget.eventId);
      final updatedStaff = updatedStaffList.firstWhere(
        (s) => s.staffUserId == _currentStaff.staffUserId,
        orElse: () => _currentStaff,
      );

      print('[DEBUG] _uploadProfileImage: Staff data reloaded, new image path: ${updatedStaff.staff?.imagePath}');

      setState(() {
        _currentStaff = updatedStaff;
        _isLoading = false;
      });

      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Immagine profilo aggiornata!')),
      );
    } catch (e, stackTrace) {
      print('[ERROR] _uploadProfileImage: $e');
      print('[ERROR] Stack trace: $stackTrace');
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
      builder: (context) => AlertDialog(
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

      print('[DEBUG] _deleteAccount: Deleting account for user ${staffUser.id}');

      final staffService = StaffUserService();
      await staffService.deactivateStaffUser(staffUser.id);

      print('[DEBUG] _deleteAccount: Account deleted successfully');

      if (!mounted) return;

      // ignore: use_build_context_synchronously
      Navigator.of(context).popUntil((route) => route.isFirst);
      
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account eliminato con successo')),
      );
    } catch (e, stackTrace) {
      print('[ERROR] _deleteAccount: $e');
      print('[ERROR] Stack trace: $stackTrace');
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

    print('[DEBUG] _editRole: Starting role edit for user ${_currentStaff.staffUserId}');
    print('[DEBUG] _editRole: Current role: ${_currentStaff.roleName} (id: ${_currentStaff.roleId})');

    final roles = ['admin', 'staff1', 'staff2', 'staff3'];
    final roleIds = {'admin': 1, 'staff1': 4, 'staff2': 5, 'staff3': 6};
    
    final currentRoleIndex = roles.indexed
        .firstWhere(
          (r) => r.$2.toLowerCase() == (_currentStaff.roleName?.toLowerCase() ?? 'staff1'),
          orElse: () => (0, 'staff1'),
        )
        .$1;

    print('[DEBUG] _editRole: Current role index: $currentRoleIndex');

    int selectedRoleIndex = currentRoleIndex;

    final result = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Modifica Ruolo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: roles
                .asMap()
                .entries
                .map((entry) => RadioListTile<int>(
                      title: Text(entry.value.toUpperCase()),
                      value: entry.key,
                      groupValue: selectedRoleIndex,
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => selectedRoleIndex = value);
                        }
                      },
                    ))
                .toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, selectedRoleIndex),
              child: const Text('Conferma'),
            ),
          ],
        ),
      ),
    );

    if (result == null || result == currentRoleIndex) {
      print('[DEBUG] _editRole: Role change cancelled or same role selected');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final newRoleId = roleIds[roles[result]]!;
      print('[DEBUG] _editRole: Updating role from ${_currentStaff.roleName} (${_currentStaff.roleId}) to ${roles[result]} ($newRoleId)');
      
      await _eventService.updateStaffRole(
        eventId: widget.eventId,
        staffUserId: _currentStaff.staffUserId!,
        newRoleId: newRoleId,
      );

      print('[DEBUG] _editRole: Role updated successfully in database');

      if (!mounted) return;

      // Reload staff data
      final updatedStaffList = await _eventService.getEventStaff(widget.eventId);
      final updatedStaff = updatedStaffList.firstWhere(
        (s) => s.staffUserId == _currentStaff.staffUserId,
        orElse: () => _currentStaff,
      );

      print('[DEBUG] _editRole: Staff data reloaded, new role: ${updatedStaff.roleName} (id: ${updatedStaff.roleId})');

      setState(() {
        _currentStaff = updatedStaff;
        _isLoading = false;
      });

      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ruolo aggiornato!')),
      );
    } catch (e, stackTrace) {
      print('[ERROR] _editRole: $e');
      print('[ERROR] Stack trace: $stackTrace');
      if (!mounted) return;
      setState(() => _isLoading = false);
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore aggiornamento ruolo: $e')),
      );
    }
  }

  Future<void> _editProfile() async {
    final staffUser = _currentStaff.staff;
    if (staffUser == null) return;

    print('[DEBUG] _editProfile: Opening edit dialog for user ${staffUser.id}');

    final firstNameController = TextEditingController(text: staffUser.firstName);
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
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
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
                  'Modifica Profilo',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: firstNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: lastNameController,
                  decoration: const InputDecoration(
                    labelText: 'Cognome',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Telefono',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate ?? DateTime.now().subtract(const Duration(days: 365 * 18)),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setModalState(() => selectedDate = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Data di Nascita',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      selectedDate != null
                          ? '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}'
                          : 'Seleziona data',
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      print('[DEBUG] _editProfile: Saving profile changes');
                      setState(() => _isLoading = true);
                      // Close the bottom sheet first
                      if (mounted) Navigator.pop(context);
                      
                      try {
                        final staffService = StaffUserService();
                        await staffService.updateStaffUser(
                          userId: staffUser.id,
                          firstName: firstNameController.text,
                          lastName: lastNameController.text,
                          email: emailController.text,
                          phone: phoneController.text,
                          dateOfBirth: selectedDate,
                        );
                        
                        print('[DEBUG] _editProfile: Profile updated successfully');

                        // Reload staff data
                        final updatedStaffList = await _eventService.getEventStaff(widget.eventId);
                        final updatedStaff = updatedStaffList.firstWhere(
                          (s) => s.staffUserId == staffUser.id,
                          orElse: () => _currentStaff,
                        );

                        if (!mounted) return;
                        
                        setState(() {
                          _currentStaff = updatedStaff;
                          _isLoading = false;
                        });

                        // ignore: use_build_context_synchronously
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Profilo aggiornato con successo!')),
                        );
                      } catch (e, stackTrace) {
                        print('[ERROR] _editProfile: $e');
                        print('[ERROR] Stack trace: $stackTrace');
                        if (!mounted) return;
                        // ignore: use_build_context_synchronously
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Errore aggiornamento: $e')),
                        );
                        setState(() => _isLoading = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('SALVA'),
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
                      icon: const Icon(Icons.delete_forever, color: Colors.red),
                      label: const Text('ELIMINA ACCOUNT'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 16),
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

  Widget _buildInfoRow(String label, String value, IconData icon, ThemeData theme) {
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
          icon: Icon(Icons.arrow_back_ios, color: theme.textTheme.bodyLarge?.color),
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Avatar
                  Stack(
                    children: [
                      CircleAvatar(
                        key: ValueKey(staffUser?.imagePath ?? 'default'),
                        radius: 60,
                        backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                        backgroundImage: (staffUser?.imagePath != null && staffUser!.imagePath!.isNotEmpty)
                            ? NetworkImage(staffUser.imagePath!) as ImageProvider
                            : null,
                        child: (staffUser?.imagePath == null || staffUser!.imagePath!.isEmpty)
                            ? Text(
                                (staffUser?.firstName ?? '?')[0].toUpperCase(),
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
                                border: Border.all(color: theme.scaffoldBackgroundColor, width: 2),
                              ),
                              child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                            AppTheme.roleIcons[roleName.toLowerCase()] ?? Icons.badge,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            roleName.toUpperCase(),
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
                  
                  const SizedBox(height: 40),
                  
                  // Details
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: theme.cardTheme.color,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow('Email', staffUser?.email ?? 'N/D', Icons.email_outlined, theme),
                        if (staffUser?.phone != null)
                          _buildInfoRow('Telefono', staffUser!.phone!, Icons.phone_outlined, theme),
                        _buildInfoRow('Assegnato da', 'Admin', Icons.admin_panel_settings_outlined, theme), // TODO: Fetch assigned_by name
                        _buildInfoRow('Data Assegnazione', _currentStaff.createdAt.toString().split(' ')[0], Icons.calendar_today_outlined, theme),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Actions
                  if (staffUser?.email != null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _launchUrl('mailto:${staffUser!.email}'),
                        icon: const Icon(Icons.mail),
                        label: const Text('INVIA EMAIL'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  if (staffUser?.phone != null) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _launchUrl('tel:${staffUser!.phone}'),
                        icon: const Icon(Icons.phone),
                        label: const Text('CHIAMA'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

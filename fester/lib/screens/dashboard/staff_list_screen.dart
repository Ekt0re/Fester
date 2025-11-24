import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/SupabaseServicies/event_service.dart';
import '../../services/SupabaseServicies/models/event_staff.dart';
import '../../theme/app_theme.dart';
import 'widgets/staff_card.dart';
import '../profile/staff_profile_screen.dart';
import '../create_event/staff_management_screen.dart';

class StaffListScreen extends StatefulWidget {
  final String eventId;

  const StaffListScreen({super.key, required this.eventId});

  @override
  State<StaffListScreen> createState() => _StaffListScreenState();
}

class _StaffListScreenState extends State<StaffListScreen> {
  final EventService _eventService = EventService();
  final TextEditingController _searchController = TextEditingController();
  String? _roleFilter; // null = tutti i ruoli

  List<EventStaff> _allStaff = [];
  List<EventStaff> _filteredStaff = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final staffList = await _eventService.getEventStaff(widget.eventId);
      if (mounted) {
        setState(() {
          _allStaff = staffList;
          _filteredStaff = staffList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore caricamento staff: $e')),
        );
      }
    }
  }

  void _filterList(String query) {
    setState(() {
      List<EventStaff> source = _allStaff;
      if (query.isNotEmpty) {
        final q = query.toLowerCase();
        source = source.where((s) {
          final name = (s.staff?.firstName ?? '').toLowerCase();
          final surname = (s.staff?.lastName ?? '').toLowerCase();
          final email = (s.staff?.email ?? '').toLowerCase();
          final role = (s.roleName ?? '').toLowerCase();
          return name.contains(q) || surname.contains(q) || email.contains(q) || role.contains(q);
        }).toList();
      }
      if (_roleFilter != null && _roleFilter != 'Tutti') {
        final roleLower = _roleFilter!.toLowerCase();
        source = source.where((s) => (s.roleName ?? '').toLowerCase() == roleLower).toList();
      }
      _filteredStaff = source;
    });
  }

  Widget _buildStaffItem(BuildContext context, int index) {
    final staffMember = _filteredStaff[index];
    final staffUser = staffMember.staff;
    final roleName = staffMember.roleName ?? 'Unknown';
    final isPending = staffUser == null;

    return StaffCard(
      name: isPending ? (staffMember.mail ?? 'No Email') : (staffUser.firstName ?? 'Unknown'),
      surname: isPending ? '' : (staffUser.lastName ?? ''),
      role: roleName,
      imageUrl: staffUser?.imagePath,
      isPending: isPending,
      onTap: () async {
        if (isPending) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Utente in attesa di registrazione')),
          );
          return;
        }
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StaffProfileScreen(
              eventStaff: staffMember,
              eventId: widget.eventId,
            ),
          ),
        );
        _loadData();
      },
    );
  }

  // TODO: sostituire con controllo reale dei ruoli (admin o staff3)
  bool get _canAddStaff => true;

  Future<void> _showAddStaffDialog() async {
    final emailController = TextEditingController();
    String selectedRole = 'Staff1';
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aggiungi Staff'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'Inserisci email collaboratore',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Email richiesta';
                  if (!value.contains('@')) return 'Email non valida';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedRole,
                decoration: const InputDecoration(labelText: 'Ruolo'),
                items: ['Staff1', 'Staff2', 'Staff3']
                    .map((role) => DropdownMenuItem(
                          value: role,
                          child: Text(role),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) selectedRole = value;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context);
                await _addStaffMember(
                    emailController.text.trim(), selectedRole);
              }
            },
            child: const Text('Aggiungi'),
          ),
        ],
      ),
    );
  }

  Future<void> _addStaffMember(String email, String roleName) async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;

      // Map UI role name to DB role name
      String dbRoleName = 'staff1';
      switch (roleName) {
        case 'Staff2':
          dbRoleName = 'staff2';
          break;
        case 'Staff3':
          dbRoleName = 'staff3';
          break;
      }

      // Get role ID from DB
      final roleResponse = await supabase
          .from('role')
          .select('id')
          .eq('name', dbRoleName)
          .maybeSingle();

      if (roleResponse == null) {
        throw Exception('Ruolo non trovato: $dbRoleName');
      }

      final roleId = roleResponse['id'];

      await supabase.from('event_staff').insert({
        'event_id': widget.eventId,
        'role_id': roleId,
        'mail': email,
        'assigned_by': supabase.auth.currentUser?.id,
      });

      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Staff aggiunto con successo')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore durante l\'aggiunta: $e')),
        );
      }
      setState(() => _isLoading = false);
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
        title: Column(
          children: [
            Text(
              'Staff Evento',
              style: GoogleFonts.outfit(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.bold),
            ),
            Text(
              'Totale: ${_allStaff.length}',
              style: GoogleFonts.outfit(color: theme.colorScheme.onPrimary.withOpacity(0.7), fontSize: 12),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.sync, color: theme.colorScheme.onPrimary),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search field
          Container(
            padding: const EdgeInsets.all(16),
            color: theme.colorScheme.primary.withOpacity(0.1),
            child: TextField(
              controller: _searchController,
              onChanged: _filterList,
              decoration: InputDecoration(
                hintText: 'Cerca membro staff...',
                prefixIcon: const Icon(Icons.search),
                fillColor: theme.colorScheme.surface,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Role filter dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _roleFilter ?? 'Tutti',
                isExpanded: true,
                items: ['Tutti', 'Staff1', 'Staff2', 'Staff3']
                    .map((role) => DropdownMenuItem<String>(
                          value: role,
                          child: Text(role),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _roleFilter = value == 'Tutti' ? null : value;
                    _filterList(_searchController.text);
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          // List of staff
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth > 900) {
                        return Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1200),
                            child: GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 3.5,
                              ),
                              itemCount: _filteredStaff.length,
                              itemBuilder: _buildStaffItem,
                            ),
                          ),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredStaff.length,
                        itemBuilder: _buildStaffItem,
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: Visibility(
        visible: _canAddStaff,
        child: FloatingActionButton.extended(
          onPressed: _showAddStaffDialog,
          icon: const Icon(Icons.add),
          label: const Text('Aggiungi Staff'),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import '../../services/supabase/event_service.dart';
import '../../services/supabase/models/event_staff.dart';
import 'widgets/staff_card.dart';
import '../profile/staff_profile_screen.dart';
import '../../services/permission_service.dart';

class StaffListScreen extends StatefulWidget {
  final String eventId;
  final String? currentUserRole;

  const StaffListScreen({
    super.key,
    required this.eventId,
    this.currentUserRole,
  });

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${'staff.load_error'.tr()}$e')));
      }
    }
  }

  void _filterList(String query) {
    setState(() {
      List<EventStaff> source = _allStaff;
      if (query.isNotEmpty) {
        final q = query.toLowerCase();
        source =
            source.where((s) {
              final name = (s.staff?.firstName ?? '').toLowerCase();
              final surname = (s.staff?.lastName ?? '').toLowerCase();
              final email = (s.staff?.email ?? '').toLowerCase();
              final role = (s.roleName ?? '').toLowerCase();
              return name.contains(q) ||
                  surname.contains(q) ||
                  email.contains(q) ||
                  role.contains(q);
            }).toList();
      }
      if (_roleFilter != null && _roleFilter != 'staff.all_roles'.tr()) {
        final roleLower = _roleFilter!.toLowerCase();
        source =
            source
                .where((s) => (s.roleName ?? '').toLowerCase() == roleLower)
                .toList();
      }
      _filteredStaff = source;
    });
  }

  Widget _buildStaffItem(BuildContext context, int index) {
    final staffMember = _filteredStaff[index];
    final staffUser = staffMember.staff;
    final roleName = staffMember.roleName;
    final isPending = staffUser == null;

    return StaffCard(
      name:
          isPending
              ? (staffMember.mail ?? 'common.no_email'.tr())
              : staffUser.firstName,
      surname: isPending ? '' : staffUser.lastName,
      role: roleName ?? 'common.unknown'.tr(),
      imageUrl: staffUser?.imagePath,
      isPending: isPending,
      onTap: () async {
        if (isPending) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('staff.pending_user'.tr())));
          return;
        }
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => StaffProfileScreen(
                  eventStaff: staffMember,
                  eventId: widget.eventId,
                ),
          ),
        );
        _loadData();
      },
    );
  }

  bool get _canAddStaff {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return false;

    try {
      final currentUserStaff = _allStaff.firstWhere(
        (s) => s.staff?.id == currentUserId,
      );
      final role = currentUserStaff.roleName;
      return PermissionService.canAdd(role);
    } catch (_) {
      return false;
    }
  }

  Future<void> _showAddStaffDialog() async {
    final emailController = TextEditingController();
    String selectedRole = 'roles.staff1';
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('staff.add_dialog_title'.tr()),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: 'staff.email_label'.tr(),
                      hintText: 'staff.email_hint'.tr(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'staff.email_required'.tr();
                      }
                      if (!value.contains('@')) {
                        return 'staff.email_invalid'.tr();
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    decoration: InputDecoration(
                      labelText: 'staff.role_label'.tr(),
                    ),
                    items:
                        ['roles.staff1', 'roles.staff2', 'roles.staff3']
                            .map(
                              (roleKey) => DropdownMenuItem(
                                value: roleKey,
                                child: Text(roleKey.tr()),
                              ),
                            )
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
                child: Text('staff.cancel'.tr()),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(context);
                    await _addStaffMember(
                      emailController.text.trim(),
                      selectedRole,
                    );
                  }
                },
                child: Text('staff.add'.tr()),
              ),
            ],
          ),
    );
  }

  Future<void> _addStaffMember(String email, String roleName) async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;

      // Map UI role key to DB role name
      String dbRoleName = 'staff1';
      switch (roleName) {
        case 'roles.staff2':
          dbRoleName = 'staff2';
          break;
        case 'roles.staff3':
          dbRoleName = 'staff3';
          break;
      }

      // Get role ID from DB
      final roleResponse =
          await supabase
              .from('role')
              .select('id')
              .eq('name', dbRoleName)
              .maybeSingle();

      if (roleResponse == null) {
        throw Exception('${'staff.role_not_found'.tr()}$dbRoleName');
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('staff.success'.tr())));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${'staff.error'.tr()}$e')));
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
              'staff.title'.tr(),
              style: GoogleFonts.outfit(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${'staff.total'.tr()}${_allStaff.length}',
              style: GoogleFonts.outfit(
                color: theme.colorScheme.onPrimary.withOpacity(0.7),
                fontSize: 12,
              ),
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
          // Invite section
          if (_canAddStaff) _buildInviteSection(theme),
          // Search field
          Container(
            padding: const EdgeInsets.all(16),
            color: theme.colorScheme.primary.withOpacity(0.1),
            child: TextField(
              controller: _searchController,
              onChanged: _filterList,
              decoration: InputDecoration(
                hintText: 'staff.search_placeholder'.tr(),
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
                value: _roleFilter ?? 'staff.all_roles'.tr(),
                isExpanded: true,
                items:
                    [
                          'staff.all_roles'.tr(),
                          'roles.staff1',
                          'roles.staff2',
                          'roles.staff3',
                        ]
                        .map(
                          (role) => DropdownMenuItem<String>(
                            value: role,
                            child: Text(
                              role.startsWith('roles.') ? role.tr() : role,
                            ),
                          ),
                        )
                        .toList(),
                onChanged: (value) {
                  setState(() {
                    _roleFilter =
                        value == 'staff.all_roles'.tr() ? null : value;
                    _filterList(_searchController.text);
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          // List of staff
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth > 900) {
                          return Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1200),
                              child: GridView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  16,
                                  100,
                                ),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
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
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
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
        child: Padding(
          padding: const EdgeInsets.only(bottom: 80.0),
          child: FloatingActionButton.extended(
            onPressed: _showAddStaffDialog,
            icon: const Icon(Icons.add),
            label: Text('staff.add_button'.tr()),
          ),
        ),
      ),
    );
  }

  Widget _buildInviteSection(ThemeData theme) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final String baseInviteLink =
        'https://fester.netlify.app/invite/staff/${widget.eventId}/$currentUserId';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Card(
        elevation: 0,
        color: theme.colorScheme.primary.withOpacity(0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.2)),
        ),
        child: ExpansionTile(
          title: Text(
            'staff.invite_link_section_title'.tr(),
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          leading: const Icon(Icons.link_rounded),
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildInviteOption(
                theme,
                'roles.staff1',
                'staff.roles_description.staff1',
                baseInviteLink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInviteOption(
    ThemeData theme,
    String roleKey,
    String descKey,
    String link,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                roleKey.tr(),
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 20),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: link));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('create_event.link_copied'.tr())),
                    );
                  }
                },
                tooltip: 'create_event.copy_link'.tr(),
              ),
            ],
          ),
          Text(
            descKey.tr(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}

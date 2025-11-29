import 'package:fester/services/SupabaseServicies/models/event_staff.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class StaffManagementScreen extends StatefulWidget {
  final List<EventStaff> initialStaff;
  final Function(List<EventStaff>) onStaffUpdated;

  const StaffManagementScreen({
    super.key,
    required this.initialStaff,
    required this.onStaffUpdated,
  });

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  final List<StaffMemberUI> _staffList = [];
  final Set<String> _expandedItems = {};
  final Set<String> _confirmedItems = {};

  @override
  void initState() {
    super.initState();
    _initializeStaffList();
  }

  void _initializeStaffList() {
    if (widget.initialStaff.isNotEmpty) {
      for (var staff in widget.initialStaff) {
        final uiModel = StaffMemberUI(
          id: staff.id,
          email: staff.mail ?? '',
          role: _mapRoleIdToRoleName(staff.roleId),
          isExisting: true,
        );
        _staffList.add(uiModel);
        _confirmedItems.add(uiModel.id);
      }
    }
  }

  String _mapRoleIdToRoleName(int roleId) {
    // Mappatura temporanea, idealmente dovrebbe venire dal DB o config
    switch (roleId) {
      case 3:
        return 'Staff3';
      case 2:
        return 'Staff2';
      case 1:
      default:
        return 'Staff1';
    }
  }

  int _mapRoleNameToRoleId(String roleName) {
    switch (roleName) {
      case 'Staff3':
        return 3;
      case 'Staff2':
        return 2;
      case 'Staff1':
      default:
        return 1;
    }
  }

  void _addNewMember() {
    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    setState(() {
      _staffList.add(StaffMemberUI(id: newId, email: '', role: 'Staff1'));
      _expandedItems.add(newId);
    });
  }

  void _removeMember(String id) {
    setState(() {
      _staffList.removeWhere((item) => item.id == id);
      _expandedItems.remove(id);
      _confirmedItems.remove(id);
    });
    _notifyParent();
  }

  void _toggleExpand(String id) {
    setState(() {
      if (_expandedItems.contains(id)) {
        _expandedItems.remove(id);
      } else {
        _expandedItems.add(id);
      }
    });
  }

  void _confirmMember(String id) {
    setState(() {
      _confirmedItems.add(id);
      _expandedItems.remove(id);
    });
    _notifyParent();
  }

  void _notifyParent() {
    final List<EventStaff> eventStaffList =
        _staffList.map((uiMember) {
          return EventStaff(
            id: uiMember.id, // ID temporaneo per i nuovi, reale per esistenti
            eventId: '', // Sarà impostato dal parent o al salvataggio
            staffUserId: null, // Gestito dal trigger DB
            roleId: _mapRoleNameToRoleId(uiMember.role),
            mail: uiMember.email,
            createdAt: DateTime.now(),
          );
        }).toList();
    widget.onStaffUpdated(eventStaffList);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'staff.management_title'.tr(),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    'staff.members_count'.tr(
                      args: [_staffList.length.toString()],
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_staffList.isEmpty)
                _buildEmptyState(theme)
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _staffList.length,
                  separatorBuilder:
                      (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final member = _staffList[index];
                    return _StaffMemberCard(
                      key: ValueKey(member.id),
                      member: member,
                      isExpanded: _expandedItems.contains(member.id),
                      isConfirmed: _confirmedItems.contains(member.id),
                      onExpand: () => _toggleExpand(member.id),
                      onDelete: () => _removeMember(member.id),
                      onConfirm: () => _confirmMember(member.id),
                      onUpdate: (updatedMember) {
                        setState(() {
                          _staffList[index] = updatedMember;
                        });
                      },
                    );
                  },
                ),
              const SizedBox(height: 24),
              _buildAddButton(theme),
              const SizedBox(height: 24),
              _buildConfirmButton(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.people_outline,
              size: 48,
              color: theme.colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 12),
            Text(
              'staff.empty_title'.tr(),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            Text(
              'staff.empty_subtitle'.tr(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton(ThemeData theme) {
    return InkWell(
      onTap: _addNewMember,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.primary.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(12),
          color: theme.colorScheme.primary.withOpacity(0.1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'staff.add_member'.tr(),
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmButton(ThemeData theme) {
    return ElevatedButton(
      onPressed: () => Navigator.of(context).pop(),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        minimumSize: const Size(double.infinity, 50),
      ),
      child: Text(
        'staff.confirm'.tr(),
        style: theme.textTheme.titleMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class StaffMemberUI {
  final String id;
  String email;
  String role;
  bool isExisting;

  StaffMemberUI({
    required this.id,
    required this.email,
    required this.role,
    this.isExisting = false,
  });
}

class _StaffMemberCard extends StatefulWidget {
  final StaffMemberUI member;
  final bool isExpanded;
  final bool isConfirmed;
  final VoidCallback onExpand;
  final VoidCallback onDelete;
  final VoidCallback onConfirm;
  final Function(StaffMemberUI) onUpdate;

  const _StaffMemberCard({
    super.key,
    required this.member,
    required this.isExpanded,
    required this.isConfirmed,
    required this.onExpand,
    required this.onDelete,
    required this.onConfirm,
    required this.onUpdate,
  });

  @override
  State<_StaffMemberCard> createState() => _StaffMemberCardState();
}

class _StaffMemberCardState extends State<_StaffMemberCard> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _emailController;
  late String _selectedRole;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.member.email);
    _selectedRole = widget.member.role;
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _handleSave() {
    if (_formKey.currentState?.validate() ?? false) {
      widget.member.email = _emailController.text.trim();
      widget.member.role = _selectedRole;
      widget.onUpdate(widget.member);
      widget.onConfirm();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isExpanded = widget.isExpanded;
    final isConfirmed = widget.isConfirmed;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              isConfirmed
                  ? theme.colorScheme.primary.withOpacity(0.5)
                  : theme.colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: widget.onExpand,
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(12),
              bottom: Radius.circular(isExpanded ? 0 : 12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:
                          isConfirmed
                              ? theme.colorScheme.primary.withOpacity(0.2)
                              : theme.colorScheme.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person_outline,
                      color:
                          isConfirmed
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.member.email.isEmpty
                              ? 'staff.new_member'.tr()
                              : widget.member.email,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (widget.member.email.isNotEmpty)
                          Text(
                            widget.member.role,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: theme.colorScheme.error,
                    ),
                    onPressed: widget.onDelete,
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ],
              ),
            ),
          ),
          // Expanded Content
          if (isExpanded)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outline.withOpacity(0.1),
                  ),
                ),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTextField(
                      theme: theme,
                      controller: _emailController,
                      label: 'staff.email_label'.tr(),
                      hint: 'staff.email_hint'.tr(),
                      icon: Icons.email_outlined,
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
                    _buildRoleDropdown(theme),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _handleSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'staff.confirm'.tr(),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required ThemeData theme,
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.3),
            ),
            prefixIcon: Icon(
              icon,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
            filled: true,
            fillColor: theme.colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.colorScheme.primary),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.colorScheme.error),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleDropdown(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'staff.role_label'.tr(),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedRole,
              dropdownColor: theme.cardTheme.color,
              isExpanded: true,
              icon: Icon(
                Icons.keyboard_arrow_down,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
              items:
                  ['Staff1', 'Staff2', 'Staff3'].map((String role) {
                    return DropdownMenuItem<String>(
                      value: role,
                      child: Row(
                        children: [
                          Icon(
                            Icons.badge_outlined,
                            size: 18,
                            color:
                                _selectedRole == role
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface.withOpacity(
                                      0.6,
                                    ),
                          ),
                          const SizedBox(width: 12),
                          Text(role),
                        ],
                      ),
                    );
                  }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedRole = newValue;
                  });
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}

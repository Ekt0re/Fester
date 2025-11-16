// lib/screens/create_event/staff_management_screen.dart
import 'package:flutter/material.dart';

class StaffMember {
  String? id;
  String email;
  String role;
  bool isExpanded;

  StaffMember({
    this.id,
    required this.email,
    required this.role,
    this.isExpanded = false,
  });

  Map<String, dynamic> toJson() {
    return {'id': id, 'email': email, 'role': role};
  }

  factory StaffMember.fromJson(Map<String, dynamic> json) {
    return StaffMember(
      id: json['id'],
      email: json['email'],
      role: json['role'],
    );
  }
}

class StaffManagementScreen extends StatefulWidget {
  final List<StaffMember> initialStaff;
  final Function(List<StaffMember>) onStaffUpdated;

  const StaffManagementScreen({
    Key? key,
    required this.initialStaff,
    required this.onStaffUpdated,
  }) : super(key: key);

  @override
  _StaffManagementScreenState createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  late List<StaffMember> _staffList;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  String _selectedRole = 'Staff1';

  // Ruoli disponibili con descrizioni
  final Map<String, String> _availableRoles = {
    'Staff1': 'Staff livello 1 - Permessi limitati (solo lettura + transazioni)',
    'Staff2': 'Staff livello 2 - Permessi medi (gestione partecipanti + menu)',
    'Staff3': 'Staff livello 3 - Permessi avanzati (gestione eventi completa)',
  };

  @override
  void initState() {
    super.initState();
    _staffList = List.from(widget.initialStaff);
  }

  void _addStaff() {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _staffList.add(
          StaffMember(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            email: _emailController.text.trim(),
            role: _selectedRole,
          ),
        );
        _emailController.clear();
        _selectedRole = 'Staff1';
      });
      widget.onStaffUpdated(_staffList);
    }
  }

  void _editStaff(int index) {
    final member = _staffList[index];
    _emailController.text = member.email;
    _selectedRole = member.role;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Modifica Staff'),
            content: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Inserisci un\'email valida';
                      }
                      if (!RegExp(
                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                      ).hasMatch(value)) {
                        return 'Inserisci un\'email valida';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Ruolo',
                      border: OutlineInputBorder(),
                    ),
                    items:
                        _availableRoles.keys.map((role) {
                          return DropdownMenuItem(
                            value: role,
                            child: Text(role),
                          );
                        }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedRole = value);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _emailController.clear();
                  _selectedRole = 'Staff1';
                  Navigator.pop(context);
                },
                child: const Text('Annulla'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState?.validate() ?? false) {
                    setState(() {
                      _staffList[index] = StaffMember(
                        id: member.id,
                        email: _emailController.text.trim(),
                        role: _selectedRole,
                      );
                      _emailController.clear();
                      _selectedRole = 'Staff1';
                    });
                    widget.onStaffUpdated(_staffList);
                    Navigator.pop(context);
                  }
                },
                child: const Text('Salva'),
              ),
            ],
          ),
    );
  }

  void _removeStaff(String id) {
    setState(() {
      _staffList.removeWhere((member) => member.id == id);
    });
    widget.onStaffUpdated(_staffList);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFB8D4E8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFB8D4E8),
        elevation: 0,
        title: const Text('Gestisci Staff'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Conferma',
          ),
        ],
      ),
      body: Column(
        children: [
          // Info box con spiegazione ruoli
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue),
                    SizedBox(width: 8),
                    Text(
                      'Ruoli disponibili',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ..._availableRoles.entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '• ${entry.key}: ',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Expanded(
                          child: Text(
                            entry.value,
                            style: const TextStyle(color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Form aggiunta staff
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black12),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'staff@example.com',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Inserisci un\'email valida';
                      }
                      if (!RegExp(
                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                      ).hasMatch(value)) {
                        return 'Inserisci un\'email valida';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Ruolo',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.badge),
                    ),
                    items:
                        _availableRoles.keys.map((role) {
                          return DropdownMenuItem(
                            value: role,
                            child: Text(role),
                          );
                        }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedRole = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _addStaff,
                    icon: const Icon(Icons.add),
                    label: const Text('Aggiungi Staff'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.black87,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Lista staff
          Expanded(
            child:
                _staffList.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 64,
                            color: Colors.black26,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Nessuno staff aggiunto',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _staffList.length,
                      itemBuilder: (context, index) {
                        final member = _staffList[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(12),
                            leading: CircleAvatar(
                              backgroundColor: Colors.black87,
                              child: Text(
                                member.email[0].toUpperCase(),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(
                              member.email,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              member.role,
                              style: const TextStyle(color: Colors.black54),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () => _editStaff(index),
                                  tooltip: 'Modifica',
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => _removeStaff(member.id!),
                                  tooltip: 'Rimuovi',
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }
}

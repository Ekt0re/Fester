import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/supabase/person_service.dart';
import 'person_profile_screen.dart';

class GroupMembersScreen extends StatefulWidget {
  final int groupId;
  final String groupName;
  final bool isSubgroup;
  final String eventId;

  const GroupMembersScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.isSubgroup,
    required this.eventId,
  });

  @override
  State<GroupMembersScreen> createState() => _GroupMembersScreenState();
}

class _GroupMembersScreenState extends State<GroupMembersScreen> {
  final PersonService _personService = PersonService();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _allMembers = [];
  List<Map<String, dynamic>> _filteredMembers = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final members =
          widget.isSubgroup
              ? await _personService.getSubgroupMembers(widget.groupId)
              : await _personService.getGroupMembers(widget.groupId);

      if (mounted) {
        setState(() {
          _allMembers = members;
          _filteredMembers = members;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Errore durante il caricamento: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _filterMembers(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredMembers = _allMembers;
      } else {
        final lowerQuery = query.toLowerCase();
        _filteredMembers =
            _allMembers.where((member) {
              final firstName =
                  (member['first_name'] ?? '').toString().toLowerCase();
              final lastName =
                  (member['last_name'] ?? '').toString().toLowerCase();
              final email = (member['email'] ?? '').toString().toLowerCase();
              final phone = (member['phone'] ?? '').toString().toLowerCase();

              return firstName.contains(lowerQuery) ||
                  lastName.contains(lowerQuery) ||
                  email.contains(lowerQuery) ||
                  phone.contains(lowerQuery);
            }).toList();
      }
    });
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isSubgroup ? 'Sottogruppo' : 'Gruppo',
              style: GoogleFonts.outfit(
                color: theme.colorScheme.onPrimary.withOpacity(0.8),
                fontSize: 14,
              ),
            ),
            Text(
              widget.groupName,
              style: GoogleFonts.outfit(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          if (!_isLoading && _filteredMembers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onPrimary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_filteredMembers.length}',
                    style: GoogleFonts.outfit(
                      color: theme.colorScheme.onPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cerca membro...',
                hintStyle: GoogleFonts.outfit(),
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: theme.colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixIcon:
                    _searchController.text.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _filterMembers('');
                          },
                        )
                        : null,
              ),
              onChanged: _filterMembers,
              style: GoogleFonts.outfit(),
            ),
          ),

          // Content
          Expanded(child: _buildContent(theme)),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage,
                style: GoogleFonts.outfit(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadMembers,
              icon: const Icon(Icons.refresh),
              label: Text('Riprova', style: GoogleFonts.outfit()),
            ),
          ],
        ),
      );
    }

    if (_filteredMembers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchController.text.isEmpty
                  ? Icons.group_off
                  : Icons.search_off,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isEmpty
                  ? 'Nessun membro in questo ${widget.isSubgroup ? "sottogruppo" : "gruppo"}'
                  : 'Nessun risultato trovato',
              style: GoogleFonts.outfit(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filteredMembers.length,
      itemBuilder: (context, index) {
        return _buildMemberCard(_filteredMembers[index], theme);
      },
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> member, ThemeData theme) {
    final fullName = '${member['first_name']} ${member['last_name']}';
    final email = member['email']?.toString();
    final phone = member['phone']?.toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => PersonProfileScreen(
                    personId: member['id'],
                    eventId: widget.eventId,
                  ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                child: Text(
                  member['first_name']?.toString()[0].toUpperCase() ?? '?',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (email != null && email.isNotEmpty)
                      Row(
                        children: [
                          Icon(
                            Icons.email_outlined,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              email,
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    if (email != null &&
                        phone != null &&
                        email.isNotEmpty &&
                        phone.isNotEmpty)
                      const SizedBox(height: 4),
                    if (phone != null && phone.isNotEmpty)
                      Row(
                        children: [
                          Icon(
                            Icons.phone_outlined,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            phone,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}

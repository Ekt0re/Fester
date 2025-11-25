import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/SupabaseServicies/person_service.dart';
import 'person_profile_screen.dart';

class InvitedGuestsScreen extends StatefulWidget {
  final String inviterId;
  final String inviterName;
  final String eventId;

  const InvitedGuestsScreen({
    super.key,
    required this.inviterId,
    required this.inviterName,
    required this.eventId,
  });

  @override
  State<InvitedGuestsScreen> createState() => _InvitedGuestsScreenState();
}

class _InvitedGuestsScreenState extends State<InvitedGuestsScreen> {
  final PersonService _personService = PersonService();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _allGuests = [];
  List<Map<String, dynamic>> _filteredGuests = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadGuests();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadGuests() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final guests = await _personService.getInvitedGuests(
        widget.inviterId,
        widget.eventId,
      );

      if (mounted) {
        setState(() {
          _allGuests = guests;
          _filteredGuests = guests;
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

  void _filterGuests(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredGuests = _allGuests;
      } else {
        final lowerQuery = query.toLowerCase();
        _filteredGuests =
            _allGuests.where((guest) {
              final person = guest['person'] ?? {};
              final firstName =
                  (person['first_name'] ?? '').toString().toLowerCase();
              final lastName =
                  (person['last_name'] ?? '').toString().toLowerCase();
              final email = (person['email'] ?? '').toString().toLowerCase();
              final phone = (person['phone'] ?? '').toString().toLowerCase();

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
              'Ospiti Invitati',
              style: GoogleFonts.outfit(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              'da ${widget.inviterName}',
              style: GoogleFonts.outfit(
                color: theme.colorScheme.onPrimary.withOpacity(0.8),
                fontSize: 14,
              ),
            ),
          ],
        ),
        actions: [
          if (!_isLoading && _filteredGuests.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Text(
                  '${_filteredGuests.length}',
                  style: GoogleFonts.outfit(
                    color: theme.colorScheme.onPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
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
                hintText: 'Cerca ospite...',
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
                            _filterGuests('');
                          },
                        )
                        : null,
              ),
              onChanged: _filterGuests,
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
            Text(
              _errorMessage,
              style: GoogleFonts.outfit(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadGuests,
              icon: const Icon(Icons.refresh),
              label: Text('Riprova', style: GoogleFonts.outfit()),
            ),
          ],
        ),
      );
    }

    if (_filteredGuests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchController.text.isEmpty
                  ? Icons.person_off
                  : Icons.search_off,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isEmpty
                  ? 'Nessun ospite invitato'
                  : 'Nessun risultato trovato',
              style: GoogleFonts.outfit(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filteredGuests.length,
      itemBuilder: (context, index) {
        return _buildGuestCard(_filteredGuests[index], theme);
      },
    );
  }

  Widget _buildGuestCard(Map<String, dynamic> guest, ThemeData theme) {
    final person = guest['person'] ?? {};
    final status = guest['status'];
    final role = guest['role'];

    final fullName = '${person['first_name']} ${person['last_name']}';
    final email = person['email']?.toString();
    final phone = person['phone']?.toString();
    final statusName = status?['name']?.toString() ?? 'N/A';
    final roleName = role?['name']?.toString() ?? 'Ospite';

    // Get gruppo and sottogruppo names from person nested data
    final gruppoName = person['gruppo']?['name']?.toString();
    final sottogruppoName = person['sottogruppo']?['name']?.toString();

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
                    personId: person['id'],
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
                  person['first_name']?.toString()[0].toUpperCase() ?? '?',
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
                    const SizedBox(height: 4),
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
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _buildChip(statusName, theme.colorScheme.secondary),
                        _buildChip(roleName, theme.colorScheme.primary),
                        if (gruppoName != null && gruppoName.isNotEmpty)
                          _buildChip(gruppoName, Colors.blue),
                        if (sottogruppoName != null &&
                            sottogruppoName.isNotEmpty)
                          _buildChip(sottogruppoName, Colors.purple),
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

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

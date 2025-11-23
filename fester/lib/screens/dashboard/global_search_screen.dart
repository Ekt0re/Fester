import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/SupabaseServicies/event_service.dart';
import '../../services/SupabaseServicies/person_service.dart';
import '../../services/SupabaseServicies/models/event_staff.dart';
import '../../theme/app_theme.dart';
import '../profile/staff_profile_screen.dart';
import '../profile/person_profile_screen.dart';

class GlobalSearchScreen extends StatefulWidget {
  final String eventId;

  const GlobalSearchScreen({super.key, required this.eventId});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final EventService _eventService = EventService();
  final PersonService _personService = PersonService();
  final TextEditingController _searchController = TextEditingController();
  
  List<SearchResult> _allResults = [];
  List<SearchResult> _filteredResults = [];
  bool _isLoading = true;
  String _searchQuery = '';
  bool _showStaff = true;
  bool _showGuests = true;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _filterList(_searchController.text);
    });
  }

  Future<void> _loadData() async {
    try {
      final results = <SearchResult>[];

      // Load staff
      final staffList = await _eventService.getEventStaff(widget.eventId);
      for (final staff in staffList) {
        if (staff.staff != null) {
          results.add(SearchResult(
            id: staff.id,
            name: '${staff.staff!.firstName} ${staff.staff!.lastName}',
            email: staff.staff!.email ?? '',
            phone: staff.staff!.phone ?? '',
            imagePath: staff.staff!.imagePath,
            type: SearchResultType.staff,
            roleName: staff.roleName ?? 'Staff',
            originalData: staff,
          ));
        }
      }

      // Load guests
      final guestList = await _personService.getEventGuests(widget.eventId);
      for (final guest in guestList) {
        results.add(SearchResult(
          id: guest['id'] ?? '',
          name: '${guest['first_name'] ?? ''} ${guest['last_name'] ?? ''}'.trim(),
          email: guest['email'] ?? '',
          phone: guest['number_phone'] ?? '',
          imagePath: null,
          type: SearchResultType.guest,
          roleName: 'Ospite',
          originalData: guest,
        ));
      }

      if (mounted) {
        setState(() {
          _allResults = results;
          _filteredResults = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore caricamento: $e')),
        );
      }
    }
  }

  void _filterList(String query) {
    setState(() {
      _searchQuery = query;
      
      _filteredResults = _allResults.where((result) {
        // Filter by type
        if (!_showStaff && result.type == SearchResultType.staff) return false;
        if (!_showGuests && result.type == SearchResultType.guest) return false;
        
        // Filter by search query
        if (query.isEmpty) return true;
        
        final q = query.toLowerCase();
        final name = result.name.toLowerCase();
        final email = result.email.toLowerCase();
        final phone = result.phone.toLowerCase();
        
        return name.contains(q) || email.contains(q) || phone.contains(q);
      }).toList();
    });
  }

  void _openProfile(SearchResult result) {
    if (result.type == SearchResultType.staff) {
      Navigator.pushNamed(
        context,
        '/staff-profile',
        arguments: {
          'eventId': widget.eventId,
          'staffUserId': (result.originalData as EventStaff).staffUserId,
        },
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PersonProfileScreen(
            personId: result.id,
            eventId: widget.eventId,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Ricerca Persone',
          style: GoogleFonts.outfit(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cerca per nome, email o telefono...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filterList('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: theme.colorScheme.surface,
              ),
            ),
          ),

          // Filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Staff'),
                  selected: _showStaff,
                  onSelected: (bool selected) {
                    setState(() {
                      _showStaff = selected;
                      _filterList(_searchQuery);
                    });
                  },
                  avatar: Icon(
                    Icons.badge,
                    size: 18,
                    color: _showStaff ? Colors.white : Colors.blue,
                  ),
                  selectedColor: Colors.blue,
                  checkmarkColor: Colors.white,
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Ospiti'),
                  selected: _showGuests,
                  onSelected: (bool selected) {
                    setState(() {
                      _showGuests = selected;
                      _filterList(_searchQuery);
                    });
                  },
                  avatar: Icon(
                    Icons.person,
                    size: 18,
                    color: _showGuests ? Colors.white : Colors.green,
                  ),
                  selectedColor: Colors.green,
                  checkmarkColor: Colors.white,
                ),
                const Spacer(),
                Text(
                  '${_filteredResults.length} risultati',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Results List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredResults.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: theme.colorScheme.onSurface.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'Nessuna persona trovata'
                                  : 'Nessun risultato per "$_searchQuery"',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredResults.length,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemBuilder: (context, index) {
                          final result = _filteredResults[index];
                          return _buildResultCard(result, theme);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(SearchResult result, ThemeData theme) {
    final isStaff = result.type == SearchResultType.staff;
    final badgeColor = isStaff ? Colors.blue : Colors.green;
    final badgeIcon = isStaff ? Icons.badge : Icons.person;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _openProfile(result),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 28,
                backgroundColor: badgeColor.withOpacity(0.2),
                backgroundImage: result.imagePath != null
                    ? NetworkImage(result.imagePath!)
                    : null,
                child: result.imagePath == null
                    ? Icon(badgeIcon, color: badgeColor, size: 28)
                    : null,
              ),
              const SizedBox(width: 16),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            result.name,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(badgeIcon, size: 12, color: badgeColor),
                              const SizedBox(width: 4),
                              Text(
                                result.roleName,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: badgeColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (result.email.isNotEmpty)
                      Row(
                        children: [
                          Icon(
                            Icons.email,
                            size: 14,
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              result.email,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    if (result.phone.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.phone,
                            size: 14,
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            result.phone,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Arrow
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurface.withOpacity(0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Search Result Model
class SearchResult {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String? imagePath;
  final SearchResultType type;
  final String roleName;
  final dynamic originalData;

  SearchResult({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.imagePath,
    required this.type,
    required this.roleName,
    required this.originalData,
  });
}

enum SearchResultType { staff, guest }

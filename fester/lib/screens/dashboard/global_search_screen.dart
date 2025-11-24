import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/SupabaseServicies/event_service.dart';
import '../../services/SupabaseServicies/person_service.dart';
import '../../services/SupabaseServicies/participation_service.dart';
import '../../services/SupabaseServicies/models/event_staff.dart';
import '../../theme/app_theme.dart';
import '../profile/person_profile_screen.dart';
import 'widgets/guest_card.dart';
import '../profile/widgets/transaction_creation_sheet.dart';

class GlobalSearchScreen extends StatefulWidget {
  final String eventId;

  const GlobalSearchScreen({super.key, required this.eventId});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final EventService _eventService = EventService();
  final PersonService _personService = PersonService();
  final ParticipationService _participationService = ParticipationService();
  final TextEditingController _searchController = TextEditingController();

  List<SearchResult> _allResults = [];
  List<SearchResult> _filteredResults = [];
  List<Map<String, dynamic>> _statuses = [];
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

      // Load statuses
      try {
        final statusResponse = await Supabase.instance.client
            .from('participation_status')
            .select()
            .order('id');
        _statuses = List<Map<String, dynamic>>.from(statusResponse);
      } catch (e) {
        debugPrint('Error loading statuses: $e');
      }

      // Load staff
      try {
        final staffList = await _eventService.getEventStaff(widget.eventId);
        for (final staff in staffList) {
          if (staff.staff != null) {
            results.add(
              SearchResult(
                id: staff.id,
                name: '${staff.staff!.firstName} ${staff.staff!.lastName}',
                email: staff.staff!.email ?? '',
                phone: staff.staff!.phone ?? '',
                imagePath: staff.staff!.imagePath,
                type: SearchResultType.staff,
                roleName: staff.roleName ?? 'Staff',
                originalData: staff,
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Error loading staff: $e');
      }

      // Load guests (participants)
      try {
        final participants = await _personService.getEventParticipants(
          widget.eventId,
        );
        for (final p in participants) {
          final person = p['person'];
          final status = p['status'];
          // role variable removed to fix lint

          if (person != null) {
            results.add(
              SearchResult(
                id: person['id'] ?? '',
                name:
                    '${person['first_name'] ?? ''} ${person['last_name'] ?? ''}'
                        .trim(),
                email: person['email'] ?? '',
                phone: person['phone'] ?? '',
                imagePath: null,
                type: SearchResultType.guest,
                roleName: status?['name'] ?? 'Sconosciuto',
                originalData: p, // Store the full participation object
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Error loading guests: $e');
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Errore caricamento: $e')));
      }
    }
  }

  void _filterList(String query) {
    setState(() {
      _searchQuery = query;

      _filteredResults =
          _allResults.where((result) {
            // Filter by type
            if (!_showStaff && result.type == SearchResultType.staff) {
              return false;
            }
            if (!_showGuests && result.type == SearchResultType.guest) {
              return false;
            }

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
      // For guests, originalData is the participation map. We need person_id.
      final participation = result.originalData as Map<String, dynamic>;
      final personId = participation['person_id'];

      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => PersonProfileScreen(
                personId: personId,
                eventId: widget.eventId,
              ),
        ),
      );
    }
  }

  Future<void> _updateStatus(
    String participationId,
    int currentStatusId,
  ) async {
    // Logic: confirmed -> checked_in -> inside -> outside -> left -> confirmed
    final currentIndex = _statuses.indexWhere(
      (s) => s['id'] == currentStatusId,
    );
    if (currentIndex == -1) return;

    const statusOrder = [
      'confirmed',
      'checked_in',
      'inside',
      'outside',
      'left',
    ];

    final currentStatusName = _statuses[currentIndex]['name'];
    int nextIndex = -1;

    for (int i = 0; i < statusOrder.length; i++) {
      if (statusOrder[i] == currentStatusName) {
        if (i < statusOrder.length - 1) {
          final nextName = statusOrder[i + 1];
          nextIndex = _statuses.indexWhere((s) => s['name'] == nextName);
        } else {
          final nextName = statusOrder[0];
          nextIndex = _statuses.indexWhere((s) => s['name'] == nextName);
        }
        break;
      }
    }

    if (nextIndex == -1 && currentStatusName == 'invited') {
      nextIndex = _statuses.indexWhere((s) => s['name'] == 'confirmed');
    }

    if (nextIndex != -1) {
      final nextStatusId = _statuses[nextIndex]['id'];
      await _changeStatus(participationId, nextStatusId);
    }
  }

  Future<void> _changeStatus(String participationId, int newStatusId) async {
    try {
      await _participationService.updateParticipationStatus(
        participationId: participationId,
        newStatusId: newStatusId,
      );

      // Update local state
      final index = _allResults.indexWhere(
        (r) =>
            r.type == SearchResultType.guest &&
            (r.originalData as Map<String, dynamic>)['id'] == participationId,
      );

      if (index != -1) {
        final oldResult = _allResults[index];
        final oldData = oldResult.originalData as Map<String, dynamic>;
        final newStatus = _statuses.firstWhere((s) => s['id'] == newStatusId);

        // Create updated participation map
        final updatedData = Map<String, dynamic>.from(oldData);
        updatedData['status_id'] = newStatusId;
        updatedData['status'] = newStatus;

        // Create updated SearchResult
        final updatedResult = SearchResult(
          id: oldResult.id,
          name: oldResult.name,
          email: oldResult.email,
          phone: oldResult.phone,
          imagePath: oldResult.imagePath,
          type: oldResult.type,
          roleName: newStatus['name'] ?? 'Sconosciuto',
          originalData: updatedData,
        );

        if (mounted) {
          setState(() {
            _allResults[index] = updatedResult;
            _filterList(_searchController.text); // Re-filter to update view
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Errore aggiornamento stato: $e')));
    }
  }

  void _showStatusMenu(String participationId, int currentStatusId) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Seleziona Stato',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ..._statuses.map((status) {
                return ListTile(
                  title: Text(status['name'].toString().toUpperCase()),
                  leading:
                      status['id'] == currentStatusId
                          ? const Icon(
                            Icons.check,
                            color: AppTheme.primaryLight,
                          )
                          : null,
                  onTap: () {
                    Navigator.pop(context);
                    _changeStatus(participationId, status['id']);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showTransactionCreation(String participationId, String type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: TransactionCreationSheet(
              eventId: widget.eventId,
              participationId: participationId,
              initialTransactionType: type,
              onSuccess: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Transazione creata con successo'),
                  ),
                );
              },
            ),
          ),
    );
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
                suffixIcon:
                    _searchQuery.isNotEmpty
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
            child:
                _isLoading
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
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.6,
                              ),
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
                        if (result.type == SearchResultType.guest) {
                          return _buildGuestCard(result);
                        } else {
                          return _buildStaffCard(result, theme);
                        }
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestCard(SearchResult result) {
    final participation = result.originalData as Map<String, dynamic>;
    final person = participation['person'] ?? {};
    final role = participation['role'];
    final participationId = participation['id'];
    final statusId = participation['status_id'];

    // Check if VIP
    final isVip =
        role?['name']?.toString().toLowerCase().contains('vip') ?? false;

    return GuestCard(
      name: person['first_name'] ?? '',
      surname: person['last_name'] ?? '',
      idEvent: widget.eventId,
      statusName: result.roleName,
      isVip: isVip,
      onTap: () => _openProfile(result),
      onDoubleTap: () => _updateStatus(participationId, statusId),
      onLongPress: () => _showStatusMenu(participationId, statusId),
      onReport: () => _showTransactionCreation(participationId, 'report'),
      onDrink: () => _showTransactionCreation(participationId, 'drink'),
    );
  }

  Widget _buildStaffCard(SearchResult result, ThemeData theme) {
    const badgeColor = Colors.blue;
    const badgeIcon = Icons.badge;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                backgroundImage:
                    result.imagePath != null
                        ? NetworkImage(result.imagePath!)
                        : null,
                child:
                    result.imagePath == null
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
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.6,
                                ),
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
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.6,
                              ),
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

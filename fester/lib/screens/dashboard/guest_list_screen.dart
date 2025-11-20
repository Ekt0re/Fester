import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/SupabaseServicies/participation_service.dart';
import '../../theme/app_theme.dart';
import 'widgets/guest_card.dart';
import '../profile/person_profile_screen.dart';

class GuestListScreen extends StatefulWidget {
  final String eventId;

  const GuestListScreen({super.key, required this.eventId});

  @override
  State<GuestListScreen> createState() => _GuestListScreenState();
}

class _GuestListScreenState extends State<GuestListScreen> {
  final ParticipationService _participationService = ParticipationService();
  final TextEditingController _searchController = TextEditingController();
  
  List<Map<String, dynamic>> _allParticipations = [];
  List<Map<String, dynamic>> _filteredParticipations = [];
  List<Map<String, dynamic>> _statuses = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // Load statuses first (or hardcode if needed, but better fetch)
      final statusResponse = await Supabase.instance.client
          .from('participation_status')
          .select()
          .order('id');
      _statuses = List<Map<String, dynamic>>.from(statusResponse);

      final participations = await _participationService.getEventParticipations(widget.eventId);
      
      if (mounted) {
        setState(() {
          _allParticipations = participations;
          _filteredParticipations = participations;
          _statuses = _statuses;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore caricamento ospiti: $e')),
        );
      }
    }
  }

  void _filterList(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredParticipations = _allParticipations;
      } else {
        _filteredParticipations = _allParticipations.where((p) {
          final person = p['person'] ?? {};
          final name = (person['first_name'] ?? '').toString().toLowerCase();
          final surname = (person['last_name'] ?? '').toString().toLowerCase();
          final idEvent = (person['id_event'] ?? '').toString().toLowerCase();
          final q = query.toLowerCase();
          return name.contains(q) || surname.contains(q) || idEvent.contains(q);
        }).toList();
      }
    });
  }

  Future<void> _updateStatus(String participationId, int currentStatusId) async {
    // Logic: confirmed -> checked_in -> inside -> outside -> left -> confirmed (loop or back?)
    // User said: confirmed -> checked_in -> inside -> outside -> left.
    // If left -> turn back (maybe to confirmed or just toggle back?)
    // "If you arrive to left turn back whit the double taps." -> implies cycle or reverse.
    
    // Let's implement a simple forward cycle for now based on IDs or Names.
    // Assuming standard IDs or finding next by order.
    
    // Find current status index
    final currentIndex = _statuses.indexWhere((s) => s['id'] == currentStatusId);
    if (currentIndex == -1) return;

    // Define the cycle order by name
    const statusOrder = ['confirmed', 'checked_in', 'inside', 'outside', 'left'];
    
    final currentStatusName = _statuses[currentIndex]['name'];
    int nextIndex = -1;
    
    // Find next status in our defined order
    for (int i = 0; i < statusOrder.length; i++) {
      if (statusOrder[i] == currentStatusName) {
        if (i < statusOrder.length - 1) {
           // Find the ID of the next status name
           final nextName = statusOrder[i+1];
           nextIndex = _statuses.indexWhere((s) => s['name'] == nextName);
        } else {
           // Cycle back to first? Or reverse? User said "turn back".
           // Let's cycle to start for simplicity or make it smart.
           // "If you arrive to left turn back whit the double taps" -> maybe reset?
           final nextName = statusOrder[0];
           nextIndex = _statuses.indexWhere((s) => s['name'] == nextName);
        }
        break;
      }
    }

    // If current status is not in our main flow (e.g. 'invited'), maybe move to 'confirmed'?
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
      // Refresh list locally to feel fast
      final index = _allParticipations.indexWhere((p) => p['id'] == participationId);
      if (index != -1) {
        setState(() {
          _allParticipations[index]['status_id'] = newStatusId;
          _allParticipations[index]['status'] = _statuses.firstWhere((s) => s['id'] == newStatusId);
          _filterList(_searchController.text);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore aggiornamento stato: $e')),
      );
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
              Text('Seleziona Stato', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ..._statuses.map((status) {
                return ListTile(
                  title: Text(status['name'].toString().toUpperCase()),
                  leading: status['id'] == currentStatusId ? const Icon(Icons.check, color: AppTheme.primaryLight) : null,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final arrivedCount = _allParticipations.where((p) {
       final status = p['status']?['name'];
       return status == 'inside' || status == 'checked_in'; // Example logic
    }).length;

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
              'Elenco ospiti',
              style: GoogleFonts.outfit(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.bold),
            ),
            Text(
              'Totale: ${_allParticipations.length} - Arrivati: $arrivedCount',
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
          // Search & QR
          Container(
            padding: const EdgeInsets.all(16),
            color: theme.colorScheme.primary.withOpacity(0.1),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _filterList,
                    decoration: InputDecoration(
                      hintText: 'Ricerca invitato...',
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
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.qr_code_scanner, color: theme.colorScheme.onPrimary),
                    onPressed: () {
                      // TODO: Open QR Scanner
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredParticipations.length,
                    itemBuilder: (context, index) {
                      final participation = _filteredParticipations[index];
                      final person = participation['person'] ?? {};
                      final status = participation['status'] ?? {};
                      final role = participation['role'] ?? {};
                      
                      return GuestCard(
                        name: person['first_name'] ?? 'Sconosciuto',
                        surname: person['last_name'] ?? '',
                        idEvent: person['id_event'] ?? '---',
                        statusName: status['name'] ?? 'unknown',
                        isVip: (role['name'] ?? '').toString().toLowerCase() == 'vip',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PersonProfileScreen(
                                personId: person['id'],
                                name: person['first_name'] ?? '',
                                surname: person['last_name'] ?? '',
                                idEvent: person['id_event'] ?? '',
                              ),
                            ),
                          );
                        },
                        onDoubleTap: () => _updateStatus(participation['id'], participation['status_id']),
                        onLongPress: () => _showStatusMenu(participation['id'], participation['status_id']),
                        onReport: () {
                          // TODO: Open Report
                        },
                        onDrink: () {
                          // TODO: Open Transaction
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

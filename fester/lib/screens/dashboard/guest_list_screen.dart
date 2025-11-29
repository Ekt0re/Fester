import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/SupabaseServicies/participation_service.dart';
import '../../services/SupabaseServicies/event_service.dart';
import '../../theme/app_theme.dart';
import 'widgets/guest_card.dart';
import '../profile/person_profile_screen.dart';
import 'add_guest_screen.dart';
import '../profile/widgets/transaction_creation_sheet.dart';
import 'qr_scanner_screen.dart';
import '../../services/SupabaseServicies/gruppo_service.dart';
import '../../services/SupabaseServicies/sottogruppo_service.dart';
import '../../services/SupabaseServicies/models/gruppo.dart';
import '../../services/SupabaseServicies/models/sottogruppo.dart';

class GuestListScreen extends StatefulWidget {
  final String eventId;

  const GuestListScreen({super.key, required this.eventId});

  @override
  State<GuestListScreen> createState() => _GuestListScreenState();
}

class _GuestListScreenState extends State<GuestListScreen> {
  final ParticipationService _participationService = ParticipationService();
  final EventService _eventService = EventService();
  final GruppoService _gruppoService = GruppoService();
  final SottogruppoService _sottogruppoService = SottogruppoService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<Map<String, dynamic>> _allParticipations = [];
  List<Map<String, dynamic>> _filteredParticipations = [];
  List<Map<String, dynamic>> _statuses = [];
  List<Gruppo> _gruppi = [];
  List<Sottogruppo> _sottogruppi = [];
  int? _selectedGruppoId;
  int? _selectedSottogruppoId;
  bool _isLoading = true;

  String? _userRole;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

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

      final participations = await _participationService.getEventParticipations(
        widget.eventId,
      );

      final gruppi = await _gruppoService.getGruppiForEvent(widget.eventId);
      final sottogruppi = await _sottogruppoService.getSottogruppiForEvent(
        widget.eventId,
      );

      // Load user role for this event
      final userId = Supabase.instance.client.auth.currentUser?.id;
      String? userRole;
      if (userId != null) {
        try {
          final staffList = await _eventService.getEventStaff(widget.eventId);
          final userStaff = staffList.firstWhere(
            (s) => s.staffUserId == userId,
          );
          userRole = userStaff.roleName?.toLowerCase();
        } catch (_) {
          // User might not be in staff list
        }
      }

      if (mounted) {
        setState(() {
          _allParticipations = participations;
          _filteredParticipations = participations;
          _statuses = _statuses;
          _gruppi = gruppi;
          _sottogruppi = sottogruppi;
          _userRole = userRole;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'guest_list.load_error'.tr()}$e')),
        );
      }
    }
  }

  void _filterList(String query) {
    setState(() {
      _filteredParticipations =
          _allParticipations.where((p) {
            final person = p['person'] ?? {};
            final name = (person['first_name'] ?? '').toString().toLowerCase();
            final surname =
                (person['last_name'] ?? '').toString().toLowerCase();
            final idEvent = (person['id_event'] ?? '').toString().toLowerCase();
            final gruppoId = person['gruppo_id'] as int?;
            final sottogruppoId = person['sottogruppo_id'] as int?;

            final matchesQuery =
                query.isEmpty ||
                name.contains(query.toLowerCase()) ||
                surname.contains(query.toLowerCase()) ||
                idEvent.contains(query.toLowerCase());

            final matchesGruppo =
                _selectedGruppoId == null || gruppoId == _selectedGruppoId;

            final matchesSottogruppo =
                _selectedSottogruppoId == null ||
                sottogruppoId == _selectedSottogruppoId;

            return matchesQuery && matchesGruppo && matchesSottogruppo;
          }).toList();
    });
  }

  Future<void> _updateStatus(
    String participationId,
    int currentStatusId,
  ) async {
    // Logic: confirmed -> checked_in -> inside -> outside -> left -> confirmed (loop or back?)
    // User said: confirmed -> checked_in -> inside -> outside -> left.
    // If left -> turn back (maybe to confirmed or just toggle back?)
    // "If you arrive to left turn back whit the double taps." -> implies cycle or reverse.

    // Let's implement a simple forward cycle for now based on IDs or Names.
    // Assuming standard IDs or finding next by order.

    // Find current status index
    final currentIndex = _statuses.indexWhere(
      (s) => s['id'] == currentStatusId,
    );
    if (currentIndex == -1) return;

    // Define the cycle order by name
    const statusOrder = [
      'confirmed',
      'checked_in',
      'inside',
      'outside',
      'left',
    ];

    final currentStatusName = _statuses[currentIndex]['name'];
    int nextIndex = -1;

    // Find next status in our defined order
    for (int i = 0; i < statusOrder.length; i++) {
      if (statusOrder[i] == currentStatusName) {
        if (i < statusOrder.length - 1) {
          // Find the ID of the next status name
          final nextName = statusOrder[i + 1];
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
      final index = _allParticipations.indexWhere(
        (p) => p['id'] == participationId,
      );
      if (index != -1) {
        setState(() {
          _allParticipations[index]['status_id'] = newStatusId;
          _allParticipations[index]['status'] = _statuses.firstWhere(
            (s) => s['id'] == newStatusId,
          );
          _filterList(_searchController.text);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore aggiornamento stato: $e')),
        );
      }
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
                'guest_list.select_status'.tr(),
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
                  SnackBar(
                    content: Text('guest_list.transaction_success'.tr()),
                  ),
                );
              },
            ),
          ),
    );
  }

  Widget _buildGuestItem(BuildContext context, int index) {
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
            builder:
                (context) => PersonProfileScreen(
                  personId: person['id'],
                  eventId: widget.eventId,
                  currentUserRole: _userRole,
                ),
          ),
        );
      },
      onDoubleTap:
          () => _updateStatus(participation['id'], participation['status_id']),
      onLongPress:
          () =>
              _showStatusMenu(participation['id'], participation['status_id']),
      onReport: () => _showTransactionCreation(participation['id'], 'report'),
      onDrink: () => _showTransactionCreation(participation['id'], 'drink'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final arrivedCount =
        _allParticipations.where((p) {
          final status = p['status']?['name'];
          return status == 'inside' || status == 'checked_in';
        }).length;

    final canAddGuests = _userRole == 'staff3' || _userRole == 'admin';

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
              'guest_list.title'.tr(),
              style: GoogleFonts.outfit(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${'guest_list.total'.tr()}${_allParticipations.length} - ${'guest_list.arrived'.tr()}$arrivedCount',
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
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        decoration: InputDecoration(
                          hintText: 'guest_list.search_placeholder'.tr(),
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: theme.colorScheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: _filterList,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.qr_code_scanner,
                          color: theme.colorScheme.onPrimary,
                        ),
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) =>
                                      QRScannerScreen(eventId: widget.eventId),
                            ),
                          );

                          if (result == 'SEARCH_TRIGGER') {
                            await Future.delayed(
                              const Duration(milliseconds: 300),
                            );
                            if (context.mounted) {
                              FocusScope.of(
                                context,
                              ).requestFocus(_searchFocusNode);
                            }
                          }
                          if (context.mounted) {
                            _loadData();
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _selectedGruppoId,
                        decoration: InputDecoration(
                          labelText: 'guest_list.group'.tr(),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: theme.colorScheme.surface,
                        ),
                        items: [
                          DropdownMenuItem<int>(
                            value: null,
                            child: Text('guest_list.all'.tr()),
                          ),
                          ..._gruppi.map(
                            (g) => DropdownMenuItem<int>(
                              value: g.id,
                              child: Text(
                                g.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _selectedGruppoId = val;
                            _selectedSottogruppoId = null; // Reset subgroup
                          });
                          _filterList(_searchController.text);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _selectedSottogruppoId,
                        decoration: InputDecoration(
                          labelText: 'guest_list.subgroup'.tr(),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: theme.colorScheme.surface,
                        ),
                        items: [
                          DropdownMenuItem<int>(
                            value: null,
                            child: Text('guest_list.all'.tr()),
                          ),
                          ..._sottogruppi
                              .where(
                                (s) =>
                                    _selectedGruppoId == null ||
                                    s.gruppoId == _selectedGruppoId,
                              )
                              .map(
                                (s) => DropdownMenuItem<int>(
                                  value: s.id,
                                  child: Text(
                                    s.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                        ],
                        onChanged: (val) {
                          setState(() => _selectedSottogruppoId = val);
                          _filterList(_searchController.text);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // List
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
                                padding: const EdgeInsets.all(16),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 16,
                                      mainAxisSpacing: 16,
                                      childAspectRatio: 3.5,
                                    ),
                                itemCount: _filteredParticipations.length,
                                itemBuilder: _buildGuestItem,
                              ),
                            ),
                          );
                        }
                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredParticipations.length,
                          itemBuilder: _buildGuestItem,
                        );
                      },
                    ),
          ),
        ],
      ),
      floatingActionButton:
          canAddGuests
              ? FloatingActionButton(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => AddGuestScreen(eventId: widget.eventId),
                    ),
                  );
                  // Reload list if guest was added
                  if (result == true) {
                    _loadData();
                  }
                },
                backgroundColor: theme.colorScheme.secondary,
                child: Icon(
                  Icons.person_add,
                  color: theme.colorScheme.onSecondary,
                ),
              )
              : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

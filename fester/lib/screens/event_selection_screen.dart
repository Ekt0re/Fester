// lib/screens/event_selection_screen.dart
import 'package:flutter/material.dart';
import '../services/SupabaseServicies/event_service.dart';
import '../services/SupabaseServicies/staff_user_service.dart';
import '../services/SupabaseServicies/models/event.dart';
import '../services/SupabaseServicies/models/event_settings.dart';
import 'create_event/create_event_flow.dart';

class EventSelectionScreen extends StatefulWidget {
  const EventSelectionScreen({super.key});

  @override
  State<EventSelectionScreen> createState() => _EventSelectionScreenState();
}

class _EventSelectionScreenState extends State<EventSelectionScreen> {
  final EventService _eventService = EventService();
  final StaffUserService _staffUserService = StaffUserService();

  List<EventWithDetails> _activeEvents = [];
  List<EventWithDetails> _archivedEvents = [];
  bool _isLoading = true;
  bool _showArchived = false;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);

    try {
      // Carica gli eventi dello staff corrente
      final events = await _eventService.getMyEvents();

      // Separa eventi attivi e archiviati
      final List<EventWithDetails> activeList = [];
      final List<EventWithDetails> archivedList = [];

      for (final event in events) {
        // Carica settings e ruolo per ogni evento
        final settings = await _eventService.getEventSettings(event.id);
        final staffList = await _eventService.getEventStaff(event.id);

        // Trova il ruolo dell'utente corrente
        final currentUser = await _staffUserService.getCurrentStaffUser();
        final userStaff = staffList.firstWhere(
          (staff) => staff['staff_user_id'] == currentUser?.id,
          orElse: () => {},
        );

        final eventDetails = EventWithDetails(
          event: event,
          settings: settings,
          userRole: userStaff['role_name'] as String? ?? 'Staff',
        );

        // Separa in base a deleted_at (archiviati)
        if (event.deletedAt != null) {
          archivedList.add(eventDetails);
        } else {
          activeList.add(eventDetails);
        }
      }

      setState(() {
        _activeEvents = activeList;
        _archivedEvents = archivedList;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore nel caricamento eventi: $e')),
        );
      }
    }
  }

  String _getEventStatus(EventWithDetails eventDetails) {
    final now = DateTime.now();
    final settings = eventDetails.settings;

    if (eventDetails.event.deletedAt != null) {
      return 'Terminato';
    }

    if (settings == null) {
      return 'In programmazione';
    }

    if (now.isBefore(settings.startAt)) {
      return 'In programmazione';
    } else if (settings.endAt != null && now.isAfter(settings.endAt!)) {
      return 'Terminato';
    } else {
      return 'Avviato';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Avviato':
        return Colors.green;
      case 'In programmazione':
        return Colors.orange;
      case 'Terminato':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFB8D4E8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFB8D4E8),
        elevation: 0,
        title: const Text(
          'FESTER 3.0',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.party_mode, color: Colors.pinkAccent),
            onPressed: () {},
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _loadEvents,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'ORGANIZZA LA TUA FESTA!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'Seleziona l\'evento che vuoi gestire!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 24),

                      // Eventi attivi
                      if (_activeEvents.isEmpty && !_showArchived)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Nessun evento attivo.\nCrea il tuo primo evento!',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16),
                          ),
                        )
                      else
                        ...(_showArchived ? _archivedEvents : _activeEvents)
                            .map(
                              (eventDetails) => _EventCard(
                                eventDetails: eventDetails,
                                status: _getEventStatus(eventDetails),
                                statusColor: _getStatusColor(
                                  _getEventStatus(eventDetails),
                                ),
                                onTap: () {
                                  // Naviga alla schermata di gestione evento
                                  Navigator.pushNamed(
                                    context,
                                    '/event-detail',
                                    arguments: eventDetails.event.id,
                                  );
                                },
                              ),
                            ),

                      const SizedBox(height: 16),

                      // Pulsante visualizza eventi archiviati
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() => _showArchived = !_showArchived);
                        },
                        icon: Icon(
                          _showArchived ? Icons.event_available : Icons.archive,
                          color: Colors.black54,
                        ),
                        label: Text(
                          _showArchived
                              ? 'Mostra eventi attivi'
                              : 'Visualizza eventi passati',
                          style: const TextStyle(color: Colors.black87),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.white.withOpacity(0.7),
                          side: const BorderSide(color: Colors.black26),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Pulsante crea evento
                      ElevatedButton(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CreateEventFlow(),
                            ),
                          );
                          _loadEvents();
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          backgroundColor: Colors.white.withOpacity(0.9),
                          foregroundColor: Colors.black87,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Crea il tuo evento!',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateEventFlow(),
            ),
          );
          _loadEvents();
        },
        backgroundColor: Colors.white,
        child: const Icon(Icons.add, color: Color(0xFF9B59B6)),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final EventWithDetails eventDetails;
  final String status;
  final Color statusColor;
  final VoidCallback onTap;

  const _EventCard({
    required this.eventDetails,
    required this.status,
    required this.statusColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        eventDetails.event.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        eventDetails.userRole,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor, width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.circle, size: 8, color: statusColor),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Classe helper per raggruppare dati evento
class EventWithDetails {
  final Event event;
  final EventSettings? settings;
  final String userRole;

  EventWithDetails({
    required this.event,
    this.settings,
    required this.userRole,
  });
}

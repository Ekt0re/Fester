// lib/screens/event_selection_screen.dart
import 'package:flutter/material.dart';
import '../services/SupabaseServicies/event_service.dart';
import '../services/SupabaseServicies/staff_user_service.dart';
import '../services/SupabaseServicies/models/event.dart';
import '../services/SupabaseServicies/models/event_settings.dart';
import '../widgets/animated_settings_icon.dart';
import 'create_event/create_event_flow.dart';
import 'settings/settings_screen.dart';

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
        
        // Use where().firstOrNull pattern which is safer and cleaner
        // If firstOrNull is not available in older Dart, we can use isEmpty check
        final matchingStaff = staffList.where(
          (staff) => staff.staffUserId == currentUser?.id,
        );
        final userStaff = matchingStaff.isNotEmpty ? matchingStaff.first : null;

        final eventDetails = EventWithDetails(
          event: event,
          settings: settings,
          userRole: userStaff?.roleName ?? 'Staff',
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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        title: Text(
          'FESTER 3.0',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
        actions: [
          AnimatedSettingsIcon(
            color: theme.colorScheme.secondary,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
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
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200), // Increased max width for grid
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isDesktop = constraints.maxWidth > 900;
                          final crossAxisCount = isDesktop ? 2 : 1;
                          final spacing = 16.0;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'ORGANIZZA LA TUA FESTA!',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 1.2,
                                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                                ),
                              ),
                              const SizedBox(height: 32),
                              Text(
                                'Seleziona l\'evento che vuoi gestire!',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 24),

                              // Eventi attivi
                              if (_activeEvents.isEmpty && !_showArchived)
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: theme.cardTheme.color,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Nessun evento attivo.\nCrea il tuo primo evento!',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyLarge,
                                  ),
                                )
                              else
                                GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossAxisCount,
                                    crossAxisSpacing: spacing,
                                    mainAxisSpacing: spacing,
                                    childAspectRatio: isDesktop ? 3 : 2.5, // Adjust ratio as needed
                                    mainAxisExtent: 100, // Fixed height for cards
                                  ),
                                  itemCount: (_showArchived ? _archivedEvents : _activeEvents).length,
                                  itemBuilder: (context, index) {
                                    final list = _showArchived ? _archivedEvents : _activeEvents;
                                    final eventDetails = list[index];
                                    return _EventCard(
                                      eventDetails: eventDetails,
                                      status: _getEventStatus(eventDetails),
                                      statusColor: _getStatusColor(
                                        _getEventStatus(eventDetails),
                                      ),
                                      onTap: () {
                                        Navigator.pushNamed(
                                          context,
                                          '/event-detail',
                                          arguments: eventDetails.event.id,
                                        );
                                      },
                                    );
                                  },
                                ),

                              const SizedBox(height: 16),

                              // Pulsante visualizza eventi archiviati
                              OutlinedButton.icon(
                                onPressed: () {
                                  setState(() => _showArchived = !_showArchived);
                                },
                                icon: Icon(
                                  _showArchived ? Icons.event_available : Icons.archive,
                                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                                ),
                                label: Text(
                                  _showArchived
                                      ? 'Mostra eventi attivi'
                                      : 'Visualizza eventi passati',
                                  style: TextStyle(color: theme.colorScheme.onSurface),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  backgroundColor: theme.cardTheme.color,
                                  side: BorderSide(color: theme.colorScheme.outline),
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
                                  backgroundColor: theme.colorScheme.surface,
                                  foregroundColor: theme.colorScheme.onSurface,
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  'Crea il tuo evento!',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
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
        backgroundColor: theme.colorScheme.secondary,
        child: const Icon(Icons.add, color: Colors.white),
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
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        elevation: 2,
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
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        eventDetails.userRole,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
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

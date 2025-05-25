import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fester_frontend/blocs/event/event_bloc.dart';
import 'package:fester_frontend/models/event.dart';

class EventDetailScreen extends StatefulWidget {
  final String eventId;

  const EventDetailScreen({Key? key, required this.eventId}) : super(key: key);

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Carica i dettagli dell'evento
    context.read<EventBloc>().add(EventDetailsRequested(eventId: widget.eventId));
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dettagli Evento'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // Navigazione alla pagina di modifica evento
              context.push('/events/${widget.eventId}/edit');
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') {
                _showDeleteConfirmation();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Text('Elimina evento'),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Informazioni'),
            Tab(text: 'Ospiti'),
            Tab(text: 'Statistiche'),
          ],
        ),
      ),
      body: BlocBuilder<EventBloc, EventState>(
        builder: (context, state) {
          if (state is EventLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          } else if (state is EventDetailsLoaded) {
            final event = state.event;
            
            return TabBarView(
              controller: _tabController,
              children: [
                _buildInfoTab(event),
                _buildGuestsTab(event),
                _buildStatsTab(event),
              ],
            );
          } else if (state is EventFailure) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Errore: ${state.message}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.read<EventBloc>().add(
                        EventDetailsRequested(eventId: widget.eventId),
                      );
                    },
                    child: const Text('Riprova'),
                  ),
                ],
              ),
            );
          }
          
          return const Center(
            child: Text('Caricamento dettagli evento...'),
          );
        },
      ),
      floatingActionButton: BlocBuilder<EventBloc, EventState>(
        builder: (context, state) {
          if (state is EventDetailsLoaded) {
            if (_tabController.index == 1) {
              // Nella tab degli ospiti, mostra il pulsante per aggiungere ospiti
              return FloatingActionButton(
                onPressed: () {
                  // Navigazione alla pagina di aggiunta ospiti
                  context.push('/events/${state.event.id}/guests/add');
                },
                child: const Icon(Icons.person_add),
              );
            } else if (_tabController.index == 0 && state.event.state == 'active') {
              // Nella tab delle informazioni, se l'evento è attivo mostra il pulsante per il check-in
              return FloatingActionButton(
                onPressed: () {
                  context.push('/events/${state.event.id}/qr-scanner');
                },
                backgroundColor: Colors.deepPurple,
                child: const Icon(Icons.qr_code_scanner),
              );
            }
          }
          
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildInfoTab(Event event) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final formattedDate = dateFormat.format(event.dateTime);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Intestazione evento
          Text(
            event.name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Stato
          Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.grey),
              const SizedBox(width: 8),
              const Text(
                'Stato:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              _buildStatusChip(event.state),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Dettagli principali
          _buildInfoItem(Icons.location_on, 'Luogo', event.place),
          _buildInfoItem(Icons.calendar_today, 'Data e ora', formattedDate),
          
          const Divider(height: 32),
          
          // Regole e informazioni aggiuntive
          if (event.rules.isNotEmpty) ...[
            const Text(
              'Regole dell\'evento',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: event.rules.map((rule) => 
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check, size: 18, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              rule.text,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).toList(),
                ),
              ),
            ),
          ],
          
          const SizedBox(height: 24),
          
          // Pulsanti per azioni rapide
          if (event.state == 'active') ...[
            const Text(
              'Azioni Rapide',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      context.push('/events/${event.id}/guests');
                    },
                    icon: const Icon(Icons.people),
                    label: const Text('Gestisci Ospiti'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      context.push('/events/${event.id}/checkin');
                    },
                    icon: const Icon(Icons.qr_code),
                    label: const Text('Check-in'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGuestsTab(Event event) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.people,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'Gestione Ospiti',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Totale ospiti: ${event.stats?.total ?? 0}',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              context.push('/events/${event.id}/guests');
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Visualizza tutti gli ospiti'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsTab(Event event) {
    final stats = event.stats ?? const EventStats(
      total: 0,
      invited: 0,
      confirmed: 0,
      present: 0,
    );
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Statistiche Evento',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          
          // Statistiche numeriche
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Totale',
                  stats.total.toString(),
                  Colors.blue,
                ),
              ),
              Expanded(
                child: _buildStatCard(
                  'Invitati',
                  stats.invited.toString(),
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Confermati',
                  stats.confirmed.toString(),
                  Colors.green,
                ),
              ),
              Expanded(
                child: _buildStatCard(
                  'Presenti',
                  stats.present.toString(),
                  Colors.purple,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // Tasso di presenza
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tasso di presenza',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: stats.total > 0 ? stats.present / stats.total : 0,
                      minHeight: 20,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      stats.total > 0
                          ? '${((stats.present / stats.total) * 100).toStringAsFixed(1)}%'
                          : '0%',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
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

  Widget _buildStatusChip(String status) {
    final Color color = status == 'attivo'
        ? Colors.green
        : status == 'concluso'
            ? Colors.grey
            : Colors.red;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(26), // 0.1 * 255 = 25.5 arrotondato a 26
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.grey),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: color.withAlpha(26), // 0.1 * 255 = 25.5 arrotondato a 26
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conferma eliminazione'),
        content: const Text(
          'Sei sicuro di voler eliminare questo evento? Questa azione non può essere annullata.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.read<EventBloc>().add(
                EventDeleteRequested(eventId: widget.eventId),
              );
              // Dopo l'eliminazione, torna alla home
              context.go('/home');
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }
} 
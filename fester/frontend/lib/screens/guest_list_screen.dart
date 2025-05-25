import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fester_frontend/blocs/event/event_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';

class GuestListScreen extends StatefulWidget {
  final String eventId;

  const GuestListScreen({Key? key, required this.eventId}) : super(key: key);

  @override
  State<GuestListScreen> createState() => _GuestListScreenState();
}

class _GuestListScreenState extends State<GuestListScreen> {
  @override
  void initState() {
    super.initState();
    // Carica gli ospiti usando il bloc
    context.read<EventBloc>().add(EventGuestsRequested(eventId: widget.eventId));
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista Ospiti'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              _showFilterDialog();
            },
          ),
        ],
      ),
      body: BlocBuilder<EventBloc, EventState>(
        builder: (context, state) {
          if (state is EventLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is EventError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Errore: ${state.message}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.read<EventBloc>().add(EventGuestsRequested(eventId: widget.eventId));
                    },
                    child: const Text('Riprova'),
                  ),
                ],
              ),
            );
          } else if (state is EventGuestsLoaded) {
            final guests = state.guests;
            
            if (guests.isEmpty) {
              return _buildEmptyState();
            }
            
            return RefreshIndicator(
              onRefresh: () async {
                context.read<EventBloc>().add(EventGuestsRequested(eventId: widget.eventId));
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats summary
                  _buildStatsSummary(guests),
                  
                  // Search bar
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Cerca ospite',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        // Implementare filtro di ricerca
                      },
                    ),
                  ),
                  
                  // Guest list
                  Expanded(
                    child: ListView.builder(
                      itemCount: guests.length,
                      itemBuilder: (context, index) {
                        return _buildGuestItem(guests[index]);
                      },
                    ),
                  ),
                ],
              ),
            );
          }
          
          return const Center(
            child: Text('Caricamento ospiti...'),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.push('/events/${widget.eventId}/guests/add');
        },
        child: const Icon(Icons.person_add),
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.people_outline,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'Nessun ospite',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Aggiungi ospiti al tuo evento',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              context.push('/events/${widget.eventId}/guests/add');
            },
            icon: const Icon(Icons.person_add),
            label: const Text('Aggiungi Ospite'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatsSummary(List<Guest> guests) {
    final int totaleOspiti = guests.length;
    final int presenti = guests.where((g) => g.isPresent).length;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Totale', totaleOspiti, Colors.blue),
          _buildStatItem('Presenti', presenti, Colors.deepPurple),
        ],
      ),
    );
  }
  
  Widget _buildStatItem(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }
  
  Widget _buildGuestItem(Guest guest) {
    final statusColor = guest.isPresent ? Colors.deepPurple : Colors.grey;
    
    return Card(
      child: ExpansionTile(
        title: Text(
          '${guest.nome} ${guest.cognome}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Row(
          children: [
            Container(
              margin: const EdgeInsets.only(right: 8),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            Text(guest.isPresent ? 'Presente' : 'Non presente'),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (guest.email.isNotEmpty)
                  _buildInfoRow(Icons.email, 'Email', guest.email),
                
                const Divider(),
                
                // QR Code per check-in
                Center(
                  child: Column(
                    children: [
                      const Text(
                        'QR Code per check-in',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      QrImageView(
                        data: guest.id,
                        version: QrVersions.auto,
                        size: 120.0,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.check),
                      label: const Text('Check-in'),
                      onPressed: () {
                        if (!guest.isPresent) {
                          context.read<EventBloc>().add(
                            EventGuestCheckinRequested(
                              eventId: widget.eventId,
                              guestId: guest.id,
                            ),
                          );
                        }
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: guest.isPresent ? Colors.grey : Colors.green,
                      ),
                    ),
                    
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        _showDeleteConfirmation(guest);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              Text(value),
            ],
          ),
        ],
      ),
    );
  }
  
  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filtra ospiti'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFilterOption('Tutti'),
            _buildFilterOption('Presenti'),
            _buildFilterOption('Non presenti'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('CHIUDI'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFilterOption(String label) {
    return ListTile(
      title: Text(label),
      onTap: () {
        Navigator.of(context).pop();
        // Implementare filtro
      },
    );
  }
  
  void _showDeleteConfirmation(Guest guest) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conferma eliminazione'),
        content: Text(
          'Sei sicuro di voler eliminare ${guest.nome} ${guest.cognome} dalla lista degli ospiti? Questa azione non può essere annullata.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('ANNULLA'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Implementare eliminazione ospite
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('ELIMINA'),
          ),
        ],
      ),
    );
  }
} 
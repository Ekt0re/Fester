import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fester_frontend/blocs/event/event_bloc.dart';

class CheckinScreen extends StatefulWidget {
  final String eventId;
  
  const CheckinScreen({Key? key, required this.eventId}) : super(key: key);
  
  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  @override
  void initState() {
    super.initState();
    // Carica i dati degli ospiti quando la schermata viene aperta
    context.read<EventBloc>().add(EventGuestsRequested(eventId: widget.eventId));
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Check-in Ospiti'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scansiona QR Code',
            onPressed: () {
              context.push('/events/${widget.eventId}/qr-scanner');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra di ricerca
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Cerca ospite',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          
          // Statistiche di check-in
          BlocBuilder<EventBloc, EventState>(
            builder: (context, state) {
              if (state is EventGuestsLoaded) {
                final totalGuests = state.guests.length;
                final checkedInGuests = state.guests.where((guest) => guest.isPresent).length;
                
                return Container(
                  padding: const EdgeInsets.all(16.0),
                  color: Colors.blue.shade50,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatistic('Totale', totalGuests),
                      _buildStatistic('Presenti', checkedInGuests),
                      _buildStatistic(
                        'Percentuale', 
                        totalGuests > 0 
                          ? '${(checkedInGuests / totalGuests * 100).toStringAsFixed(1)}%'
                          : '0%'
                      ),
                    ],
                  ),
                );
              }
              
              return const SizedBox(height: 80);
            },
          ),
          
          // Lista ospiti
          Expanded(
            child: BlocBuilder<EventBloc, EventState>(
              builder: (context, state) {
                if (state is EventLoading) {
                  return const Center(child: CircularProgressIndicator());
                } else if (state is EventGuestsLoaded) {
                  final filteredGuests = _searchQuery.isEmpty
                      ? state.guests
                      : state.guests.where((guest) =>
                          '${guest.nome} ${guest.cognome}'.toLowerCase()
                              .contains(_searchQuery.toLowerCase())).toList();
                  
                  if (filteredGuests.isEmpty) {
                    return const Center(
                      child: Text('Nessun ospite trovato'),
                    );
                  }
                  
                  return ListView.builder(
                    itemCount: filteredGuests.length,
                    itemBuilder: (context, index) {
                      final guest = filteredGuests[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: guest.isPresent ? Colors.green : Colors.grey,
                            child: Icon(
                              guest.isPresent ? Icons.check : Icons.person,
                              color: Colors.white,
                            ),
                          ),
                          title: Text('${guest.nome} ${guest.cognome}'),
                          subtitle: Text(guest.email),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (guest.isPresent)
                                Text(
                                  'Check-in: ${DateFormat('HH:mm').format(guest.checkinTime ?? DateTime.now())}',
                                  style: const TextStyle(color: Colors.green),
                                ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: guest.isPresent
                                    ? null
                                    : () {
                                        context.read<EventBloc>().add(
                                          EventGuestCheckinRequested(
                                            eventId: widget.eventId,
                                            guestId: guest.id,
                                          ),
                                        );
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: guest.isPresent ? Colors.grey : Colors.green,
                                ),
                                child: Text(
                                  guest.isPresent ? 'Presente' : 'Check-in',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                } else if (state is EventError) {
                  return Center(
                    child: Text('Errore: ${state.message}'),
                  );
                }
                
                return const Center(
                  child: Text('Carica gli ospiti dell\'evento'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatistic(String title, dynamic value) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value.toString(),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
} 
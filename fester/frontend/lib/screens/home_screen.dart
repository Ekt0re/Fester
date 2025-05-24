import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fester_frontend/blocs/auth/auth_bloc.dart';
import 'package:fester_frontend/blocs/event/event_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    // Carica gli eventi al primo avvio
    context.read<EventBloc>().add(const EventsFetchRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fester'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              context.read<AuthBloc>().add(const AuthLogoutRequested());
              context.go('/login');
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildDashboard(),
          _buildEventsTab(),
          _buildProfileTab(),
        ],
      ),
      floatingActionButton: _selectedIndex == 1
          ? FloatingActionButton(
              onPressed: () {
                context.push('/events/create');
              },
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event),
            label: 'Eventi',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profilo',
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dashboard',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          
          // Guida Rapida
          const Text(
            'Guida Rapida',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  'Crea Evento',
                  'Crea un nuovo evento e gestiscilo',
                  Icons.add_box,
                  Colors.blue,
                  () => context.push('/events/create'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildActionCard(
                  'Partecipa ad Evento',
                  'Unisciti allo staff di un evento esistente',
                  Icons.group_add,
                  Colors.green,
                  () => _showJoinEventDialog(),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Stats Cards
          _buildStatsRow(),
          const SizedBox(height: 24),
          
          // Eventi recenti
          const Text(
            'Eventi Recenti',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          BlocBuilder<EventBloc, EventState>(
            builder: (context, state) {
              if (state is EventLoading) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              } else if (state is EventsLoadSuccess) {
                final events = state.events;
                
                if (events.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('Nessun evento trovato. Crea il tuo primo evento!'),
                    ),
                  );
                }
                
                // Mostra solo i primi 3 eventi più recenti
                final recentEvents = events.length > 3 ? events.sublist(0, 3) : events;
                
                return Column(
                  children: recentEvents.map((event) => _buildEventCard(event)).toList(),
                );
              } else if (state is EventFailure) {
                return Center(
                  child: Text('Errore: ${state.message}'),
                );
              }
              
              return const Center(
                child: Text('Carica i tuoi eventi'),
              );
            },
          ),
          
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () {
                setState(() {
                  _selectedIndex = 1; // Passa alla tab Eventi
                });
              },
              child: const Text('Vedi tutti gli eventi'),
            ),
          ),
          
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 48),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showJoinEventDialog() {
    final codeController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Partecipa ad Evento'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Inserisci il codice dell\'evento per unirti come staff',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: codeController,
              decoration: const InputDecoration(
                labelText: 'Codice Evento',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.key),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ANNULLA'),
          ),
          ElevatedButton(
            onPressed: () {
              final code = codeController.text.trim();
              if (code.isNotEmpty) {
                context.read<EventBloc>().add(JoinEventRequested(code: code));
                Navigator.of(context).pop();
              }
            },
            child: const Text('PARTECIPA'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return BlocBuilder<EventBloc, EventState>(
      builder: (context, state) {
        int totalEvents = 0;
        int activeEvents = 0;
        int guestsCount = 0;
        
        if (state is EventsLoadSuccess) {
          totalEvents = state.events.length;
          activeEvents = state.events.where((e) => e['stato'] == 'attivo').length;
          // Questo è solo un esempio, i dati reali dovrebbero venire dall'API
          guestsCount = 0; // Placeholder
        }
        
        return Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Eventi Totali',
                totalEvents.toString(),
                Colors.blue,
                Icons.event,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Eventi Attivi',
                activeEvents.toString(),
                Colors.green,
                Icons.event_available,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Ospiti',
                guestsCount.toString(),
                Colors.orange,
                Icons.people,
              ),
            ),
          ],
        );
      }
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventsTab() {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<EventBloc>().add(const EventsFetchRequested());
      },
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'I tuoi Eventi',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: BlocBuilder<EventBloc, EventState>(
                builder: (context, state) {
                  if (state is EventLoading) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  } else if (state is EventsLoadSuccess) {
                    final events = state.events;
                    
                    if (events.isEmpty) {
                      return const Center(
                        child: Text('Nessun evento trovato. Crea il tuo primo evento!'),
                      );
                    }
                    
                    return ListView.builder(
                      itemCount: events.length,
                      itemBuilder: (context, index) {
                        return _buildEventCard(events[index]);
                      },
                    );
                  } else if (state is EventFailure) {
                    return Center(
                      child: Text('Errore: ${state.message}'),
                    );
                  }
                  
                  return const Center(
                    child: Text('Carica i tuoi eventi'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final dateTime = DateTime.parse(event['data_ora']);
    final formattedDate = dateFormat.format(dateTime);
    
    final statusColor = event['stato'] == 'attivo' 
        ? Colors.green 
        : event['stato'] == 'concluso' 
            ? Colors.grey 
            : Colors.red;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          context.push('/events/${event['id']}');
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      event['nome'],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(26),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      event['stato'],
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      event['luogo'],
                      style: const TextStyle(color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    formattedDate,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (event['ruolo'] != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: event['ruolo'] == 'owner' 
                            ? Colors.purple.withAlpha(26)
                            : Colors.blue.withAlpha(26),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        event['ruolo'] == 'owner' ? 'Organizzatore' : 'Staff',
                        style: TextStyle(
                          color: event['ruolo'] == 'owner' 
                              ? Colors.purple 
                              : Colors.blue,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileTab() {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is AuthAuthenticated) {
          final user = supabase.Supabase.instance.client.auth.currentUser;
          final userMetadata = user?.userMetadata;
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Profilo Utente',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Info profilo
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.deepPurple.shade100,
                        child: Text(
                          userMetadata?['nome']?.substring(0, 1).toUpperCase() ?? 'U',
                          style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '${userMetadata?['nome'] ?? ''} ${userMetadata?['cognome'] ?? ''}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.email ?? '',
                        style: const TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Opzioni account
                const Card(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(Icons.person),
                          title: Text('Modifica Profilo'),
                          trailing: Icon(Icons.chevron_right),
                        ),
                        Divider(),
                        ListTile(
                          leading: Icon(Icons.lock),
                          title: Text('Cambia Password'),
                          trailing: Icon(Icons.chevron_right),
                        ),
                        Divider(),
                        ListTile(
                          leading: Icon(Icons.settings),
                          title: Text('Impostazioni'),
                          trailing: Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Opzioni app
                const Card(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(Icons.help),
                          title: Text('Aiuto e Supporto'),
                          trailing: Icon(Icons.chevron_right),
                        ),
                        Divider(),
                        ListTile(
                          leading: Icon(Icons.info),
                          title: Text('Informazioni'),
                          trailing: Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Logout Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      context.read<AuthBloc>().add(const AuthLogoutRequested());
                      context.go('/login');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Disconnetti'),
                  ),
                ),
              ],
            ),
          );
        }
        
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );
  }
} 
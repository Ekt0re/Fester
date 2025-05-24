import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:qr_flutter/qr_flutter.dart';

class GuestListScreen extends StatefulWidget {
  final String eventId;

  const GuestListScreen({Key? key, required this.eventId}) : super(key: key);

  @override
  State<GuestListScreen> createState() => _GuestListScreenState();
}

class _GuestListScreenState extends State<GuestListScreen> {
  final dio = Dio();
  final secureStorage = const FlutterSecureStorage();
  final String apiBaseUrl = 'http://localhost:5000/api';
  
  List<Map<String, dynamic>> guests = [];
  bool isLoading = true;
  String? error;
  
  @override
  void initState() {
    super.initState();
    _setupDioHeaders();
    _fetchGuests();
  }
  
  Future<void> _setupDioHeaders() async {
    final token = await secureStorage.read(key: 'auth_token');
    if (token != null) {
      dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }
  
  Future<void> _fetchGuests() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    
    try {
      final response = await dio.get(
        '$apiBaseUrl/events/${widget.eventId}/guests',
      );
      
      if (response.statusCode == 200) {
        final data = response.data['data'] as List;
        setState(() {
          guests = data.map((guest) => guest as Map<String, dynamic>).toList();
          isLoading = false;
        });
      } else {
        setState(() {
          error = 'Errore durante il caricamento degli ospiti';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Errore: ${e.toString()}';
        isLoading = false;
      });
    }
  }
  
  Future<void> _updateGuestStatus(String guestId, String newStatus) async {
    try {
      await dio.put(
        '$apiBaseUrl/events/${widget.eventId}/guests/$guestId',
        data: {
          'stato': newStatus,
        },
      );
      
      // Aggiorna la lista
      _fetchGuests();
      
      // Mostra messaggio di conferma solo se il widget è ancora montato
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Stato ospite aggiornato a: $newStatus')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: ${e.toString()}')),
        );
      }
    }
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
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(error!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchGuests,
                        child: const Text('Riprova'),
                      ),
                    ],
                  ),
                )
              : guests.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _fetchGuests,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Stats summary
                          _buildStatsSummary(),
                          
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
  
  Widget _buildStatsSummary() {
    final int totaleOspiti = guests.length;
    final int invitati = guests.where((g) => g['stato'] == 'invitato').length;
    final int confermati = guests.where((g) => g['stato'] == 'confermato').length;
    final int presenti = guests.where((g) => g['stato'] == 'presente').length;
    
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
          _buildStatItem('Invitati', invitati, Colors.orange),
          _buildStatItem('Confermati', confermati, Colors.green),
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
  
  Widget _buildGuestItem(Map<String, dynamic> guest) {
    final statusColor = guest['stato'] == 'invitato'
        ? Colors.orange
        : guest['stato'] == 'confermato'
            ? Colors.green
            : guest['stato'] == 'presente'
                ? Colors.deepPurple
                : Colors.grey;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ExpansionTile(
        title: Text(
          '${guest['nome']} ${guest['cognome']}',
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
            Text(guest['stato']),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (guest['email'] != null && guest['email'].toString().isNotEmpty)
                  _buildInfoRow(Icons.email, 'Email', guest['email']),
                  
                if (guest['telefono'] != null && guest['telefono'].toString().isNotEmpty)
                  _buildInfoRow(Icons.phone, 'Telefono', guest['telefono']),
                  
                if (guest['note'] != null && guest['note'].toString().isNotEmpty) ...[
                  const Divider(),
                  _buildInfoRow(Icons.note, 'Note', guest['note']),
                ],
                
                const Divider(),
                
                // QR Code
                Center(
                  child: Column(
                    children: [
                      const Text(
                        'QR Code per check-in',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      QrImageView(
                        data: guest['codice_qr'] ?? 'error',
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
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        _updateGuestStatus(guest['id'], value);
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'invitato',
                          child: Text('Segna come invitato'),
                        ),
                        const PopupMenuItem(
                          value: 'confermato',
                          child: Text('Segna come confermato'),
                        ),
                        const PopupMenuItem(
                          value: 'presente',
                          child: Text('Segna come presente'),
                        ),
                        const PopupMenuItem(
                          value: 'annullato',
                          child: Text('Annulla invito'),
                        ),
                      ],
                      child: TextButton.icon(
                        icon: const Icon(Icons.edit),
                        label: const Text('Cambia stato'),
                        onPressed: null, // Handled by PopupMenuButton
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
            _buildFilterOption('Invitati'),
            _buildFilterOption('Confermati'),
            _buildFilterOption('Presenti'),
            _buildFilterOption('Annullati'),
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
  
  void _showDeleteConfirmation(Map<String, dynamic> guest) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conferma eliminazione'),
        content: Text(
          'Sei sicuro di voler eliminare ${guest['nome']} ${guest['cognome']} dalla lista degli ospiti? Questa azione non può essere annullata.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('ANNULLA'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              // Implementare eliminazione ospite
              // await dio.delete('$apiBaseUrl/events/${widget.eventId}/guests/${guest['id']}');
              // _fetchGuests();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('ELIMINA'),
          ),
        ],
      ),
    );
  }
} 
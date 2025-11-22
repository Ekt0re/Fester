import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import '../../services/SupabaseServicies/person_service.dart';
import '../../services/SupabaseServicies/event_service.dart';
import 'widgets/consumption_graph.dart';
import 'widgets/transaction_creation_sheet.dart';
import 'widgets/transaction_list_sheet.dart';
import '../dashboard/add_guest_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class PersonProfileScreen extends StatefulWidget {
  final String personId;
  final String eventId;
  final String? currentUserRole;

  const PersonProfileScreen({
    super.key,
    required this.personId,
    required this.eventId,
    this.currentUserRole,
  });

  @override
  State<PersonProfileScreen> createState() => _PersonProfileScreenState();
}

class _PersonProfileScreenState extends State<PersonProfileScreen> {
  final PersonService _personService = PersonService();
  final EventService _eventService = EventService();
  bool _isLoading = true;
  Map<String, dynamic>? _profileData;
  List<Map<String, dynamic>> _transactions = [];
  
  // Stats
  int _alcoholCount = 0;
  int _nonAlcoholCount = 0;
  int _foodCount = 0;
  
  // Limits
  int? _maxDrinks; 

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final profile = await _personService.getPersonProfile(widget.personId, widget.eventId);
      final participationId = profile['id'];
      final transactions = await _personService.getPersonTransactions(participationId);
      final settings = await _eventService.getEventSettings(widget.eventId);

      // Calculate stats
      int alcohol = 0;
      int nonAlcohol = 0;
      int food = 0;

      for (var t in transactions) {
        final type = t['type'] ?? {};
        final typeName = (type['name'] ?? '').toString().toLowerCase();
        final affectsDrinkCount = type['affects_drink_count'] == true;
        final quantity = (t['quantity'] as num?)?.toInt() ?? 0;

        if (typeName == 'drink') {
          if (affectsDrinkCount) {
            alcohol += quantity;
          } else {
            nonAlcohol += quantity;
          }
        } else if (typeName == 'food') {
          food += quantity;
        }
      }

      if (mounted) {
        setState(() {
          _profileData = profile;
          _transactions = transactions;
          _alcoholCount = alcohol;
          _nonAlcoholCount = nonAlcohol;
          _foodCount = food;
          _maxDrinks = settings?.defaultMaxDrinksPerPerson; 
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore caricamento profilo: $e')),
        );
      }
    }
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Impossibile aprire il link')),
        );
      }
    }
  }
  
  void _contactUser(String? email, String? phone) {
    if (email == null && phone == null) return;

    if (phone != null && email == null) {
      _launchUrl('tel:$phone');
      return;
    }
    
    if (email != null && phone == null) {
      _launchUrl('mailto:$email');
      return;
    }

    final theme = Theme.of(context);
    // Both exist, show sheet
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.phone, color: theme.colorScheme.primary),
              title: Text('Chiama $phone', style: TextStyle(color: theme.textTheme.bodyLarge?.color)),
              onTap: () {
                Navigator.pop(context);
                _launchUrl('tel:$phone');
              },
            ),
            ListTile(
              leading: Icon(Icons.email, color: theme.colorScheme.primary),
              title: Text('Invia Email a $email', style: TextStyle(color: theme.textTheme.bodyLarge?.color)),
              onTap: () {
                Navigator.pop(context);
                _launchUrl('mailto:$email');
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showTransactionMenu(String? type) {
    if (_profileData == null) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: TransactionCreationSheet(
          eventId: widget.eventId,
          participationId: _profileData!['id'],
          initialTransactionType: type,
          onSuccess: () {
            _loadData(); // Refresh data
          },
        ),
      ),
    );
  }
  
  void _showTransactionList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TransactionListSheet(
        transactions: _transactions,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_profileData == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(child: Text('Profilo non trovato', style: TextStyle(color: theme.textTheme.bodyLarge?.color))),
      );
    }

    final person = _profileData!['person'] ?? {};
    final role = _profileData!['role'] ?? {};
    final roleName = (role['name'] ?? 'Ospite').toString();
    final isVip = roleName.toLowerCase() == 'vip';
    
    final firstName = person['first_name'] ?? '';
    final lastName = person['last_name'] ?? '';
    final fullName = '$firstName $lastName'.trim();
    final age = _calculateAge(person['date_of_birth']);
    final email = person['email'];
    final phone = person['phone'];
    final canEdit = widget.currentUserRole == 'Staff3' || widget.currentUserRole == 'Admin';
    final hasContact = email != null || phone != null;

    // Filter reports
    final reports = _transactions.where((t) {
      final typeName = (t['type']?['name'] ?? '').toString().toLowerCase();
      return ['fine', 'sanction', 'report'].contains(typeName);
    }).toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: theme.textTheme.bodyLarge?.color),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: theme.textTheme.bodyLarge?.color),
            onPressed: () {
              // Settings or Edit
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          children: [
            // Avatar & Name
            CircleAvatar(
              radius: 50,
              backgroundColor: colorScheme.primary,
              child: Icon(Icons.person, size: 60, color: colorScheme.onPrimary),
            ),
            const SizedBox(height: 16),
            Text(
              fullName.toUpperCase(),
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 24),

            // Personal Details Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: _cardDecoration(theme),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('DETTAGLI PERSONALI', style: _headerStyle(theme)),
                  const SizedBox(height: 12),
                  _detailRow('NOME', firstName, theme),
                  _detailRow('COGNOME', lastName, theme),
                  _detailRow('ETÀ', age, theme),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text('RUOLO: ', style: _labelStyle(theme)),
                      Text(roleName, style: _valueStyle(theme)),
                      if (isVip) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.statusVip,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'VIP',
                            style: GoogleFonts.outfit(
                              color: Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Consumptions Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: _cardDecoration(theme),
              child: Column(
                children: [
                  Text('CONSUMAZIONI', style: _headerStyle(theme)),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      ConsumptionGraph(
                        label: 'ALCOL',
                        count: _alcoholCount,
                        maxCount: _maxDrinks,
                        icon: Icons.local_bar,
                        color: Colors.blueGrey,
                        onLongPress: () => _showTransactionMenu('drink'),
                      ),
                      ConsumptionGraph(
                        label: 'ANALCOL',
                        count: _nonAlcoholCount,
                        maxCount: null, // Usually unlimited?
                        icon: Icons.free_breakfast, // Using closest match for now
                        color: Colors.blueGrey,
                        onLongPress: () => _showTransactionMenu('drink'), // Default to drink, toggle in sheet
                      ),
                      ConsumptionGraph(
                        label: 'CIBO',
                        count: _foodCount,
                        maxCount: null,
                        icon: Icons.local_pizza,
                        color: Colors.blueGrey,
                        onLongPress: () => _showTransactionMenu('food'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _showTransactionList,
                    child: Text(
                      'Visualizza elenco transazioni',
                      style: GoogleFonts.outfit(
                        color: theme.textTheme.bodyLarge?.color,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Contact Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: _cardDecoration(theme),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CONTATTO', style: _headerStyle(theme)),
                  const SizedBox(height: 12),
                  if (email != null && email.toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          const Icon(Icons.email, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(child: Text(email, style: _valueStyle(theme))),
                        ],
                      ),
                    ),
                  if (phone != null && phone.toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Row(
                        children: [
                          const Icon(Icons.phone, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(child: Text(phone, style: _valueStyle(theme))),
                        ],
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: hasContact ? () => _contactUser(email, phone) : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        disabledBackgroundColor: Colors.grey[300],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'CONTATTA',
                        style: GoogleFonts.outfit(
                          color: colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Reports Area
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'AREA SEGNALAZIONI', 
                      style: GoogleFonts.outfit(
                        fontSize: 14, 
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.bodyLarge?.color
                      )
                    ),
                    TextButton.icon(
                      onPressed: () => _showTransactionMenu('report'),
                      icon: Icon(Icons.add, size: 16, color: colorScheme.error),
                      label: Text(
                        'AGGIUNGI',
                        style: GoogleFonts.outfit(
                          color: colorScheme.error,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (reports.isNotEmpty) ...[
                   ...reports.map((r) {
                     final typeName = (r['type']?['name'] ?? '').toString().toUpperCase();
                     final description = r['description'] ?? '';
                     return Container(
                       width: double.infinity,
                       margin: const EdgeInsets.only(bottom: 12),
                       padding: const EdgeInsets.all(16),
                       decoration: _cardDecoration(theme).copyWith(
                         boxShadow: [
                           BoxShadow(
                             color: colorScheme.error.withOpacity(0.1),
                             blurRadius: 8,
                             offset: const Offset(0, 4),
                           )
                         ]
                       ),
                       child: Row(
                         children: [
                           Icon(Icons.warning_amber_rounded, color: colorScheme.error, size: 32),
                           const SizedBox(width: 16),
                           Expanded(
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Text(
                                   typeName,
                                   style: GoogleFonts.outfit(
                                     color: colorScheme.error,
                                     fontWeight: FontWeight.bold,
                                     fontSize: 18,
                                   ),
                                 ),
                                 if (description.isNotEmpty)
                                   Text(
                                     description,
                                     style: GoogleFonts.outfit(color: Colors.grey[700]),
                                   ),
                               ],
                             ),
                           ),
                         ],
                       ),
                     );
                   }),
                ] else ...[
                   Container(
                     width: double.infinity,
                     padding: const EdgeInsets.all(20),
                     decoration: _cardDecoration(theme),
                     child: Center(
                       child: Text(
                         'Nessuna segnalazione',
                         style: GoogleFonts.outfit(color: Colors.grey),
                       ),
                     ),
                   ),
                ],
              ],
            ),
            const SizedBox(height: 80), // Space for FAB
          ],
        ),
      ),
      floatingActionButton: canEdit ? FloatingActionButton(
        onPressed: () async {
          if (_profileData == null) return;
          
          final person = _profileData!['person'];
          final initialData = {
            'first_name': person['first_name'],
            'last_name': person['last_name'],
            'email': person['email'],
            'phone': person['phone'],
            'date_of_birth': person['date_of_birth'],
            'role_id': _profileData!['role_id'],
            'status_id': _profileData!['status_id'],
          };

          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddGuestScreen(
                eventId: widget.eventId,
                personId: person['id'],
                initialData: initialData,
              ),
            ),
          );

          if (result == true) {
            _loadData(); // Refresh profile if updated
          }
        },
        backgroundColor: colorScheme.primary,
        child: Icon(Icons.edit, color: colorScheme.onPrimary),
      ) : null,
    );
  }

  BoxDecoration _cardDecoration(ThemeData theme) {
    return BoxDecoration(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  TextStyle _headerStyle(ThemeData theme) {
    return GoogleFonts.outfit(
      fontSize: 14,
      fontWeight: FontWeight.bold,
      color: theme.textTheme.bodyLarge?.color,
      letterSpacing: 0.5,
    );
  }

  TextStyle _labelStyle(ThemeData theme) {
    return GoogleFonts.outfit(
      fontSize: 14,
      color: Colors.grey[600],
    );
  }

  TextStyle _valueStyle(ThemeData theme) {
    return GoogleFonts.outfit(
      fontSize: 14,
      color: theme.textTheme.bodyLarge?.color,
      fontWeight: FontWeight.w500,
    );
  }

  Widget _detailRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          Text('$label: ', style: _labelStyle(theme)),
          Text(value, style: _valueStyle(theme)),
        ],
      ),
    );
  }

  String _calculateAge(String? dobString) {
    if (dobString == null) return '--';
    try {
      final dob = DateTime.parse(dobString);
      final now = DateTime.now();
      int age = now.year - dob.year;
      if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
        age--;
      }
      return age.toString();
    } catch (_) {
      return '--';
    }
  }
}

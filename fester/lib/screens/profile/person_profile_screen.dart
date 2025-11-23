import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import '../../services/SupabaseServicies/person_service.dart';
import '../../services/SupabaseServicies/event_service.dart';
import '../../services/SupabaseServicies/participation_service.dart';
import 'widgets/consumption_graph.dart';
import 'widgets/transaction_creation_sheet.dart';
import 'widgets/transaction_list_sheet.dart';
import 'widgets/status_history_sheet.dart';
import '../dashboard/add_guest_screen.dart';
import '../../widgets/animated_settings_icon.dart';
import '../settings/settings_screen.dart';
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
  final ParticipationService _participationService = ParticipationService();
  
  bool _isLoading = true;
  Map<String, dynamic>? _profileData;
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _statusHistory = [];
  List<Map<String, dynamic>> _statuses = [];
  
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
      
      // Parallel requests for better performance
      final results = await Future.wait([
        _personService.getPersonTransactions(participationId),
        _eventService.getEventSettings(widget.eventId),
        _participationService.getParticipationStatusHistory(participationId),
        _participationService.getParticipationStatuses(),
      ]);

      final transactions = results[0] as List<Map<String, dynamic>>;
      final settings = results[1] as dynamic; // EventSettings?
      final history = results[2] as List<Map<String, dynamic>>;
      final statuses = results[3] as List<Map<String, dynamic>>;

      // Calculate stats
      int alcohol = 0;
      int nonAlcohol = 0;
      int food = 0;

      for (var t in transactions) {
        final type = t['type'] ?? {};
        final typeName = (type['name'] ?? '').toString().toLowerCase();
        final description = (t['description'] ?? '').toString();
        
        // Determine if alcoholic based on type AND description tag
        bool affectsDrinkCount = type['affects_drink_count'] == true;
        
        // Override if tagged as non-alcoholic
        if (description.contains('[NON-ALCOHOLIC]')) {
          affectsDrinkCount = false;
        }

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
          _statusHistory = history;
          _statuses = statuses;
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

  void _showTransactionMenu(String? type, {bool? isAlcoholic}) {
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
          initialIsAlcoholic: isAlcoholic,
          onSuccess: () {
            _loadData(); // Refresh data
          },
        ),
      ),
    );
  }
  
  void _showTransactionList() {
    final canEdit = widget.currentUserRole?.toLowerCase() == 'staff3' || widget.currentUserRole?.toLowerCase() == 'admin';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TransactionListSheet(
        transactions: _transactions,
        canEdit: canEdit,
        onTransactionUpdated: _loadData,
      ),
    );
  }

  void _showStatusHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatusHistorySheet(
        history: _statusHistory,
      ),
    );
  }

  Future<void> _updateStatus(int newStatusId) async {
    if (_profileData == null) return;
    
    try {
      await _participationService.updateParticipation(
        participationId: _profileData!['id'],
        statusId: newStatusId,
      );
      
      // Refresh data to show new status and history
      await _loadData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stato aggiornato')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore aggiornamento stato: $e')),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'confermato':
        return AppTheme.statusConfirmed;
      case 'checked_in':
      case 'registrato':
        return AppTheme.statusCheckedIn;
      case 'inside':
      case 'dentro':
      case 'arrivato':
        return AppTheme.statusConfirmed;
      case 'outside':
      case 'fuori':
        return AppTheme.statusOutside;
      case 'left':
      case 'uscito':
      case 'partito':
        return AppTheme.statusLeft;
      case 'invited':
      case 'invitato':
      case 'in arrivo':
        return AppTheme.statusInvited;
      default:
        return AppTheme.statusInvited;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'confermato':
        return Icons.check_circle_outline;
      case 'checked_in':
      case 'registrato':
        return Icons.how_to_reg;
      case 'inside':
      case 'dentro':
      case 'arrivato':
        return Icons.login;
      case 'outside':
      case 'fuori':
        return Icons.logout;
      case 'left':
      case 'uscito':
      case 'partito':
        return Icons.exit_to_app;
      case 'invited':
      case 'invitato':
      case 'in arrivo':
        return Icons.mail_outline;
      default:
        return Icons.help_outline;
    }
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
    final statusId = _profileData!['status_id'] as int;
    
    final firstName = person['first_name'] ?? '';
    final lastName = person['last_name'] ?? '';
    final fullName = '$firstName $lastName'.trim();
    final age = _calculateAge(person['date_of_birth']);
    final email = person['email'];
    final phone = person['phone'];
    
    // Check permissions (case insensitive)
    final userRole = widget.currentUserRole?.toLowerCase();
    final canEdit = userRole == 'staff3' || userRole == 'admin';
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
          AnimatedSettingsIcon(
            color: theme.colorScheme.onSurface,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
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

            // 1. CONSUMPTIONS (Moved to top)
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
                        icon: AppTheme.transactionIcons['drink']!,
                        color: Colors.blueGrey,
                        onLongPress: () => _showTransactionMenu('drink', isAlcoholic: true),
                      ),
                      ConsumptionGraph(
                        label: 'ANALCOL',
                        count: _nonAlcoholCount,
                        maxCount: null, 
                        icon: Icons.free_breakfast, 
                        color: Colors.blueGrey,
                        onLongPress: () => _showTransactionMenu('drink', isAlcoholic: false),
                      ),
                      ConsumptionGraph(
                        label: 'CIBO',
                        count: _foodCount,
                        maxCount: null,
                        icon: AppTheme.transactionIcons['food']!,
                        color: Colors.blueGrey,
                        onLongPress: () => _showTransactionMenu('food'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Total Spent / Earned
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Totale: ',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                      Text(
                        '${_calculateTotal() >= 0 ? '+' : ''}${_calculateTotal().toStringAsFixed(2)} €',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _calculateTotal() >= 0 ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
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

            // 2. DETAILS + CONTACT (Side by Side)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Personal Details
                  Expanded(
                    flex: 3,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: _cardDecoration(theme),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('DETTAGLI', style: _headerStyle(theme)),
                          const SizedBox(height: 12),
                          _detailRow('NOME', firstName, theme),
                          _detailRow('COGNOME', lastName, theme),
                          _detailRow('ETÀ', age, theme),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(AppTheme.roleIcons[roleName.toLowerCase()] ?? Icons.person, size: 16, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(roleName, style: _valueStyle(theme)),
                              if (isVip) ...[
                                const SizedBox(width: 8),
                                Icon(AppTheme.roleIcons['vip'], size: 16, color: AppTheme.statusVip),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Contact
                  Expanded(
                    flex: 2,
                    child: Container(
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
                                  Icon(Icons.email, size: 16, color: theme.colorScheme.primary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      email, 
                                      style: _valueStyle(theme).copyWith(fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (phone != null && phone.toString().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: Row(
                                children: [
                                  Icon(Icons.phone, size: 16, color: theme.colorScheme.primary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      phone, 
                                      style: _valueStyle(theme).copyWith(fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const Spacer(), // Push button to bottom if needed, or just let it sit
                          if (hasContact)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => _contactUser(email, phone),
                                icon: const Icon(Icons.contact_phone, size: 16),
                                label: Text(
                                  'CONTATTA',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colorScheme.primary,
                                  foregroundColor: colorScheme.onPrimary,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            )
                          else
                            Text('Nessun contatto', style: _labelStyle(theme)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. PARTICIPATION STATUS
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: _cardDecoration(theme),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('STATO PARTECIPAZIONE', style: _headerStyle(theme)),
                  const SizedBox(height: 12),
                  
                  // Status Dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: statusId,
                        isExpanded: true,
                        items: _statuses.map((s) {
                          final name = (s['name'] as String).toUpperCase();
                          final color = _getStatusColor(s['name']);
                          final icon = _getStatusIcon(s['name']);
                          
                          return DropdownMenuItem<int>(
                            value: s['id'] as int,
                            child: Row(
                              children: [
                                Icon(icon, color: color, size: 20),
                                const SizedBox(width: 12),
                                Text(
                                  name,
                                  style: GoogleFonts.outfit(
                                    color: theme.textTheme.bodyLarge?.color,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null && val != statusId) {
                            _updateStatus(val);
                          }
                        },
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // History Link
                  InkWell(
                    onTap: _showStatusHistory,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Visualizza cronologia stati',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            color: colorScheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios, size: 14, color: colorScheme.primary),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 4. REPORTS AREA
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
                    if (canEdit) // Only show add button if staff/admin
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
                     final name = r['name'] ?? '';
                     final description = r['description'] ?? '';
                     
                     // Format: TYPE - NAME
                     final title = name.isNotEmpty ? '$typeName - $name' : typeName;

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
                           Icon(AppTheme.transactionIcons['report'] ?? Icons.warning_amber_rounded, color: colorScheme.error, size: 32),
                           const SizedBox(width: 16),
                           Expanded(
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Text(
                                   title,
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
                           // Edit Button for Reports (if staff/admin)
                           if (canEdit)
                             IconButton(
                               icon: const Icon(Icons.edit, size: 20),
                               onPressed: () {
                                 // Open edit dialog or sheet
                                 // We can reuse TransactionListSheet logic or create a simple dialog
                                 // For now, let's open TransactionListSheet filtered? 
                                 // Or better, just open the full list since we added edit there.
                                 _showTransactionList();
                               },
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
            'participation_id': _profileData!['id'],
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

  double _calculateTotal() {
    double total = 0;
    for (var t in _transactions) {
      final amount = (t['amount'] as num?)?.toDouble() ?? 0.0;
      final quantity = (t['quantity'] as num?)?.toInt() ?? 1;
      total += amount * quantity;
    }
    return total;
  }
}

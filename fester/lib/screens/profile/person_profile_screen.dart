import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../theme/app_theme.dart';
import '../../services/supabase/person_service.dart';
import '../../services/supabase/event_service.dart';
import '../../services/supabase/participation_service.dart';
import 'widgets/consumption_graph.dart';
import 'widgets/transaction_creation_sheet.dart';
import 'widgets/transaction_list_sheet.dart';
import 'widgets/status_history_sheet.dart';
import '../dashboard/add_guest_screen.dart';
import '../../widgets/animated_settings_icon.dart';
import '../settings/settings_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../utils/qr_code_generator.dart';
import 'invited_guests_screen.dart';
import 'group_members_screen.dart';

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
      final profile = await _personService.getPersonProfile(
        widget.personId,
        widget.eventId,
      );
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
          SnackBar(
            content: Text('${'person_profile.profile_load_error'.tr()}$e'),
          ),
        );
      }
    }
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('person_profile.launch_error'.tr())),
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
      builder:
          (context) => Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.phone, color: theme.colorScheme.primary),
                  title: Text(
                    'person_profile.call_user'.tr(args: [phone.toString()]),
                    style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _launchUrl('tel:$phone');
                  },
                ),
                ListTile(
                  leading: Icon(Icons.email, color: theme.colorScheme.primary),
                  title: Text(
                    'person_profile.email_user'.tr(args: [email.toString()]),
                    style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                  ),
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
      builder:
          (context) => Padding(
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
    final canEdit =
        widget.currentUserRole?.toLowerCase() == 'staff3' ||
        widget.currentUserRole?.toLowerCase() == 'admin';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => TransactionListSheet(
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
      builder: (context) => StatusHistorySheet(history: _statusHistory),
    );
  }

  void _showQRCode() {
    if (_profileData == null) return;
    final participationId = _profileData!['id'];
    final qrData = QRCodeGenerator.generate(participationId);
    final person = _profileData!['person'] ?? {};
    final fullName = '${person['first_name']} ${person['last_name']}';

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'person_profile.qr_code_title'.tr(),
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    fullName,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 24),
                  QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 250.0,
                    backgroundColor: Colors.white,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    qrData,
                    style: GoogleFonts.robotoMono(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryLight,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text('common.close'.tr()),
                    ),
                  ),
                ],
              ),
            ),
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
          SnackBar(content: Text('person_profile.status_updated'.tr())),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${'person_profile.status_update_error'.tr()}$e'),
          ),
        );
      }
    }
  }

  Widget _buildAvatarAndName(
    ThemeData theme,
    ColorScheme colorScheme,
    String fullName,
  ) {
    return Column(
      children: [
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
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _showQRCode,
          icon: const Icon(Icons.qr_code, size: 18),
          label: Text('person_profile.show_qr_code'.tr()),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
            foregroundColor: theme.colorScheme.primary,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConsumptions(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(theme),
      child: Column(
        children: [
          Text(
            'person_profile.consumptions_title'.tr(),
            style: _headerStyle(theme),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              ConsumptionGraph(
                label: 'person_profile.alcohol_label'.tr(),
                count: _alcoholCount,
                maxCount: _maxDrinks,
                icon: AppTheme.transactionIcons['drink']!,
                color: Colors.blueGrey,
                onLongPress:
                    () => _showTransactionMenu('drink', isAlcoholic: true),
              ),
              ConsumptionGraph(
                label: 'person_profile.non_alcohol_label'.tr(),
                count: _nonAlcoholCount,
                maxCount: null,
                icon: Icons.free_breakfast,
                color: Colors.blueGrey,
                onLongPress:
                    () => _showTransactionMenu('drink', isAlcoholic: false),
              ),
              ConsumptionGraph(
                label: 'person_profile.food_label'.tr(),
                count: _foodCount,
                maxCount: null,
                icon: AppTheme.transactionIcons['food']!,
                color: Colors.blueGrey,
                onLongPress: () => _showTransactionMenu('food'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'person_profile.total_label'.tr(),
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
              'person_profile.view_transactions'.tr(),
              style: GoogleFonts.outfit(
                color: theme.textTheme.bodyLarge?.color,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsAndContact(
    ThemeData theme,
    ColorScheme colorScheme,
    String firstName,
    String lastName,
    String age,
    String roleName,
    bool isVip,
    String? email,
    String? phone,
    bool hasContact,
  ) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: _cardDecoration(theme),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'person_profile.details_title'.tr(),
                    style: _headerStyle(theme),
                  ),
                  const SizedBox(height: 12),
                  _detailRow(
                    'person_profile.name_label'.tr(),
                    firstName,
                    theme,
                  ),
                  _detailRow(
                    'person_profile.surname_label'.tr(),
                    lastName,
                    theme,
                  ),
                  _detailRow('person_profile.age_label'.tr(), age, theme),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        AppTheme.roleIcons[roleName.toLowerCase()] ??
                            Icons.person,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(roleName, style: _valueStyle(theme)),
                      if (isVip) ...[
                        const SizedBox(width: 8),
                        Icon(
                          AppTheme.roleIcons['vip'],
                          size: 16,
                          color: AppTheme.statusVip,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: _cardDecoration(theme),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'person_profile.contact_title'.tr(),
                    style: _headerStyle(theme),
                  ),
                  const SizedBox(height: 12),
                  if (email != null && email.toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          Icon(
                            Icons.email,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
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
                          Icon(
                            Icons.phone,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
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
                  const Spacer(),
                  if (hasContact)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _contactUser(email, phone),
                        icon: const Icon(Icons.contact_phone, size: 16),
                        label: Text(
                          'person_profile.contact_button'.tr(),
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
                    Text(
                      'person_profile.no_contact'.tr(),
                      style: _labelStyle(theme),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalInfo(
    ThemeData theme,
    String? codiceFiscale,
    String? indirizzo,
    dynamic sottogruppo,
    dynamic gruppo,
    String? invitedById,
    String? invitedByName,
    String? currentAreaName,
  ) {
    // Check if there's any data to display
    final hasData =
        (codiceFiscale != null && codiceFiscale.isNotEmpty) ||
        (indirizzo != null && indirizzo.isNotEmpty) ||
        (sottogruppo != null) ||
        (gruppo != null) ||
        (invitedByName != null && invitedByName.isNotEmpty) ||
        (currentAreaName != null);

    if (!hasData) {
      return const SizedBox.shrink(); // Return empty widget if no data
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(theme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'person_profile.additional_info'.tr(),
            style: _headerStyle(theme),
          ),
          const SizedBox(height: 12),
          if (currentAreaName != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  Text(
                    'Area Attuale: ',
                    style: _labelStyle(theme).copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Text(
                    currentAreaName,
                    style: _valueStyle(
                      theme,
                    ).copyWith(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            ),
          if (codiceFiscale != null && codiceFiscale.isNotEmpty)
            _detailRow('person_profile.fiscal_code'.tr(), codiceFiscale, theme),
          if (indirizzo != null && indirizzo.isNotEmpty)
            _detailRow('person_profile.address'.tr(), indirizzo, theme),
          if (invitedByName != null &&
              invitedByName.isNotEmpty &&
              invitedById != null)
            _groupLinkRow(
              'person_profile.invited_by'.tr(),
              invitedByName,
              theme,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => InvitedGuestsScreen(
                          inviterId: invitedById,
                          inviterName: invitedByName,
                          eventId: widget.eventId,
                        ),
                  ),
                );
              },
            ),
          if (sottogruppo != null)
            _groupLinkRow(
              'person_profile.subgroup'.tr(),
              sottogruppo['name'],
              theme,
              () => _showGroupMembers(
                sottogruppo['id'],
                sottogruppo['name'],
                true,
              ),
            ),
          if (gruppo != null)
            _groupLinkRow(
              'person_profile.group'.tr(),
              gruppo['name'],
              theme,
              () => _showGroupMembers(gruppo['id'], gruppo['name'], false),
            ),
        ],
      ),
    );
  }

  Widget _groupLinkRow(
    String label,
    String value,
    ThemeData theme,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 150, child: Text(label, style: _labelStyle(theme))),
          Expanded(
            child: InkWell(
              onTap: onTap,
              child: Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: theme.colorScheme.primary,
                  decoration: TextDecoration.underline,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showGroupMembers(int id, String name, bool isSubgroup) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => GroupMembersScreen(
              groupId: id,
              groupName: name,
              isSubgroup: isSubgroup,
              eventId: widget.eventId,
            ),
      ),
    );
  }

  Widget _buildParticipationStatus(
    ThemeData theme,
    ColorScheme colorScheme,
    int statusId,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(theme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'person_profile.participation_status'.tr(),
            style: _headerStyle(theme),
          ),
          const SizedBox(height: 12),
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
                items:
                    _statuses.map((s) {
                      final name =
                          'status.${s['name'].toString().toLowerCase()}'
                              .tr()
                              .toUpperCase();
                      final color = AppTheme.getStatusColor(
                        s['name'].toString(),
                      );
                      final icon = AppTheme.getStatusIcon(s['name'].toString());

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
          InkWell(
            onTap: _showStatusHistory,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'person_profile.view_status_history'.tr(),
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: colorScheme.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: colorScheme.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportsArea(
    ThemeData theme,
    ColorScheme colorScheme,
    bool canEdit,
    List<Map<String, dynamic>> reports,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'person_profile.reports_area'.tr(),
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
            if (canEdit)
              TextButton.icon(
                onPressed: () => _showTransactionMenu('report'),
                icon: Icon(Icons.add, size: 16, color: colorScheme.error),
                label: Text(
                  'person_profile.add_report'.tr(),
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
            final typeName =
                (r['type']?['name'] ?? '').toString().toUpperCase();
            final name = r['name'] ?? '';
            final description = r['description'] ?? '';

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
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    AppTheme.transactionIcons['report'] ??
                        Icons.warning_amber_rounded,
                    color: colorScheme.error,
                    size: 32,
                  ),
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
                  if (canEdit)
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () {
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
                'person_profile.no_reports'.tr(),
                style: GoogleFonts.outfit(color: Colors.grey),
              ),
            ),
          ),
        ],
      ],
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
        body: Center(
          child: Text(
            'person_profile.profile_not_found'.tr(),
            style: TextStyle(color: theme.textTheme.bodyLarge?.color),
          ),
        ),
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
    final codiceFiscale = person['codice_fiscale'] as String?;
    final indirizzo = person['indirizzo'] as String?;
    final sottogruppo = person['sottogruppo'];
    final gruppo = person['gruppo'];

    final currentArea = _profileData!['current_area'];
    final currentAreaName = currentArea?['name'] as String?;

    // Get invited_by information
    final invitedById = _profileData!['invited_by'] as String?;
    String? invitedByName;
    if (invitedById != null) {
      // Try to get the name from the invited_by_person if it exists
      final invitedByPerson = _profileData!['invited_by_person'];
      if (invitedByPerson != null) {
        invitedByName =
            '${invitedByPerson['first_name'] ?? ''} ${invitedByPerson['last_name'] ?? ''}'
                .trim();
      }
    }

    final userRole = widget.currentUserRole?.toLowerCase();
    final canEdit = userRole == 'staff3' || userRole == 'admin';
    final hasContact = email != null || phone != null;

    final reports =
        _transactions.where((t) {
          final typeName = (t['type']?['name'] ?? '').toString().toLowerCase();
          return ['fine', 'sanction', 'report'].contains(typeName);
        }).toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: theme.textTheme.bodyLarge?.color,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          AnimatedSettingsIcon(
            color: theme.colorScheme.onSurface,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 900;

          if (isDesktop) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Column(
                    children: [
                      _buildAvatarAndName(theme, colorScheme, fullName),
                      const SizedBox(height: 32),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Column
                          Expanded(
                            flex: 4,
                            child: Column(
                              children: [
                                _buildDetailsAndContact(
                                  theme,
                                  colorScheme,
                                  firstName,
                                  lastName,
                                  age,
                                  roleName,
                                  isVip,
                                  email,
                                  phone,
                                  hasContact,
                                ),
                                const SizedBox(height: 24),
                                _buildAdditionalInfo(
                                  theme,
                                  codiceFiscale,
                                  indirizzo,
                                  sottogruppo,
                                  gruppo,
                                  invitedById,
                                  invitedByName,
                                  currentAreaName,
                                ),
                                const SizedBox(height: 24),
                                _buildParticipationStatus(
                                  theme,
                                  colorScheme,
                                  statusId,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 32),
                          // Right Column
                          Expanded(
                            flex: 6,
                            child: Column(
                              children: [
                                _buildConsumptions(theme),
                                const SizedBox(height: 24),
                                _buildReportsArea(
                                  theme,
                                  colorScheme,
                                  canEdit,
                                  reports,
                                ),
                              ],
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

          // Mobile Layout
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              children: [
                _buildAvatarAndName(theme, colorScheme, fullName),
                const SizedBox(height: 24),
                _buildConsumptions(theme),
                const SizedBox(height: 16),
                _buildDetailsAndContact(
                  theme,
                  colorScheme,
                  firstName,
                  lastName,
                  age,
                  roleName,
                  isVip,
                  email,
                  phone,
                  hasContact,
                ),
                const SizedBox(height: 16),
                _buildAdditionalInfo(
                  theme,
                  codiceFiscale,
                  indirizzo,
                  sottogruppo,
                  gruppo,
                  invitedById,
                  invitedByName,
                  currentAreaName,
                ),
                const SizedBox(height: 16),
                _buildParticipationStatus(theme, colorScheme, statusId),
                const SizedBox(height: 16),
                _buildReportsArea(theme, colorScheme, canEdit, reports),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
      floatingActionButton:
          canEdit
              ? FloatingActionButton(
                onPressed: () async {
                  if (_profileData == null) return;

                  final person = _profileData!['person'];
                  final initialData = {
                    'person': person, // Pass the entire person object
                    'first_name': person['first_name'],
                    'last_name': person['last_name'],
                    'email': person['email'],
                    'phone': person['phone'],
                    'date_of_birth': person['date_of_birth'],
                    'role_id': _profileData!['role_id'],
                    'status_id': _profileData!['status_id'],
                    'participation_id': _profileData!['id'],
                    'id': _profileData!['id'], // Add participation id
                    'local_id': _profileData!['local_id'],
                    'invited_by': _profileData!['invited_by'],
                    'codice_fiscale':
                        _profileData!['codice_fiscale'], // Aggiunto codice fiscale
                    'gruppo': _profileData!['gruppo'], // Aggiunto gruppo
                    'sottogruppo':
                        _profileData!['sottogruppo'], // Aggiunto sottogruppo
                  };

                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => AddGuestScreen(
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
              )
              : null,
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
    return GoogleFonts.outfit(fontSize: 14, color: Colors.grey[600]);
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
      if (now.month < dob.month ||
          (now.month == dob.month && now.day < dob.day)) {
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

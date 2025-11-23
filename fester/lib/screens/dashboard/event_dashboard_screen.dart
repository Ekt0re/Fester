import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/SupabaseServicies/event_service.dart';
import '../../services/SupabaseServicies/models/event.dart';
import '../../theme/app_theme.dart';
import '../../widgets/animated_settings_icon.dart';
import 'guest_list_screen.dart';
import 'staff_list_screen.dart';
import 'global_search_screen.dart';
import '../settings/settings_screen.dart';

class EventDashboardScreen extends StatefulWidget {
  final String eventId;

  const EventDashboardScreen({super.key, required this.eventId});

  @override
  State<EventDashboardScreen> createState() => _EventDashboardScreenState();
}

class _EventDashboardScreenState extends State<EventDashboardScreen> {
  final EventService _eventService = EventService();
  Event? _event;
  bool _isLoading = true;
  int _staffCount = 0;
  String? _userRole;
  Timer? _syncTimer;
  DateTime _lastSync = DateTime.now();
  int _selectedIndex = 0; // For NavigationRail/BottomNavBar

  @override
  void initState() {
    super.initState();
    _loadEventData();
    // Auto-sync every minute
    _syncTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _loadEventData(silent: true);
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadEventData({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoading = true);
    }
    try {
      final event = await _eventService.getEventById(widget.eventId);
      final staff = await _eventService.getEventStaff(widget.eventId);
      
      // Find current user role
      final userId = Supabase.instance.client.auth.currentUser?.id;
      String? role;
      if (userId != null) {
        try {
          final userStaff = staff.firstWhere((s) => s.staffUserId == userId);
          role = userStaff.roleName; 
        } catch (_) {
          // User might be creator but not in staff list explicitly or other issue
        }
      }

      if (mounted) {
        setState(() {
          _event = event;
          _staffCount = staff.length;
          _userRole = role;
          _lastSync = DateTime.now();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        if (!silent) setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore caricamento evento: $e')),
        );
      }
    }
  }

  String _getTimeSinceSync() {
    final diff = DateTime.now().difference(_lastSync);
    if (diff.inMinutes < 1) return 'Adesso';
    return '${diff.inMinutes} min fa';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= AppTheme.desktopBreakpoint) {
          return _buildDesktopLayout();
        } else {
          return _buildMobileLayout();
        }
      },
    );
  }

  Widget _buildMobileLayout() {
    final user = Supabase.instance.client.auth.currentUser;
    final userName = user?.userMetadata?['first_name'] ?? 'Organizzatore';

    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildAppBar(theme: theme),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadEventData(silent: true),
              child: _buildDashboardContent(isDesktop: false, userName: userName, theme: theme),
            ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.primaryLight,
          borderRadius: BorderRadius.vertical(top: Radius.circular(0)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildBottomNavItem(Icons.search, Colors.cyanAccent, 0),
            _buildBottomNavItem(Icons.notifications, Colors.amber, 1),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.home, color: Colors.orangeAccent, size: 30),
            ),
            _buildBottomNavItem(Icons.book, Colors.pinkAccent, 2),
            _buildBottomNavItem(Icons.sports_bar, Colors.white, 3),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(IconData icon, Color color, int index) {
    return IconButton(
      icon: Icon(icon, color: color),
      onPressed: () {
        if (index == 0) {
          // Navigate to Global Search Screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GlobalSearchScreen(eventId: widget.eventId),
            ),
          );
        } else {
          // Handle navigation for other items
        }
      },
    );
  }

  Widget _buildDesktopLayout() {
    final user = Supabase.instance.client.auth.currentUser;
    final userName = user?.userMetadata?['first_name'] ?? 'Organizzatore';

    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              if (index == 1) {
                // Navigate to Global Search Screen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GlobalSearchScreen(eventId: widget.eventId),
                  ),
                );
              } else {
                setState(() {
                  _selectedIndex = index;
                });
              }
            },
            backgroundColor: theme.colorScheme.primary,
            selectedIconTheme: IconThemeData(color: theme.colorScheme.secondary),
            unselectedIconTheme: IconThemeData(color: theme.colorScheme.onPrimary.withOpacity(0.7)),
            selectedLabelTextStyle: GoogleFonts.outfit(color: theme.colorScheme.secondary, fontWeight: FontWeight.bold),
            unselectedLabelTextStyle: GoogleFonts.outfit(color: theme.colorScheme.onPrimary.withOpacity(0.7)),
            extended: true,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Column(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.surface,
                    radius: 24,
                    child: Icon(Icons.person, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    userName,
                    style: GoogleFonts.outfit(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.home),
                label: Text('Home'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.search),
                label: Text('Cerca'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.notifications),
                label: Text('Notifiche'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.book),
                label: Text('Prenotazioni'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.sports_bar),
                label: Text('Bar'),
              ),
            ],
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      );
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.settings, color: theme.colorScheme.onPrimary.withOpacity(0.7)),
                        const SizedBox(height: 4),
                        Text(
                          'Impostazioni',
                          style: GoogleFonts.outfit(
                            color: theme.colorScheme.onPrimary.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: Column(
              children: [
                _buildAppBar(isDesktop: true, theme: theme),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _buildDashboardContent(isDesktop: true, userName: userName, theme: theme),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar({bool isDesktop = false, required ThemeData theme}) {
    return AppBar(
      backgroundColor: theme.scaffoldBackgroundColor,
      elevation: 0,
      leading: isDesktop
          ? null
          : IconButton(
              icon: Icon(Icons.arrow_back_ios, color: theme.colorScheme.onSurface),
              onPressed: () => Navigator.of(context).pop(),
            ),
      title: Column(
        children: [
          Text(
            'FESTER 3.0',
            style: GoogleFonts.outfit(
              color: theme.colorScheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'ORGANIZZA LA TUA FESTA!',
            style: GoogleFonts.outfit(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
              fontSize: 10,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
      centerTitle: true,
      actions: [
        if (!isDesktop)
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
        if (isDesktop) const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildDashboardContent({required bool isDesktop, required String userName, required ThemeData theme}) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isDesktop ? 1200 : 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Welcome Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Benvenuto, $userName!',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: isDesktop ? 28 : 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (_userRole != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withOpacity(0.5)),
                            ),
                            child: Text(
                              _userRole!.toUpperCase(),
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Gestisci il tuo evento con facilità',
                      style: GoogleFonts.outfit(
                        color: Colors.white70,
                        fontSize: isDesktop ? 16 : 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Icon(Icons.sync, color: Colors.orange, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Ultimo sync: ${_getTimeSinceSync()}',
                          style: GoogleFonts.outfit(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        if (isDesktop) ...[
                          const Spacer(),
                          ElevatedButton.icon(
                            onPressed: () {
                              // Action for desktop
                            },
                            icon: const Icon(Icons.desktop_windows, size: 16),
                            label: const Text("Desktop Action"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.surface,
                              foregroundColor: theme.colorScheme.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                          )
                        ]
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Grid Actions
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: isDesktop ? 4 : 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: isDesktop ? 1.5 : 1.4,
                children: [
                  _DashboardCard(
                    icon: Icons.people,
                    iconColor: const Color(0xFFE0BBE4),
                    label: 'Elenco ospiti',
                    value: '0', // Placeholder
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => GuestListScreen(eventId: widget.eventId),
                        ),
                      );
                    },
                  ),
                  _DashboardCard(
                    icon: Icons.local_bar,
                    iconColor: const Color(0xFF957DAD),
                    label: 'Elenco consumazioni',
                    value: '0', // Placeholder
                    onTap: () {},
                  ),
                  _DashboardCard(
                    icon: Icons.person,
                    iconColor: const Color(0xFFD291BC),
                    label: 'Gestisci staff',
                    value: '$_staffCount',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StaffListScreen(eventId: widget.eventId),
                        ),
                      );
                    },
                  ),
                  _DashboardCard(
                    icon: Icons.bar_chart,
                    iconColor: const Color(0xFFFEC8D8),
                    label: 'Visualizza statistiche',
                    value: '0', // Placeholder
                    onTap: () {},
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Scan QR Button
              if (!isDesktop) ...[
                Container(
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        // TODO: Open QR Scanner
                      },
                      borderRadius: BorderRadius.circular(24),
                      child: Center(
                        child: Text(
                          'SCAN QR',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ] else ...[
                // Desktop alternative for Scan QR (maybe smaller or different)
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surface.withOpacity(0.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code_scanner, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                        const SizedBox(width: 12),
                        Text(
                          'Usa l\'app mobile per scansionare i QR code',
                          style: GoogleFonts.outfit(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _DashboardCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(icon, color: iconColor, size: 28),
                    Text(
                      value,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
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

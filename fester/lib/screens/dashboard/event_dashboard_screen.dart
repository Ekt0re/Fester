import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase/event_service.dart';
import '../../services/supabase/models/event.dart';
import '../../theme/app_theme.dart';
import '../../widgets/animated_settings_icon.dart';
import '../../services/notification_service.dart';
import '../../services/notification_scheduler.dart';
import '../../services/permission_service.dart';
// Ensure this exists for navigation
import '../settings/settings_screen.dart';
import 'event_settings_screen.dart';
import 'event_export_screen.dart';
import 'guests_import_screen.dart';
import '../profile/staff_profile_screen.dart';
import '../../services/supabase/models/event_staff.dart';
import 'people_counter_screen.dart';
import 'communications_screen.dart';
import '../../utils/location_helper.dart';

class EventDashboardScreen extends StatefulWidget {
  final String eventId;

  const EventDashboardScreen({super.key, required this.eventId});

  @override
  State<EventDashboardScreen> createState() => _EventDashboardScreenState();
}

class _EventDashboardScreenState extends State<EventDashboardScreen> {
  final EventService _eventService = EventService();
  final _scheduler = NotificationScheduler();
  Event? _event;
  bool _isLoading = true;
  int _staffCount = 0;
  int _guestCount = 0;
  int _menuItemCount = 0;
  String? _userRole;
  EventStaff? _currentUserStaff;
  RealtimeChannel? _subscription;
  Timer? _syncTimer;
  //DateTime _lastSync = DateTime.now(); // Unused
  int _selectedIndex = 0; // For NavigationRail/BottomNavBar
  String? _eventLocation;

  @override
  void initState() {
    super.initState();
    _loadEventData();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    _scheduler.dispose();
    _syncTimer?.cancel();
    _subscription?.unsubscribe();
    super.dispose();
  }

  void _setupRealtimeSubscription() {
    final supabase = Supabase.instance.client;
    // Subscribe to multiple tables changes
    _subscription =
        supabase
            .channel('event_dashboard:${widget.eventId}')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'participation',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'event_id',
                value: widget.eventId,
              ),
              callback: (payload) {
                _loadEventData(silent: true);
              },
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'event_staff',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'event_id',
                value: widget.eventId,
              ),
              callback: (payload) {
                _loadEventData(silent: true);
              },
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'menu',
              // Menu item changes are harder to track directly if we filter by event_id on menu table,
              // but let's try to catch menu table changes for now.
              // Ideally we'd need to filter menu_id which we might not have yet.
              // For simplicity, we'll reload on any menu change for this event.
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'event_id',
                value: widget.eventId,
              ),
              callback: (payload) {
                _loadEventData(silent: true);
              },
            )
            .subscribe();

    // Separate subscription for menu items might be needed if we knew the menu IDs,
    // but simpler to rely on polling for deep nested changes or broader subscription if needed.
    // For now, let's keep the timer as a fallback but increase duration or rely on this.
    // We will keep the 1 minute timer as a safe fallback.
    _syncTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _loadEventData(silent: true);
    });
  }

  Future<void> _loadEventData({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoading = true);
    }
    try {
      final event = await _eventService.getEventById(widget.eventId);

      final staff = await _eventService.getEventStaff(widget.eventId);

      // Count guests (participations)
      final supabase = Supabase.instance.client;
      final guestCountResult = await supabase
          .from('participation')
          .select('id')
          .eq('event_id', widget.eventId);
      final guestCount = (guestCountResult as List).length;

      // Count menu items
      int menuItemCount = 0;
      try {
        final menuResult =
            await supabase
                .from('menu')
                .select('id')
                .eq('event_id', widget.eventId)
                .maybeSingle();

        if (menuResult != null) {
          final menuItemResult = await supabase
              .from('menu_item')
              .select('id')
              .eq('menu_id', menuResult['id']);
          menuItemCount = (menuItemResult as List).length;
        }
      } catch (_) {
        // Menu might not exist yet
      }

      // Fetch settings (location, start/end time)
      String? location;
      DateTime? startAt;
      DateTime? endAt;
      try {
        final settingsResult =
            await supabase
                .from('event_settings')
                .select('location, start_at, end_at')
                .eq('event_id', widget.eventId)
                .maybeSingle();
        if (settingsResult != null) {
          location = settingsResult['location'] as String?;
          if (settingsResult['start_at'] != null) {
            startAt = DateTime.parse(settingsResult['start_at']);
          }
          if (settingsResult['end_at'] != null) {
            endAt = DateTime.parse(settingsResult['end_at']);
          }
        }
      } catch (_) {}

      // Find current user role and staff object
      final userId = Supabase.instance.client.auth.currentUser?.id;
      String? role;
      EventStaff? currentUserStaff;
      if (userId != null) {
        try {
          final userStaff = staff.firstWhere((s) => s.staffUserId == userId);
          role = userStaff.roleName;
          currentUserStaff = userStaff;
        } catch (_) {
          // User might be creator but not in staff list explicitly or other issue
        }
      }

      if (mounted) {
        setState(() {
          _event = event;
          _isLoading = false;
          _staffCount = staff.length;
          _guestCount = guestCount;
          _menuItemCount = menuItemCount;
          _userRole = role;
          _currentUserStaff = currentUserStaff;
          _eventLocation = location;
          //_lastSync = DateTime.now();
          _isLoading = false;
        });

        // Invia notifica di sync se non è silenzioso
        if (!silent && _event != null) {
          NotificationService().notifySync(
            eventId: widget.eventId,
            updatedItems: _guestCount + _menuItemCount + _staffCount,
          );

          // Schedule notifications
          if (_event != null && startAt != null) {
            _scheduler.schedule(
              eventId: widget.eventId,
              eventName: _event!.name,
              start: startAt,
              end: endAt,
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        if (!silent) setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'dashboard.load_error'.tr()}$e')),
        );
      }
    }
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
    final userName =
        user?.userMetadata?['first_name'] ?? 'dashboard.organizer_default'.tr();

    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildAppBar(theme: theme),
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: () => _loadEventData(silent: true),
                child: _buildDashboardContent(
                  isDesktop: false,
                  userName: userName,
                  theme: theme,
                ),
              ),
          _buildMobileBottomSheetMenu(theme),
        ],
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
              child: const Icon(
                Icons.home,
                color: Colors.orangeAccent,
                size: 30,
              ),
            ),
            _buildBottomNavItem(Icons.restaurant_menu, Colors.pinkAccent, 2),
            _buildBottomNavItem(Icons.settings, Colors.white, 3),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileBottomSheetMenu(ThemeData theme) {
    return DraggableScrollableSheet(
      initialChildSize: 0.06, // Much smaller when hidden - just the handle
      minChildSize: 0.06,
      maxChildSize: 0.55,
      snap: true,
      snapSizes: const [0.06, 0.35, 0.55], // Snap points for smooth UX
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    // Handle bar - minimal when collapsed
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: theme.dividerColor.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                    // Title only visible when expanded
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        "dashboard.quick_menu".tr(),
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                sliver: SliverGrid.count(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.95, // Better proportions
                  children: [
                    if (PermissionService.canEdit(_userRole))
                      _buildMenuGridItem(
                        icon: Icons.settings,
                        label: 'dashboard.event_settings'.tr(),
                        color: Colors.blue,
                        onTap: () {
                          _handleNavigationWithReload(
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => EventSettingsScreen(
                                      eventId: widget.eventId,
                                    ),
                              ),
                            ),
                          );
                        },
                      ),
                    _buildMenuGridItem(
                      icon: Icons.download,
                      label: 'dashboard.export_data'.tr(),
                      color: Colors.green,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => EventExportScreen(
                                  eventId: widget.eventId,
                                  eventName:
                                      _event?.name ?? 'dashboard.event'.tr(),
                                ),
                          ),
                        );
                      },
                    ),
                    if (PermissionService.canAdd(_userRole))
                      _buildMenuGridItem(
                        icon: Icons.upload_file,
                        label: 'dashboard.import_guests'.tr(),
                        color: Colors.orange,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => GuestsImportScreen(
                                    eventId: widget.eventId,
                                  ),
                            ),
                          );
                        },
                      ),
                    if (PermissionService.canEdit(_userRole))
                      _buildMenuGridItem(
                        icon: Icons.people_outline,
                        label: 'dashboard.people_counter'.tr(),
                        color: Colors.purple,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => PeopleCounterScreen(
                                    eventId: widget.eventId,
                                  ),
                            ),
                          );
                        },
                      ),
                    if (PermissionService.canManageSmtp(_userRole))
                      _buildMenuGridItem(
                        icon: Icons.alternate_email,
                        label: 'smtp_config.title'.tr(),
                        color: Colors.blueAccent,
                        onTap: () {
                          context.push('/event/${widget.eventId}/smtp-config');
                        },
                      ),
                    if (PermissionService.canEdit(_userRole))
                      _buildMenuGridItem(
                        icon: Icons.mail_outline,
                        label: 'dashboard.communications'.tr(),
                        color: Colors.teal,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => CommunicationsScreen(
                                    eventId: widget.eventId,
                                    currentUserRole: _userRole,
                                  ),
                            ),
                          );
                        },
                      ),
                    _buildMenuGridItem(
                      icon: Icons.analytics_outlined,
                      label: 'dashboard.advanced_stats'.tr(),
                      color: Colors.red,
                      onTap: () {
                        context.push('/event/${widget.eventId}/statistics');
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuGridItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start, // Align to top
        children: [
          const SizedBox(height: 12), // Fixed top padding
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Reload handler when returning from pages that might edit event
  Future<void> _handleNavigationWithReload(
    Future<dynamic> navigationFuture,
  ) async {
    await navigationFuture;
    _loadEventData(silent: true);
  }

  Widget _buildBottomNavItem(IconData icon, Color color, int index) {
    return IconButton(
      icon: Icon(icon, color: color),
      onPressed: () {
        if (index == 0) {
          // Navigate to Global Search Screen
          context.push('/event/${widget.eventId}/search');
        } else if (index == 1) {
          // Navigate to Notifications Screen
          context.push('/event/${widget.eventId}/notifications');
        } else if (index == 2) {
          // Navigate to Menu Management
          _handleNavigationWithReload(
            context.push('/event/${widget.eventId}/menu', extra: _userRole),
          );
        } else if (index == 3) {
          // Navigate to Event Settings
          _handleNavigationWithReload(
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) => EventSettingsScreen(eventId: widget.eventId),
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildDesktopLayout() {
    final user = Supabase.instance.client.auth.currentUser;
    final userName =
        user?.userMetadata?['first_name'] ?? 'dashboard.organizer_default'.tr();

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
                context.push('/event/${widget.eventId}/search');
              } else if (index == 2) {
                // Navigate to Notifications Screen
                context.push('/event/${widget.eventId}/notifications');
              } else if (index == 3) {
                // Navigate to Menu Management Screen
                context.push('/event/${widget.eventId}/menu', extra: _userRole);
              } else {
                setState(() {
                  _selectedIndex = index;
                });
              }
            },
            backgroundColor: theme.colorScheme.primary,
            selectedIconTheme: IconThemeData(
              color: theme.colorScheme.secondary,
            ),
            unselectedIconTheme: IconThemeData(
              color: theme.colorScheme.onPrimary.withOpacity(0.7),
            ),
            selectedLabelTextStyle: GoogleFonts.outfit(
              color: theme.colorScheme.secondary,
              fontWeight: FontWeight.bold,
            ),
            unselectedLabelTextStyle: GoogleFonts.outfit(
              color: theme.colorScheme.onPrimary.withOpacity(0.7),
            ),
            extended: true,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Column(
                children: [
                  InkWell(
                    onTap: () {
                      if (_currentUserStaff != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => StaffProfileScreen(
                                  eventStaff: _currentUserStaff!,
                                  eventId: widget.eventId,
                                ),
                          ),
                        );
                      }
                    },
                    child: CircleAvatar(
                      backgroundColor: theme.colorScheme.surface,
                      radius: 24,
                      backgroundImage:
                          (_currentUserStaff?.staff?.imagePath != null &&
                                  _currentUserStaff!
                                      .staff!
                                      .imagePath!
                                      .isNotEmpty)
                              ? NetworkImage(
                                _currentUserStaff!.staff!.imagePath!,
                              )
                              : null,
                      child:
                          (_currentUserStaff?.staff?.imagePath == null ||
                                  _currentUserStaff!.staff!.imagePath!.isEmpty)
                              ? Icon(
                                Icons.person,
                                color: theme.colorScheme.primary,
                              )
                              : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    userName,
                    style: GoogleFonts.outfit(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            destinations: [
              NavigationRailDestination(
                icon: const Icon(Icons.home),
                label: Text('dashboard.nav.home'.tr()),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.search),
                label: Text('dashboard.nav.search'.tr()),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.notifications),
                label: Text('dashboard.nav.notifications'.tr()),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.restaurant_menu),
                label: Text('dashboard.nav.menu'.tr()),
              ),
            ],
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Event Menu Button
                      PopupMenuButton<String>(
                        offset: const Offset(200, 0),
                        icon: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.more_vert,
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                        tooltip: 'dashboard.manage_event'.tr(),
                        itemBuilder:
                            (context) => [
                              if (PermissionService.canEdit(_userRole))
                                PopupMenuItem(
                                  value: 'settings',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.settings,
                                        color: theme.colorScheme.primary,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'dashboard.event_settings'.tr(),
                                        style: GoogleFonts.outfit(),
                                      ),
                                    ],
                                  ),
                                ),
                              PopupMenuItem(
                                value: 'export',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.download,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'dashboard.export_data'.tr(),
                                      style: GoogleFonts.outfit(),
                                    ),
                                  ],
                                ),
                              ),
                              if (PermissionService.canAdd(_userRole))
                                PopupMenuItem(
                                  value: 'import',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.upload_file,
                                        color: theme.colorScheme.primary,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'dashboard.import_guests'.tr(),
                                        style: GoogleFonts.outfit(),
                                      ),
                                    ],
                                  ),
                                ),
                              if (PermissionService.canEdit(_userRole))
                                PopupMenuItem(
                                  value: 'people_counter',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.people_outline,
                                        color: theme.colorScheme.primary,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'dashboard.people_counter'.tr(),
                                        style: GoogleFonts.outfit(),
                                      ),
                                    ],
                                  ),
                                ),
                              if (PermissionService.canManageSmtp(_userRole))
                                PopupMenuItem(
                                  value: 'smtp_config',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.alternate_email,
                                        color: theme.colorScheme.primary,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'smtp_config.title'.tr(),
                                        style: GoogleFonts.outfit(),
                                      ),
                                    ],
                                  ),
                                ),
                              if (PermissionService.canEdit(_userRole))
                                PopupMenuItem(
                                  value: 'communications',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.mail_outline,
                                        color: theme.colorScheme.primary,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'dashboard.communications'.tr(),
                                        style: GoogleFonts.outfit(),
                                      ),
                                    ],
                                  ),
                                ),
                              const PopupMenuItem(
                                value: 'divider',
                                enabled: false,
                                child: Divider(),
                              ),
                              PopupMenuItem(
                                value: 'statistics',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.analytics_outlined,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'dashboard.advanced_stats'.tr(),
                                      style: GoogleFonts.outfit(),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                        onSelected: (value) {
                          if (value == 'settings') {
                            _handleNavigationWithReload(
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => EventSettingsScreen(
                                        eventId: widget.eventId,
                                      ),
                                ),
                              ),
                            );
                          } else if (value == 'export') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => EventExportScreen(
                                      eventId: widget.eventId,
                                      eventName:
                                          _event?.name ??
                                          'dashboard.event'.tr(),
                                    ),
                              ),
                            );
                          } else if (value == 'import') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => GuestsImportScreen(
                                      eventId: widget.eventId,
                                    ),
                              ),
                            );
                          } else if (value == 'statistics') {
                            context.push('/event/${widget.eventId}/statistics');
                          } else if (value == 'people_counter') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => PeopleCounterScreen(
                                      eventId: widget.eventId,
                                      currentUserRole: _userRole,
                                    ),
                              ),
                            );
                          } else if (value == 'communications') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => CommunicationsScreen(
                                      eventId: widget.eventId,
                                      currentUserRole: _userRole,
                                    ),
                              ),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'dashboard.manage_event'.tr(),
                        style: GoogleFonts.outfit(
                          color: theme.colorScheme.onPrimary.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // App Settings Button
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) =>
                                      SettingsScreen(eventId: widget.eventId),
                            ),
                          );
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.settings,
                              color: theme.colorScheme.onPrimary.withOpacity(
                                0.7,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'dashboard.settings'.tr(),
                              style: GoogleFonts.outfit(
                                color: theme.colorScheme.onPrimary.withOpacity(
                                  0.7,
                                ),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
                  child:
                      _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _buildDashboardContent(
                            isDesktop: true,
                            userName: userName,
                            theme: theme,
                          ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar({
    bool isDesktop = false,
    required ThemeData theme,
  }) {
    return AppBar(
      backgroundColor: theme.scaffoldBackgroundColor,
      elevation: 0,
      leading:
          isDesktop
              ? IconButton(
                icon: const Icon(Icons.exit_to_app),
                tooltip: 'dashboard.exit_to_selection'.tr(),
                onPressed: () => context.go('/event-selection'),
              )
              : IconButton(
                icon: const Icon(Icons.exit_to_app),
                tooltip: 'dashboard.exit_to_selection'.tr(),
                onPressed: () => context.go('/event-selection'),
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
            'dashboard.subtitle'.tr(),
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
              _handleNavigationWithReload(
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => SettingsScreen(eventId: widget.eventId),
                  ),
                ),
              );
            },
          ),
        if (isDesktop) const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildDashboardContent({
    required bool isDesktop,
    required String userName,
    required ThemeData theme,
  }) {
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
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min, // Compact vertical size
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'dashboard.welcome'.tr(args: [userName]),
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize:
                                  isDesktop ? 24 : 18, // Reduced font size
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (_userRole != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.5),
                              ),
                            ),
                            child: Text(
                              _userRole!.toUpperCase(),
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4), // Reduced spacing
                    Text(
                      'dashboard.manage_ease'.tr(),
                      style: GoogleFonts.outfit(
                        color: Colors.white70,
                        fontSize: isDesktop ? 14 : 12,
                      ),
                    ),
                    const SizedBox(height: 4), // Reduced spacing
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: Colors.white70,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getLocationName(_eventLocation),
                          style: GoogleFonts.outfit(
                            color: Colors.white70,
                            fontSize: isDesktop ? 14 : 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12), // Reduced spacing
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            // Realtime indicator
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.greenAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'LIVE',
                              style: GoogleFonts.outfit(
                                color: Colors.greenAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                        if (isDesktop) ...[
                          const Spacer(),
                          // Removed the placeholder button
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16), // Reduced spacing below card
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
                    label: 'dashboard.guest_list'.tr(),
                    value: '$_guestCount',
                    onTap: () {
                      context.push('/event/${widget.eventId}/guests');
                    },
                  ),
                  _DashboardCard(
                    icon: Icons.restaurant_menu,
                    iconColor: const Color(0xFF957DAD),
                    label: 'dashboard.menu_management'.tr(),
                    value: '$_menuItemCount',
                    onTap: () {
                      context.push(
                        '/event/${widget.eventId}/menu',
                        extra: _userRole,
                      );
                    },
                  ),
                  _DashboardCard(
                    icon: Icons.person,
                    iconColor: const Color(0xFFD291BC),
                    label: 'dashboard.manage_staff'.tr(),
                    value: '$_staffCount',
                    onTap: () {
                      context.push(
                        '/event/${widget.eventId}/staff',
                        extra: _userRole,
                      );
                    },
                  ),
                  _DashboardCard(
                    icon: Icons.bar_chart,
                    iconColor: const Color(0xFFFEC8D8),
                    label: 'dashboard.view_stats'.tr(),
                    value: '',
                    onTap: () {
                      context.push('/event/${widget.eventId}/statistics');
                    },
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
                        context.push(
                          '/event/${widget.eventId}/qr-scanner',
                          extra: _userRole,
                        );
                      },
                      borderRadius: BorderRadius.circular(24),
                      child: Center(
                        child: Text(
                          'dashboard.scan_qr'.tr(),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.qr_code_scanner,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'dashboard.desktop_qr_hint'.tr(),
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

  String _getLocationName(String? location) {
    if (location == null || location.isEmpty) {
      return 'dashboard.no_location'.tr();
    }
    final name = LocationHelper.getName(location);
    return name.isNotEmpty ? name : 'dashboard.no_location'.tr();
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

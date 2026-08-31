import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../services/permission_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui' as ui;

class MobileNavBar extends StatefulWidget {
  final String? eventId;
  final String? userRole;

  const MobileNavBar({super.key, this.eventId, this.userRole});

  @override
  State<MobileNavBar> createState() => _MobileNavBarState();
}

class _MobileNavBarState extends State<MobileNavBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  String? _fetchedRole;

  @override
  void initState() {
    super.initState();
    _fetchedRole = widget.userRole;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<double>(
      begin: 0,
      end: -15,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    if (widget.eventId != null && widget.userRole == null) {
      _fetchUserRole();
    }
  }

  @override
  void didUpdateWidget(MobileNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userRole != oldWidget.userRole) {
      setState(() => _fetchedRole = widget.userRole);
    }
    if (widget.eventId != oldWidget.eventId ||
        (widget.userRole == null && _fetchedRole == null)) {
      if (widget.eventId != null && widget.userRole == null) {
        _fetchUserRole();
      }
    }
  }

  Future<void> _fetchUserRole() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null || widget.eventId == null) return;

      final response =
          await Supabase.instance.client
              .from('event_staff')
              .select('role:role_id(name)')
              .eq('event_id', widget.eventId!)
              .eq('staff_user_id', user.id)
              .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          final roleData = response['role'] as Map<String, dynamic>?;
          _fetchedRole = roleData?['name'] as String?;
        });
      }
    } catch (e) {
      debugPrint('Error fetching user role: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  void _onTapAnimation() {
    _controller.forward().then((_) => _controller.reverse());
  }

  void _hideMenu() {
    if (_sheetController.size > 0.05) {
      _sheetController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _toggleMenu() {
    _onTapAnimation();
    if (_sheetController.size > 0.05) {
      _hideMenu();
    } else {
      _sheetController.animateTo(
        0.6,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool hasEventId =
        widget.eventId != null && widget.eventId!.isNotEmpty;
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Barrier for tapping outside to close
        if (hasEventId)
          ListenableBuilder(
            listenable: _sheetController,
            builder: (context, child) {
              final double size =
                  _sheetController.isAttached ? _sheetController.size : 0.0;
              if (size <= 0.05) return const SizedBox.shrink();
              return GestureDetector(
                onTap: _hideMenu,
                behavior: HitTestBehavior.opaque,
                child: Container(color: Colors.transparent),
              );
            },
          ),

        // Quick Menu Sheet (Behind the navbar)
        if (hasEventId) _buildMobileBottomSheetMenu(theme),

        // Floating NavBar
        Positioned(
          left: 16,
          right: 16,
          bottom:
              bottomPadding > 0
                  ? bottomPadding + 8
                  : 16, // Standardized padding
          child: AnimatedBuilder(
            animation: _slideAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _slideAnimation.value),
                child: child,
              );
            },
            child: Container(
              height: 65,
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: GestureDetector(
                onTap: _hideMenu,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: _buildNavItems(context, hasEventId),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildNavItems(BuildContext context, bool hasEventId) {
    if (!hasEventId) {
      return [
        _buildNavItem(Icons.home_rounded, Colors.white, () {
          _onTapAnimation();
          context.go('/event-selection');
        }),
        _buildNavItem(Icons.person_rounded, Colors.white70, () {
          _onTapAnimation();
        }),
        _buildNavItem(Icons.settings_rounded, Colors.white70, () {
          _onTapAnimation();
          context.push('/event-selection');
        }),
      ];
    }

    final roleToPass = _fetchedRole ?? widget.userRole;

    return [
      _buildNavItem(Icons.grid_view_rounded, Colors.cyanAccent, () {
        _toggleMenu();
      }),
      _buildNavItem(Icons.qr_code_scanner_rounded, Colors.amberAccent, () {
        _hideMenu();
        _onTapAnimation();
        context.push('/event/${widget.eventId}/qr-scanner', extra: roleToPass);
      }),
      _buildNavItem(Icons.home_rounded, Colors.white, () {
        _hideMenu();
        _onTapAnimation();
        context.go('/event/${widget.eventId}');
      }, isMain: true),
      _buildNavItem(Icons.groups_rounded, Colors.pinkAccent, () {
        _hideMenu();
        _onTapAnimation();
        context.push(
          '/event/${widget.eventId}/people-counter',
          extra: roleToPass,
        );
      }),
      _buildNavItem(Icons.settings_rounded, Colors.white, () {
        _hideMenu();
        _onTapAnimation();
        context.push('/event/${widget.eventId}/settings');
      }),
    ];
  }

  Widget _buildNavItem(
    IconData icon,
    Color color,
    VoidCallback onTap, {
    bool isMain = false,
  }) {
    if (isMain) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: Icon(icon, color: color, size: 30),
        ),
      );
    }
    return IconButton(
      icon: Icon(icon, color: color, size: 26),
      onPressed: onTap,
      splashRadius: 24,
    );
  }

  Widget _buildMobileBottomSheetMenu(ThemeData theme) {
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.0,
      minChildSize: 0.0,
      maxChildSize: 0.7,
      snap: true,
      snapSizes: const [0.0, 0.7],
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: theme.cardColor.withOpacity(0.9),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
              ),
              child: GestureDetector(
                onTap: _hideMenu,
                behavior: HitTestBehavior.translucent,
                child: CustomScrollView(
                  controller: scrollController,
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            child: Center(
                              child: Container(
                                width: 45,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: theme.dividerColor.withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ),
                          Text(
                            "dashboard.quick_menu".tr(),
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              letterSpacing: 0.5,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 10,
                      ),
                      sliver: SliverGrid.count(
                        crossAxisCount: 3,
                        mainAxisSpacing: 25,
                        crossAxisSpacing: 25,
                        childAspectRatio: 0.9,
                        children: [
                          _buildMenuGridItem(
                            icon: Icons.notifications_rounded,
                            label: 'dashboard.nav.notifications'.tr(),
                            color: Colors.amberAccent,
                            onTap: () {
                              _hideMenu();
                              context.push(
                                '/event/${widget.eventId}/notifications',
                              );
                            },
                            theme: theme,
                          ),
                          _buildMenuGridItem(
                            icon: Icons.search_rounded,
                            label: 'dashboard.nav.search'.tr(),
                            color: Colors.cyanAccent,
                            onTap: () {
                              _hideMenu();
                              context.push(
                                '/event/${widget.eventId}/search',
                                extra: widget.userRole,
                              );
                            },
                            theme: theme,
                          ),
                          _buildMenuGridItem(
                            icon: Icons.restaurant_menu_rounded,
                            label: 'dashboard.nav.menu'.tr(),
                            color: Colors.pinkAccent,
                            onTap: () {
                              _hideMenu();
                              context.push(
                                '/event/${widget.eventId}/menu',
                                extra: widget.userRole,
                              );
                            },
                            theme: theme,
                          ),
                          if (PermissionService.canEdit(widget.userRole))
                            _buildMenuGridItem(
                              icon: Icons.settings_outlined,
                              label: 'dashboard.event_settings'.tr(),
                              color: Colors.blueAccent,
                              onTap: () {
                                _hideMenu();
                                context.push(
                                  '/event/${widget.eventId}/settings',
                                );
                              },
                              theme: theme,
                            ),
                          _buildMenuGridItem(
                            icon: Icons.upload_file_outlined,
                            label: 'dashboard.import_guests'.tr(),
                            color: Colors.orangeAccent,
                            onTap: () {
                              _hideMenu();
                              context.push(
                                '/event/${widget.eventId}/import-guests',
                              );
                            },
                            theme: theme,
                          ),
                          if (PermissionService.canEdit(widget.userRole))
                            _buildMenuGridItem(
                              icon: Icons.people_outline_rounded,
                              label: 'dashboard.people_counter'.tr(),
                              color: Colors.purpleAccent,
                              onTap: () {
                                _hideMenu();
                                context.push(
                                  '/event/${widget.eventId}/people-counter',
                                  extra: widget.userRole,
                                );
                              },
                              theme: theme,
                            ),
                          if (PermissionService.canManageSmtp(widget.userRole))
                            _buildMenuGridItem(
                              icon: Icons.alternate_email_rounded,
                              label: 'smtp_config.title'.tr(),
                              color: Colors.indigoAccent,
                              onTap: () {
                                _hideMenu();
                                context.push(
                                  '/event/${widget.eventId}/smtp-config',
                                );
                              },
                              theme: theme,
                            ),
                          if (PermissionService.canEdit(widget.userRole))
                            _buildMenuGridItem(
                              icon: Icons.mail_outline_rounded,
                              label: 'dashboard.communications'.tr(),
                              color: Colors.tealAccent,
                              onTap: () {
                                _hideMenu();
                                context.push(
                                  '/event/${widget.eventId}/communications',
                                );
                              },
                              theme: theme,
                            ),
                          _buildMenuGridItem(
                            icon: Icons.analytics_outlined,
                            label: 'dashboard.advanced_stats'.tr(),
                            color: Colors.redAccent,
                            onTap: () {
                              _hideMenu();
                              context.push(
                                '/event/${widget.eventId}/statistics',
                              );
                            },
                            theme: theme,
                          ),
                        ],
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 120)),
                  ],
                ),
              ),
            ),
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
    required ThemeData theme,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: color.withOpacity(0.2),
        highlightColor: color.withOpacity(0.1),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                // Use a cleaner look with just color opacity
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: color.withOpacity(0.3), width: 1),
                // Removed heavy shadow for "cleaner" look requested
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.visible,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

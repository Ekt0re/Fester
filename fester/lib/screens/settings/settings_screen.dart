import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../models/app_settings.dart';
import '../../services/settings_service.dart';
import '../../services/SupabaseServicies/staff_user_service.dart';
import '../../services/SupabaseServicies/models/staff_user.dart';
import '../../providers/theme_provider.dart';
import 'widgets/settings_tile.dart';
import 'language_settings_screen.dart';
import 'notification_settings_screen.dart';
import 'theme_editor_screen.dart';
import 'faq_screen.dart';
import 'support_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../config/localization_config.dart';
import 'feedback_screen.dart';

class SettingsScreen extends StatefulWidget {
  final String? eventId;

  const SettingsScreen({super.key, this.eventId});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settingsService = SettingsService();
  AppSettings _settings = AppSettings.defaultSettings;
  String _appVersion = '';
  bool _isLoading = true;
  StaffUser? _currentStaffUser;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadAppVersion();
    _loadStaffUser();
  }

  Future<void> _loadSettings() async {
    final settings = await _settingsService.loadSettings();
    if (mounted) {
      setState(() {
        _settings = settings;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
      });
    }
  }

  Future<void> _loadStaffUser() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        final staffService = StaffUserService();
        final staffUser = await staffService.getStaffUserById(userId);
        if (mounted) {
          setState(() {
            _currentStaffUser = staffUser;
          });
        }
      }
    } catch (e) {
      // Silently fail - user might not have staff profile yet
    }
  }

  Future<void> _updateSettings(AppSettings newSettings) async {
    await _settingsService.saveSettings(newSettings);
    setState(() {
      _settings = newSettings;
    });
  }

  Future<void> _resetSettings() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('settings.reset_dialog.title'.tr()),
            content: Text('settings.reset_dialog.content'.tr()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('settings.reset_dialog.cancel'.tr()),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text('settings.reset_dialog.confirm'.tr()),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await _settingsService.resetSettings();
      await _loadSettings();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('settings.reset_success'.tr())));
      }
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('settings.logout_dialog.title'.tr()),
            content: Text('settings.logout_dialog.content'.tr()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('settings.logout_dialog.cancel'.tr()),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text('settings.logout_dialog.confirm'.tr()),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = Supabase.instance.client.auth.currentUser;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'settings.title'.tr(),
          style: GoogleFonts.outfit(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 900;
          if (isDesktop) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Column: Profile & Logout
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: [
                        _buildUserProfile(theme, user),
                        const SizedBox(height: 32),
                        _buildLogoutButton(theme),
                        const SizedBox(height: 16),
                        Text(
                          '${'settings.app_version_prefix'.tr()} $_appVersion',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 48),
                  // Right Column: Settings Sections
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.eventId != null) ...[
                          _buildSectionHeader(
                            theme,
                            'settings.event_settings'.tr(),
                          ),
                          const SizedBox(height: 12),
                          _buildEventSettingsSection(theme),
                          const SizedBox(height: 32),
                        ],
                        _buildSectionHeader(theme, 'settings.preferences'.tr()),
                        const SizedBox(height: 12),
                        _buildPreferencesSection(theme),
                        const SizedBox(height: 32),
                        _buildSectionHeader(
                          theme,
                          'settings.help_support'.tr(),
                        ),
                        const SizedBox(height: 12),
                        _buildHelpSection(theme),
                      ],
                    ),
                  ),
                ],
              ),
            );
          } else {
            // Mobile Layout
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildUserProfile(theme, user),
                  const SizedBox(height: 32),
                  if (widget.eventId != null) ...[
                    _buildSectionHeader(theme, 'settings.event_settings'.tr()),
                    const SizedBox(height: 12),
                    _buildEventSettingsSection(theme),
                    const SizedBox(height: 32),
                  ],
                  _buildSectionHeader(theme, 'settings.preferences'.tr()),
                  const SizedBox(height: 12),
                  _buildPreferencesSection(theme),
                  const SizedBox(height: 32),
                  _buildSectionHeader(theme, 'settings.help_support'.tr()),
                  const SizedBox(height: 12),
                  _buildHelpSection(theme),
                  const SizedBox(height: 32),
                  _buildLogoutButton(theme),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      '${'settings.app_version'.tr()} $_appVersion',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildUserProfile(ThemeData theme, User? user) {
    final userMetadata = user?.userMetadata;
    final firstName =
        userMetadata?['first_name'] ?? 'settings.user_default'.tr();
    final lastName = userMetadata?['last_name'] ?? '';
    final fullName = '$firstName $lastName'.trim();
    final userId = user?.id.substring(0, 8) ?? 'N/A';
    final role = userMetadata?['role'] ?? 'settings.role_default'.tr();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            key: ValueKey(_currentStaffUser?.imagePath ?? 'default'),
            radius: 32,
            backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
            backgroundImage:
                (_currentStaffUser?.imagePath != null &&
                        _currentStaffUser!.imagePath!.isNotEmpty)
                    ? NetworkImage(_currentStaffUser!.imagePath!)
                        as ImageProvider
                    : null,
            child:
                (_currentStaffUser?.imagePath == null ||
                        _currentStaffUser!.imagePath!.isEmpty)
                    ? Text(
                      firstName.isNotEmpty ? firstName[0].toUpperCase() : 'U',
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    )
                    : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${'settings.id_prefix'.tr()} $userId',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${'settings.role_prefix'.tr()} $role',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit, color: theme.colorScheme.primary),
            onPressed: () async {
              // Navigate to staff profile screen for editing
              final currentUserId = user?.id;
              if (currentUserId == null) return;

              String? eventId = widget.eventId;

              try {
                if (mounted) {
                  Navigator.pushNamed(
                    context,
                    '/staff-profile',
                    arguments: {
                      'eventId': eventId,
                      'staffUserId': currentUserId,
                    },
                  );
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('settings.no_event'.tr())),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${'settings.error_prefix'.tr()} $e'),
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurface.withOpacity(0.5),
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildEventSettingsSection(ThemeData theme) {
    return Column(
      children: [
        SettingsTile(
          icon: Icons.settings_applications,
          title: 'settings.event_settings'.tr(),
          subtitle: 'settings.manage_event_settings'.tr(),
          onTap: () {
            if (widget.eventId != null) {
              Navigator.pushNamed(context, '/event/${widget.eventId}/settings');
            }
          },
        ),
      ],
    );
  }

  Widget _buildPreferencesSection(ThemeData theme) {
    return Column(
      children: [
        SettingsTile(
          icon: Icons.language,
          title: 'settings.language_region'.tr(),
          subtitle: LocalizationConfig.getLanguageName(
            context.locale.languageCode,
          ),
          onTap: () async {
            final result = await Navigator.push<String>(
              context,
              MaterialPageRoute(
                builder:
                    (context) => LanguageSettingsScreen(
                      currentLanguage: context.locale.languageCode,
                    ),
              ),
            );
            if (result != null && mounted) {
              await context.setLocale(
                LocalizationConfig.supportedLocales.firstWhere(
                  (l) => l.languageCode == result,
                ),
              );
              if (mounted) {
                await _updateSettings(_settings.copyWith(language: result));
              }
            }
          },
        ),
        const SizedBox(height: 8),
        SettingsTile(
          icon: Icons.palette,
          title: 'Theme',
          subtitle: _getThemeName(context),
          onTap: () => _showThemePicker(context),
        ),
        const SizedBox(height: 8),
        SettingsTile(
          icon: Icons.notifications,
          title: 'settings.notifications'.tr(),
          subtitle: 'settings.manage_notifications'.tr(),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const NotificationSettingsScreen(),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        SettingsTile(
          icon: Icons.vibration,
          title: 'settings.vibration'.tr(),
          trailing: Switch(
            value: _settings.vibrationEnabled,
            onChanged: (value) {
              _updateSettings(_settings.copyWith(vibrationEnabled: value));
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHelpSection(ThemeData theme) {
    return Column(
      children: [
        SettingsTile(
          icon: Icons.help_outline,
          title: 'settings.faq'.tr(),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const FAQScreen()),
            );
          },
        ),
        const SizedBox(height: 8),
        SettingsTile(
          icon: Icons.support_agent,
          title: 'settings.contact_support'.tr(),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SupportScreen()),
            );
          },
        ),
        const SizedBox(height: 8),
        SettingsTile(
          icon: Icons.feedback_outlined,
          title: 'settings.send_feedback'.tr(),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const FeedbackScreen()),
            );
          },
        ),
        const SizedBox(height: 8),
        SettingsTile(
          icon: Icons.refresh,
          title: 'settings.reset_settings'.tr(),
          iconColor: Colors.orange,
          onTap: _resetSettings,
        ),
      ],
    );
  }

  String _getThemeName(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    if (themeProvider.selectedCustomThemeId != null) {
      final customTheme = themeProvider.customThemes.firstWhere(
        (t) => t.id == themeProvider.selectedCustomThemeId,
        orElse: () => themeProvider.customThemes.first,
      );
      // Validate existance
      if (themeProvider.customThemes.any(
        (t) => t.id == themeProvider.selectedCustomThemeId,
      )) {
        return customTheme.name;
      }
    }

    switch (themeProvider.preferredThemeMode) {
      case ThemeMode.system:
        return 'System';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }

  void _showThemePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Consumer<ThemeProvider>(
          builder: (context, themeProvider, child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppBar(
                  title: const Text('Select Theme'),
                  automaticallyImplyLeading: false,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        Navigator.pop(context); // Close sheet
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ThemeEditorScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                Expanded(
                  child: ListView(
                    children: [
                      _buildThemeRadio(
                        context,
                        'System Default',
                        ThemeMode.system,
                        themeProvider,
                      ),
                      _buildThemeRadio(
                        context,
                        'Light Mode',
                        ThemeMode.light,
                        themeProvider,
                      ),
                      _buildThemeRadio(
                        context,
                        'Dark Mode',
                        ThemeMode.dark,
                        themeProvider,
                      ),
                      const Divider(),
                      if (themeProvider.customThemes.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'No custom themes yet. Create one!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ...themeProvider.customThemes.map((theme) {
                        final isSelected =
                            themeProvider.selectedCustomThemeId == theme.id;
                        return ListTile(
                          title: Text(theme.name),
                          leading: CircleAvatar(
                            backgroundColor: Color(theme.primaryColor),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isSelected)
                                const Icon(Icons.check, color: Colors.blue),
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                onPressed: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => ThemeEditorScreen(
                                            initialTheme: theme,
                                          ),
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  size: 20,
                                  color: Colors.red,
                                ),
                                onPressed: () {
                                  themeProvider.deleteCustomTheme(theme.id);
                                },
                              ),
                            ],
                          ),
                          onTap: () {
                            themeProvider.selectCustomTheme(theme.id);
                            // Do not close to allow seeing selection or switching back
                          },
                        );
                      }),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildThemeRadio(
    BuildContext context,
    String label,
    ThemeMode mode,
    ThemeProvider provider,
  ) {
    bool isSelected =
        provider.selectedCustomThemeId == null &&
        provider.preferredThemeMode == mode;
    return ListTile(
      title: Text(label),
      leading: Icon(
        mode == ThemeMode.light
            ? Icons.light_mode
            : mode == ThemeMode.dark
            ? Icons.dark_mode
            : Icons.brightness_auto,
      ),
      trailing: isSelected ? const Icon(Icons.check, color: Colors.blue) : null,
      onTap: () {
        provider.setThemeMode(mode);
      },
    );
  }

  Widget _buildLogoutButton(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _logout,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          'settings.logout'.tr(),
          style: theme.textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

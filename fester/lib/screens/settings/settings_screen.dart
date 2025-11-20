import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../models/app_settings.dart';
import '../../services/settings_service.dart';
import '../../providers/theme_provider.dart';
import 'widgets/settings_tile.dart';
import 'language_settings_screen.dart';
import 'notification_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settingsService = SettingsService();
  AppSettings _settings = AppSettings.defaultSettings;
  String _appVersion = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadAppVersion();
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

  Future<void> _updateSettings(AppSettings newSettings) async {
    await _settingsService.saveSettings(newSettings);
    setState(() {
      _settings = newSettings;
    });
  }

  Future<void> _resetSettings() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Impostazioni'),
        content: const Text('Sei sicuro di voler resettare tutte le impostazioni ai valori di default?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _settingsService.resetSettings();
      await _loadSettings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impostazioni resettate')),
        );
      }
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Sei sicuro di voler uscire?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Esci'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
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
          'Settings',
          style: GoogleFonts.outfit(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Profile Widget
            _buildUserProfile(theme, user),
            const SizedBox(height: 32),

            // PREFERENCES Section
            _buildSectionHeader(theme, 'PREFERENCES'),
            const SizedBox(height: 12),
            _buildPreferencesSection(theme),
            const SizedBox(height: 32),

            // HELP & SUPPORT Section
            _buildSectionHeader(theme, 'HELP & SUPPORT'),
            const SizedBox(height: 12),
            _buildHelpSection(theme),
            const SizedBox(height: 32),

            // Logout Button
            _buildLogoutButton(theme),
            const SizedBox(height: 16),

            // App Version
            Center(
              child: Text(
                'App Version $_appVersion',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildUserProfile(ThemeData theme, User? user) {
    final userMetadata = user?.userMetadata;
    final firstName = userMetadata?['first_name'] ?? 'User';
    final lastName = userMetadata?['last_name'] ?? '';
    final fullName = '$firstName $lastName'.trim();
    final userId = user?.id.substring(0, 8) ?? 'N/A';
    final role = userMetadata?['role'] ?? 'Event Manager';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
            child: Text(
              firstName.isNotEmpty ? firstName[0].toUpperCase() : 'U',
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
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
                  'ID: $userId',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Role: $role',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit, color: theme.colorScheme.primary),
            onPressed: () {
              // TODO: Navigate to profile edit
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Edit profile - Coming soon')),
              );
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

  Widget _buildPreferencesSection(ThemeData theme) {
    return Column(
      children: [
        SettingsTile(
          icon: Icons.language,
          title: 'Language & Region',
          subtitle: _getLanguageName(_settings.language),
          onTap: () async {
            final result = await Navigator.push<String>(
              context,
              MaterialPageRoute(
                builder: (context) => LanguageSettingsScreen(
                  currentLanguage: _settings.language,
                ),
              ),
            );
            if (result != null) {
              await _updateSettings(_settings.copyWith(language: result));
            }
          },
        ),
        const SizedBox(height: 8),
        SettingsTile(
          icon: _settings.themeMode == ThemeMode.dark
              ? Icons.dark_mode
              : Icons.light_mode,
          title: 'Dark mode',
          trailing: Switch(
            value: _settings.themeMode == ThemeMode.dark,
            onChanged: (value) {
              final newMode = value ? ThemeMode.dark : ThemeMode.light;
              _updateSettings(_settings.copyWith(themeMode: newMode));
              // Aggiorna il tema immediatamente
              Provider.of<ThemeProvider>(context, listen: false).setThemeMode(newMode);
            },
          ),
        ),
        const SizedBox(height: 8),
        SettingsTile(
          icon: _settings.notificationLevel.icon,
          title: 'Notification Settings',
          subtitle: _settings.notificationLevel.displayName,
          onTap: () async {
            final result = await Navigator.push<NotificationLevel>(
              context,
              MaterialPageRoute(
                builder: (context) => NotificationSettingsScreen(
                  currentLevel: _settings.notificationLevel,
                ),
              ),
            );
            if (result != null) {
              await _updateSettings(_settings.copyWith(notificationLevel: result));
            }
          },
        ),
        const SizedBox(height: 8),
        SettingsTile(
          icon: Icons.vibration,
          title: 'Vibration',
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
          title: 'FAQ',
          onTap: () {
            // TODO: Navigate to FAQ
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('FAQ - Coming soon')),
            );
          },
        ),
        const SizedBox(height: 8),
        SettingsTile(
          icon: Icons.support_agent,
          title: 'Contact Support',
          onTap: () {
            // TODO: Navigate to support
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Contact Support - Coming soon')),
            );
          },
        ),
        const SizedBox(height: 8),
        SettingsTile(
          icon: Icons.feedback_outlined,
          title: 'Send Feedback',
          onTap: () {
            // TODO: Navigate to feedback
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Send Feedback - Coming soon')),
            );
          },
        ),
        const SizedBox(height: 8),
        SettingsTile(
          icon: Icons.refresh,
          title: 'Reset Settings',
          iconColor: Colors.orange,
          onTap: _resetSettings,
        ),
      ],
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
          'Log Out',
          style: theme.textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  String _getLanguageName(String code) {
    switch (code) {
      case 'it':
        return 'Italiano';
      case 'en':
        return 'English';
      case 'de':
        return 'Deutsch';
      case 'es':
        return 'Español';
      case 'fr':
        return 'Français';
      case 'zh':
        return '中文';
      default:
        return 'Italiano';
    }
  }
}

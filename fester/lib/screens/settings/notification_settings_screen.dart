import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../services/notification_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _warningNotifications = true;
  bool _drinkLimitNotifications = true;
  bool _eventStartNotifications = true;
  bool _eventEndNotifications = true;
  bool _syncNotifications = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _warningNotifications = prefs.getBool('notification_${NotificationService.typeWarning}') ?? true;
      _drinkLimitNotifications = prefs.getBool('notification_${NotificationService.typeDrinkLimit}') ?? true;
      _eventStartNotifications = prefs.getBool('notification_${NotificationService.typeEventStart}') ?? true;
      _eventEndNotifications = prefs.getBool('notification_${NotificationService.typeEventEnd}') ?? true;
      _syncNotifications = prefs.getBool('notification_${NotificationService.typeSync}') ?? true;
    });
  }

  Future<void> _saveSetting(String type, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notification_$type', value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('notification_settings.title'.tr()),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'notification_settings.subtitle'.tr(),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 24),

          _buildSectionTitle(theme, 'notification_settings.section_guests'.tr()),
          _buildNotificationTile(
            theme: theme,
            icon: Icons.warning_amber,
            iconColor: Colors.orange,
            title: 'notification_settings.warning_received'.tr(),
            subtitle: 'notification_settings.warning_received_desc'.tr(),
            value: _warningNotifications,
            onChanged: (value) {
              setState(() => _warningNotifications = value);
              _saveSetting(NotificationService.typeWarning, value);
            },
          ),
          const SizedBox(height: 8),
          
          _buildNotificationTile(
            theme: theme,
            icon: Icons.local_bar,
            iconColor: Colors.red,
            title: 'notification_settings.drink_limit'.tr(),
            subtitle: 'notification_settings.drink_limit_desc'.tr(),
            value: _drinkLimitNotifications,
            onChanged: (value) {
              setState(() => _drinkLimitNotifications = value);
              _saveSetting(NotificationService.typeDrinkLimit, value);
            },
          ),
          const SizedBox(height: 24),

          _buildSectionTitle(theme, 'notification_settings.section_event'.tr()),
          _buildNotificationTile(
            theme: theme,
            icon: Icons.play_circle_outline,
            iconColor: Colors.green,
            title: 'notification_settings.event_start'.tr(),
            subtitle: 'notification_settings.event_start_desc'.tr(),
            value: _eventStartNotifications,
            onChanged: (value) {
              setState(() => _eventStartNotifications = value);
              _saveSetting(NotificationService.typeEventStart, value);
            },
          ),
          const SizedBox(height: 8),
          
          _buildNotificationTile(
            theme: theme,
            icon: Icons.stop_circle_outlined,
            iconColor: Colors.blue,
            title: 'notification_settings.event_end'.tr(),
            subtitle: 'notification_settings.event_end_desc'.tr(),
            value: _eventEndNotifications,
            onChanged: (value) {
              setState(() => _eventEndNotifications = value);
              _saveSetting(NotificationService.typeEventEnd, value);
            },
          ),
          const SizedBox(height: 24),

          _buildSectionTitle(theme, 'notification_settings.section_system'.tr()),
          _buildNotificationTile(
            theme: theme,
            icon: Icons.sync,
            iconColor: Colors.purple,
            title: 'notification_settings.sync'.tr(),
            subtitle: 'notification_settings.sync_desc'.tr(),
            value: _syncNotifications,
            onChanged: (value) {
              setState(() => _syncNotifications = value);
              _saveSetting(NotificationService.typeSync, value);
            },
          ),

          const SizedBox(height: 32),
          Card(
            color: theme.colorScheme.primary.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'notification_settings.info_message'.tr(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildNotificationTile({
    required ThemeData theme,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SwitchListTile(
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        value: value,
        onChanged: onChanged,
        activeColor: theme.colorScheme.primary,
      ),
    );
  }
}

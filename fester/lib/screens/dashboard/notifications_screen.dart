import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../services/notification_service.dart';
import '../settings/notification_settings_screen.dart';
import '../profile/person_profile_screen.dart';

class NotificationsScreen extends StatefulWidget {
  final String eventId;

  const NotificationsScreen({super.key, required this.eventId});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _notificationService = NotificationService();
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    // Configure timeago for Italian
    timeago.setLocaleMessages('it', timeago.ItMessages());
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final notifications = await _notificationService.getNotifications(
        widget.eventId,
      );
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore caricamento notifiche: $e')),
        );
      }
    }
  }

  Future<void> _markAllAsRead() async {
    await _notificationService.markAllAsRead(widget.eventId);
    _loadNotifications();
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case NotificationService.typeWarning:
        return Icons.warning_amber;
      case NotificationService.typeDrinkLimit:
        return Icons.local_bar;
      case NotificationService.typeEventStart:
        return Icons.play_circle_outline;
      case NotificationService.typeEventEnd:
        return Icons.stop_circle_outlined;
      case NotificationService.typeSync:
        return Icons.sync;
      default:
        return Icons.notifications;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case NotificationService.typeWarning:
        return Colors.orange;
      case NotificationService.typeDrinkLimit:
        return Colors.red;
      case NotificationService.typeEventStart:
        return Colors.green;
      case NotificationService.typeEventEnd:
        return Colors.blue;
      case NotificationService.typeSync:
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Notifiche'),
        actions: [
          if (_notifications.any((n) => n['is_read'] == false))
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text('Segna tutte lette'),
            ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationSettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _loadNotifications,
                child:
                    _notifications.isEmpty
                        ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.notifications_off_outlined,
                                size: 64,
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.3,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Nessuna notifica',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        )
                        : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _notifications.length,
                          separatorBuilder:
                              (context, index) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final notification = _notifications[index];
                            final notificationType = notification['type'];
                            final data =
                                notification['data'] as Map<String, dynamic>?;

                            return Dismissible(
                              key: Key(notification['id']),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.delete,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              onDismissed: (direction) async {
                                await _notificationService.deleteNotification(
                                  notification['id'],
                                );
                                setState(() {
                                  _notifications.removeAt(index);
                                });
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Notifica eliminata'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                }
                              },
                              child: _NotificationCard(
                                title: notification['title'],
                                message: notification['message'],
                                time: _formatTime(notification['created_at']),
                                icon: _getIconForType(notification['type']),
                                color: _getColorForType(notification['type']),
                                isRead: notification['is_read'],
                                onTap: () async {
                                  // Mark as read if not already
                                  if (!notification['is_read']) {
                                    await _notificationService.markAsRead(
                                      notification['id'],
                                    );
                                  }

                                  // Navigate to person profile if it's a warning or drink limit notification
                                  if ((notificationType ==
                                              NotificationService.typeWarning ||
                                          notificationType ==
                                              NotificationService
                                                  .typeDrinkLimit) &&
                                      data != null &&
                                      data['person_id'] != null) {
                                    if (context.mounted) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) => PersonProfileScreen(
                                                personId: data['person_id'],
                                                eventId: widget.eventId,
                                              ),
                                        ),
                                      );
                                    }
                                  }

                                  _loadNotifications();
                                },
                              ),
                            );
                          },
                        ),
              ),
    );
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return 'Sconosciuto';
    try {
      final time = DateTime.parse(timestamp);
      return timeago.format(time, locale: 'it');
    } catch (e) {
      return 'Sconosciuto';
    }
  }
}

class _NotificationCard extends StatelessWidget {
  final String title;
  final String message;
  final String time;
  final IconData icon;
  final Color color;
  final bool isRead;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.title,
    required this.message,
    required this.time,
    required this.icon,
    required this.color,
    required this.isRead,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color:
          isRead
              ? theme.cardColor
              : theme.colorScheme.primary.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      time,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

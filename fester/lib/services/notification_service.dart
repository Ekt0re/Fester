import 'dart:async';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'logger_service.dart';

class NotificationService {
  static const String _tag = 'NotificationService';
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _supabase = Supabase.instance.client;
  final _localNotifications = FlutterLocalNotificationsPlugin();
  RealtimeChannel? _subscription;

  // Stream controller to broadcast new notifications to UI
  final _notificationStreamController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onNotificationReceived =>
      _notificationStreamController.stream;

  /// Initialize Notifications (Local + Realtime Listener)
  Future<void> init() async {
    await _initLocalNotifications();
    _startRealtimeListener();
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        LoggerService.debug(
          'Notification clicked: ${response.payload}',
          tag: _tag,
        );
        // Handle navigation here if needed, e.g. using a global navigator key
      },
    );
  }

  void _startRealtimeListener() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    // Listen to INSERTs on 'notifications' table for the current user
    _subscription =
        _supabase
            .channel('public:notifications:$userId')
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'notifications',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'staff_user_id',
                value: userId,
              ),
              callback: (payload) {
                _handleNewNotification(payload.newRecord);
              },
            )
            .subscribe();

    LoggerService.info(
      'Listening for realtime notifications for user $userId',
      tag: _tag,
    );
  }

  /// Stop listening to notifications
  void dispose() {
    _subscription?.unsubscribe();
    _notificationStreamController.close();
  }

  Future<void> _handleNewNotification(Map<String, dynamic> record) async {
    try {
      // Broadcast to UI
      _notificationStreamController.add(record);

      final type = record['type'] as String;
      final title = record['title'] as String;
      final message = record['message'] as String;
      final data = record['data'] as Map<String, dynamic>?;

      // Check if enabled in settings
      if (!await isNotificationEnabled(type)) return;

      // Show Local Notification
      await _showLocalNotification(
        id: record['id'].hashCode,
        title: title,
        body: message,
        payload: jsonEncode(data),
      );
    } catch (e) {
      LoggerService.error(
        'Error handling new notification',
        tag: _tag,
        error: e,
      );
    }
  }

  Future<void> _showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'fester_channel_id',
      'Fester Notifications',
      channelDescription: 'Notifications from Fester App',
      importance: Importance.max,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(id, title, body, details, payload: payload);
  }

  // Notification types
  static const String typeWarning = 'warning';
  static const String typeDrinkLimit = 'drink_limit';
  static const String typeEventStart = 'event_start';
  static const String typeEventEnd = 'event_end';
  static const String typeSync = 'sync';

  /// Check if notification type is enabled in settings
  Future<bool> isNotificationEnabled(String type) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notification_$type') ?? true; // Default enabled
  }

  /// Save notification to database (This triggers the Realtime listener on other devices)
  Future<void> saveNotification({
    required String eventId,
    required String type,
    required String title,
    required String message,
    String? staffUserId,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _supabase.from('notifications').insert({
        'event_id': eventId,
        'staff_user_id': staffUserId ?? _supabase.auth.currentUser?.id,
        'type': type,
        'title': title,
        'message': message,
        'data': data,
        'is_read': false,
      });
    } catch (e) {
      LoggerService.error('Error saving notification', tag: _tag, error: e);
    }
  }

  /// Get notifications for an event
  Future<List<Map<String, dynamic>>> getNotifications(String eventId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase
          .from('notifications')
          .select()
          .eq('event_id', eventId)
          .eq('staff_user_id', userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      LoggerService.error('Error fetching notifications', tag: _tag, error: e);
      return [];
    }
  }

  /// Get unread notification count
  Future<int> getUnreadCount(String eventId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return 0;

      final response = await _supabase
          .from('notifications')
          .select('id')
          .eq('event_id', eventId)
          .eq('staff_user_id', userId)
          .eq('is_read', false);

      return (response as List).length;
    } catch (e) {
      LoggerService.error('Error fetching unread count', tag: _tag, error: e);
      return 0;
    }
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (e) {
      LoggerService.error(
        'Error marking notification as read',
        tag: _tag,
        error: e,
      );
    }
  }

  /// Mark all notifications as read for an event
  Future<void> markAllAsRead(String eventId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('event_id', eventId)
          .eq('staff_user_id', userId)
          .eq('is_read', false);
    } catch (e) {
      LoggerService.error('Error marking all as read', tag: _tag, error: e);
    }
  }

  /// Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _supabase.from('notifications').delete().eq('id', notificationId);
    } catch (e) {
      LoggerService.error('Error deleting notification', tag: _tag, error: e);
    }
  }

  // Helper methods for specific notification types

  Future<void> notifyWarningReceived({
    required String eventId,
    required String personName,
    required String personId,
    required String reason,
  }) async {
    await saveNotification(
      eventId: eventId,
      type: typeWarning,
      title: 'notifications_service.warning_received_title'.tr(),
      message: 'notifications_service.warning_received_message'.tr(
        args: [personName, reason],
      ),
      data: {
        'person_name': personName,
        'person_id': personId,
        'reason': reason,
      },
    );
  }

  Future<void> notifyDrinkLimitExceeded({
    required String eventId,
    required String personName,
    required String personId,
    required int drinkCount,
    required int limit,
  }) async {
    await saveNotification(
      eventId: eventId,
      type: typeDrinkLimit,
      title: 'notifications_service.drink_limit_exceeded_title'.tr(),
      message: 'notifications_service.drink_limit_exceeded_message'.tr(
        args: [personName, drinkCount.toString(), limit.toString()],
      ),
      data: {
        'person_name': personName,
        'person_id': personId,
        'drink_count': drinkCount,
        'limit': limit,
      },
    );
  }

  Future<void> notifyEventStart({
    required String eventId,
    required String eventName,
  }) async {
    await saveNotification(
      eventId: eventId,
      type: typeEventStart,
      title: 'notifications_service.event_start_title'.tr(),
      message: 'notifications_service.event_start_message'.tr(
        args: [eventName],
      ),
    );
  }

  Future<void> notifyEventEnd({
    required String eventId,
    required String eventName,
  }) async {
    await saveNotification(
      eventId: eventId,
      type: typeEventEnd,
      title: 'notifications_service.event_end_title'.tr(),
      message: 'notifications_service.event_end_message'.tr(args: [eventName]),
    );
  }

  Future<void> notifySync({
    required String eventId,
    required int updatedItems,
  }) async {
    await saveNotification(
      eventId: eventId,
      type: typeSync,
      title: 'notifications_service.sync_title'.tr(),
      message: 'notifications_service.sync_message'.tr(
        args: [updatedItems.toString()],
      ),
    );
  }
}

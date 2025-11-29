import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _supabase = Supabase.instance.client;

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

  /// Save notification to database
  Future<void> saveNotification({
    required String eventId,
    required String type,
    required String title,
    required String message,
    String? staffUserId,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Check if this type is enabled
      if (!await isNotificationEnabled(type)) {
        return; // Don't save if disabled
      }

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
      debugPrint('Error saving notification: $e');
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
      debugPrint('Error fetching notifications: $e');
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
      debugPrint('Error fetching unread count: $e');
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
      debugPrint('Error marking notification as read: $e');
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
      debugPrint('Error marking all as read: $e');
    }
  }

  /// Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _supabase.from('notifications').delete().eq('id', notificationId);
    } catch (e) {
      debugPrint('Error deleting notification: $e');
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
      message: 'notifications_service.warning_received_message'.tr(args: [personName, reason]),
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
      message: 'notifications_service.drink_limit_exceeded_message'.tr(args: [personName, drinkCount.toString(), limit.toString()]),
      data: {
        'person_name': personName,
        'person_id': personId,
        'drink_count': drinkCount,
        'limit': limit,
      },
    );
  }

  Future<void> notifyEventStarting({
    required String eventId,
    required String eventName,
  }) async {
    await saveNotification(
      eventId: eventId,
      type: typeEventStart,
      title: 'notifications_service.event_starting_title'.tr(),
      message: 'notifications_service.event_starting_message'.tr(args: [eventName]),
      data: {'event_name': eventName},
    );
  }

  Future<void> notifyEventEnding({
    required String eventId,
    required String eventName,
  }) async {
    await saveNotification(
      eventId: eventId,
      type: typeEventEnd,
      title: 'notifications_service.event_ending_title'.tr(),
      message: 'notifications_service.event_ending_message'.tr(args: [eventName]),
      data: {'event_name': eventName},
    );
  }

  Future<void> notifySync({
    required String eventId,
    required int updatedItems,
  }) async {
    await saveNotification(
      eventId: eventId,
      type: typeSync,
      title: 'notifications_service.sync_completed_title'.tr(),
      message: 'notifications_service.sync_completed_message'.tr(args: [updatedItems.toString()]),
      data: {'count': updatedItems},
    );
  }
}

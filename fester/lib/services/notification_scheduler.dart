import 'dart:async';
import 'package:flutter/foundation.dart';
import 'notification_service.dart';

/// Scheduler for event start/end notifications.
/// Instantiated once per event (e.g. by the Admin/Organizer) to broadcast notifications.
class NotificationScheduler {
  final NotificationService _notificationService = NotificationService();

  Timer? _startTimer;
  Timer? _endTimer;

  /// Schedule notifications for the event.
  ///
  /// [eventId] Event ID.
  /// [eventName] Event Name.
  /// [start] Event start time (UTC).
  /// [end] Event end time (UTC).
  void schedule({
    required String eventId,
    required String eventName,
    required DateTime start,
    DateTime? end,
  }) {
    // Cancel existing timers
    _cancel();

    final now = DateTime.now().toUtc();

    // Notify 10 minutes before start
    final startNotifyAt = start.subtract(const Duration(minutes: 10));
    if (startNotifyAt.isAfter(now)) {
      final diff = startNotifyAt.difference(now);
      _startTimer = Timer(diff, () async {
        debugPrint('Scheduler: Triggering Event Start Notification');
        await _notificationService.notifyEventStart(
          eventId: eventId,
          eventName: eventName,
        );
      });
      debugPrint(
        'Scheduled Start Notification for: $startNotifyAt (in ${diff.inMinutes} mins)',
      );
    }

    // Notify 30 minutes before end
    if (end != null) {
      final endNotifyAt = end.subtract(const Duration(minutes: 30));
      if (endNotifyAt.isAfter(now)) {
        final diff = endNotifyAt.difference(now);
        _endTimer = Timer(diff, () async {
          debugPrint('Scheduler: Triggering Event End Notification');
          await _notificationService.notifyEventEnd(
            eventId: eventId,
            eventName: eventName,
          );
        });
        debugPrint(
          'Scheduled End Notification for: $endNotifyAt (in ${diff.inMinutes} mins)',
        );
      }
    }
  }

  /// Cancel all active timers.
  void _cancel() {
    _startTimer?.cancel();
    _endTimer?.cancel();
    _startTimer = null;
    _endTimer = null;
  }

  /// Public dispose method if needed by UI
  void dispose() => _cancel();
}

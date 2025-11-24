// lib/services/notification_scheduler.dart
import 'dart:async';

import 'notification_service.dart';

/// Scheduler per notifiche di avvio/fine evento.
/// Viene istanziato una volta per evento e utilizza [Timer] per
/// inviare le notifiche 10 minuti prima dell'inizio e 30 minuti prima della fine.
class NotificationScheduler {
  final NotificationService _notificationService = NotificationService();

  Timer? _startTimer;
  Timer? _endTimer;

  /// Avvia il scheduling per l'evento specificato.
  ///
  /// [eventId]  ID dell'evento.
  /// [start]    Data/ora di inizio dell'evento (UTC).
  /// [end]      Data/ora di fine dell'evento (UTC).
  void schedule({
    required String eventId,
    required DateTime start,
    required DateTime end,
  }) {
    // Cancella eventuali timer preesistenti
    _cancel();

    final now = DateTime.now().toUtc();
    // 10 minuti prima dell'inizio
    final startNotifyAt = start.subtract(const Duration(minutes: 10));
    if (startNotifyAt.isAfter(now)) {
      final diff = startNotifyAt.difference(now);
      _startTimer = Timer(diff, () async {
        await _notificationService.notifyEventStart(eventId: eventId);
      });
    }

    // 30 minuti prima della fine
    final endNotifyAt = end.subtract(const Duration(minutes: 30));
    if (endNotifyAt.isAfter(now)) {
      final diff = endNotifyAt.difference(now);
      _endTimer = Timer(diff, () async {
        await _notificationService.notifyEventEnd(eventId: eventId);
      });
    }
  }

  /// Cancella tutti i timer attivi.
  void _cancel() {
    _startTimer?.cancel();
    _endTimer?.cancel();
    _startTimer = null;
    _endTimer = null;
  }
}

import 'package:supabase_flutter/supabase_flutter.dart';

/// Servizio per la gestione delle notifiche di eventi.
/// Fornisce metodi per inviare notifiche relative all'inizio e fine degli eventi.
class NotificationService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Invia una notifica per l'inizio di un evento.
  ///
  /// [eventId] ID dell'evento che sta per iniziare.
  Future<void> notifyEventStart({required String eventId}) async {
    try {
      // Recupera i dettagli dell'evento
      final eventResponse = await _supabase
          .from('events')
          .select('title, description, start')
          .eq('id', eventId)
          .single();

      // Recupera gli utenti partecipanti
      final participants = await _supabase
          .from('person_event')
          .select('person_id')
          .eq('event_id', eventId);

      // Invia notifiche ai partecipanti
      for (final participant in participants) {
        await _sendNotification(
          userId: participant['person_id'],
          title: 'Evento in arrivo!',
          body: 'L\'evento "${eventResponse['title']}" inizierà tra 10 minuti.',
        );
      }

      print('Notifiche di inizio evento inviate per: $eventId');
    } catch (e) {
      print('Errore nell\'invio notifica inizio evento: $e');
    }
  }

  /// Invia una notifica per la fine di un evento.
  ///
  /// [eventId] ID dell'evento che sta per terminare.
  Future<void> notifyEventEnd({required String eventId}) async {
    try {
      // Recupera i dettagli dell'evento
      final eventResponse = await _supabase
          .from('events')
          .select('title, description, end')
          .eq('id', eventId)
          .single();

      // Recupera gli utenti partecipanti
      final participants = await _supabase
          .from('person_event')
          .select('person_id')
          .eq('event_id', eventId);

      // Invia notifiche ai partecipanti
      for (final participant in participants) {
        await _sendNotification(
          userId: participant['person_id'],
          title: 'Evento in conclusione',
          body: 'L\'evento "${eventResponse['title']}" terminerà tra 30 minuti.',
        );
      }

      print('Notifiche di fine evento inviate per: $eventId');
    } catch (e) {
      print('Errore nell\'invio notifica fine evento: $e');
    }
  }

  /// Metodo privato per l'invio effettivo della notifica.
  /// Da implementare con il sistema di notifiche desiderato (push, email, etc.)
  Future<void> _sendNotification({
    required String userId,
    required String title,
    required String body,
  }) async {
    try {
      // Qui puoi implementare la logica di invio notifiche:
      // - Notifiche push (Firebase Cloud Messaging)
      // - Email
      // - Notifiche in-app
      // - WebSocket per notifiche real-time
      
      // Per ora, stampiamo solo i dettagli della notifica
      print('Notifica per utente $userId: $title - $body');
      
      // Esempio di implementazione con Supabase Realtime:
      // await _supabase.channel('notifications').send({
      //   'user_id': userId,
      //   'title': title,
      //   'body': body,
      //   'created_at': DateTime.now().toIso8601String(),
      // });
      
    } catch (e) {
      print('Errore nell\'invio della notifica: $e');
    }
  }
}

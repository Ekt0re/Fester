import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/guest.dart';
import '../models/event.dart';
import '../models/user.dart' as local;

class SyncService {
  final SupabaseClient _supabase;
  final Box<Guest> _guestBox;
  final Box<Event> _eventBox;
  final Box<local.User> _userBox;

  SyncService({
    required SupabaseClient supabase,
    required Box<Guest> guestBox,
    required Box<Event> eventBox,
    required Box<local.User> userBox,
  }) : 
    _supabase = supabase,
    _guestBox = guestBox,
    _eventBox = eventBox,
    _userBox = userBox;

  Future<void> syncGuests(String eventId, DateTime lastSync) async {
    try {
    final response = await _supabase
        .from('guests')
        .select()
        .eq('event_id', eventId)
          .gt('last_updated', lastSync.toIso8601String());

      final List<dynamic> data = response;
    for (var guestData in data) {
      final guest = Guest.fromJson(guestData);
      await _guestBox.put(guest.id, guest);
      }
    } catch (e) {
      throw Exception('Failed to sync guests: $e');
    }
  }

  Future<void> syncEvents(DateTime lastSync) async {
    try {
    final response = await _supabase
        .from('events')
        .select()
          .gt('last_updated', lastSync.toIso8601String());

      final List<dynamic> data = response;
    for (var eventData in data) {
      final event = Event.fromJson(eventData);
      await _eventBox.put(event.id, event);
      }
    } catch (e) {
      throw Exception('Failed to sync events: $e');
    }
  }

  Future<void> syncUsers(DateTime lastSync) async {
    try {
    final response = await _supabase
        .from('users')
        .select()
          .gt('last_updated', lastSync.toIso8601String());

      final List<dynamic> data = response;
    for (var userData in data) {
        final user = local.User.fromJson(userData);
      await _userBox.put(user.id, user);
      }
    } catch (e) {
      throw Exception('Failed to sync users: $e');
    }
  }

  Future<void> uploadLocalChanges(String eventId) async {
    try {
    final localGuests = _guestBox.values
        .where((guest) => guest.eventId == eventId)
        .toList();

    for (var guest in localGuests) {
      await _supabase
          .from('guests')
            .upsert(guest.toJson());
      }
    } catch (e) {
      throw Exception('Failed to upload local changes: $e');
    }
  }

  Future<void> performFullSync(String eventId) async {
    try {
    final lastSync = DateTime.now().subtract(const Duration(days: 30));
    
    await syncGuests(eventId, lastSync);
    await syncEvents(lastSync);
    await syncUsers(lastSync);
    
    await uploadLocalChanges(eventId);
    } catch (e) {
      throw Exception('Failed to perform full sync: $e');
    }
  }

  // Metodo statico per compatibilità con GuestProvider
  static Future<void> syncAllData() async {
    try {
      // Implementazione semplificata per ora
      // In futuro, qui si può aggiungere la logica di sincronizzazione completa
      await Future.delayed(const Duration(seconds: 1));
    } catch (e) {
      throw Exception('Sync failed: $e');
    }
  }
}

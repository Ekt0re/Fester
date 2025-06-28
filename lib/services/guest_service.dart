import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logging/logging.dart';
import '../models/guest.dart';

class GuestService {
  final SupabaseClient _supabase;
  final Box<Guest> _guestBox;
  final Logger _logger = Logger('GuestService');

  GuestService({
    required SupabaseClient supabase,
    required Box<Guest> guestBox,
  }) : 
    _supabase = supabase,
    _guestBox = guestBox;

  Future<Guest?> getGuestByCode(String eventId, String code) async {
    try {
      // First check local Hive database
      final localGuest = _guestBox.values.where(
        (guest) => guest.eventId == eventId && guest.code == code,
      ).firstOrNull;

      // If local guest exists, return it
      if (localGuest != null) return localGuest;

      // Fetch from Supabase
      final response = await _supabase
          .from('guests')
          .select()
          .eq('event_id', eventId)
          .eq('code', code)
          .limit(1)
          .single();

      return Guest.fromJson(response);
    } catch (e) {
      _logger.warning('Error fetching guest by code', e);
      return null;
    }
  }

  Future<List<Guest>> getEventGuests(String eventId) async {
    try {
      final response = await _supabase
          .from('guests')
          .select()
          .eq('event_id', eventId);

      final List<dynamic> data = response;
      return data.map((json) => Guest.fromJson(json)).toList();
    } catch (e) {
      _logger.warning('Error fetching event guests', e);
      return [];
    }
  }

  Future<void> addGuest(Guest guest) async {
    try {
      // Save to Supabase
      await _supabase
          .from('guests')
          .insert(guest.toJson());

      // Save to local Hive database
      await _guestBox.put(guest.id, guest);
    } catch (e) {
      _logger.warning('Error adding guest', e);
      rethrow;
    }
  }

  Future<void> updateGuest(Guest guest) async {
    try {
      // Update in Supabase
      await _supabase
          .from('guests')
          .update(guest.toJson())
          .eq('id', guest.id);

      // Update in local Hive database
      await _guestBox.put(guest.id, guest);
    } catch (e) {
      _logger.warning('Error updating guest', e);
      rethrow;
    }
  }

  Future<void> deleteGuest(String guestId) async {
    try {
      // Delete from Supabase
      await _supabase
          .from('guests')
          .delete()
          .eq('id', guestId);

      // Delete from local Hive database
      await _guestBox.delete(guestId);
    } catch (e) {
      _logger.warning('Error deleting guest', e);
      rethrow;
    }
  }
}

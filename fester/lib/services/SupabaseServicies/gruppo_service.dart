import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/gruppo.dart';

class GruppoService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get all gruppi for an event
  Future<List<Gruppo>> getGruppiForEvent(String eventId) async {
    try {
      final response = await _supabase
          .from('gruppo')
          .select()
          .eq('event_id', eventId)
          .order('name', ascending: true);

      return (response as List)
          .map((json) => Gruppo.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Error fetching gruppi: $e');
    }
  }

  /// Create a new gruppo
  Future<Gruppo> createGruppo({
    required String name,
    required String eventId,
  }) async {
    try {
      final response =
          await _supabase
              .from('gruppo')
              .insert({'name': name, 'event_id': eventId})
              .select()
              .single();

      return Gruppo.fromJson(response);
    } catch (e) {
      throw Exception('Error creating gruppo: $e');
    }
  }

  /// Get gruppo by ID
  Future<Gruppo?> getGruppoById(int id) async {
    try {
      final response =
          await _supabase.from('gruppo').select().eq('id', id).maybeSingle();

      if (response == null) return null;
      return Gruppo.fromJson(response);
    } catch (e) {
      throw Exception('Error fetching gruppo: $e');
    }
  }

  /// Delete gruppo
  Future<void> deleteGruppo(int id) async {
    try {
      await _supabase.from('gruppo').delete().eq('id', id);
    } catch (e) {
      throw Exception('Error deleting gruppo: $e');
    }
  }

  /// Update gruppo name
  Future<Gruppo> updateGruppo({required int id, required String name}) async {
    try {
      final response =
          await _supabase
              .from('gruppo')
              .update({'name': name})
              .eq('id', id)
              .select()
              .single();

      return Gruppo.fromJson(response);
    } catch (e) {
      throw Exception('Error updating gruppo: $e');
    }
  }
}

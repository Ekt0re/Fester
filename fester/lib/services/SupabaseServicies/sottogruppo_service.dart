import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/sottogruppo.dart';

class SottogruppoService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get all sottogruppi for an event
  Future<List<Sottogruppo>> getSottogruppiForEvent(String eventId) async {
    try {
      final response = await _supabase
          .from('sottogruppo')
          .select()
          .eq('event_id', eventId)
          .order('name', ascending: true);

      return (response as List)
          .map((json) => Sottogruppo.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Error fetching sottogruppi: $e');
    }
  }

  /// Get sottogruppi for a specific gruppo
  Future<List<Sottogruppo>> getSottogruppiForGruppo(int gruppoId) async {
    try {
      final response = await _supabase
          .from('sottogruppo')
          .select()
          .eq('gruppo_id', gruppoId)
          .order('name', ascending: true);

      return (response as List)
          .map((json) => Sottogruppo.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Error fetching sottogruppi: $e');
    }
  }

  /// Create a new sottogruppo
  Future<Sottogruppo> createSottogruppo({
    required String name,
    required int gruppoId,
    required String eventId,
  }) async {
    try {
      final response =
          await _supabase
              .from('sottogruppo')
              .insert({
                'name': name,
                'gruppo_id': gruppoId,
                'event_id': eventId,
              })
              .select()
              .single();

      return Sottogruppo.fromJson(response);
    } catch (e) {
      throw Exception('Error creating sottogruppo: $e');
    }
  }

  /// Get sottogruppo by ID
  Future<Sottogruppo?> getSottogruppoById(int id) async {
    try {
      final response =
          await _supabase
              .from('sottogruppo')
              .select()
              .eq('id', id)
              .maybeSingle();

      if (response == null) return null;
      return Sottogruppo.fromJson(response);
    } catch (e) {
      throw Exception('Error fetching sottogruppo: $e');
    }
  }

  /// Delete sottogruppo
  Future<void> deleteSottogruppo(int id) async {
    try {
      await _supabase.from('sottogruppo').delete().eq('id', id);
    } catch (e) {
      throw Exception('Error deleting sottogruppo: $e');
    }
  }

  /// Update sottogruppo name
  Future<Sottogruppo> updateSottogruppo({
    required int id,
    required String name,
  }) async {
    try {
      final response =
          await _supabase
              .from('sottogruppo')
              .update({'name': name})
              .eq('id', id)
              .select()
              .single();

      return Sottogruppo.fromJson(response);
    } catch (e) {
      throw Exception('Error updating sottogruppo: $e');
    }
  }
}

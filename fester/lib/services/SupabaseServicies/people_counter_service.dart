import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/SupabaseServicies/models/event_area.dart';

class PeopleCounterService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get stream of areas for an event (Real-time)
  Stream<List<EventArea>> getAreasStream(String eventId) {
    return _supabase
        .from('event_area')
        .stream(primaryKey: ['id'])
        .eq('event_id', eventId)
        .order('created_at')
        .map((data) => data.map((json) => EventArea.fromJson(json)).toList());
  }

  /// Get current areas (Future)
  Future<List<EventArea>> getAreas(String eventId) async {
    final response = await _supabase
        .from('event_area')
        .select()
        .eq('event_id', eventId)
        .order('created_at');

    return (response as List).map((json) => EventArea.fromJson(json)).toList();
  }

  /// Create a new area
  Future<void> createArea(String eventId, String name) async {
    await _supabase.from('event_area').insert({
      'event_id': eventId,
      'name': name,
      'current_count': 0,
    });
  }

  /// Delete an area
  /// Performs a manual cascade delete: first deletes logs, then the area.
  Future<void> deleteArea(String areaId) async {
    // 1. Delete all logs associated with this area
    await _supabase.from('event_area_log').delete().eq('area_id', areaId);

    // 2. Delete the area itself
    await _supabase.from('event_area').delete().eq('id', areaId);
  }

  /// Increment or Decrement count
  /// Instead of updating `event_area` directly, we insert into `event_area_log`.
  /// The database trigger will handle the update of `event_area.current_count`.
  Future<void> updateCount(String areaId, int delta) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not logged in');

    await _supabase.from('event_area_log').insert({
      'area_id': areaId,
      'delta': delta, // +1 or -1
      'staff_user_id': userId,
    });
  }

  /// Get logs for a list of areas
  Future<List<Map<String, dynamic>>> getAreaLogs(List<String> areaIds) async {
    if (areaIds.isEmpty) return [];

    final response = await _supabase
        .from('event_area_log')
        .select()
        .filter('area_id', 'in', areaIds)
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }
}

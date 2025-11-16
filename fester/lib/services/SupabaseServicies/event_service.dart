// lib/services/event_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/event.dart';
import 'models/event_settings.dart';

class EventService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get all events for current user (where user is staff)
  Future<List<Event>> getMyEvents() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('event')
          .select('''
            *
          ''')
          .order('created_at', ascending: false);

      return (response as List).map((json) => Event.fromJson(json)).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Get event by ID
  Future<Event?> getEventById(String eventId) async {
    try {
      final response =
          await _supabase
              .from('event')
              .select()
              .eq('id', eventId)
              .maybeSingle();

      if (response == null) return null;
      return Event.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Create new event
  Future<Event> createEvent({required String name, String? description}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response =
          await _supabase
              .from('event')
              .insert({
                'name': name,
                'description': description,
                'created_by': userId,
              })
              .select()
              .single();

      return Event.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Update event
  Future<Event> updateEvent({
    required String eventId,
    String? name,
    String? description,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (name != null) updates['name'] = name;
      if (description != null) updates['description'] = description;

      final response =
          await _supabase
              .from('event')
              .update(updates)
              .eq('id', eventId)
              .select()
              .single();

      return Event.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Delete event (soft delete)
  Future<void> deleteEvent(String eventId) async {
    try {
      await _supabase
          .from('event')
          .update({'deleted_at': DateTime.now().toIso8601String()})
          .eq('id', eventId);
    } catch (e) {
      rethrow;
    }
  }

  /// Get event settings
  Future<EventSettings?> getEventSettings(String eventId) async {
    try {
      final response =
          await _supabase
              .from('event_settings')
              .select()
              .eq('event_id', eventId)
              .maybeSingle();

      if (response == null) return null;
      return EventSettings.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Create or update event settings
  Future<EventSettings> upsertEventSettings({
    required String eventId,
    int? maxParticipants,
    bool? allowGuests,
    String? location,
    String? currency,
    DateTime? startAt,
    DateTime? endAt,
    DateTime? checkInStartTime,
    DateTime? checkInEndTime,
    bool? lateEntryAllowed,
    int? ageRestriction,
    bool? idCheckRequired,
    int? maxWarningsBeforeBan,
    int? defaultMaxDrinksPerPerson,
    Map<String, dynamic>? roleDrinkLimits,
    Map<String, dynamic>? customSettings,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final data = <String, dynamic>{'event_id': eventId, 'created_by': userId};

      if (maxParticipants != null) data['max_participants'] = maxParticipants;
      if (allowGuests != null) data['allow_guests'] = allowGuests;
      if (location != null) data['location'] = location;
      if (currency != null) data['currency'] = currency;
      if (startAt != null) data['start_at'] = startAt.toIso8601String();
      if (endAt != null) data['end_at'] = endAt.toIso8601String();
      if (checkInStartTime != null) {
        data['check_in_start_time'] = checkInStartTime.toIso8601String();
      }
      if (checkInEndTime != null) {
        data['check_in_end_time'] = checkInEndTime.toIso8601String();
      }
      if (lateEntryAllowed != null)
        data['late_entry_allowed'] = lateEntryAllowed;
      if (ageRestriction != null) data['age_restriction'] = ageRestriction;
      if (idCheckRequired != null) data['id_check_required'] = idCheckRequired;
      if (maxWarningsBeforeBan != null) {
        data['max_warnings_before_ban'] = maxWarningsBeforeBan;
      }
      if (defaultMaxDrinksPerPerson != null) {
        data['default_max_drinks_per_person'] = defaultMaxDrinksPerPerson;
      }
      if (roleDrinkLimits != null) data['role_drink_limits'] = roleDrinkLimits;
      if (customSettings != null) data['custom_settings'] = customSettings;

      final response =
          await _supabase.from('event_settings').upsert(data).select().single();

      return EventSettings.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Get event staff members
  Future<List<Map<String, dynamic>>> getEventStaff(String eventId) async {
    try {
      final response = await _supabase
          .from('event_staff')
          .select('''
            *,
            staff:staff_user_id(first_name, last_name, email, image_path),
            role:role_id(name, description)
          ''')
          .eq('event_id', eventId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Assign staff to event
  Future<void> assignStaffToEvent({
    required String eventId,
    required String staffUserId,
    required int roleId,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      await _supabase.from('event_staff').insert({
        'event_id': eventId,
        'staff_user_id': staffUserId,
        'role_id': roleId,
        'assigned_by': userId,
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Remove staff from event
  Future<void> removeStaffFromEvent({
    required String eventId,
    required String staffUserId,
  }) async {
    try {
      await _supabase
          .from('event_staff')
          .delete()
          .eq('event_id', eventId)
          .eq('staff_user_id', staffUserId);
    } catch (e) {
      rethrow;
    }
  }

  /// Stream event changes (real-time)
  Stream<Event> streamEvent(String eventId) {
    return _supabase
        .from('event')
        .stream(primaryKey: ['id'])
        .eq('id', eventId)
        .map((data) => Event.fromJson(data.first));
  }
}

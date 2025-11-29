// lib/services/event_service.dart
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/event.dart';
import 'models/event_settings.dart';
import 'models/event_staff.dart';

class EventService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get all events for current staff_user
  /// Uses RLS policies: automatically filters events where user is creator or staff
  Future<List<Event>> getMyEvents({bool includeArchived = false}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      debugPrint('[EventService] Getting events for staff_user: $userId');

      // Simplified query thanks to RLS policies (event_select_unified)
      var query = _supabase.from('event').select();

      if (!includeArchived) {
        query = query.isFilter('deleted_at', null);
      }

      final response = await query.order('created_at', ascending: false);

      debugPrint('[EventService] Found ${(response as List).length} events');
      return (response as List).map((json) => Event.fromJson(json)).toList();
    } catch (e) {
      debugPrint('[EventService] ERROR: $e');
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

  /// Generate a unique invite code
  String _generateInviteCode(String userId) {
    final random = Random.secure();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final randomString =
        List.generate(5, (index) => chars[random.nextInt(chars.length)]).join();

    final now = DateTime.now();
    final timeString =
        '${now.year}${now.month}${now.day}${now.hour}${now.minute}';

    return '${userId.substring(0, 6)}$timeString$randomString';
  }

  /// Create new event with an invite code
  Future<Event> createEvent({required String name, String? description}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final inviteCode = _generateInviteCode(userId);

      final response =
          await _supabase
              .from('event')
              .insert({
                'name': name,
                'description': description,
                'created_by': userId,
                'invite_code': inviteCode,
              })
              .select()
              .single();

      // Add creator as staff (use staff_user_id consistently)
      // Note: RLS policy event_insert_admin_only might restrict this if not handled by trigger or policy
      // Assuming creator has permission to insert into event_staff for their own event
      await _supabase.from('event_staff').insert({
        'event_id': response['id'],
        'staff_user_id': userId,
        'role_id':
            1, // Default to admin role (id=1 usually, check your seed data)
        'assigned_by': userId,
      });

      return Event.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Get event by invite code
  Future<Event?> getEventByInviteCode(String inviteCode) async {
    try {
      final response =
          await _supabase
              .from('event')
              .select()
              .eq('invite_code', inviteCode)
              .maybeSingle();

      if (response == null) return null;
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

  /// Restore event (undo soft delete)
  Future<void> restoreEvent(String eventId) async {
    try {
      await _supabase
          .from('event')
          .update({'deleted_at': null})
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
      if (lateEntryAllowed != null) {
        data['late_entry_allowed'] = lateEntryAllowed;
      }
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
  Future<List<EventStaff>> getEventStaff(String eventId) async {
    try {
      debugPrint('[DEBUG] getEventStaff: Fetching staff for event $eventId');
      final response = await _supabase
          .from('event_staff')
          .select('''
            *,
            staff:staff_user_id(id, first_name, last_name, email, phone, date_of_birth, image_path, created_at, is_active),
            role:role_id(name, description)
          ''')
          .eq('event_id', eventId)
          .order('created_at', ascending: false);

      debugPrint(
        '[DEBUG] getEventStaff: Received ${(response as List).length} staff members',
      );

      final staffList =
          (response as List)
              .map((json) => EventStaff.fromJson(json as Map<String, dynamic>))
              .toList();

      // Debug debugPrint first staff member to verify data
      if (staffList.isNotEmpty) {
        final firstStaff = staffList.first;
        debugPrint('[DEBUG] getEventStaff: Sample staff data:');
        debugPrint(
          '  - Name: ${firstStaff.staff?.firstName} ${firstStaff.staff?.lastName}',
        );
        debugPrint('  - Email: ${firstStaff.staff?.email}');
        debugPrint('  - Phone: ${firstStaff.staff?.phone}');
        debugPrint('  - DOB: ${firstStaff.staff?.dateOfBirth}');
        debugPrint('  - Image: ${firstStaff.staff?.imagePath}');
        debugPrint(
          '  - Role: ${firstStaff.roleName} (ID: ${firstStaff.roleId})',
        );
      }

      return staffList;
    } catch (e, stackTrace) {
      debugPrint('[ERROR] getEventStaff: $e');
      debugPrint('[ERROR] Stack trace: $stackTrace');
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

  /// Update staff role in event
  Future<void> updateStaffRole({
    required String eventId,
    required String staffUserId,
    required int newRoleId,
  }) async {
    try {
      debugPrint(
        '[DEBUG] updateStaffRole: Updating role for user $staffUserId in event $eventId to role $newRoleId',
      );
      await _supabase
          .from('event_staff')
          .update({'role_id': newRoleId})
          .eq('event_id', eventId)
          .eq('staff_user_id', staffUserId);
      debugPrint('[DEBUG] updateStaffRole: Role updated successfully');
    } catch (e, stackTrace) {
      debugPrint('[ERROR] updateStaffRole: $e');
      debugPrint('[ERROR] Stack trace: $stackTrace');
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

  /// Get event menu items
  Future<List<Map<String, dynamic>>> getEventMenuItems(String eventId) async {
    try {
      final response = await _supabase
          .from('menu_item')
          .select('*, menu!inner(event_id)')
          .eq('menu.event_id', eventId)
          .order('name');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      rethrow;
    }
  }
}

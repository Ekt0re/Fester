// lib/services/participation_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/participation.dart';

class ParticipationService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get all participations for an event
  Future<List<Map<String, dynamic>>> getEventParticipations(
    String eventId,
  ) async {
    try {
      final response = await _supabase
          .from('participation')
          .select('''
            *,
            person:person_id(*),
            status:status_id(name, description, is_inside),
            role:role_id(name, description),
            invited_by_person:invited_by(first_name, last_name)
          ''')
          .eq('event_id', eventId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Get participation by ID
  Future<Participation?> getParticipationById(String participationId) async {
    try {
      final response =
          await _supabase
              .from('participation')
              .select()
              .eq('id', participationId)
              .maybeSingle();

      if (response == null) return null;
      return Participation.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Create participation
  Future<Participation> createParticipation({
    required String personId,
    required String eventId,
    required int statusId,
    int? roleId,
    String? invitedBy,
  }) async {
    try {
      final response =
          await _supabase
              .from('participation')
              .insert({
                'person_id': personId,
                'event_id': eventId,
                'status_id': statusId,
                'role_id': roleId,
                'invited_by': invitedBy,
              })
              .select()
              .single();

      return Participation.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Update participation (status and role)
  Future<Participation> updateParticipation({
    required String participationId,
    int? statusId,
    int? roleId,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (statusId != null) updates['status_id'] = statusId;
      if (roleId != null) updates['role_id'] = roleId;

      final response =
          await _supabase
              .from('participation')
              .update(updates)
              .eq('id', participationId)
              .select()
              .single();

      // If status was updated, record history
      if (statusId != null) {
        String? changedByPersonId;
        final user = _supabase.auth.currentUser;
        
        if (user != null && user.email != null) {
          try {
            final eventId = response['event_id'];
            // Try to find a person record for this user in this event
            final personData = await _supabase
                .from('person')
                .select('id')
                .eq('email', user.email!)
                .eq('id_event', eventId)
                .maybeSingle();
            
            if (personData != null) {
              changedByPersonId = personData['id'] as String;
            }
          } catch (e) {
            // Ignore error, leave changedByPersonId as null
            print('Error finding person for history: $e');
          }
        }

        await _supabase.from('participation_status_history').insert({
          'participation_id': participationId,
          'status_id': statusId,
          'changed_by': changedByPersonId,
        });
      }

      return Participation.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Update participation status (legacy wrapper)
  Future<Participation> updateParticipationStatus({
    required String participationId,
    required int newStatusId,
  }) async {
    return updateParticipation(participationId: participationId, statusId: newStatusId);
  }

  /// Get participation status history
  Future<List<Map<String, dynamic>>> getParticipationStatusHistory(
    String participationId,
  ) async {
    try {
      final response = await _supabase
          .from('participation_status_history')
          .select('''
            *,
            status:status_id(name, description),
            changed_by_person:person(first_name, last_name)
          ''')
          .eq('participation_id', participationId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Get participation statuses
  Future<List<Map<String, dynamic>>> getParticipationStatuses() async {
    try {
      final response = await _supabase
          .from('participation_status')
          .select()
          .order('id');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Get available roles
  Future<List<Map<String, dynamic>>> getRoles() async {
    try {
      final response = await _supabase
          .from('role')
          .select()
          .order('id');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Get participation statistics
  Future<Map<String, dynamic>> getParticipationStats(
    String participationId,
  ) async {
    try {
      final response =
          await _supabase
              .from('participation_stats')
              .select()
              .eq('participation_id', participationId)
              .maybeSingle();

      return response ?? {};
    } catch (e) {
      rethrow;
    }
  }

  /// Check in participant
  Future<Participation> checkInParticipant(
    String participationId,
    int checkedInStatusId,
  ) async {
    return updateParticipation(
      participationId: participationId,
      statusId: checkedInStatusId,
    );
  }

  /// Stream participations for an event (real-time)
  Stream<List<Map<String, dynamic>>> streamEventParticipations(String eventId) {
    return _supabase
        .from('participation')
        .stream(primaryKey: ['id'])
        .eq('event_id', eventId)
        .order('created_at', ascending: false)
        .map((data) => List<Map<String, dynamic>>.from(data));
  }
}

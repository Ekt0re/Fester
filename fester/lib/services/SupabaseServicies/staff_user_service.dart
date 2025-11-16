// lib/services/staff_user_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/staff_user.dart';
import 'dart:typed_data';

class StaffUserService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get current staff user profile
  Future<StaffUser?> getCurrentStaffUser() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final response =
          await _supabase
              .from('staff_user')
              .select()
              .eq('id', userId)
              .maybeSingle();

      if (response == null) return null;
      return StaffUser.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Get staff user by ID
  Future<StaffUser?> getStaffUserById(String userId) async {
    try {
      final response =
          await _supabase
              .from('staff_user')
              .select()
              .eq('id', userId)
              .maybeSingle();

      if (response == null) return null;
      return StaffUser.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Get all active staff users
  Future<List<StaffUser>> getAllStaffUsers() async {
    try {
      final response = await _supabase
          .from('staff_user')
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => StaffUser.fromJson(json))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Update staff user profile
  Future<StaffUser> updateStaffUser({
    required String userId,
    String? firstName,
    String? lastName,
    DateTime? dateOfBirth,
    String? email,
    String? phone,
    String? imagePath,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (firstName != null) updates['first_name'] = firstName;
      if (lastName != null) updates['last_name'] = lastName;
      if (dateOfBirth != null) {
        updates['date_of_birth'] = dateOfBirth.toIso8601String().split('T')[0];
      }
      if (email != null) updates['email'] = email;
      if (phone != null) updates['phone'] = phone;
      if (imagePath != null) updates['image_path'] = imagePath;

      final response =
          await _supabase
              .from('staff_user')
              .update(updates)
              .eq('id', userId)
              .select()
              .single();

      return StaffUser.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Upload staff user profile image
  Future<String> uploadProfileImage({
    required String userId,
    required String filePath,
    required List<int> fileBytes,
  }) async {
    try {
      final fileExt = filePath.split('.').last;
      final fileName =
          '$userId-${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final storagePath = 'staff-avatars/$fileName';

      // Convert List<int> to Uint8List
      final uint8ListBytes = Uint8List.fromList(fileBytes);

      await _supabase.storage
          .from('avatars')
          .uploadBinary(storagePath, uint8ListBytes);

      final publicUrl = _supabase.storage
          .from('avatars')
          .getPublicUrl(storagePath);

      // Update staff_user with new image path
      await updateStaffUser(userId: userId, imagePath: storagePath);

      return publicUrl;
    } catch (e) {
      rethrow;
    }
  }

  /// Delete staff user profile image
  Future<void> deleteProfileImage({
    required String userId,
    required String imagePath,
  }) async {
    try {
      await _supabase.storage.from('avatars').remove([imagePath]);

      // Clear image path from staff_user
      await updateStaffUser(userId: userId, imagePath: '');
    } catch (e) {
      rethrow;
    }
  }

  /// Deactivate staff user (soft delete)
  Future<void> deactivateStaffUser(String userId) async {
    try {
      await _supabase
          .from('staff_user')
          .update({
            'is_active': false,
            'deleted_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);
    } catch (e) {
      rethrow;
    }
  }

  /// Reactivate staff user
  Future<void> reactivateStaffUser(String userId) async {
    try {
      await _supabase
          .from('staff_user')
          .update({'is_active': true, 'deleted_at': null})
          .eq('id', userId);
    } catch (e) {
      rethrow;
    }
  }

  /// Search staff users by name or email
  Future<List<StaffUser>> searchStaffUsers(String query) async {
    try {
      final response = await _supabase
          .from('staff_user')
          .select()
          .eq('is_active', true)
          .or(
            'first_name.ilike.%$query%,last_name.ilike.%$query%,email.ilike.%$query%',
          )
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => StaffUser.fromJson(json))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Get staff user events with roles
  Future<List<Map<String, dynamic>>> getStaffUserEvents(String userId) async {
    try {
      final response = await _supabase
          .from('event_staff')
          .select('''
            *,
            event:event_id(*),
            role:role_id(*),
            assigned_by_user:assigned_by(first_name, last_name)
          ''')
          .eq('staff_user_id', userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Check if staff user has specific role in an event
  Future<bool> hasEventRole({
    required String userId,
    required String eventId,
    required String roleName,
  }) async {
    try {
      final response = await _supabase.rpc(
        'get_event_staff_role',
        params: {'event_uuid': eventId},
      );

      return response?.toString().toLowerCase() == roleName.toLowerCase();
    } catch (e) {
      rethrow;
    }
  }

  /// Check if staff user is admin
  Future<bool> isAdmin() async {
    try {
      final response = await _supabase.rpc('is_admin');
      return response == true;
    } catch (e) {
      rethrow;
    }
  }

  /// Get staff user statistics
  Future<Map<String, dynamic>> getStaffUserStats(String userId) async {
    try {
      // Get number of events
      final eventsData = await _supabase
          .from('event_staff')
          .select('id') // solo un argomento posizionale
          .eq('staff_user_id', userId);

      // Get number of transactions created
      final transactionsData = await _supabase
          .from('transaction')
          .select('id') // solo un argomento posizionale
          .eq('created_by', userId);

      return {
        'events_count': eventsData.length,
        'transactions_count': transactionsData.length,
      };
    } catch (e) {
      rethrow;
    }
  }

  /// Stream staff user changes (real-time)
  Stream<StaffUser?> streamCurrentStaffUser() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return Stream.value(null);

    return _supabase
        .from('staff_user')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .map((data) {
          if (data.isEmpty) return null;
          return StaffUser.fromJson(data.first);
        });
  }
}

/*
Gestione dello staff:

✅ CRUD completo per staff_user
✅ Upload/delete immagine profilo
✅ Soft delete (activate/deactivate)
✅ Search staff
✅ Verifica ruoli (isAdmin, hasEventRole)
✅ Statistiche staff
✅ Real-time streaming

 */

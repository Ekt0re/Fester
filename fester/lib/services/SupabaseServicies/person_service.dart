// lib/services/person_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/person.dart';

class PersonService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get person by ID
  Future<Person?> getPersonById(String personId) async {
    try {
      final response =
          await _supabase
              .from('person')
              .select()
              .eq('id', personId)
              .eq('is_active', true)
              .maybeSingle();

      if (response == null) return null;
      return Person.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Create person
  Future<Person> createPerson({
    required String firstName,
    required String lastName,
    DateTime? dateOfBirth,
    String? email,
    String? phone,
    String? imagePath,
    String? idEvent,
  }) async {
    try {
      final response =
          await _supabase
              .from('person')
              .insert({
                'first_name': firstName,
                'last_name': lastName,
                'date_of_birth': dateOfBirth?.toIso8601String().split('T')[0],
                'email': email,
                'phone': phone,
                'image_path': imagePath,
                'id_event': idEvent,
              })
              .select()
              .single();

      return Person.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Update person
  Future<Person> updatePerson({
    required String personId,
    String? firstName,
    String? lastName,
    DateTime? dateOfBirth,
    String? email,
    String? phone,
    String? imagePath,
    String? idEvent,
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
      if (idEvent != null) updates['id_event'] = idEvent;

      final response =
          await _supabase
              .from('person')
              .update(updates)
              .eq('id', personId)
              .select()
              .single();

      return Person.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Search persons
  Future<List<Person>> searchPersons(String query) async {
    try {
      final response = await _supabase
          .from('person')
          .select()
          .eq('is_active', true)
          .or(
            'first_name.ilike.%$query%,last_name.ilike.%$query%,email.ilike.%$query%',
          )
          .order('created_at', ascending: false);

      return (response as List).map((json) => Person.fromJson(json)).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Delete person (soft delete)
  Future<void> deletePerson(String personId) async {
    try {
      await _supabase
          .from('person')
          .update({
            'is_active': false,
            'deleted_at': DateTime.now().toIso8601String(),
          })
          .eq('id', personId);
    } catch (e) {
      rethrow;
    }
  }
}

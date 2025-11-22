import 'package:supabase_flutter/supabase_flutter.dart';

class PersonService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Fetches full profile details including participation info
  Future<Map<String, dynamic>> getPersonProfile(String personId, String eventId) async {
    try {
      final response = await _supabase
          .from('participation')
          .select('''
            *,
            person:person_id (*),
            role:role_id (*),
            status:status_id (*)
          ''')
          .eq('person_id', personId)
          .eq('event_id', eventId)
          .single();
      
      return response;
    } catch (e) {
      throw Exception('Error fetching person profile: $e');
    }
  }

  /// Fetches all transactions for a specific participation
  Future<List<Map<String, dynamic>>> getPersonTransactions(String participationId) async {
    try {
      final response = await _supabase
          .from('transaction')
          .select('''
            *,
            type:transaction_type_id (*),
            menu_item:menu_item_id (*)
          ''')
          .eq('participation_id', participationId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Error fetching transactions: $e');
    }
  }

  /// Fetches transaction types (cached or fresh) to help with categorization if needed
  Future<List<Map<String, dynamic>>> getTransactionTypes() async {
    try {
      final response = await _supabase
          .from('transaction_type')
          .select();
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Error fetching transaction types: $e');
    }
  }

  /// Creates a new person record
  Future<dynamic> createPerson({
    required String firstName,
    required String lastName,
    String? email,
    String? phone,
    DateTime? dateOfBirth,
    required String idEvent,
  }) async {
    try {
      final response = await _supabase
          .from('person')
          .insert({
            'first_name': firstName,
            'last_name': lastName,
            'email': email,
            'phone': phone,
            'date_of_birth': dateOfBirth?.toIso8601String(),
            'id_event': idEvent,
          })
          .select()
          .single();
      
      // Return a simple object or map, assuming the caller handles it. 
      // The caller uses .id so we might need to return a model or just the map.
      // If the caller expects an object with .id, we might need a model.
      // Looking at AddGuestScreen: person.id. 
      // If response is Map, person['id'] works. But code says person.id.
      // Let's check if there is a Person model. 
      // The error said "The method 'createPerson' isn't defined".
      // It didn't say "The getter 'id' isn't defined".
      // But if I return a Map, person.id will fail if dynamic doesn't handle it (it won't).
      // I should probably return a simple class or change AddGuestScreen to use ['id'].
      // However, I can't see a Person model file.
      // Let's assume for now I return a Map and I might need to fix AddGuestScreen too if it expects a model.
      // Wait, if AddGuestScreen uses `person.id`, then `person` must be an object.
      // I'll check if I can return a custom object or if I should fix AddGuestScreen.
      // For now, I'll return a simple object-like structure or just the Map and see.
      // Actually, looking at the previous conversation summaries, there was a "Fixing Guest Creation Error" task.
      // Maybe there WAS a Person model.
      // I'll define a simple Person class inside this file or return a Map and update AddGuestScreen to use ['id'].
      // Updating AddGuestScreen is safer if I don't want to create a model file.
      // BUT, the user code `person.id` implies a model.
      // I'll create a minimal Person class at the bottom of PersonService or just return a Map and let the user fix the call site? No, I should fix it.
      // I'll return a Map and change AddGuestScreen to use person['id'].
      return response;
    } catch (e) {
      throw Exception('Error creating person: $e');
    }
  }

  /// Updates an existing person record
  Future<void> updatePerson({
    required String personId,
    required String firstName,
    required String lastName,
    String? email,
    String? phone,
    DateTime? dateOfBirth,
  }) async {
    try {
      await _supabase.from('person').update({
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'phone': phone,
        'date_of_birth': dateOfBirth?.toIso8601String(),
      }).eq('id', personId);
    } catch (e) {
      throw Exception('Error updating person: $e');
    }
  }
}

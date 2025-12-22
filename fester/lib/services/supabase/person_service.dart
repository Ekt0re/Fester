import 'package:supabase_flutter/supabase_flutter.dart';
import '../logger_service.dart';

class PersonService {
  static const String _tag = 'PersonService';
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Fetches full profile details including participation info
  Future<Map<String, dynamic>> getPersonProfile(
    String personId,
    String eventId,
  ) async {
    try {
      final response =
          await _supabase
              .from('participation')
              .select('''
          *,
          person:person_id (
            *,
            gruppo:gruppo_id (id, name),
            sottogruppo:sottogruppo_id (id, name)
          ),
          role:role_id (*),
          status:status_id (*),
          invited_by_person:invited_by (
            id,
            first_name,
            last_name
          ),
          current_area:current_area_id (id, name)
        ''')
              .eq('person_id', personId)
              .eq('event_id', eventId)
              .single();

      return response;
    } catch (e) {
      LoggerService.error('Error fetching person profile', tag: _tag, error: e);
      rethrow;
    }
  }

  /// Get all members of a specific group
  Future<List<Map<String, dynamic>>> getGroupMembers(int groupId) async {
    try {
      final response = await _supabase
          .from('person')
          .select('id, first_name, last_name, email, phone, id_event')
          .eq('gruppo_id', groupId)
          .order('first_name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      LoggerService.error('Error fetching group members', tag: _tag, error: e);
      rethrow;
    }
  }

  /// Get all members of a specific subgroup
  Future<List<Map<String, dynamic>>> getSubgroupMembers(int subgroupId) async {
    try {
      final response = await _supabase
          .from('person')
          .select('id, first_name, last_name, email, phone, id_event')
          .eq('sottogruppo_id', subgroupId)
          .order('first_name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      LoggerService.error(
        'Error fetching subgroup members',
        tag: _tag,
        error: e,
      );
      rethrow;
    }
  }

  /// Get all guests invited by a specific person
  Future<List<Map<String, dynamic>>> getInvitedGuests(
    String inviterId,
    String eventId,
  ) async {
    try {
      final response = await _supabase
          .from('participation')
          .select('''
            *,
            person:person_id (
              id,
              first_name,
              last_name,
              email,
              phone,
              gruppo:gruppo_id (id, name),
              sottogruppo:sottogruppo_id (id, name)
            ),
            status:status_id (id, name),
            role:role_id (id, name)
          ''')
          .eq('invited_by', inviterId)
          .eq('event_id', eventId);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      LoggerService.error('Error fetching invited guests', tag: _tag, error: e);
      rethrow;
    }
  }

  /// Fetches all transactions for a specific participation
  Future<List<Map<String, dynamic>>> getPersonTransactions(
    String participationId,
  ) async {
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
      LoggerService.error(
        'Error fetching person transactions',
        tag: _tag,
        error: e,
      );
      rethrow;
    }
  }

  /// Fetches transaction types
  Future<List<Map<String, dynamic>>> getTransactionTypes() async {
    try {
      final response = await _supabase.from('transaction_type').select();
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      LoggerService.error(
        'Error fetching transaction types',
        tag: _tag,
        error: e,
      );
      rethrow;
    }
  }

  /// Creates a new person record
  Future<dynamic> createPerson({
    required String firstName,
    required String lastName,
    String? email,
    String? phone,
    DateTime? dateOfBirth,
    String? codiceFiscale,
    String? indirizzo,
    int? gruppoId,
    int? sottogruppoId,
    required String idEvent,
  }) async {
    try {
      final response =
          await _supabase
              .from('person')
              .insert({
                'first_name': firstName,
                'last_name': lastName,
                'email': email,
                'phone': phone,
                'date_of_birth': dateOfBirth?.toIso8601String(),
                'codice_fiscale': codiceFiscale,
                'indirizzo': indirizzo,
                'gruppo_id': gruppoId,
                'sottogruppo_id': sottogruppoId,
                'id_event': idEvent,
              })
              .select()
              .single();

      return response;
    } catch (e) {
      LoggerService.error('Error creating person', tag: _tag, error: e);
      rethrow;
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
    String? codiceFiscale,
    String? indirizzo,
    int? gruppoId,
    int? sottogruppoId,
  }) async {
    try {
      await _supabase
          .from('person')
          .update({
            'first_name': firstName,
            'last_name': lastName,
            'email': email,
            'phone': phone,
            'date_of_birth': dateOfBirth?.toIso8601String(),
            'codice_fiscale': codiceFiscale,
            'indirizzo': indirizzo,
            'gruppo_id': gruppoId,
            'sottogruppo_id': sottogruppoId,
          })
          .eq('id', personId);
    } catch (e) {
      LoggerService.error('Error updating person', tag: _tag, error: e);
      rethrow;
    }
  }

  /// Get all guests (persons) for a specific event
  Future<List<Map<String, dynamic>>> getEventGuests(String eventId) async {
    try {
      final response = await _supabase
          .from('person')
          .select()
          .eq('id_event', eventId)
          .order('first_name', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      LoggerService.error('Error fetching event guests', tag: _tag, error: e);
      rethrow;
    }
  }

  /// Get all participants (guests with status/role) for a specific event
  Future<List<Map<String, dynamic>>> getEventParticipants(
    String eventId,
  ) async {
    try {
      final response = await _supabase
          .from('participation')
          .select('''
            *,
            person:person_id (*),
            role:role_id (*),
            status:status_id (*)
          ''')
          .eq('event_id', eventId);

      final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(
        response,
      );
      data.sort((a, b) {
        final pA = a['person'] ?? {};
        final pB = b['person'] ?? {};
        final nameA = '${pA['first_name']} ${pA['last_name']}';
        final nameB = '${pB['first_name']} ${pB['last_name']}';
        return nameA.toLowerCase().compareTo(nameB.toLowerCase());
      });

      return data;
    } catch (e) {
      LoggerService.error(
        'Error fetching event participants',
        tag: _tag,
        error: e,
      );
      rethrow;
    }
  }

  /// Search for people and staff by query
  Future<List<Map<String, dynamic>>> searchPeopleAndStaff(
    String eventId,
    String query,
  ) async {
    try {
      final lowerQuery = query.toLowerCase();

      // Check if query could be a UUID (basic validation)
      final isUuid = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        caseSensitive: false,
      ).hasMatch(query);

      // Search persons through participation (since person table doesn't have event_id FK)
      final participations = await _supabase
          .from('participation')
          .select('''
            person:person_id (
              id, 
              first_name, 
              last_name, 
              email, 
              phone, 
              id_event
            )
          ''')
          .eq('event_id', eventId);

      // Filter persons in Dart since we can't use OR on nested fields
      final persons = <Map<String, dynamic>>[];
      for (var participation in participations) {
        final person = participation['person'];
        if (person != null) {
          final firstName =
              (person['first_name'] ?? '').toString().toLowerCase();
          final lastName = (person['last_name'] ?? '').toString().toLowerCase();
          final email = (person['email'] ?? '').toString().toLowerCase();
          final phone = (person['phone'] ?? '').toString().toLowerCase();
          final personId = person['id']?.toString() ?? '';

          // Check if query matches
          bool matches = false;
          if (isUuid && personId == query) {
            matches = true;
          } else if (!isUuid) {
            matches =
                firstName.contains(lowerQuery) ||
                lastName.contains(lowerQuery) ||
                email.contains(lowerQuery) ||
                phone.contains(lowerQuery);
          }

          if (matches) {
            persons.add(person);
          }
        }
      }

      // Search staff through event_staff
      final staff = await _supabase
          .from('event_staff')
          .select(
            'staff:staff_user_id(id, first_name, last_name, email, phone)',
          )
          .eq('event_id', eventId);

      final results = <Map<String, dynamic>>[];

      // Add persons to results
      for (var person in persons) {
        results.add({
          'id': person['id'],
          'first_name': person['first_name'],
          'last_name': person['last_name'],
          'email': person['email'],
          'phone': person['phone'],
          'id_event': person['id_event'],
          'type': 'person',
        });
      }

      // Add staff to results
      for (var s in staff) {
        final staffData = s['staff'];
        if (staffData != null) {
          final fullName =
              '${staffData['first_name']} ${staffData['last_name']}';
          final staffEmail = staffData['email']?.toString() ?? '';
          final staffPhone = staffData['phone']?.toString() ?? '';
          final staffId = staffData['id']?.toString() ?? '';

          // Apply search filter
          bool matchesSearch = false;
          if (isUuid && staffId == query) {
            matchesSearch = true;
          } else if (!isUuid) {
            matchesSearch =
                fullName.toLowerCase().contains(lowerQuery) ||
                staffEmail.toLowerCase().contains(lowerQuery) ||
                staffPhone.toLowerCase().contains(lowerQuery);
          }

          if (matchesSearch) {
            results.add({
              'id': staffData['id'],
              'first_name': staffData['first_name'],
              'last_name': staffData['last_name'],
              'email': staffData['email'],
              'phone': staffData['phone'],
              'type': 'staff',
            });
          }
        }
      }

      return results;
    } catch (e) {
      LoggerService.error(
        'Error searching people and staff',
        tag: _tag,
        error: e,
      );
      rethrow;
    }
  }

  /// Checks if a person with the same email or phone already exists in the event
  Future<Map<String, dynamic>?> checkDuplicate({
    required String eventId,
    String? email,
    String? phone,
    String? excludePersonId,
  }) async {
    try {
      if (email == null && phone == null) return null;

      var query = _supabase
          .from('participation')
          .select('person:person_id(*)')
          .eq('event_id', eventId);

      final response = await query;
      final participations = List<Map<String, dynamic>>.from(response);

      for (var part in participations) {
        final person = part['person'];
        if (person == null) continue;
        if (excludePersonId != null && person['id'] == excludePersonId) {
          continue;
        }

        if (email != null &&
            person['email']?.toString().toLowerCase() == email.toLowerCase()) {
          return person;
        }
        if (phone != null && person['phone']?.toString() == phone) {
          return person;
        }
      }
      return null;
    } catch (e) {
      LoggerService.error(
        'Error checking duplicate person',
        tag: _tag,
        error: e,
      );
      return null;
    }
  }
}

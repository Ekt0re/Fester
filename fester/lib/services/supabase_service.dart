import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

/// Servizio centralizzato per gestire tutte le operazioni con Supabase
class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  SupabaseClient get client => Supabase.instance.client;
  User? get currentUser => client.auth.currentUser;
  String? get currentUserId => currentUser?.id;

  // ============================================
  // INIZIALIZZAZIONE
  // ============================================

  /// Inizializza Supabase
  static Future<void> initialize({
    required String url,
    required String anonKey,
  }) async {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }

  // ============================================
  // AUTENTICAZIONE
  // ============================================

  /// Login con email e password
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Registrazione con email e password + creazione automatica staff_user
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phone,
    DateTime? dateOfBirth,
  }) async {
    try {
      print('Tentativo di registrazione per: $email');

      // Passa i dati nei metadata per il trigger
      final response = await client.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: 'fester://login-callback',
        data: {
          'first_name': firstName,
          'last_name': lastName,
          'phone': phone,
          'date_of_birth': dateOfBirth?.toIso8601String(),
        },
      );

      print('Risposta registrazione: ${response.user?.email}');

      if (response.user == null) {
        throw Exception('Impossibile creare l\'utente.');
      }

      // Il trigger ha già creato lo staff_user automaticamente!
      return response;
    } on AuthException catch (e) {
      print('Errore AuthException durante la registrazione:');
      print('Status code: ${e.statusCode}');
      print('Messaggio: ${e.message}');

      String errorMessage = 'Errore durante la registrazione';

      if (e.statusCode == '400') {
        if (e.message.toLowerCase().contains('already registered') ||
            e.message.toLowerCase().contains('already in use')) {
          errorMessage = 'Email già registrata';
        } else if (e.message.toLowerCase().contains('password')) {
          errorMessage = 'La password deve contenere almeno 6 caratteri';
        } else {
          errorMessage = 'Dati non validi: ${e.message}';
        }
      } else if (e.statusCode == '500') {
        errorMessage = 'Errore del server. Codice: 500';
      }

      throw Exception(errorMessage);
    } catch (e, stackTrace) {
      print('Errore generico durante la registrazione:');
      print(e);
      print(stackTrace);
      throw Exception('Errore durante la registrazione: ${e.toString()}');
    }
  }

  /// Logout
  Future<void> signOut() async {
    await client.auth.signOut();
  }

  /// Reset password
  Future<void> resetPassword(String email) async {
    await client.auth.resetPasswordForEmail(email);
  }

  /// Stream dello stato di autenticazione
  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  // ============================================
  // STAFF USER (NUOVO)
  // ============================================

  /// Ottieni staff user corrente
  Future<Map<String, dynamic>?> getCurrentStaffUser() async {
    if (currentUserId == null) return null;

    final response =
        await client
            .from('staff_user')
            .select()
            .eq('id', currentUserId!)
            .maybeSingle();

    return response;
  }

  /// Crea staff user (chiamato durante registrazione)
  Future<Map<String, dynamic>> createStaffUser({
    required String userId,
    required String firstName,
    required String lastName,
    required String email,
    String? phone,
    DateTime? dateOfBirth,
    String? imagePath,
  }) async {
    final data = {
      'id': userId, // Stesso UUID di auth.users
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      if (phone != null) 'phone': phone,
      if (dateOfBirth != null) 'date_of_birth': dateOfBirth.toIso8601String(),
      if (imagePath != null) 'image_path': imagePath,
    };

    return await client.from('staff_user').insert(data).select().single();
  }

  /// Aggiorna staff user
  Future<Map<String, dynamic>> updateStaffUser(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    return await client
        .from('staff_user')
        .update(updates)
        .eq('id', userId)
        .select()
        .single();
  }

  /// Ottieni tutti gli staff users (solo admin)
  Future<List<Map<String, dynamic>>> getAllStaffUsers() async {
    return await client.from('staff_user').select().order('last_name');
  }

  // ============================================
  // EVENT STAFF (NUOVO)
  // ============================================

  /// Ottieni staff assegnati ad un evento
  Future<List<Map<String, dynamic>>> getEventStaff(String eventId) async {
    return await client
        .from('event_staff')
        .select('*, staff_user(*), role(*)')
        .eq('event_id', eventId)
        .order('created_at');
  }

  /// Assegna staff ad un evento
  Future<Map<String, dynamic>> assignStaffToEvent({
    required String eventId,
    required String staffUserId,
    required int roleId, // staff1, staff2, staff3
  }) async {
    return await client
        .from('event_staff')
        .insert({
          'event_id': eventId,
          'staff_user_id': staffUserId,
          'role_id': roleId,
          'assigned_by': currentUserId,
        })
        .select()
        .single();
  }

  /// Rimuovi staff da un evento
  Future<void> removeStaffFromEvent({
    required String eventId,
    required String staffUserId,
  }) async {
    await client
        .from('event_staff')
        .delete()
        .eq('event_id', eventId)
        .eq('staff_user_id', staffUserId);
  }

  /// Aggiorna ruolo staff in un evento
  Future<Map<String, dynamic>> updateEventStaffRole({
    required String eventId,
    required String staffUserId,
    required int newRoleId,
  }) async {
    return await client
        .from('event_staff')
        .update({'role_id': newRoleId})
        .eq('event_id', eventId)
        .eq('staff_user_id', staffUserId)
        .select()
        .single();
  }

  /// Ottieni eventi dello staff corrente
  Future<List<Map<String, dynamic>>> getMyStaffEvents() async {
    if (currentUserId == null) return [];

    return await client
        .from('event_staff')
        .select('*, event(*, event_settings(*)), role(*)')
        .eq('staff_user_id', currentUserId!)
        .order('created_at', ascending: false);
  }

  // ============================================
  // PERSON
  // ============================================

  /// Ottieni persona con età calcolata
  Future<Map<String, dynamic>?> getPersonWithAge(String personId) async {
    final response =
        await client
            .from('person_with_age')
            .select()
            .eq('id', personId)
            .maybeSingle();

    return response;
  }

  /// Ottieni tutte le persone (solo per staff/admin)
  Future<List<Map<String, dynamic>>> getAllPersons({
    int? limit,
    int? offset,
    bool includeDeleted = false,
  }) async {
    var query = client.from('person').select();

    if (!includeDeleted) {
      query = query.isFilter('deleted_at', null);
    }

    if (offset != null && limit != null) {
      return await query.range(offset, offset + limit - 1).order('last_name');
    } else if (limit != null) {
      return await query.limit(limit).order('last_name');
    }

    return await query.order('last_name');
  }

  /// Cerca persone per nome
  Future<List<Map<String, dynamic>>> searchPersons(String searchTerm) async {
    return await client
        .from('person')
        .select()
        .isFilter('deleted_at', null)
        .or('first_name.ilike.%$searchTerm%,last_name.ilike.%$searchTerm%')
        .order('last_name');
  }

  /// Crea nuova persona
  Future<Map<String, dynamic>> createPerson({
    required String firstName,
    required String lastName,
    String? email,
    String? phone,
    DateTime? dateOfBirth,
    String? imagePath,
  }) async {
    final data = {
      'first_name': firstName,
      'last_name': lastName,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (dateOfBirth != null) 'date_of_birth': dateOfBirth.toIso8601String(),
      if (imagePath != null) 'image_path': imagePath,
    };

    return await client.from('person').insert(data).select().single();
  }

  /// Aggiorna persona
  Future<Map<String, dynamic>> updatePerson(
    String personId,
    Map<String, dynamic> updates,
  ) async {
    return await client
        .from('person')
        .update(updates)
        .eq('id', personId)
        .select()
        .single();
  }

  /// Soft delete persona
  Future<void> deletePerson(String personId) async {
    await client
        .from('person')
        .update({
          'is_active': false,
          'deleted_at': DateTime.now().toIso8601String(),
        })
        .eq('id', personId);
  }

  // ============================================
  // ROLES
  // ============================================

  /// Ottieni tutti i ruoli
  Future<List<Map<String, dynamic>>> getRoles() async {
    return await client.from('role').select().order('name');
  }

  /// Ottieni ruoli staff (staff1, staff2, staff3)
  Future<List<Map<String, dynamic>>> getStaffRoles() async {
    return await client
        .from('role')
        .select()
        .inFilter('name', ['staff1', 'staff2', 'staff3'])
        .order('name');
  }

  /// Ottieni ruoli partecipanti (guest, vip)
  Future<List<Map<String, dynamic>>> getParticipantRoles() async {
    return await client
        .from('role')
        .select()
        .inFilter('name', ['guest', 'vip'])
        .order('name');
  }

  // ============================================
  // EVENTS
  // ============================================

  /// Ottieni tutti gli eventi visibili all'utente
  Future<List<Map<String, dynamic>>> getEvents({
    bool includeDeleted = false,
  }) async {
    var query = client.from('event').select('*, event_settings(*)');

    if (!includeDeleted) {
      query = query.isFilter('deleted_at', null);
    }

    return await query.order('created_at', ascending: false);
  }

  /// Ottieni evento singolo
  Future<Map<String, dynamic>?> getEvent(String eventId) async {
    return await client
        .from('event')
        .select('*, event_settings(*)')
        .eq('id', eventId)
        .maybeSingle();
  }

  /// Crea nuovo evento
  Future<Map<String, dynamic>> createEvent({
    required String name,
    String? description,
    required Map<String, dynamic> settings,
  }) async {
    // Crea l'evento
    final event =
        await client
            .from('event')
            .insert({
              'name': name,
              'description': description,
              'created_by': currentUserId,
            })
            .select()
            .single();

    // Crea le settings
    await client.from('event_settings').insert({
      'event_id': event['id'],
      'created_by': currentUserId,
      ...settings,
    });

    return event;
  }

  /// Aggiorna evento
  Future<Map<String, dynamic>> updateEvent(
    String eventId,
    Map<String, dynamic> updates,
  ) async {
    return await client
        .from('event')
        .update(updates)
        .eq('id', eventId)
        .select()
        .single();
  }

  /// Aggiorna settings evento
  Future<Map<String, dynamic>> updateEventSettings(
    String eventId,
    Map<String, dynamic> updates,
  ) async {
    return await client
        .from('event_settings')
        .update(updates)
        .eq('event_id', eventId)
        .select()
        .single();
  }

  /// Soft delete evento
  Future<void> deleteEvent(String eventId) async {
    await client
        .from('event')
        .update({'deleted_at': DateTime.now().toIso8601String()})
        .eq('id', eventId);
  }

  // ============================================
  // MENU
  // ============================================

  /// Ottieni tutti i menu
  Future<List<Map<String, dynamic>>> getMenus() async {
    return await client
        .from('menu')
        .select('*, menu_item(*)')
        .order('created_at', ascending: false);
  }

  /// Ottieni menu singolo con items
  Future<Map<String, dynamic>?> getMenu(String menuId) async {
    return await client
        .from('menu')
        .select('*, menu_item(*, transaction_type(*))')
        .eq('id', menuId)
        .maybeSingle();
  }

  /// Crea nuovo menu
  Future<Map<String, dynamic>> createMenu({
    required String name,
    String? description,
  }) async {
    return await client
        .from('menu')
        .insert({
          'name': name,
          'description': description,
          'created_by': currentUserId,
        })
        .select()
        .single();
  }

  /// Aggiorna menu
  Future<Map<String, dynamic>> updateMenu(
    String menuId,
    Map<String, dynamic> updates,
  ) async {
    return await client
        .from('menu')
        .update(updates)
        .eq('id', menuId)
        .select()
        .single();
  }

  /// Elimina menu
  Future<void> deleteMenu(String menuId) async {
    await client.from('menu').delete().eq('id', menuId);
  }

  // ============================================
  // MENU ITEMS
  // ============================================

  /// Ottieni items di un menu
  Future<List<Map<String, dynamic>>> getMenuItems(String menuId) async {
    return await client
        .from('menu_item')
        .select('*, transaction_type(*)')
        .eq('menu_id', menuId)
        .order('sort_order');
  }

  /// Crea menu item
  Future<Map<String, dynamic>> createMenuItem({
    required String menuId,
    required int transactionTypeId,
    required String name,
    required double price,
    String? description,
    bool isAvailable = true,
    int sortOrder = 0,
  }) async {
    return await client
        .from('menu_item')
        .insert({
          'menu_id': menuId,
          'transaction_type_id': transactionTypeId,
          'name': name,
          'description': description,
          'price': price,
          'is_available': isAvailable,
          'sort_order': sortOrder,
        })
        .select()
        .single();
  }

  /// Aggiorna menu item
  Future<Map<String, dynamic>> updateMenuItem(
    String itemId,
    Map<String, dynamic> updates,
  ) async {
    return await client
        .from('menu_item')
        .update(updates)
        .eq('id', itemId)
        .select()
        .single();
  }

  /// Elimina menu item
  Future<void> deleteMenuItem(String itemId) async {
    await client.from('menu_item').delete().eq('id', itemId);
  }

  // ============================================
  // EVENT MENU
  // ============================================

  /// Ottieni menu associato ad un evento
  Future<Map<String, dynamic>?> getEventMenu(String eventId) async {
    final result =
        await client
            .from('event_menu')
            .select('*, menu(*, menu_item(*, transaction_type(*)))')
            .eq('event_id', eventId)
            .maybeSingle();

    return result;
  }

  /// Associa menu ad evento
  Future<Map<String, dynamic>> setEventMenu({
    required String eventId,
    required String menuId,
  }) async {
    // Prima elimina eventuali associazioni precedenti
    await client.from('event_menu').delete().eq('event_id', eventId);

    // Poi crea la nuova associazione
    return await client
        .from('event_menu')
        .insert({'event_id': eventId, 'menu_id': menuId})
        .select()
        .single();
  }

  // ============================================
  // INVENTORY
  // ============================================

  /// Ottieni inventario di un evento
  Future<List<Map<String, dynamic>>> getEventInventory(String eventId) async {
    return await client
        .from('event_menu_item_inventory')
        .select('*, menu_item(*, transaction_type(*))')
        .eq('event_id', eventId);
  }

  /// Imposta quantità disponibile per un item
  Future<Map<String, dynamic>> setInventoryQuantity({
    required String eventId,
    required String menuItemId,
    int? availableQuantity,
  }) async {
    return await client
        .from('event_menu_item_inventory')
        .upsert({
          'event_id': eventId,
          'menu_item_id': menuItemId,
          'available_quantity': availableQuantity,
        })
        .select()
        .single();
  }

  // ============================================
  // PARTICIPATIONS
  // ============================================

  /// Ottieni partecipazioni di un evento
  Future<List<Map<String, dynamic>>> getEventParticipations(
    String eventId, {
    String? statusName,
  }) async {
    var query = client
        .from('participation')
        .select('*, person(*), participation_status(*), role(*)')
        .eq('event_id', eventId);

    if (statusName != null) {
      query = query.eq('participation_status.name', statusName);
    }

    return await query.order('created_at', ascending: false);
  }

  /// Ottieni partecipazioni di una persona
  Future<List<Map<String, dynamic>>> getPersonParticipations(
    String personId,
  ) async {
    return await client
        .from('participation')
        .select('*, event(*), participation_status(*), role(*)')
        .eq('person_id', personId)
        .order('created_at', ascending: false);
  }

  /// Ottieni statistiche partecipazione
  Future<Map<String, dynamic>?> getParticipationStats(
    String participationId,
  ) async {
    return await client
        .from('participation_stats')
        .select()
        .eq('participation_id', participationId)
        .maybeSingle();
  }

  /// Crea partecipazione
  Future<Map<String, dynamic>> createParticipation({
    required String personId,
    required String eventId,
    required int statusId,
    int? roleId, // guest o vip
    String? invitedBy,
  }) async {
    return await client
        .from('participation')
        .insert({
          'person_id': personId,
          'event_id': eventId,
          'status_id': statusId,
          if (roleId != null) 'role_id': roleId,
          if (invitedBy != null) 'invited_by': invitedBy,
        })
        .select()
        .single();
  }

  /// Aggiorna status partecipazione
  Future<Map<String, dynamic>> updateParticipationStatus({
    required String participationId,
    required int newStatusId,
    String? notes,
  }) async {
    // Aggiorna la partecipazione
    final updated =
        await client
            .from('participation')
            .update({'status_id': newStatusId})
            .eq('id', participationId)
            .select()
            .single();

    // Registra nello storico
    await client.from('participation_status_history').insert({
      'participation_id': participationId,
      'status_id': newStatusId,
      'changed_by': currentUserId,
      if (notes != null) 'notes': notes,
    });

    return updated;
  }

  /// Elimina partecipazione
  Future<void> deleteParticipation(String participationId) async {
    await client.from('participation').delete().eq('id', participationId);
  }

  // ============================================
  // TRANSACTIONS
  // ============================================

  /// Ottieni transazioni di una partecipazione
  Future<List<Map<String, dynamic>>> getParticipationTransactions(
    String participationId,
  ) async {
    return await client
        .from('transaction')
        .select(
          '*, transaction_type(*), menu_item(*), created_by:staff_user!created_by(*)',
        )
        .eq('participation_id', participationId)
        .order('created_at', ascending: false);
  }

  /// Ottieni transazioni di un evento
  Future<List<Map<String, dynamic>>> getEventTransactions(
    String eventId,
  ) async {
    return await client
        .from('transaction')
        .select(
          '*, transaction_type(*), menu_item(*), participation!inner(event_id)',
        )
        .eq('participation.event_id', eventId)
        .order('created_at', ascending: false);
  }

  /// Crea transazione
  Future<Map<String, dynamic>> createTransaction({
    required String participationId,
    required int transactionTypeId,
    String? menuItemId,
    String? name,
    String? description,
    double amount = 0.0,
    int quantity = 1,
  }) async {
    return await client
        .from('transaction')
        .insert({
          'participation_id': participationId,
          'transaction_type_id': transactionTypeId,
          if (menuItemId != null) 'menu_item_id': menuItemId,
          if (name != null) 'name': name,
          if (description != null) 'description': description,
          'amount': amount,
          'quantity': quantity,
          'created_by': currentUserId,
        })
        .select()
        .single();
  }

  /// Aggiorna transazione
  Future<Map<String, dynamic>> updateTransaction(
    String transactionId,
    Map<String, dynamic> updates,
  ) async {
    return await client
        .from('transaction')
        .update(updates)
        .eq('id', transactionId)
        .select()
        .single();
  }

  /// Elimina transazione
  Future<void> deleteTransaction(String transactionId) async {
    await client.from('transaction').delete().eq('id', transactionId);
  }

  // ============================================
  // PARTICIPATION STATUS
  // ============================================

  /// Ottieni tutti gli status disponibili
  Future<List<Map<String, dynamic>>> getParticipationStatuses() async {
    return await client.from('participation_status').select().order('id');
  }

  /// Ottieni status per nome
  Future<Map<String, dynamic>?> getStatusByName(String name) async {
    return await client
        .from('participation_status')
        .select()
        .eq('name', name)
        .maybeSingle();
  }

  // ============================================
  // TRANSACTION TYPES
  // ============================================

  /// Ottieni tutti i tipi di transazione
  Future<List<Map<String, dynamic>>> getTransactionTypes() async {
    return await client.from('transaction_type').select().order('id');
  }

  /// Ottieni tipo transazione per nome
  Future<Map<String, dynamic>?> getTransactionTypeByName(String name) async {
    return await client
        .from('transaction_type')
        .select()
        .eq('name', name)
        .maybeSingle();
  }

  // ============================================
  // REALTIME SUBSCRIPTIONS
  // ============================================

  /// Sottoscrivi aggiornamenti transazioni evento
  RealtimeChannel subscribeToEventTransactions(
    String eventId,
    void Function(Map<String, dynamic>) onData,
  ) {
    return client
        .channel('event_transactions_$eventId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'transaction',
          callback: (payload) {
            onData(payload.newRecord);
          },
        )
        .subscribe();
  }

  /// Sottoscrivi aggiornamenti partecipazioni evento
  RealtimeChannel subscribeToEventParticipations(
    String eventId,
    void Function(Map<String, dynamic>) onData,
  ) {
    return client
        .channel('event_participations_$eventId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'participation',
          callback: (payload) {
            onData(payload.newRecord);
          },
        )
        .subscribe();
  }

  /// Sottoscrivi aggiornamenti inventario evento
  RealtimeChannel subscribeToEventInventory(
    String eventId,
    void Function(Map<String, dynamic>) onData,
  ) {
    return client
        .channel('event_inventory_$eventId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'event_menu_item_inventory',
          callback: (payload) {
            onData(payload.newRecord);
          },
        )
        .subscribe();
  }

  /// Disiscriviti da un canale
  Future<void> unsubscribe(RealtimeChannel channel) async {
    await client.removeChannel(channel);
  }

  // ============================================
  // STORAGE
  // ============================================

  /// Upload immagine profilo
  Future<String> uploadProfileImage(String userId, String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final ext = filePath.split('.').last;
    final path = 'avatars/$userId.$ext';

    await client.storage.from('avatars').uploadBinary(path, bytes);

    return client.storage.from('avatars').getPublicUrl(path);
  }

  /// Elimina immagine profilo
  Future<void> deleteProfileImage(String imagePath) async {
    final path = imagePath.split('/').last;
    await client.storage.from('avatars').remove([path]);
  }
}

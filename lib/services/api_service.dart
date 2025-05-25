Future<Map<String, dynamic>> addGuest(String eventId, Map<String, dynamic> guestData) async {
  try {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {
        'success': false,
        'message': 'Utente non autenticato'
      };
    }
    
    // Verifichiamo che l'utente abbia accesso all'evento
    final eventAccess = await _supabase
        .from('events')
        .select()
        .eq('id', eventId)
        .eq('creato_da', user.id);
    
    if (eventAccess.isEmpty) {
      return {
        'success': false,
        'message': 'Non hai i permessi per modificare questo evento'
      };
    }
    
    // Utilizza l'auth_user_id fornito o quello corrente se non specificato
    final authUserId = guestData['auth_user_id'] ?? user.id;
    final role = guestData['role'] ?? 'guest';
    
    // Prepara i dati per la tabella event_users - rimuoviamo is_present che non esiste
    final userData = {
      'event_id': eventId,
      'auth_user_id': authUserId,
      'role': role,
    };
    
    // Cerca prima se esiste già un record con questo event_id e auth_user_id
    final existingRecords = await _supabase
        .from('event_users')
        .select()
        .eq('event_id', eventId)
        .eq('auth_user_id', authUserId);
    
    // Se esiste già, usa upsert per aggiornarlo invece di crearne uno nuovo
    if (existingRecords.isNotEmpty) {
      // Aggiorna l'elemento esistente
      final data = await _supabase
        .from('event_users')
        .update(userData)
        .eq('event_id', eventId)
        .eq('auth_user_id', authUserId)
        .select();
      
      return {'success': true, 'data': data, 'message': 'Ospite aggiornato'};
    } else {
      // Inserisci nuovo record
      final data = await _supabase.from('event_users').insert(userData).select();
      return {'success': true, 'data': data, 'message': 'Ospite aggiunto con successo'};
    }
  } catch (e) {
    _logger.severe('Errore aggiunta ospite: $e');
    return {'success': false, 'message': 'Errore: ${_getErrorMessage(e)}'};
  }
} 
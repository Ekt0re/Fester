import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'dart:developer';
import '../models/guest.dart';
import '../services/local_database_service.dart';
import '../services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Enhanced SyncService class with full Supabase integration
class SyncService {
  static Future<void> syncAllData() async {
    List<String> errors = [];
    bool hasSuccessfulOperation = false;
    
    try {
      // 1. Fetch latest guests from Supabase
      final supabase = SupabaseConfig.client;
      
      // Get last sync time or use a reasonable default (30 days ago)
      final lastSyncStr = LocalDatabaseService.getSetting<String>('last_sync_time');
      final lastSync = lastSyncStr != null 
          ? DateTime.tryParse(lastSyncStr) ?? DateTime.now().subtract(const Duration(days: 30))
          : DateTime.now().subtract(const Duration(days: 30));
      
      // Check if local cache is empty to decide sync strategy
      final localGuests = await LocalDatabaseService.getAllGuests();
      final isFirstSync = localGuests.isEmpty;
      
      // 2. Download updated guests from Supabase with error handling
      List<Guest> remoteGuests = [];
      try {
        PostgrestFilterBuilder<dynamic> query = supabase.from('guests').select();
        
        // If cache is empty or this is first sync, download all data
        if (isFirstSync) {
          log('Cache is empty - performing full sync from server');
          // No date filter - download everything
        } else {
          // Incremental sync - only get updated records
          query = query.gt('last_updated', lastSync.toIso8601String());
        }
        
        final response = await query;
        
        final List<dynamic> guestData = response;
        
        // Process each guest with individual error handling
        for (final json in guestData) {
          try {
            if (json != null && json is Map<String, dynamic>) {
              final guest = Guest.fromJson(json);
              remoteGuests.add(guest);
              hasSuccessfulOperation = true;
            }
          } catch (e) {
            errors.add('Error parsing guest: $e');
            // Continue with other guests instead of failing completely
            continue;
          }
        }
        
        if (isFirstSync) {
          log('Full sync: Downloaded ${remoteGuests.length} guests from server');
        } else {
          log('Incremental sync: Downloaded ${remoteGuests.length} updated guests');
        }
      } catch (e) {
        errors.add('Error fetching from Supabase: $e');
        // Don't throw here, continue with local data
      }
      
      // 3. Save remote guests to local database
      if (remoteGuests.isNotEmpty) {
        try {
          await LocalDatabaseService.saveGuests(remoteGuests);
          hasSuccessfulOperation = true;
        } catch (e) {
          errors.add('Error saving locally: $e');
          // Continue even if local save fails
        }
      }
      
      // 4. Upload local changes to Supabase (only if not first sync)
      if (!isFirstSync) {
        try {
          final currentLocalGuests = await LocalDatabaseService.getAllGuests();
          final recentLocalGuests = currentLocalGuests
              .where((guest) => guest.lastUpdated.isAfter(lastSync))
              .toList();
          
          // Upload modified local guests to Supabase
          int uploadCount = 0;
          for (final guest in recentLocalGuests) {
            try {
              await supabase
                  .from('guests')
                  .upsert(guest.toJson());
              uploadCount++;
              hasSuccessfulOperation = true;
            } catch (e) {
              errors.add('Error uploading guest ${guest.name}: $e');
              // Continue with other guests
              continue;
            }
          }
          
          if (uploadCount > 0) {
            log('Successfully uploaded $uploadCount guests');
          }
        } catch (e) {
          errors.add('Error during upload process: $e');
          // Don't throw, sync is partially successful
        }
      }
      
      // 5. Update last sync timestamp
      try {
        await LocalDatabaseService.saveSetting(
          'last_sync_time', 
          DateTime.now().toIso8601String()
        );
        hasSuccessfulOperation = true;
      } catch (e) {
        errors.add('Error updating sync timestamp: $e');
        // Non-critical error
      }
      
      // Log all errors for debugging but don't throw if we had some success
      if (errors.isNotEmpty) {
        log('Sync completed with ${errors.length} errors:');
        for (final error in errors) {
          log('  - $error');
        }
      }
      
      // Only throw if we had no successful operations at all
      if (!hasSuccessfulOperation && errors.isNotEmpty) {
        throw Exception('Sync completely failed: ${errors.first}');
      }
      
    } catch (e) {
      // Only throw if it's a critical error that prevents any sync
      log('Critical sync error: $e');
      throw Exception('Sync failed: $e');
    }
  }
  
  // New method for full sync from server (when cache is explicitly cleared)
  static Future<void> fullSyncFromServer() async {
    List<String> errors = [];
    bool hasSuccessfulOperation = false;
    
    try {
      log('Starting full sync from server...');
      final supabase = SupabaseConfig.client;
      
      // Clear existing cache first
      await LocalDatabaseService.clearGuestData();
      
      // Download ALL guests from Supabase
      List<Guest> allGuests = [];
      try {
        final response = await supabase.from('guests').select();
        
        final List<dynamic> guestData = response;
        
        for (final json in guestData) {
          try {
            if (json != null && json is Map<String, dynamic>) {
              final guest = Guest.fromJson(json);
              allGuests.add(guest);
              hasSuccessfulOperation = true;
            }
          } catch (e) {
            errors.add('Error parsing guest: $e');
            continue;
          }
        }
        
        log('Full sync: Downloaded ${allGuests.length} guests from server');
      } catch (e) {
        errors.add('Error fetching all guests from Supabase: $e');
        throw Exception('Failed to download data from server: $e');
      }
      
      // Save all guests to local database
      if (allGuests.isNotEmpty) {
        try {
          await LocalDatabaseService.saveGuests(allGuests);
          hasSuccessfulOperation = true;
          log('Successfully saved ${allGuests.length} guests to local cache');
        } catch (e) {
          errors.add('Error saving guests locally: $e');
          throw Exception('Failed to save data locally: $e');
        }
      }
      
      // Update sync timestamp
      try {
        await LocalDatabaseService.saveSetting(
          'last_sync_time', 
          DateTime.now().toIso8601String()
        );
        hasSuccessfulOperation = true;
      } catch (e) {
        errors.add('Error updating sync timestamp: $e');
      }
      
      if (errors.isNotEmpty) {
        log('Full sync completed with ${errors.length} warnings:');
        for (final error in errors) {
          log('  - $error');
        }
      }
      
      if (!hasSuccessfulOperation) {
        throw Exception('Full sync failed completely');
      }
      
      log('Full sync completed successfully!');
      
    } catch (e) {
      log('Full sync error: $e');
      throw Exception('Full sync failed: $e');
    }
  }
}

class GuestState {
  final List<Guest> guests;
  final bool isLoading;
  final String? error;
  final DateTime? lastSyncTime;
  final bool isSyncing;

  const GuestState({
    this.guests = const [],
    this.isLoading = false,
    this.error,
    this.lastSyncTime,
    this.isSyncing = false,
  });

  GuestState copyWith({
    List<Guest>? guests,
    bool? isLoading,
    String? error,
    DateTime? lastSyncTime,
    bool? isSyncing,
  }) {
    return GuestState(
      guests: guests ?? this.guests,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      isSyncing: isSyncing ?? this.isSyncing,
    );
  }

  // Helper getters per le statistiche
  List<Guest> get arrivedGuests => 
    guests.where((g) => g.status == GuestStatus.arrived).toList();
  
  List<Guest> get notArrivedGuests => 
    guests.where((g) => g.status == GuestStatus.notArrived).toList();
  
  List<Guest> get leftGuests => 
    guests.where((g) => g.status == GuestStatus.left).toList();

  int get totalDrinks => 
    guests.fold(0, (sum, guest) => sum + guest.drinksCount);
}

class GuestNotifier extends StateNotifier<GuestState> {
  Timer? _syncTimer;
  int _consecutiveFailures = 0;
  static const int _maxConsecutiveFailures = 3;
  
  GuestNotifier() : super(const GuestState()) {
    _loadLocalGuests();
    _startPeriodicSync();
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  void _startPeriodicSync() {
    // Sincronizzazione automatica ogni minuto
    _syncTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      // Se abbiamo troppi errori consecutivi, disabilita la sync automatica temporaneamente
      if (_consecutiveFailures >= _maxConsecutiveFailures) {
        log('Too many sync failures, skipping automatic sync. Failures: $_consecutiveFailures');
        return;
      }
      _backgroundSync();
    });
  }

  Future<void> _backgroundSync() async {
    if (state.isSyncing) return; // Evita sovrapposizioni
    
    try {
      state = state.copyWith(isSyncing: true);
      await SyncService.syncAllData();
      await _loadLocalGuests();
      
      // Reset counter on successful sync
      _consecutiveFailures = 0;
      
      // Clear any previous errors on successful sync
      if (state.error != null) {
        state = state.copyWith(error: null);
      }
    } catch (e) {
      // Increment failure counter
      _consecutiveFailures++;
      
      // Sync silenzioso in background - non mostrare errori all'utente
      log('Background sync failed (attempt $_consecutiveFailures/$_maxConsecutiveFailures): $e');
      // Non aggiornare l'errore UI per background sync
    } finally {
      state = state.copyWith(isSyncing: false);
    }
  }

  Future<void> _syncAfterAction() async {
    // Sincronizzazione immediata dopo ogni azione
    try {
      state = state.copyWith(isSyncing: true);
      await SyncService.syncAllData();
      await _loadLocalGuests();
      
      // Clear any previous errors on successful sync
      if (state.error != null) {
        state = state.copyWith(error: null);
      }
    } catch (e) {
      log('Post-action sync failed: $e');
      // Non mostrare errori per sync post-azione
    } finally {
      state = state.copyWith(isSyncing: false);
    }
  }

  Future<void> _loadLocalGuests() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final guests = await LocalDatabaseService.getAllGuests();
      final lastSyncStr = LocalDatabaseService.getSetting<String>('last_sync_time');
      final lastSync = lastSyncStr != null 
          ? DateTime.tryParse(lastSyncStr) 
          : null;
      
      state = state.copyWith(
        guests: guests,
        isLoading: false,
        lastSyncTime: lastSync,
      );
    } catch (e) {
      log('Error loading local guests: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Errore nel caricamento ospiti: $e',
      );
    }
  }

  Future<void> refreshGuests() async {
    await _loadLocalGuests();
  }

  Future<void> syncGuests() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await SyncService.syncAllData();
      await LocalDatabaseService.saveSetting('last_sync_time', DateTime.now().toIso8601String());
      await _loadLocalGuests();
    } catch (e) {
      log('Sync error: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Errore nella sincronizzazione: $e',
      );
    }
  }

  Future<void> forceSync() async {
    // Sincronizzazione forzata (es. quando si apre dashboard)
    state = state.copyWith(isSyncing: true, error: null);
    try {
      await SyncService.syncAllData();
      await _loadLocalGuests();
      
      // Reset failure counter on manual successful sync
      _consecutiveFailures = 0;
      
    } catch (e) {
      log('Force sync error: $e');
      state = state.copyWith(
        error: 'Errore nella sincronizzazione: $e',
      );
    } finally {
      state = state.copyWith(isSyncing: false);
    }
  }

  Future<void> fullSync() async {
    // Sincronizzazione completa - scarica tutti i dati dal server
    state = state.copyWith(isSyncing: true, error: null, isLoading: true);
    try {
      await SyncService.fullSyncFromServer();
      await _loadLocalGuests();
      
      // Reset failure counter on successful sync
      _consecutiveFailures = 0;
      
    } catch (e) {
      log('Full sync error: $e');
      state = state.copyWith(
        error: 'Errore nella sincronizzazione completa: $e',
      );
    } finally {
      state = state.copyWith(isSyncing: false, isLoading: false);
    }
  }

  Future<List<Guest>> searchGuests(String query) async {
    if (query.isEmpty) return state.guests;
    
    try {
      return await LocalDatabaseService.searchGuests(query);
    } catch (e) {
      state = state.copyWith(error: 'Errore nella ricerca: $e');
      return [];
    }
  }

  Future<Guest?> getGuestByCode(String code) async {
    try {
      final guests = await LocalDatabaseService.searchGuests(code);
      return guests.firstWhere(
        (guest) => guest.code.toLowerCase() == code.toLowerCase(),
        orElse: () => throw Exception('Ospite non trovato'),
      );
    } catch (e) {
      state = state.copyWith(error: 'Ospite non trovato');
      return null;
    }
  }

  Future<void> updateGuestStatus(String guestId, GuestStatus newStatus) async {
    try {
      final guestIndex = state.guests.indexWhere((g) => g.id == guestId);
      if (guestIndex == -1) {
        state = state.copyWith(error: 'Ospite non trovato');
        return;
      }

      final guest = state.guests[guestIndex];
      final updatedGuest = Guest(
        id: guest.id,
        name: guest.name,
        surname: guest.surname,
        code: guest.code,
        qrCode: guest.qrCode,
        barcode: guest.barcode,
        status: newStatus,
        drinksCount: guest.drinksCount,
        flags: guest.flags,
        invitedBy: guest.invitedBy,
        eventId: guest.eventId,
      );

      // Aggiorna localmente (Hive)
      await LocalDatabaseService.updateGuest(updatedGuest);

      // Aggiorna anche su Supabase
      await SupabaseConfig.client
          .from('guests')
          .update({
            'status': Guest.statusToDb(newStatus),
            'last_updated': DateTime.now().toIso8601String(),
          })
          .eq('id', guestId);

      final updatedGuests = List<Guest>.from(state.guests);
      updatedGuests[guestIndex] = updatedGuest;

      state = state.copyWith(guests: updatedGuests);
      
      // Sincronizza dopo l'azione
      _syncAfterAction();
    } catch (e) {
      state = state.copyWith(error: 'Errore nell\'aggiornamento: $e');
    }
  }

  Future<void> incrementDrinks(String guestId) async {
    try {
      final guestIndex = state.guests.indexWhere((g) => g.id == guestId);
      if (guestIndex == -1) {
        state = state.copyWith(error: 'Ospite non trovato');
        return;
      }

      final guest = state.guests[guestIndex];
      final newDrinksCount = guest.drinksCount + 1;
      final updatedGuest = Guest(
        id: guest.id,
        name: guest.name,
        surname: guest.surname,
        code: guest.code,
        qrCode: guest.qrCode,
        barcode: guest.barcode,
        status: guest.status,
        drinksCount: newDrinksCount,
        flags: guest.flags,
        invitedBy: guest.invitedBy,
        eventId: guest.eventId,
      );

      // Aggiorna localmente
      await LocalDatabaseService.updateGuest(updatedGuest);

      // Aggiorna Supabase
      await SupabaseConfig.client
          .from('guests')
          .update({
            'drinks_count': newDrinksCount,
            'last_updated': DateTime.now().toIso8601String(),
          })
          .eq('id', guestId);

      final updatedGuests = List<Guest>.from(state.guests);
      updatedGuests[guestIndex] = updatedGuest;

      state = state.copyWith(guests: updatedGuests);
      
      // Sincronizza dopo l'azione
      _syncAfterAction();
    } catch (e) {
      state = state.copyWith(error: 'Errore nell\'aggiornamento: $e');
    }
  }

  Future<void> decrementDrinks(String guestId) async {
    try {
      final guestIndex = state.guests.indexWhere((g) => g.id == guestId);
      if (guestIndex == -1) {
        state = state.copyWith(error: 'Ospite non trovato');
        return;
      }

      final guest = state.guests[guestIndex];
      if (guest.drinksCount <= 0) return; // Non può andare sotto zero
      
      final newDrinksCount = guest.drinksCount - 1;
      final updatedGuest = Guest(
        id: guest.id,
        name: guest.name,
        surname: guest.surname,
        code: guest.code,
        qrCode: guest.qrCode,
        barcode: guest.barcode,
        status: guest.status,
        drinksCount: newDrinksCount,
        flags: guest.flags,
        invitedBy: guest.invitedBy,
        eventId: guest.eventId,
      );

      // Aggiorna localmente
      await LocalDatabaseService.updateGuest(updatedGuest);

      // Aggiorna Supabase
      await SupabaseConfig.client
          .from('guests')
          .update({
            'drinks_count': newDrinksCount,
            'last_updated': DateTime.now().toIso8601String(),
          })
          .eq('id', guestId);

      final updatedGuests = List<Guest>.from(state.guests);
      updatedGuests[guestIndex] = updatedGuest;

      state = state.copyWith(guests: updatedGuests);
      
      // Sincronizza dopo l'azione
      _syncAfterAction();
    } catch (e) {
      state = state.copyWith(error: 'Errore nell\'aggiornamento: $e');
    }
  }

  Future<void> addFlag(String guestId, String flag) async {
    try {
      final guestIndex = state.guests.indexWhere((g) => g.id == guestId);
      if (guestIndex == -1) {
        state = state.copyWith(error: 'Ospite non trovato');
        return;
      }

      final guest = state.guests[guestIndex];
      final newFlags = List<String>.from(guest.flags);
      if (!newFlags.contains(flag)) {
        newFlags.add(flag);
      }

      final updatedGuest = Guest(
        id: guest.id,
        name: guest.name,
        surname: guest.surname,
        code: guest.code,
        qrCode: guest.qrCode,
        barcode: guest.barcode,
        status: guest.status,
        drinksCount: guest.drinksCount,
        flags: newFlags,
        invitedBy: guest.invitedBy,
        eventId: guest.eventId,
      );

      await LocalDatabaseService.updateGuest(updatedGuest);

      await SupabaseConfig.client
          .from('guests')
          .update({
            'flags': newFlags,
            'last_updated': DateTime.now().toIso8601String(),
          })
          .eq('id', guestId);

      final updatedGuests = List<Guest>.from(state.guests);
      updatedGuests[guestIndex] = updatedGuest;

      state = state.copyWith(guests: updatedGuests);
      
      // Sincronizza dopo l'azione
      _syncAfterAction();
    } catch (e) {
      state = state.copyWith(error: 'Errore nell\'aggiornamento: $e');
    }
  }

  Future<void> removeFlag(String guestId, String flag) async {
    try {
      final guestIndex = state.guests.indexWhere((g) => g.id == guestId);
      if (guestIndex == -1) {
        state = state.copyWith(error: 'Ospite non trovato');
        return;
      }

      final guest = state.guests[guestIndex];
      final newFlags = List<String>.from(guest.flags)..remove(flag);

      final updatedGuest = Guest(
        id: guest.id,
        name: guest.name,
        surname: guest.surname,
        code: guest.code,
        qrCode: guest.qrCode,
        barcode: guest.barcode,
        status: guest.status,
        drinksCount: guest.drinksCount,
        flags: newFlags,
        invitedBy: guest.invitedBy,
        eventId: guest.eventId,
      );

      await LocalDatabaseService.updateGuest(updatedGuest);

      await SupabaseConfig.client
          .from('guests')
          .update({
            'flags': newFlags,
            'last_updated': DateTime.now().toIso8601String(),
          })
          .eq('id', guestId);

      final updatedGuests = List<Guest>.from(state.guests);
      updatedGuests[guestIndex] = updatedGuest;

      state = state.copyWith(guests: updatedGuests);
      
      // Sincronizza dopo l'azione
      _syncAfterAction();
    } catch (e) {
      state = state.copyWith(error: 'Errore nell\'aggiornamento: $e');
    }
  }

  Future<void> addGuest(Guest guest) async {
    try {
      await LocalDatabaseService.updateGuest(guest);

      // Invia su Supabase
      await SupabaseConfig.client.from('guests').insert(guest.toJson());

      final updatedGuests = List<Guest>.from(state.guests);
      updatedGuests.add(guest);

      state = state.copyWith(guests: updatedGuests);
      
      // Sincronizza dopo l'azione
      _syncAfterAction();
    } catch (e) {
      state = state.copyWith(error: 'Errore nell\'aggiunta ospite: $e');
      rethrow;
    }
  }

  Future<void> updateGuest(Guest guest) async {
    try {
      await LocalDatabaseService.updateGuest(guest);

      await SupabaseConfig.client.from('guests').upsert(guest.toJson());

      final updatedGuests = List<Guest>.from(state.guests);
      final index = updatedGuests.indexWhere((g) => g.id == guest.id);

      if (index != -1) {
        updatedGuests[index] = guest;
      } else {
        updatedGuests.add(guest);
      }

      state = state.copyWith(guests: updatedGuests);
      
      // Sincronizza dopo l'azione
      _syncAfterAction();
    } catch (e) {
      state = state.copyWith(error: 'Errore nell\'aggiornamento ospite: $e');
      rethrow;
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final guestProvider = StateNotifierProvider<GuestNotifier, GuestState>((ref) {
  return GuestNotifier();
}); 
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:developer';
import '../models/guest.dart';
import '../models/event.dart';
import '../models/user.dart';
import '../models/app_settings.dart';

class LocalDatabaseService {
  static const String _guestBoxName = 'guests';
  static const String _eventBoxName = 'events';
  static const String _userBoxName = 'users';

  static Future<void> initializeHive() async {
    await Hive.initFlutter();

    // Register adapters for custom types
    Hive.registerAdapter(GuestAdapter());
    Hive.registerAdapter(EventAdapter());
    Hive.registerAdapter(UserAdapter());
    Hive.registerAdapter(UserRoleAdapter());
    Hive.registerAdapter(GuestStatusAdapter());
    Hive.registerAdapter(DatabaseModeAdapter());
    Hive.registerAdapter(AppSettingsAdapter());
  }

  static Future<Box<Guest>> openGuestBox() async {
    return await Hive.openBox<Guest>(_guestBoxName);
  }

  static Future<Box<Event>> openEventBox() async {
    return await Hive.openBox<Event>(_eventBoxName);
  }

  static Future<Box<User>> openUserBox() async {
    return await Hive.openBox<User>(_userBoxName);
  }

  static Future<Box> openSettingsBox() async {
    return await Hive.openBox('settings');
  }

  // Current user management
  static Future<void> saveCurrentUser(User user) async {
    final box = await openSettingsBox();
    await box.put('current_user', user.toJson());
  }

  static User? getCurrentUser() {
    try {
      final box = Hive.box('settings');
      final userData = box.get('current_user');
      if (userData != null) {
        return User.fromJson(Map<String, dynamic>.from(userData));
      }
      return null;
    } catch (e) {
      log('Error loading current user: $e');
      return null;
    }
  }

  static Future<void> clearCurrentUser() async {
    final box = await openSettingsBox();
    await box.delete('current_user');
  }

  // Guest management
  static Future<void> saveGuests(List<Guest> guests) async {
    final box = await openGuestBox();
    for (final guest in guests) {
      await box.put(guest.id, guest);
    }
  }

  static Future<List<Guest>> getAllGuests() async {
    try {
      final box = await openGuestBox();
      final guests = <Guest>[];
      
      for (final guest in box.values) {
        try {
          // Verifica che l'oggetto sia valido prima di aggiungerlo alla lista
          if (guest.id.isNotEmpty) {
            guests.add(guest);
          }
        } catch (e) {
          log('Error loading individual guest: $e');
          // Continua con gli altri ospiti
        }
      }
      
      return guests;
    } catch (e) {
      log('Error loading guests from Hive: $e');
      // Ritorna lista vuota invece di lanciare eccezione
      return <Guest>[];
    }
  }

  static Future<Guest?> getGuestById(String id) async {
    final box = await openGuestBox();
    return box.get(id);
  }

  static Future<List<Guest>> searchGuests(String query) async {
    final box = await openGuestBox();
    final guests = box.values.toList();
    final lowercaseQuery = query.toLowerCase();
    
    return guests.where((guest) =>
      guest.name.toLowerCase().contains(lowercaseQuery) ||
      guest.surname.toLowerCase().contains(lowercaseQuery) ||
      guest.code.toLowerCase().contains(lowercaseQuery) ||
      guest.qrCode.toLowerCase().contains(lowercaseQuery) ||
      guest.barcode.toLowerCase().contains(lowercaseQuery)
    ).toList();
  }

  static Future<List<Guest>> searchGuestsByCode(String code) async {
    final box = await openGuestBox();
    final guests = box.values.toList();
    final lowercaseCode = code.toLowerCase();
    
    return guests.where((guest) =>
      guest.qrCode.toLowerCase() == lowercaseCode ||
      guest.code.toLowerCase() == lowercaseCode ||
      guest.barcode.toLowerCase() == lowercaseCode
    ).toList();
  }

  static Future<void> updateGuest(Guest guest) async {
    final box = await openGuestBox();
    final updatedGuest = Guest(
      id: guest.id,
      name: guest.name,
      surname: guest.surname,
      code: guest.code,
      qrCode: guest.qrCode,
      barcode: guest.barcode,
      status: guest.status,
      drinksCount: guest.drinksCount,
      flags: guest.flags,
      invitedBy: guest.invitedBy,
      eventId: guest.eventId,
      lastUpdated: DateTime.now(),
    );
    await box.put(guest.id, updatedGuest);
  }

  // Settings management
  static Future<void> saveSetting(String key, dynamic value) async {
    final box = await openSettingsBox();
    await box.put(key, value);
  }

  static T? getSetting<T>(String key, {T? defaultValue}) {
    final box = Hive.box('settings');
    return box.get(key, defaultValue: defaultValue) as T?;
  }

  // App Settings management
  static Future<void> saveAppSettings(AppSettings settings) async {
    final box = await openSettingsBox();
    await box.put('app_settings', settings.toJson());
  }

  static AppSettings? getAppSettings() {
    final box = Hive.box('settings');
    final settingsData = box.get('app_settings');
    if (settingsData != null) {
      return AppSettings.fromJson(Map<String, dynamic>.from(settingsData));
    }
    return null;
  }

  // Cleanup methods
  static Future<void> closeAllBoxes() async {
    await Hive.close();
  }

  static Future<void> clearAllData() async {
    await Hive.deleteFromDisk();
    await initializeHive();
  }

  static Future<void> clearGuestData() async {
    final box = await openGuestBox();
    await box.clear();
  }
}

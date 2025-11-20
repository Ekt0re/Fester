import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';

/// Servizio per gestire il salvataggio e caricamento delle impostazioni dell'app
class SettingsService {
  static const String _settingsKey = 'app_settings';
  
  /// Carica le impostazioni salvate
  Future<AppSettings> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_settingsKey);
      
      if (jsonString == null) {
        return AppSettings.defaultSettings;
      }
      
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return AppSettings.fromJson(json);
    } catch (e) {
      print('Errore caricamento impostazioni: $e');
      return AppSettings.defaultSettings;
    }
  }
  
  /// Salva le impostazioni
  Future<void> saveSettings(AppSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(settings.toJson());
      await prefs.setString(_settingsKey, jsonString);
    } catch (e) {
      print('Errore salvataggio impostazioni: $e');
      rethrow;
    }
  }
  
  /// Resetta le impostazioni ai valori di default
  Future<void> resetSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_settingsKey);
    } catch (e) {
      print('Errore reset impostazioni: $e');
      rethrow;
    }
  }
}

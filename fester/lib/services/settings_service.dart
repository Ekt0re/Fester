import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';
import '../models/custom_theme.dart';

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
      debugPrint('Errore caricamento impostazioni: $e');
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
      debugPrint('Errore salvataggio impostazioni: $e');
      rethrow;
    }
  }

  /// Resetta le impostazioni ai valori di default
  Future<void> resetSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_settingsKey);
    } catch (e) {
      debugPrint('Errore reset impostazioni: $e');
      rethrow;
    }
  }

  static const String _customThemesKey = 'custom_themes';

  /// Carica i temi personalizzati salvati
  Future<List<CustomTheme>> loadCustomThemes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStringList = prefs.getStringList(_customThemesKey);

      if (jsonStringList == null) {
        return [];
      }

      return jsonStringList
          .map((jsonString) {
            try {
              return CustomTheme.fromJson(jsonDecode(jsonString));
            } catch (e) {
              debugPrint('Error parsing custom theme: $e');
              return null;
            }
          })
          .whereType<CustomTheme>()
          .toList();
    } catch (e) {
      debugPrint('Errore caricamento temi personalizzati: $e');
      return [];
    }
  }

  /// Salva tutti i temi personalizzati
  Future<void> saveCustomThemes(List<CustomTheme> themes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStringList =
          themes.map((theme) => jsonEncode(theme.toJson())).toList();
      await prefs.setStringList(_customThemesKey, jsonStringList);
    } catch (e) {
      debugPrint('Errore salvataggio temi personalizzati: $e');
      rethrow;
    }
  }

  /// Aggiunge un tema personalizzato
  Future<void> addCustomTheme(CustomTheme theme) async {
    final themes = await loadCustomThemes();
    // Rimuovi se esiste già (aggiornamento)
    themes.removeWhere((t) => t.id == theme.id);
    themes.add(theme);
    await saveCustomThemes(themes);
  }

  /// Rimuove un tema personalizzato
  Future<void> removeCustomTheme(String themeId) async {
    final themes = await loadCustomThemes();
    themes.removeWhere((t) => t.id == themeId);
    await saveCustomThemes(themes);
  }
}

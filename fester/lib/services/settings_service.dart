import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'logger_service.dart';
import '../models/app_settings.dart';
import '../models/custom_theme.dart';

/// Servizio per gestire il salvataggio e caricamento delle impostazioni dell'app
class SettingsService {
  static const String _settingsKey = 'app_settings';
  static const String _tag = 'SettingsService';

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
      LoggerService.error(
        'Errore caricamento impostazioni',
        tag: _tag,
        error: e,
      );
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
      LoggerService.error(
        'Errore salvataggio impostazioni',
        tag: _tag,
        error: e,
      );
      rethrow;
    }
  }

  /// Resetta le impostazioni ai valori di default
  Future<void> resetSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_settingsKey);
    } catch (e) {
      LoggerService.error('Errore reset impostazioni', tag: _tag, error: e);
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
              LoggerService.warning(
                'Error parsing custom theme',
                tag: _tag,
                error: e,
              );
              return null;
            }
          })
          .whereType<CustomTheme>()
          .toList();
    } catch (e) {
      LoggerService.error(
        'Errore caricamento temi personalizzati',
        tag: _tag,
        error: e,
      );
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
      LoggerService.error(
        'Errore salvataggio temi personalizzati',
        tag: _tag,
        error: e,
      );
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

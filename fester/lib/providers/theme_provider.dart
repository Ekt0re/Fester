import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../services/settings_service.dart';

/// Provider per gestire il tema dell'applicazione
class ThemeProvider extends ChangeNotifier {
  final SettingsService _settingsService = SettingsService();
  ThemeMode _themeMode = ThemeMode.system;
  
  ThemeMode get themeMode => _themeMode;
  
  ThemeProvider() {
    _loadTheme();
  }
  
  Future<void> _loadTheme() async {
    final settings = await _settingsService.loadSettings();
    _themeMode = settings.themeMode;
    notifyListeners();
  }
  
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    
    // Salva nelle impostazioni
    final settings = await _settingsService.loadSettings();
    await _settingsService.saveSettings(settings.copyWith(themeMode: mode));
  }
  
  Future<void> toggleTheme() async {
    final newMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(newMode);
  }
}

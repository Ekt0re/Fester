import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../models/custom_theme.dart';
import '../theme/app_theme.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  final SettingsService _settingsService = SettingsService();

  List<CustomTheme> _customThemes = [];
  String? _selectedCustomThemeId;

  ThemeMode get themeMode {
    if (_selectedCustomThemeId != null) {
      // If a custom theme is selected, we force usage of the light theme slot
      // which will contain our custom theme data.
      // We could also check customTheme.isDark and force ThemeMode.dark if we put it in darkTheme slot,
      // but putting it in light slot and forcing light mode is easier.
      return ThemeMode.light;
    }
    return _themeMode;
  }

  // Expose the raw preference for UI selectors
  ThemeMode get preferredThemeMode => _themeMode;

  List<CustomTheme> get customThemes => _customThemes;
  String? get selectedCustomThemeId => _selectedCustomThemeId;

  ThemeData get lightTheme {
    if (_selectedCustomThemeId != null) {
      final customTheme = _customThemes.firstWhere(
        (t) => t.id == _selectedCustomThemeId,
        orElse:
            () =>
                _customThemes
                    .first, // Fallback if ID not found, logic should prevent this
      );
      // Ensure we return a valid custom theme data
      // If for some reason lookup fails (deleted?), fallback to default
      try {
        if (_customThemes.any((t) => t.id == _selectedCustomThemeId)) {
          return customTheme.toThemeData();
        }
      } catch (e) {
        // Fallback
      }
    }
    return AppTheme.lightTheme;
  }

  ThemeData get darkTheme {
    // If a custom theme is selected, we could return it here too if we wanted to support system toggle with custom themes,
    // but typically a custom theme defines its own brightness.
    // Since we force ThemeMode.light when custom theme is active, this might not be used,
    // BUT to be safe we can return default dark theme.
    return AppTheme.darkTheme;
  }

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final settings = await _settingsService.loadSettings();
      _themeMode = settings.themeMode;
      _selectedCustomThemeId = settings.customThemeId;
      _customThemes = await _settingsService.loadCustomThemes();

      // Validation: if selected custom theme doesn't exist, clear selection
      if (_selectedCustomThemeId != null &&
          !_customThemes.any((t) => t.id == _selectedCustomThemeId)) {
        _selectedCustomThemeId = null;
        // Optionally save this correction?
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading theme: $e');
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    _selectedCustomThemeId =
        null; // Clear custom theme when standard mode selected
    notifyListeners();
    await _saveSettings();
  }

  Future<void> selectCustomTheme(String themeId) async {
    if (_customThemes.any((t) => t.id == themeId)) {
      _selectedCustomThemeId = themeId;
      notifyListeners();
      await _saveSettings();
    }
  }

  // Helper to save current state
  Future<void> _saveSettings() async {
    try {
      final currentSettings = await _settingsService.loadSettings();
      final newSettings = currentSettings.copyWith(
        themeMode: _themeMode,
        customThemeId: _selectedCustomThemeId, // Can be null
      );
      await _settingsService.saveSettings(newSettings);
    } catch (e) {
      debugPrint('Error saving theme settings: $e');
    }
  }

  Future<void> addCustomTheme(CustomTheme theme) async {
    await _settingsService.addCustomTheme(theme);
    _customThemes = await _settingsService.loadCustomThemes();
    notifyListeners();
  }

  Future<void> updateCustomTheme(CustomTheme theme) async {
    await _settingsService.addCustomTheme(
      theme,
    ); // add handles update/overwrite
    _customThemes = await _settingsService.loadCustomThemes();
    notifyListeners();
  }

  Future<void> deleteCustomTheme(String themeId) async {
    await _settingsService.removeCustomTheme(themeId);
    _customThemes = await _settingsService.loadCustomThemes();

    if (_selectedCustomThemeId == themeId) {
      _selectedCustomThemeId = null;
      _themeMode = ThemeMode.system; // Revert to system
      await _saveSettings();
    }
    notifyListeners();
  }
}

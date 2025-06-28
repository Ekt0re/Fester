import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_settings.dart';
import '../services/local_database_service.dart';

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(AppSettings()) {
    _loadSettings();
  }

  void _loadSettings() {
    try {
      final savedSettings = LocalDatabaseService.getAppSettings();
      if (savedSettings != null) {
        state = savedSettings;
      }
    } catch (e) {
      // Se non ci sono impostazioni salvate, usa i default
      state = AppSettings();
    }
  }

  Future<void> updateDatabaseMode(DatabaseMode mode) async {
    final newSettings = state.copyWith(databaseMode: mode);
    await _saveSettings(newSettings);
    state = newSettings;
  }

  Future<void> updateMongoDbConfig({
    String? host,
    int? port,
  }) async {
    final newSettings = state.copyWith(
      mongoDbHost: host ?? state.mongoDbHost,
      mongoDbPort: port ?? state.mongoDbPort,
    );
    await _saveSettings(newSettings);
    state = newSettings;
  }

  Future<void> updateAuthToken(String? token) async {
    final newSettings = state.copyWith(jwtToken: token);
    await _saveSettings(newSettings);
    state = newSettings;
  }

  Future<void> toggleRealAuth(bool useReal) async {
    final newSettings = state.copyWith(useRealAuth: useReal);
    await _saveSettings(newSettings);
    state = newSettings;
  }

  Future<void> updateLastSyncTime(String timestamp) async {
    final newSettings = state.copyWith(lastSyncTime: timestamp);
    await _saveSettings(newSettings);
    state = newSettings;
  }

  Future<void> _saveSettings(AppSettings settings) async {
    await LocalDatabaseService.saveAppSettings(settings);
  }

  Future<void> resetToDefaults() async {
    final defaultSettings = AppSettings();
    await _saveSettings(defaultSettings);
    state = defaultSettings;
  }

  // Helper getters
  bool get isUsingSupabase => state.databaseMode == DatabaseMode.supabase;
  bool get isUsingMongoDB => state.databaseMode == DatabaseMode.mongodb;
  String get currentConnectionString => 
      isUsingSupabase ? 'Supabase Cloud' : state.mongoConnectionString;
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
}); 
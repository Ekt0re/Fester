import 'package:flutter/material.dart';

class LocalizationConfig {
  static const List<Map<String, dynamic>> supportedLanguages = [
    {'code': 'it', 'name': 'Italiano', 'flag': '🇮🇹', 'countryCode': 'IT'},
    {'code': 'en', 'name': 'English', 'flag': '🇬🇧', 'countryCode': 'US'},
    {'code': 'de', 'name': 'Deutsch', 'flag': '🇩🇪', 'countryCode': 'DE'},
    {'code': 'es', 'name': 'Español', 'flag': '🇪🇸', 'countryCode': 'ES'},
    {'code': 'fr', 'name': 'Français', 'flag': '🇫🇷', 'countryCode': 'FR'},
    {'code': 'zh', 'name': '中文', 'flag': '🇨🇳', 'countryCode': 'CN'},
  ];

  static const String path = 'assets/translations';

  static const Locale fallbackLocale = Locale('en', 'US');

  static List<Locale> get supportedLocales {
    return supportedLanguages.map((lang) {
      return Locale(lang['code'], lang['countryCode']);
    }).toList();
  }

  static String getLanguageName(String code) {
    final language = supportedLanguages.firstWhere(
      (lang) => lang['code'] == code,
      orElse: () => {'name': 'Unknown'},
    );
    return language['name'];
  }

  static String getLanguageFlag(String code) {
    final language = supportedLanguages.firstWhere(
      (lang) => lang['code'] == code,
      orElse: () => {'flag': '🏳️'},
    );
    return language['flag'];
  }
}

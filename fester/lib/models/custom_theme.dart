import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CustomTheme {
  final String id;
  String name;
  bool isDark;
  int primaryColor;
  int secondaryColor;
  int backgroundColor;
  int surfaceColor;
  int errorColor;
  int textColor;

  CustomTheme({
    required this.id,
    required this.name,
    required this.isDark,
    required this.primaryColor,
    required this.secondaryColor,
    required this.backgroundColor,
    required this.surfaceColor,
    required this.errorColor,
    required this.textColor,
  });

  factory CustomTheme.fromJson(Map<String, dynamic> json) {
    return CustomTheme(
      id: json['id'] as String,
      name: json['name'] as String,
      isDark: json['isDark'] as bool,
      primaryColor: json['primaryColor'] as int,
      secondaryColor: json['secondaryColor'] as int,
      backgroundColor: json['backgroundColor'] as int,
      surfaceColor: json['surfaceColor'] as int,
      errorColor: json['errorColor'] as int,
      textColor: json['textColor'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'isDark': isDark,
      'primaryColor': primaryColor,
      'secondaryColor': secondaryColor,
      'backgroundColor': backgroundColor,
      'surfaceColor': surfaceColor,
      'errorColor': errorColor,
      'textColor': textColor,
    };
  }

  CustomTheme copyWith({
    String? id,
    String? name,
    bool? isDark,
    int? primaryColor,
    int? secondaryColor,
    int? backgroundColor,
    int? surfaceColor,
    int? errorColor,
    int? textColor,
  }) {
    return CustomTheme(
      id: id ?? this.id,
      name: name ?? this.name,
      isDark: isDark ?? this.isDark,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      surfaceColor: surfaceColor ?? this.surfaceColor,
      errorColor: errorColor ?? this.errorColor,
      textColor: textColor ?? this.textColor,
    );
  }

  ThemeData toThemeData() {
    return AppTheme.createTheme(
      isDark: isDark,
      primary: Color(primaryColor),
      secondary: Color(secondaryColor),
      background: Color(backgroundColor),
      surface: Color(surfaceColor),
      error: Color(errorColor),
      text: Color(textColor),
    );
  }
}

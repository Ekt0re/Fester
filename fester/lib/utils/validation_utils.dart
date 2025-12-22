// lib/utils/validation_utils.dart

class FormValidator {
  /// Valida se l'email è nel formato corretto
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'validation.email_required';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'validation.invalid_email';
    }
    return null;
  }

  /// Valida la lunghezza minima della password
  static String? validatePassword(String? value, {int minLength = 6}) {
    if (value == null || value.isEmpty) {
      return 'validation.password_required';
    }
    if (value.length < minLength) {
      return 'validation.password_too_short';
    }
    return null;
  }

  /// Valida che il campo non sia vuoto
  static String? validateRequired(String? value, String fieldNameKey) {
    if (value == null || value.trim().isEmpty) {
      return 'validation.field_required';
    }
    return null;
  }

  /// Valida il formato del numero di telefono (semplice)
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) return null; // Opzionale
    final phoneRegex = RegExp(r'^\+?[0-9]{8,15}$');
    if (!phoneRegex.hasMatch(value)) {
      return 'validation.invalid_phone';
    }
    return null;
  }
}

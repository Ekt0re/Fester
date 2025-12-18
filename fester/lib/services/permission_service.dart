class PermissionService {
  /// Staff 1: Sola lettura.
  /// Staff 2: Modifica ma non eliminazione.
  /// Staff 3/Admin: Accesso completo.

  static bool canAdd(String? role) {
    if (role == null) return false;
    final r = role.toLowerCase();
    return r == 'admin' || r == 'staff3' || r == 'staff2';
  }

  static bool canEdit(String? role) {
    if (role == null) return false;
    final r = role.toLowerCase();
    return r == 'admin' || r == 'staff3' || r == 'staff2';
  }

  static bool canDelete(String? role) {
    if (role == null) return false;
    final r = role.toLowerCase();
    return r == 'admin' || r == 'staff3';
  }

  static bool isReadOnly(String? role) {
    if (role == null) return true;
    final r = role.toLowerCase();
    return r == 'staff1';
  }
}

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
    final r = role?.toLowerCase();
    return r == 'admin' || r == 'staff3';
  }

  static bool canManageSmtp(String? role) {
    final r = role?.toLowerCase();
    return r == 'admin' || r == 'staff3';
  }

  static bool canCheckIn(String? role) {
    final r = role?.toLowerCase();
    // Tutti i ruoli staff e admin possono fare check-in
    return r == 'admin' || r == 'staff3' || r == 'staff2' || r == 'staff1';
  }

  static bool canAddTransaction(String? role) {
    final r = role?.toLowerCase();
    // Tutti i ruoli staff e admin possono aggiungere transazioni (drink/food)
    return r == 'admin' || r == 'staff3' || r == 'staff2' || r == 'staff1';
  }

  static bool isReadOnly(String? role) {
    if (role == null) return true;
    final r = role.toLowerCase();
    return r == 'staff1';
  }
}

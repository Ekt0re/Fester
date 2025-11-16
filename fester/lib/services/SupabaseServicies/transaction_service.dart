// lib/services/transaction_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/transaction.dart';

class TransactionService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get all transactions for a participation
  Future<List<Map<String, dynamic>>> getParticipationTransactions(
    String participationId,
  ) async {
    try {
      final response = await _supabase
          .from('transaction')
          .select('''
            *,
            transaction_type:transaction_type_id(name, description, affects_drink_count, is_monetary),
            menu_item:menu_item_id(name, price),
            created_by_user:created_by(first_name, last_name)
          ''')
          .eq('participation_id', participationId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Create transaction
  Future<Transaction> createTransaction({
    required String participationId,
    required int transactionTypeId,
    String? menuItemId,
    String? name,
    String? description,
    double? amount,
    int? quantity,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response =
          await _supabase
              .from('transaction')
              .insert({
                'participation_id': participationId,
                'transaction_type_id': transactionTypeId,
                'menu_item_id': menuItemId,
                'name': name,
                'description': description,
                'amount': amount ?? 0.0,
                'quantity': quantity ?? 1,
                'created_by': userId,
              })
              .select()
              .single();

      return Transaction.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Update transaction
  Future<Transaction> updateTransaction({
    required String transactionId,
    int? quantity,
    double? amount,
    String? description,
  }) async {
    try {
      final updates = <String, dynamic>{};

      if (quantity != null) updates['quantity'] = quantity;
      if (amount != null) updates['amount'] = amount;
      if (description != null) updates['description'] = description;

      final response =
          await _supabase
              .from('transaction')
              .update(updates)
              .eq('id', transactionId)
              .select()
              .single();

      return Transaction.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Delete transaction
  Future<void> deleteTransaction(String transactionId) async {
    try {
      await _supabase.from('transaction').delete().eq('id', transactionId);
    } catch (e) {
      rethrow;
    }
  }

  /// Get transaction summary for event
  Future<Map<String, dynamic>> getEventTransactionSummary(
    String eventId,
  ) async {
    try {
      // This would require a custom RPC function or complex query
      // For now, returning a placeholder
      return {'total_amount': 0.0, 'total_drinks': 0, 'total_transactions': 0};
    } catch (e) {
      rethrow;
    }
  }

  /// Stream transactions for a participation (real-time)
  Stream<List<Map<String, dynamic>>> streamParticipationTransactions(
    String participationId,
  ) {
    return _supabase
        .from('transaction')
        .stream(primaryKey: ['id'])
        .eq('participation_id', participationId)
        .order('created_at', ascending: false)
        .map((data) => List<Map<String, dynamic>>.from(data));
  }
}

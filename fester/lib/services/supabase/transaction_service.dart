// lib/services/transaction_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'models/transaction.dart';
import '../notification_service.dart';

class TransactionService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final NotificationService _notificationService = NotificationService();

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

      // Check and send notifications
      await _checkAndSendNotifications(
        participationId: participationId,
        transactionTypeId: transactionTypeId,
        name: name,
      );

      return Transaction.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Check and send notifications based on transaction
  Future<void> _checkAndSendNotifications({
    required String participationId,
    required int transactionTypeId,
    String? name,
  }) async {
    try {
      // Fetch participation with disambiguated person relationship
      final participation =
          await _supabase
              .from('participation')
              .select(
                'event_id, drink_count, person!inner!participation_person_id_fkey(id, first_name, last_name)',
              )
              .eq('id', participationId)
              .single();

      final String eventId = participation['event_id'] as String;
      final int drinkCount = participation['drink_count'] ?? 0;
      final person = participation['person'];
      final String personId = person['id'] as String;
      final String personName =
          '${person['first_name'] ?? ''} ${person['last_name'] ?? ''}'.trim();

      // Get transaction type info
      final transactionType =
          await _supabase
              .from('transaction_type')
              .select('name, affects_drink_count')
              .eq('id', transactionTypeId)
              .single();

      final String typeName = (transactionType['name'] as String).toLowerCase();
      final bool affectsDrinkCount =
          transactionType['affects_drink_count'] ?? false;

      // Warning notifications (fine, sanction, report)
      if (typeName == 'fine' ||
          typeName == 'sanction' ||
          typeName == 'report') {
        await _notificationService.notifyWarningReceived(
          eventId: eventId,
          personName: personName,
          personId: personId,
          reason: name ?? typeName,
        );
      }

      // Drink limit exceeded notifications
      if (affectsDrinkCount) {
        final eventSettings =
            await _supabase
                .from('event_settings')
                .select('default_max_drinks_per_person')
                .eq('event_id', eventId)
                .maybeSingle();

        if (eventSettings != null) {
          final maxDrinks = eventSettings['default_max_drinks_per_person'];
          if (maxDrinks != null && drinkCount >= maxDrinks) {
            await _notificationService.notifyDrinkLimitExceeded(
              eventId: eventId,
              personName: personName,
              personId: personId,
              drinkCount: drinkCount,
              limit: maxDrinks,
            );
          }
        }
      }
    } catch (e) {
      // Log silently, don't break transaction creation
      debugPrint('Error checking notifications: $e');
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
      // Placeholder implementation
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

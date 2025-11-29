import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ExportService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<XFile> exportData({
    required String eventId,
    required String eventName,
    required String format, // 'csv', 'excel', 'pdf'
    // Flags
    bool includeEventInfo = false,
    bool includeEventSettings = false,
    bool includeEventStats = false,
    bool includePersonName = false,
    bool includePersonEmail = false,
    bool includePersonPhone = false,
    bool includePersonBirthDate = false,
    bool includePersonImage = false,
    bool includePersonNotes = false,
    bool includeParticipationId = false,
    bool includeParticipationStatus = false,
    bool includeParticipationTimestamps = false,
    bool includeParticipationReferrer = false,
    bool includeParticipationGuests = false,
    bool includeParticipationTable = false,
    bool includeTransactionHistory = false,
    bool includeTransactionDetails = false,
    bool includeTransactionStaff = false,
    bool includeTransactionSummary = false,
    bool includeTransactionBalance = false,
    bool includeEventStaffList = false,
    bool includeEventStaffDetails = false,
    bool includeEventStaffRoles = false,
    bool includeEventStaffContacts = false,
    bool includeGroupsList = false,
    bool includeGroupsMembers = false,
    bool includeSubgroups = false,
    bool includeGroupsHierarchy = false,
    bool includeMenuItems = false,
    bool includeMenuStats = false,
    bool includeMenuAlcoholic = false,
  }) async {
    final pdf = pw.Document();
    // 1. Fetch Data (per future use)
    await _fetchData(
      eventId: eventId,
      includeEventInfo:
          includeEventInfo || includeEventSettings || includeEventStats,
      includeParticipants:
          includePersonName ||
          includePersonEmail ||
          includePersonPhone ||
          includePersonBirthDate ||
          includePersonImage ||
          includePersonNotes ||
          includeParticipationId ||
          includeParticipationStatus ||
          includeParticipationTimestamps ||
          includeParticipationReferrer ||
          includeParticipationGuests ||
          includeParticipationTable,
      includeTransactions:
          includeTransactionHistory ||
          includeTransactionDetails ||
          includeTransactionStaff ||
          includeTransactionSummary ||
          includeTransactionBalance,
      includeStaff:
          includeEventStaffList ||
          includeEventStaffDetails ||
          includeEventStaffRoles ||
          includeEventStaffContacts,
      includeGroups:
          includeGroupsList ||
          includeGroupsMembers ||
          includeSubgroups ||
          includeGroupsHierarchy,
      includeMenu: includeMenuItems || includeMenuStats || includeMenuAlcoholic,
    );

    // 2. Generate File
    // 2. Generate File
    final String timestamp = DateFormat(
      'yyyyMMdd_HHmmss',
    ).format(DateTime.now());
    final String fileName =
        'Export_${eventName.replaceAll(' ', '_')}_$timestamp';

    final bytes = await pdf.save();
    return XFile.fromData(
      bytes,
      mimeType: 'application/pdf',
      name: '$fileName.pdf',
    );
  }

  Future<Map<String, dynamic>> _fetchData({
    required String eventId,
    required bool includeEventInfo,
    required bool includeParticipants,
    required bool includeTransactions,
    required bool includeStaff,
    required bool includeGroups,
    required bool includeMenu,
  }) async {
    final Map<String, dynamic> result = {};

    try {
      if (includeEventInfo) {
        final eventData =
            await _supabase.from('event').select().eq('id', eventId).single();
        result['event'] = eventData;
      }

      if (includeParticipants) {
        final participantsData = await _supabase
            .from('participation')
            .select('*, person(*)')
            .eq('event_id', eventId);
        result['participants'] = participantsData;
      }

      if (includeTransactions) {
        final transactionsData = await _supabase
            .from('transaction')
            .select('*, staff(*)')
            .eq('event_id', eventId);
        result['transactions'] = transactionsData;
      }

      if (includeStaff) {
        final staffData = await _supabase
            .from('event_staff')
            .select('*, staff(*)')
            .eq('event_id', eventId);
        result['staff'] = staffData;
      }

      if (includeGroups) {
        // Fetch groups if needed, assuming a 'groups' table or similar structure exists
        // For now, we'll just return an empty list if the table structure isn't fully known or simple
        // Adjust this based on actual schema if 'groups' table exists
        try {
          final groupsData = await _supabase
              .from('group') // Assuming table name is 'group'
              .select()
              .eq('event_id', eventId);
          result['groups'] = groupsData;
        } catch (_) {
          // Ignore if table doesn't exist or other error
          result['groups'] = [];
        }
      }

      if (includeMenu) {
        final menuData =
            await _supabase
                .from('menu')
                .select('*, menu_item(*)')
                .eq('event_id', eventId)
                .maybeSingle();
        result['menu'] = menuData;
      }
    } catch (e) {
      debugPrint('Error fetching export data: $e');
    }

    return result;
  }
}

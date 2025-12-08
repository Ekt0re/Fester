import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
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
    // 1. Fetch Data
    final data = await _fetchData(
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
    final String timestamp = DateFormat(
      'yyyyMMdd_HHmmss',
    ).format(DateTime.now());
    final String fileName =
        'Export_${eventName.replaceAll(' ', '_')}_$timestamp';

    if (format == 'csv') {
      final bytes = _generateCsv(data);
      return XFile.fromData(bytes, mimeType: 'text/csv', name: '$fileName.csv');
    } else if (format == 'excel') {
      final bytes = _generateExcel(data);
      return XFile.fromData(
        bytes,
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        name: '$fileName.xlsx',
      );
    } else {
      // PDF fallback placeholder
      final pdf = pw.Document();
      // ... pdf generation logic ...
      final bytes = await pdf.save();
      return XFile.fromData(
        bytes,
        mimeType: 'application/pdf',
        name: '$fileName.pdf',
      );
    }
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
            await _supabase
                .from('event')
                .select('*, event_settings(*)')
                .eq('id', eventId)
                .single();
        result['event'] = eventData;
      }

      // Always fetch participants if groups are needed (for aggregation fallback)
      if (includeParticipants || includeGroups) {
        final participantsData = await _supabase
            .from('participation')
            .select('*, person:person!participation_person_id_fkey(*)')
            .eq('event_id', eventId);
        result['participants'] = participantsData;
      }

      if (includeTransactions) {
        final transactionsData = await _supabase
            .from('transaction')
            .select('*, participation!inner(event_id), staff_user(*)')
            .eq('participation.event_id', eventId);
        result['transactions'] = transactionsData;
      }

      if (includeStaff) {
        final staffData = await _supabase
            .from('event_staff')
            .select('*, staff_user!event_staff_staff_user_id_fkey(*)')
            .eq('event_id', eventId);
        result['staff'] = staffData;
      }

      if (includeGroups) {
        try {
          final groupsData = await _supabase
              .from('gruppo')
              .select()
              .eq('event_id', eventId);
          result['groups'] = groupsData;
        } catch (_) {
          result['groups'] = [];
        }
      }

      if (includeMenu) {
        final menuData =
            await _supabase
                .from('menu')
                .select('*, menu_item(*, transaction_type(*))')
                .eq('event_id', eventId)
                .maybeSingle();
        result['menu'] = menuData;
      }
    } catch (e) {
      debugPrint('Error fetching export data: $e');
      rethrow;
    }

    return result;
  }

  Uint8List _generateCsv(Map<String, dynamic> data) {
    List<List<dynamic>> rows = [];

    // --- Event Info Section ---
    if (data.containsKey('event')) {
      final e = data['event'];
      final s = e['event_settings'] ?? {};
      rows.add(['--- EVENTO ---']);
      rows.add(['ID', 'Nome', 'Descrizione', 'Data Inizio', 'Luogo']);
      rows.add([
        e['id'],
        e['name'],
        e['description'],
        s['start_at'] ?? e['created_at'],
        s['location'] ?? '',
      ]);
      rows.add([]);
    }

    // --- Participants to Groups Aggregation Helpers ---
    Map<String, int> groupCounts = {};
    if (data.containsKey('participants')) {
      final participants = data['participants'] as List;
      for (var p in participants) {
        final person = p['person'] ?? {};
        final gName = person['gruppo']?.toString();
        if (gName != null && gName.isNotEmpty) {
          groupCounts[gName] = (groupCounts[gName] ?? 0) + 1;
        }
      }
    }

    // --- Participants Section ---
    if (data.containsKey('participants')) {
      rows.add(['--- PARTECIPANTI ---']);
      rows.add([
        'ID',
        'Nome',
        'Cognome',
        'Email',
        'Telefono',
        'Data Nascita',
        'Stato',
        'Ospiti Aggiunti',
        'Referrer',
        'Tavolo',
        'Gruppo',
        'Note',
      ]);

      final participants = data['participants'] as List;
      for (var p in participants) {
        final person = p['person'] ?? {};
        rows.add([
          p['id'],
          person['first_name'],
          person['last_name'],
          person['email'],
          person['phone'],
          person['birth_date'],
          p['status_id'],
          p['guests_count'],
          p['invited_by'],
          p['table'],
          person['gruppo'],
          person['notes'],
        ]);
      }
      rows.add([]);
    }

    // --- Groups Section ---
    if (data.containsKey('groups')) {
      rows.add(['--- GRUPPI ---']);
      rows.add(['Nome', 'Membri']);

      final dbGroups = data['groups'] as List? ?? [];
      if (dbGroups.isNotEmpty) {
        for (var g in dbGroups) {
          rows.add([g['name'], g['members_count'] ?? 0]);
        }
      } else {
        groupCounts.forEach((name, count) {
          rows.add([name, count]);
        });
      }
      rows.add([]);
    }

    // --- Transactions Section ---
    if (data.containsKey('transactions')) {
      rows.add(['--- TRANSAZIONI ---']);
      rows.add(['ID', 'Importo', 'Tipo', 'Note', 'Data', 'Staff']);
      final transactions = data['transactions'] as List;
      for (var t in transactions) {
        final staff = t['staff_user'] ?? {};
        rows.add([
          t['id'],
          t['amount'],
          t['name'] ?? t['type'],
          t['notes'],
          t['created_at'],
          '${staff['first_name'] ?? ''} ${staff['last_name'] ?? ''}'.trim(),
        ]);
      }
      rows.add([]);
    }

    // --- Menu Section ---
    if (data.containsKey('menu') && data['menu'] != null) {
      rows.add(['--- MENU ---']);
      rows.add([
        'Nome',
        'Prezzo',
        'Categoria',
        'Descrizione',
        'Consumazione Drink',
        'Monetario',
      ]);
      final menu = data['menu'];
      final items = menu['menu_item'] as List? ?? [];
      for (var i in items) {
        final tType = i['transaction_type'] ?? {};
        rows.add([
          i['name'],
          i['price'],
          tType['name'] ?? '',
          i['description'],
          (tType['affects_drink_count'] == true) ? 'Sì' : 'No',
          (tType['is_monetary'] == true) ? 'Sì' : 'No',
        ]);
      }
      rows.add([]);
    }

    // --- Staff Section ---
    if (data.containsKey('staff')) {
      rows.add(['--- STAFF ---']);
      rows.add(['Nome', 'Cognome', 'Ruolo', 'Email', 'Telefono']);
      final staffList = data['staff'] as List;
      for (var s in staffList) {
        final user = s['staff_user'] ?? {};
        final firstName = user['first_name']?.toString() ?? '';
        final lastName = user['last_name']?.toString() ?? '';
        final displayName =
            (firstName.isEmpty && lastName.isEmpty) ? '(In Attesa)' : firstName;

        String role = '${s['role_id']}';
        if (s['role_id'] == 1) role = 'Admin (1)';

        rows.add([displayName, lastName, role, user['email'], user['phone']]);
      }
      rows.add([]);
    }

    final csvString = const ListToCsvConverter().convert(rows);
    return Uint8List.fromList(utf8.encode(csvString));
  }

  Uint8List _generateExcel(Map<String, dynamic> data) {
    var excel = Excel.createExcel();

    // Event Info
    if (data.containsKey('event')) {
      Sheet sheet = excel['Evento'];
      final e = data['event'];
      final s = e['event_settings'] ?? {};

      sheet.appendRow([
        TextCellValue('ID'),
        TextCellValue('Nome'),
        TextCellValue('Descrizione'),
        TextCellValue('Data Inizio'),
        TextCellValue('Luogo'),
      ]);
      sheet.appendRow([
        TextCellValue(e['id']?.toString() ?? ''),
        TextCellValue(e['name']?.toString() ?? ''),
        TextCellValue(e['description']?.toString() ?? ''),
        TextCellValue(
          s['start_at']?.toString() ?? e['created_at']?.toString() ?? '',
        ),
        TextCellValue(s['location']?.toString() ?? ''),
      ]);
    }

    // Aggregation for Groups
    Map<String, int> groupCounts = {};
    if (data.containsKey('participants')) {
      final participants = data['participants'] as List;
      for (var p in participants) {
        final person = p['person'] ?? {};
        final gName = person['gruppo']?.toString();
        if (gName != null && gName.isNotEmpty) {
          groupCounts[gName] = (groupCounts[gName] ?? 0) + 1;
        }
      }
    }

    // Partecipanti
    if (data.containsKey('participants')) {
      Sheet sheet = excel['Partecipanti'];
      sheet.appendRow([
        TextCellValue('ID'),
        TextCellValue('Nome'),
        TextCellValue('Cognome'),
        TextCellValue('Email'),
        TextCellValue('Telefono'),
        TextCellValue('Data Nascita'),
        TextCellValue('Stato'),
        TextCellValue('Gruppo'),
        TextCellValue('Ospiti'),
        TextCellValue('Referrer'),
        TextCellValue('Tavolo'),
        TextCellValue('Note'),
      ]);

      final participants = data['participants'] as List;
      for (var p in participants) {
        final person = p['person'] ?? {};
        sheet.appendRow([
          TextCellValue(p['id']?.toString() ?? ''),
          TextCellValue(person['first_name']?.toString() ?? ''),
          TextCellValue(person['last_name']?.toString() ?? ''),
          TextCellValue(person['email']?.toString() ?? ''),
          TextCellValue(person['phone']?.toString() ?? ''),
          TextCellValue(person['birth_date']?.toString() ?? ''),
          IntCellValue(p['status_id'] ?? 0),
          TextCellValue(person['gruppo']?.toString() ?? ''),
          IntCellValue(p['guests_count'] ?? 0),
          TextCellValue(p['invited_by']?.toString() ?? ''),
          TextCellValue(p['table']?.toString() ?? ''),
          TextCellValue(person['notes']?.toString() ?? ''),
        ]);
      }
    }

    // Gruppi
    if (data.containsKey('groups')) {
      Sheet sheet = excel['Gruppi'];
      sheet.appendRow([TextCellValue('Nome'), TextCellValue('Membri')]);

      final dbGroups = data['groups'] as List? ?? [];
      if (dbGroups.isNotEmpty) {
        for (var g in dbGroups) {
          sheet.appendRow([
            TextCellValue(g['name']?.toString() ?? ''),
            IntCellValue(g['members_count'] ?? 0),
          ]);
        }
      } else {
        if (groupCounts.isEmpty) {
          sheet.appendRow([
            TextCellValue('Nessun gruppo trovato'),
            IntCellValue(0),
          ]);
        } else {
          groupCounts.forEach((name, count) {
            sheet.appendRow([TextCellValue(name), IntCellValue(count)]);
          });
        }
      }
    }

    // Transazioni
    if (data.containsKey('transactions')) {
      Sheet sheet = excel['Transazioni'];
      sheet.appendRow([
        TextCellValue('ID'),
        TextCellValue('Importo'),
        TextCellValue('Tipo'),
        TextCellValue('Data'),
        TextCellValue('Note'),
        TextCellValue('Staff'),
      ]);
      final transactions = data['transactions'] as List;
      for (var t in transactions) {
        final staff = t['staff_user'] ?? {};
        sheet.appendRow([
          TextCellValue(t['id']?.toString() ?? ''),
          DoubleCellValue((t['amount'] as num?)?.toDouble() ?? 0.0),
          TextCellValue(t['name']?.toString() ?? t['type']?.toString() ?? ''),
          TextCellValue(t['created_at']?.toString() ?? ''),
          TextCellValue(t['notes']?.toString() ?? ''),
          TextCellValue(
            '${staff['first_name'] ?? ''} ${staff['last_name'] ?? ''}',
          ),
        ]);
      }
    }

    // Menu
    if (data.containsKey('menu') && data['menu'] != null) {
      Sheet sheet = excel['Menu'];
      sheet.appendRow([
        TextCellValue('Nome'),
        TextCellValue('Prezzo'),
        TextCellValue('Categoria'),
        TextCellValue('Descrizione'),
        TextCellValue('Consumazione Drink'),
        TextCellValue('Monetario'),
      ]);
      final menu = data['menu'];
      final items = menu['menu_item'] as List? ?? [];
      for (var i in items) {
        final tType = i['transaction_type'] ?? {};
        sheet.appendRow([
          TextCellValue(i['name']?.toString() ?? ''),
          DoubleCellValue((i['price'] as num?)?.toDouble() ?? 0.0),
          TextCellValue(tType['name']?.toString() ?? ''),
          TextCellValue(i['description']?.toString() ?? ''),
          TextCellValue((tType['affects_drink_count'] == true) ? 'Sì' : 'No'),
          TextCellValue((tType['is_monetary'] == true) ? 'Sì' : 'No'),
        ]);
      }
    }

    // Staff
    if (data.containsKey('staff')) {
      Sheet sheet = excel['Staff'];
      sheet.appendRow([
        TextCellValue('Nome'),
        TextCellValue('Cognome'),
        TextCellValue('Ruolo'),
        TextCellValue('Email'),
        TextCellValue('Telefono'),
      ]);
      final staffList = data['staff'] as List;
      for (var s in staffList) {
        final user = s['staff_user'] ?? {};
        final firstName = user['first_name']?.toString() ?? '';
        final lastName = user['last_name']?.toString() ?? '';
        final displayName =
            (firstName.isEmpty && lastName.isEmpty) ? '(In Attesa)' : firstName;

        String role = '${s['role_id']}';
        if (s['role_id'] == 1) role = 'Admin (1)';

        sheet.appendRow([
          TextCellValue(displayName),
          TextCellValue(lastName),
          TextCellValue(role),
          TextCellValue(user['email']?.toString() ?? ''),
          TextCellValue(user['phone']?.toString() ?? ''),
        ]);
      }
    }

    if (excel.sheets.length > 1) {
      excel.delete('Sheet1');
    }

    return Uint8List.fromList(excel.save()!);
  }
}

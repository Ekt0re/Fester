import 'dart:io';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';

class BulkImportService {
  /// Parses a file and returns a list of rows (`List<dynamic>`).
  /// The first row is usually headers.
  Future<List<List<dynamic>>> parseFile(PlatformFile file) async {
    final extension = file.extension?.toLowerCase();
    List<int> bytes;

    if (file.bytes != null) {
      bytes = file.bytes!;
    } else if (file.path != null) {
      bytes = await File(file.path!).readAsBytes();
    } else {
      throw Exception('File content unavailable');
    }

    if (extension == 'csv') {
      return _parseCsvBytes(bytes);
    } else if (extension == 'xlsx' || extension == 'xls') {
      return _parseExcelBytes(bytes);
    } else {
      throw Exception('Unsupported file format: $extension');
    }
  }

  Future<List<List<dynamic>>> _parseCsvBytes(List<int> bytes) async {
    final content = utf8.decode(bytes);
    return const CsvToListConverter().convert(content);
  }

  Future<List<List<dynamic>>> _parseExcelBytes(List<int> bytes) async {
    final excel = Excel.decodeBytes(bytes);

    // Assuming data is in the first sheet
    if (excel.tables.isEmpty) return [];
    final table = excel.tables[excel.tables.keys.first];
    if (table == null) return [];

    return table.rows.map((row) {
      return row.map((cell) => cell?.value?.toString() ?? '').toList();
    }).toList();
  }

  /// Maps raw rows to structured data based on column mapping.
  /// [rows]: The raw data including headers.
  /// [mapping]: Map where key is the internal field name (e.g., 'first_name') and value is the column index/name.
  List<Map<String, dynamic>> mapData(
    List<List<dynamic>> rows,
    Map<String, int> mapping,
  ) {
    if (rows.isEmpty) return [];

    // Skip header row usually, handled by caller by passing rows.sublist(1) or similar logic is safer
    // But here we assume caller passes data rows only or handles it.
    // Let's assume input is DATA ONLY.

    final result = <Map<String, dynamic>>[];

    for (var row in rows) {
      final entry = <String, dynamic>{};
      mapping.forEach((key, colIndex) {
        if (colIndex < row.length) {
          entry[key] = row[colIndex];
        }
      });
      result.add(entry);
    }
    return result;
  }

  // Define available fields for mapping
  static const Map<String, String> availableFields = {
    'first_name': 'Nome (Richiesto)',
    'last_name': 'Cognome (Richiesto)',
    'email': 'Email',
    'phone': 'Telefono',
    'birth_date': 'Data Nascita',
    'codice_fiscale': 'Codice Fiscale',
    'indirizzo': 'Indirizzo',
  };
}

import 'dart:convert';
import 'package:http/http.dart' as http;

class OverpassService {
  static const String _baseUrl = 'https://overpass-api.de/api/interpreter';

  /// Searches for POIs around a specific location
  /// [category] corresponds to the "amenity" tag in OSM (e.g., 'bar', 'restaurant', 'parking')
  /// [radius] is in meters (default 1000m)
  Future<List<Map<String, dynamic>>> searchNearby({
    required double lat,
    required double lon,
    required String category,
    double radius = 1000,
  }) async {
    // Construct the Overpass QL query
    // We look for both nodes and ways (areas) with the given amenity tag
    // [out:json]; ensures JSON output
    final query = '''
      [out:json][timeout:25];
      (
        node["amenity"="$category"](around:$radius,$lat,$lon);
        way["amenity"="$category"](around:$radius,$lat,$lon);
      );
      out center;
    ''';

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          // Good practice to set a User-Agent for OSM services
          'User-Agent': 'FesterApp/1.0',
        },
        body: 'data=$query',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final elements = data['elements'] as List<dynamic>;

        return elements
            .map<Map<String, dynamic>>((e) {
              // Flatten data to a consistent structure
              // "ways" might have "center", "nodes" have "lat"/"lon" directly
              final validLat = e['lat'] ?? e['center']?['lat'];
              final validLon = e['lon'] ?? e['center']?['lon'];

              if (validLat == null || validLon == null) return {};

              return {
                'id': e['id'],
                'type': e['type'],
                'lat': validLat,
                'lon': validLon,
                'name': e['tags']?['name'] ?? 'Unknown',
                'amenity': e['tags']?['amenity'],
                'address': _formatAddress(e['tags']),
              };
            })
            .where((e) => e.isNotEmpty && e['name'] != 'Unknown')
            .toList();
      } else {
        throw Exception('Overpass API error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to fetch POIs: $e');
    }
  }

  /// Searches for POIs within a specific bounding box
  /// [south], [west], [north], [east] define the visible map area
  Future<List<Map<String, dynamic>>> searchInBounds({
    required double south,
    required double west,
    required double north,
    required double east,
    required String category,
  }) async {
    // [bbox] header is global filter for the query
    // [timeout:60] increases default timeout to handle larger areas
    final query = '''
      [out:json][timeout:60][bbox:$south,$west,$north,$east];
      (
        node["amenity"="$category"];
        way["amenity"="$category"];
      );
      out center;
    ''';

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': 'FesterApp/1.0',
        },
        body: 'data=$query',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final elements = data['elements'] as List<dynamic>;

        return elements
            .map<Map<String, dynamic>>((e) {
              final validLat = e['lat'] ?? e['center']?['lat'];
              final validLon = e['lon'] ?? e['center']?['lon'];

              if (validLat == null || validLon == null) return {};

              return {
                'id': e['id'],
                'type': e['type'],
                'lat': validLat,
                'lon': validLon,
                'name': e['tags']?['name'] ?? 'Unknown',
                'amenity': e['tags']?['amenity'],
                'address': _formatAddress(e['tags']),
              };
            })
            .where((e) => e.isNotEmpty && e['name'] != 'Unknown')
            .toList();
      } else {
        if (response.statusCode == 429) {
          throw Exception('Too many requests. Please wait a moment.');
        } else if (response.statusCode == 504) {
          throw Exception('Area too large. Please zoom in.');
        }
        throw Exception('Overpass API error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to fetch POIs: $e');
    }
  }

  /// Helper to create a readable address string from OSM tags
  String _formatAddress(Map<String, dynamic>? tags) {
    if (tags == null) return '';
    final street = tags['addr:street'] ?? '';
    final number = tags['addr:housenumber'] ?? '';
    final city = tags['addr:city'] ?? '';

    if (street.isEmpty) return city;
    return '$street $number, $city'.trim();
  }
}

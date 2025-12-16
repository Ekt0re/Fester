import 'package:latlong2/latlong.dart';

class LocationHelper {
  static const String posTagStart = '[POS]';
  static const String posTagEnd = '[/POS]';
  static const String nameTagStart = '[NAME]';
  static const String nameTagEnd = '[/NAME]';

  /// Parses a location string and returns the name part.
  /// Format: [POS]lat,lng[/POS][NAME]Place Name[/NAME]
  /// Or just a plain string.
  static String getName(String? location) {
    if (location == null || location.isEmpty) return '';

    final nameRegex = RegExp(r'\[NAME\](.*?)\[/NAME\]');
    final match = nameRegex.firstMatch(location);
    if (match != null) {
      return match.group(1) ?? '';
    }

    // Fallback: remove POS tags if present and return valid remainder, or just the string
    final posRegex = RegExp(r'\[POS\].*?\[/POS\]');
    return location.replaceAll(posRegex, '').trim();
  }

  /// Parses a location string and returns the LatLng if present.
  static LatLng? getCoordinates(String? location) {
    if (location == null || location.isEmpty) return null;

    final posRegex = RegExp(r'\[POS\](.*?)\[/POS\]');
    final match = posRegex.firstMatch(location);

    if (match != null) {
      try {
        final coordsStr = match.group(1);
        if (coordsStr != null) {
          final parts = coordsStr.split(',');
          if (parts.length == 2) {
            return LatLng(double.parse(parts[0]), double.parse(parts[1]));
          }
        }
      } catch (e) {
        // parsing error
      }
    }
    return null;
  }

  /// Formats name and coordinates into the storage string.
  static String formatLocation(String name, LatLng? coords) {
    String result = '';
    if (coords != null) {
      result += '$posTagStart${coords.latitude},${coords.longitude}$posTagEnd';
    }
    if (name.isNotEmpty) {
      // If we have tags in the name (user typed them?), strip them to avoid corruption,
      // though unlikely.
      final cleanName = name
          .replaceAll(posTagStart, '')
          .replaceAll(posTagEnd, '')
          .replaceAll(nameTagStart, '')
          .replaceAll(nameTagEnd, '');

      // If we have coords, we MUST use tags for name to be consistent with the "variant 2"
      // If we don't have coords, user says "variant 1 is normal string".
      // However, to keep it consistent, if we have coords, we usually wrap the name.

      if (coords != null) {
        result += '$nameTagStart$cleanName$nameTagEnd';
      } else {
        // Variant 1: Normal string (no tags)
        return cleanName;
      }
    } else {
      // Coords but no name?
      // The requirement says: [POS]lat,lng[/POS][NAME]Place Name[/NAME]
      // If name is empty but coords exist, maybe just return coords part + empty name tags?
      if (coords != null) {
        result += '$nameTagStart$nameTagEnd';
      }
    }

    return result;
  }
}

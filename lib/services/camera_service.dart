import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

/// Servizio per gestire la disponibilità della fotocamera e delle piattaforme
class CameraService {
  static CameraService? _instance;
  
  CameraService._();
  
  static CameraService get instance {
    _instance ??= CameraService._();
    return _instance!;
  }

  /// Verifica se la piattaforma supporta la scansione QR
  bool get isPlatformSupported {
    if (kIsWeb) {
      return true; // Web è supportato da mobile_scanner 5.2.3
    }
    
    if (!kIsWeb) {
      try {
        // Android, iOS, macOS sono supportati
        return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
      } catch (e) {
        // Se Platform non è disponibile (web), restituisce false
        return false;
      }
    }
    
    return false;
  }

  /// Verifica se la fotocamera è probabilmente disponibile
  bool get isCameraLikelyAvailable {
    // Su piattaforme mobili e web, assumiamo che la fotocamera sia disponibile
    if (kIsWeb) return true;
    
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        return true; // Mobile devices usually have cameras
      }
      if (Platform.isMacOS) {
        return true; // Most Macs have built-in cameras
      }
      return false; // Windows/Linux desktop unlikely to have cameras
    } catch (e) {
      return kIsWeb; // Fallback to web check
    }
  }

  /// Verifica se Windows è la piattaforma corrente
  bool get isWindows {
    if (kIsWeb) return false;
    try {
      return Platform.isWindows;
    } catch (e) {
      return false;
    }
  }

  /// Verifica se Linux è la piattaforma corrente
  bool get isLinux {
    if (kIsWeb) return false;
    try {
      return Platform.isLinux;
    } catch (e) {
      return false;
    }
  }

  /// Verifica se è una piattaforma desktop non supportata
  bool get isUnsupportedDesktop {
    return isWindows || isLinux;
  }

  /// Messaggio informativo sul supporto della piattaforma
  String get platformSupportMessage {
    if (kIsWeb) {
      return 'Web: Scanner QR disponibile con webcam';
    }
    
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        return 'Mobile: Scanner QR completamente supportato';
      }
      if (Platform.isMacOS) {
        return 'macOS: Scanner QR supportato con fotocamera integrata';
      }
      if (Platform.isWindows) {
        return 'Windows: Solo inserimento manuale codici';
      }
      if (Platform.isLinux) {
        return 'Linux: Solo inserimento manuale codici';
      }
    } catch (e) {
      // Fallback se Platform non è disponibile
    }
    
    return 'Piattaforma non riconosciuta';
  }

  /// Mostra se la fotocamera dovrebbe essere disponibile teoricamente
  bool get shouldHaveCamera {
    if (kIsWeb) {
      return true; // Assumiamo che la maggior parte dei dispositivi web abbiano webcam
    }
    
    if (!kIsWeb) {
      try {
        // Mobile e alcuni desktop hanno fotocamera
        return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
      } catch (e) {
        return false;
      }
    }
    
    return false;
  }

  /// Messaggio informativo sulla disponibilità della fotocamera
  String get cameraAvailabilityMessage {
    if (!isPlatformSupported) {
      return 'Scanner non supportato su questa piattaforma';
    }
    
    if (kIsWeb) {
      return 'Richiede accesso alla webcam del browser';
    }
    
    return 'Scanner fotocamera disponibile';
  }
} 
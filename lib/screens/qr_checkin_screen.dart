import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../providers/guest_provider.dart';
import '../services/supabase_service.dart';
import '../services/camera_service.dart';
import '../utils/app_colors.dart';
import '../models/guest.dart';

class QRCheckInScreen extends ConsumerStatefulWidget {
  const QRCheckInScreen({super.key});

  @override
  ConsumerState<QRCheckInScreen> createState() => _QRCheckInScreenState();
}

class _QRCheckInScreenState extends ConsumerState<QRCheckInScreen> {
  final supabase = SupabaseConfig.client;
  final manualController = TextEditingController();
  final CameraService _cameraService = CameraService.instance;
  bool isProcessing = false;
  String statusMessage = '';
  MobileScannerController? cameraController;

  @override
  void initState() {
    super.initState();
    
    // Inizializza il controller solo se la piattaforma è supportata
    if (_cameraService.isPlatformSupported) {
      cameraController = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        facing: CameraFacing.back,
        torchEnabled: false,
      );
    }
  }

  @override
  void dispose() {
    manualController.dispose();
    cameraController?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (isProcessing) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String? code = barcodes.first.rawValue;
      if (code != null && code.isNotEmpty) {
        _processCheckIn(code.trim());
      }
    }
  }

  Future<void> _processCheckIn(String code) async {
    if (isProcessing) return;
    
    setState(() {
      isProcessing = true;
      statusMessage = 'Elaborazione check-in...';
    });

    try {
      // Cerca l'ospite nel provider
      final guestNotifier = ref.read(guestProvider.notifier);
      final guests = ref.read(guestProvider).guests;
      
      // Prima prova con il codice come guest code
      Guest? guest;
      try {
        guest = guests.firstWhere((g) => g.code == code);
      } catch (_) {
        // Se non trovato, prova con QR code
        try {
          guest = guests.firstWhere((g) => g.qrCode == code);
        } catch (_) {
          // Se non trovato, prova con barcode
          try {
            guest = guests.firstWhere((g) => g.barcode == code);
          } catch (_) {
            guest = null;
          }
        }
      }

      if (guest != null) {
        if (guest.status == GuestStatus.arrived) {
          setState(() {
            statusMessage = '⚠️ ${guest!.name} ${guest.surname} è già arrivato';
          });
        } else {
          // Effettua il check-in
          await guestNotifier.updateGuestStatus(guest.id, GuestStatus.arrived);
          
          setState(() {
            statusMessage = '✅ Check-in completato per ${guest!.name} ${guest.surname}';
          });
        }
      } else {
        setState(() {
          statusMessage = '❌ Ospite non trovato con codice: $code';
        });
      }
    } catch (e) {
      setState(() {
        statusMessage = '❌ Errore durante il check-in: $e';
      });
    } finally {
      setState(() => isProcessing = false);
      
      // Reset del messaggio dopo 3 secondi
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() => statusMessage = '');
        }
      });
    }
  }

  Future<void> _manualCheckIn() async {
    final code = manualController.text.trim();
    if (code.isNotEmpty) {
      manualController.clear();
      await _processCheckIn(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Check-In'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Scanner o messaggio per piattaforme non supportate
          Expanded(
            flex: 3,
            child: _cameraService.isPlatformSupported && cameraController != null
                ? _buildScannerSection()
                : _buildUnsupportedSection(),
          ),
          
          // Sezione inserimento manuale
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Inserimento Manuale',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: manualController,
                        decoration: InputDecoration(
                          hintText: 'Inserisci codice ospite, QR o barcode',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.edit),
                        ),
                        onSubmitted: (_) => _manualCheckIn(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: isProcessing ? null : _manualCheckIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Icon(Icons.check),
                    ),
                  ],
                ),
                
                if (statusMessage.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: statusMessage.startsWith('✅') 
                          ? AppColors.success.withAlpha(25)
                          : statusMessage.startsWith('⚠️')
                              ? AppColors.warning.withAlpha(25)
                              : AppColors.error.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: statusMessage.startsWith('✅') 
                            ? AppColors.success.withAlpha(100)
                            : statusMessage.startsWith('⚠️')
                                ? AppColors.warning.withAlpha(100)
                                : AppColors.error.withAlpha(100),
                      ),
                    ),
                    child: Text(
                      statusMessage,
                      style: TextStyle(
                        color: statusMessage.startsWith('✅') 
                            ? AppColors.success
                            : statusMessage.startsWith('⚠️')
                                ? AppColors.warning
                                : AppColors.error,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerSection() {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // Scanner
          MobileScanner(
            controller: cameraController,
            onDetect: _onDetect,
          ),
          
          // Overlay
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.accent,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          
          // Istruzioni
          Positioned(
            top: 40,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(178),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Scansiona il codice QR dell\'ospite per il check-in',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          
          if (isProcessing)
            Container(
              color: Colors.black.withAlpha(127),
              child: const Center(
                child: CircularProgressIndicator(
                  color: AppColors.accent,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUnsupportedSection() {
    return Container(
      color: AppColors.background,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.accent.withAlpha(25),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.accent.withAlpha(100)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.info_outline,
                  color: AppColors.accent,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _cameraService.cameraAvailabilityMessage,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.accent.withAlpha(200),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 
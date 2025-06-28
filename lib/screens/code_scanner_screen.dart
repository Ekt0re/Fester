import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../utils/app_colors.dart';
import '../services/camera_service.dart';

/// Screen che usa la fotocamera (o webcam) per leggere QR-Code / Barcode.
/// Ritorna il codice letto con `Navigator.pop(context, code)`.
class CodeScannerScreen extends StatefulWidget {
  const CodeScannerScreen({super.key});

  @override
  State<CodeScannerScreen> createState() => _CodeScannerScreenState();
}

class _CodeScannerScreenState extends State<CodeScannerScreen> {
  MobileScannerController? cameraController;
  bool _isProcessing = false;
  bool _isFlashOn = false;
  final CameraService _cameraService = CameraService.instance;
  String? _errorMessage;

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
    } else {
      _errorMessage = _cameraService.platformSupportMessage;
    }
  }

  @override
  void dispose() {
    cameraController?.dispose();
    super.dispose();
  }

  void _foundBarcode(BarcodeCapture capture) {
    if (_isProcessing) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    
    if (barcodes.isNotEmpty) {
      _isProcessing = true;
      final String code = barcodes.first.rawValue ?? '';
      
      if (code.isNotEmpty) {
        // Feedback tattile
        HapticFeedback.vibrate();
        
        // Ritorna il codice scansionato
        Navigator.of(context).pop(code);
      } else {
        _isProcessing = false;
      }
    }
  }

  void _toggleFlash() {
    if (cameraController != null) {
      setState(() => _isFlashOn = !_isFlashOn);
      cameraController!.toggleTorch();
    }
  }

  void _switchCamera() {
    if (cameraController != null) {
      cameraController!.switchCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scansiona Codice'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_cameraService.isPlatformSupported && cameraController != null) ...[
            // Flash toggle
            IconButton(
              icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off),
              onPressed: _toggleFlash,
              color: _isFlashOn ? Colors.yellow : Colors.white,
            ),
            // Camera switch
            IconButton(
              icon: const Icon(Icons.flip_camera_android),
              onPressed: _switchCamera,
              color: Colors.white,
            ),
          ],
        ],
      ),
      body: _cameraService.isPlatformSupported && cameraController != null
          ? _buildScannerView()
          : _buildUnsupportedView(),
    );
  }

  Widget _buildScannerView() {
    return Stack(
      children: [
        // Camera preview
        MobileScanner(
          controller: cameraController,
          onDetect: _foundBarcode,
        ),
        
        // Overlay with scan area
        _buildScanOverlay(),
        
        // Instructions
        Positioned(
          bottom: 100,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(178),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.qr_code_scanner,
                  color: Colors.white,
                  size: 32,
                ),
                SizedBox(height: 8),
                Text(
                  'Posiziona il codice QR o barcode\nnell\'area di scansione',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScanOverlay() {
    return Center(
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
        child: Stack(
          children: [
            // Corner indicators
            ...List.generate(4, (index) {
              return Positioned(
                top: index < 2 ? 0 : null,
                bottom: index >= 2 ? 0 : null,
                left: index % 2 == 0 ? 0 : null,
                right: index % 2 == 1 ? 0 : null,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.only(
                      topLeft: index == 0 ? const Radius.circular(16) : Radius.zero,
                      topRight: index == 1 ? const Radius.circular(16) : Radius.zero,
                      bottomLeft: index == 2 ? const Radius.circular(16) : Radius.zero,
                      bottomRight: index == 3 ? const Radius.circular(16) : Radius.zero,
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildUnsupportedView() {
    return Container(
      color: AppColors.background,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.warning.withAlpha(25),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.warning.withAlpha(100)),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.camera_alt_outlined,
                      size: 64,
                      color: AppColors.warning,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Scanner non disponibile',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.warning,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage ?? _cameraService.platformSupportMessage,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Torna Indietro'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 
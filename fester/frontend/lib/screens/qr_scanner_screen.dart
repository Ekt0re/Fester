import 'package:flutter/material.dart';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScannerScreen extends StatefulWidget {
  final String eventId;

  const QrScannerScreen({Key? key, required this.eventId}) : super(key: key);

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final dio = Dio();
  final secureStorage = const FlutterSecureStorage();
  final String apiBaseUrl = 'http://localhost:5000/api';
  
  final MobileScannerController controller = MobileScannerController();
  bool isProcessing = false;
  String? scanResult;
  String? errorMessage;
  bool isSuccess = false;
  
  Timer? _resetTimer;
  
  @override
  void initState() {
    super.initState();
    _setupDioHeaders();
  }
  
  @override
  void dispose() {
    controller.dispose();
    _resetTimer?.cancel();
    super.dispose();
  }
  
  Future<void> _setupDioHeaders() async {
    final token = await secureStorage.read(key: 'auth_token');
    if (token != null) {
      dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }
  
  Future<void> _processQrCode(String code) async {
    if (isProcessing) return;
    
    setState(() {
      isProcessing = true;
      scanResult = code;
      errorMessage = null;
      isSuccess = false;
    });
    
    try {
      final response = await dio.post(
        '$apiBaseUrl/events/${widget.eventId}/checkin',
        data: {'qr_code': code},
      );
      
      if (response.statusCode == 200) {
        final guestData = response.data['data'];
        setState(() {
          isSuccess = true;
          scanResult = '${guestData['nome']} ${guestData['cognome']} ha effettuato il check-in con successo!';
        });
      } else {
        setState(() {
          isSuccess = false;
          errorMessage = 'Errore durante il check-in';
        });
      }
    } catch (e) {
      setState(() {
        isSuccess = false;
        if (e is DioException && e.response?.statusCode == 404) {
          errorMessage = 'QR Code non valido o ospite non trovato';
        } else if (e is DioException && e.response?.statusCode == 409) {
          errorMessage = 'L\'ospite ha già effettuato il check-in';
        } else {
          errorMessage = 'Errore: ${e.toString()}';
        }
      });
    } finally {
      // Reset after 3 seconds
      _resetTimer?.cancel();
      _resetTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            isProcessing = false;
            scanResult = null;
            errorMessage = null;
          });
          controller.start();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: controller.torchState,
              builder: (context, state, child) {
                return Icon(
                  state == TorchState.on ? Icons.flash_on : Icons.flash_off,
                );
              },
            ),
            onPressed: () => controller.toggleTorch(),
          ),
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: controller.cameraFacingState,
              builder: (context, state, child) {
                return Icon(
                  state == CameraFacing.front
                      ? Icons.camera_front
                      : Icons.camera_rear,
                );
              },
            ),
            onPressed: () => controller.switchCamera(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: isProcessing
                ? _buildScanResult()
                : _buildScanner(),
          ),
          Expanded(
            flex: 1,
            child: _buildInstructions(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildScanner() {
    return Stack(
      alignment: Alignment.center,
      children: [
        MobileScanner(
          controller: controller,
          onDetect: (capture) {
            final barcodes = capture.barcodes;
            if (barcodes.isNotEmpty && !isProcessing) {
              final code = barcodes.first.rawValue;
              if (code != null) {
                controller.stop();
                _processQrCode(code);
              }
            }
          },
        ),
        // Scanner overlay
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(128),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest.shortestSide * 0.7;
              return Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      border: Border.all(
                        color: Colors.white,
                        width: 2.0,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  ClipPath(
                    clipper: ScannerOverlayClipper(
                      scannerSize: size,
                      borderRadius: 12,
                    ),
                    child: Container(
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                      color: Colors.black.withAlpha(128),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildScanResult() {
    return Container(
      color: isSuccess ? Colors.green.shade50 : Colors.red.shade50,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSuccess ? Icons.check_circle : Icons.error,
            color: isSuccess ? Colors.green : Colors.red,
            size: 80,
          ),
          const SizedBox(height: 24),
          Text(
            isSuccess ? 'Check-in completato!' : 'Errore',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            errorMessage ?? scanResult ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInstructions() {
    return Container(
      color: Colors.grey.shade100,
      padding: const EdgeInsets.all(16),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Inquadra il QR Code dell\'ospite',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Assicurati che il QR Code sia ben illuminato e completamente visibile',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class ScannerOverlayClipper extends CustomClipper<Path> {
  final double scannerSize;
  final double borderRadius;

  ScannerOverlayClipper({
    required this.scannerSize,
    required this.borderRadius,
  });

  @override
  Path getClip(Size size) {
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final cutoutLeft = (size.width - scannerSize) / 2;
    final cutoutTop = (size.height - scannerSize) / 2;

    final cutout = Rect.fromLTWH(
      cutoutLeft,
      cutoutTop,
      scannerSize,
      scannerSize,
    );
    
    final cutoutPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          cutout,
          Radius.circular(borderRadius),
        ),
      );

    return Path.combine(PathOperation.difference, path, cutoutPath);
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) {
    return true;
  }
} 
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vibration/vibration.dart';
import '../../services/SupabaseServicies/participation_service.dart';
import '../../services/SupabaseServicies/models/participation.dart';
import '../../theme/app_theme.dart';
import '../profile/person_profile_screen.dart';

class QRScannerScreen extends StatefulWidget {
  final String eventId;

  const QRScannerScreen({super.key, required this.eventId});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    returnImage: false,
  );
  final ParticipationService _participationService = ParticipationService();
  
  // Notification system
  final List<ScanNotification> _notifications = [];
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  
  bool _isProcessing = false;
  bool _isScannerInitialized = false;
  DateTime? _lastScanTime;
  String? _lastScannedCode;

  // Recent Scans
  final List<Participation> _recentScans = [];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_checkScannerStatus);
  }

  void _checkScannerStatus() {
    if (_controller.value.isInitialized && !_isScannerInitialized) {
      setState(() {
        _isScannerInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_checkScannerStatus);
    _controller.dispose();
    super.dispose();
  }

  void _handleScan(BarcodeCapture capture) async {
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code == null || _isProcessing) return;

    // Debounce: prevent scanning the same code too quickly
    if (_lastScanTime != null && 
        _lastScannedCode == code &&
        DateTime.now().difference(_lastScanTime!) < const Duration(seconds: 30)) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _lastScanTime = DateTime.now();
      _lastScannedCode = code;
    });

    // Feedback tattile immediato
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 50);
    }

    try {
      // 1. Validate Format: FEV-<UUID><CountOfA>
      if (!code.startsWith('FEV-')) {
        _showNotification(
          title: 'Codice Non Valido',
          message: 'Formato non riconosciuto',
          isError: true,
        );
        return;
      }

      final String content = code.substring(4); // Remove FEV-
      if (content.length < 36) { // UUID is 36 chars
        _showNotification(
          title: 'Codice Non Valido',
          message: 'Codice troppo corto',
          isError: true,
        );
        return;
      }

      final String uuid = content.substring(0, 36);
      final String suffix = content.substring(36);
      
      // Validate Authenticity (Count of 'a's)
      final int countA = uuid.toLowerCase().split('a').length - 1;
      if (suffix != countA.toString()) {
        _showNotification(
          title: 'Codice Non Valido',
          message: 'Controllo autenticità fallito',
          isError: true,
        );
        return;
      }

      // 2. Fetch Participation
      final participation = await _participationService.getParticipationById(uuid);
      if (participation == null) {
        _showNotification(
          title: 'Non Trovato',
          message: 'Nessuna partecipazione trovata',
          isError: true,
        );
        return;
      }

      if (participation.eventId != widget.eventId) {
        _showNotification(
          title: 'Evento Errato',
          message: 'Questo biglietto è per un altro evento',
          isError: true,
        );
        return;
      }

      // Add to recent scans
      if (!_recentScans.any((p) => p.id == participation.id)) {
        setState(() {
          _recentScans.insert(0, participation);
          if (_recentScans.length > 5) {
            _recentScans.removeLast();
          }
        });
      }

      // 3. Update Status
      // Fetch statuses to find IDs
      final statuses = await _participationService.getParticipationStatuses();
      final currentStatusId = participation.statusId;
      final currentStatus = statuses.firstWhere(
        (s) => s['id'] == currentStatusId,
        orElse: () => {'name': 'unknown'},
      );
      final currentStatusName = (currentStatus['name'] as String).toLowerCase();

      String newStatusName = currentStatusName;
      int? newStatusId;

      // Logic: Invited/Confirmed -> Inside/Checked_in
      // Defaulting to 'inside' as per request for "Checked_in / Inside"
      // Let's try to find 'inside' first, then 'checked_in'
      final insideStatus = statuses.firstWhere(
        (s) => s['name'] == 'inside' || s['name'] == 'dentro',
        orElse: () => {},
      );
      
      if (insideStatus.isNotEmpty) {
        // If currently invited or confirmed, move to inside
        if (currentStatusName == 'invited' || 
            currentStatusName == 'invitato' ||
            currentStatusName == 'confirmed' || 
            currentStatusName == 'confermato') {
          newStatusId = insideStatus['id'];
          newStatusName = insideStatus['name'];
        } else if (currentStatusName == 'inside' || currentStatusName == 'dentro') {
           _showNotification(
            title: 'Già Dentro',
            message: '${participation.person?['first_name']} ${participation.person?['last_name']} è già dentro',
            personId: participation.personId,
            eventId: widget.eventId,
            isWarning: true,
          );
          return;
        }
      }

      if (newStatusId != null) {
        await _participationService.updateParticipationStatus(
          participationId: uuid,
          newStatusId: newStatusId,
        );
        
        _showNotification(
          title: 'Ingresso Autorizzato',
          message: '${participation.person?['first_name']} ${participation.person?['last_name']} -> ${newStatusName.toUpperCase()}',
          personId: participation.personId,
          eventId: widget.eventId,
          isSuccess: true,
        );
      } else {
        // No status change needed or possible
         _showNotification(
          title: 'Info Scansione',
          message: '${participation.person?['first_name']} ${participation.person?['last_name']}: ${currentStatusName.toUpperCase()}',
          personId: participation.personId,
          eventId: widget.eventId,
          isWarning: true,
        );
      }

    } catch (e) {
      print('Scan error: $e');
      _showNotification(
        title: 'Errore',
        message: 'Si è verificato un errore: $e',
        isError: true,
      );
    } finally {
      // Small delay before allowing next scan processing to finish UI updates
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showNotification({
    required String title,
    required String message,
    String? personId,
    String? eventId,
    bool isError = false,
    bool isSuccess = false,
    bool isWarning = false,
  }) {
    final notification = ScanNotification(
      title: title,
      message: message,
      personId: personId,
      eventId: eventId,
      type: isError ? NotificationType.error : (isSuccess ? NotificationType.success : (isWarning ? NotificationType.warning : NotificationType.info)),
      onDismiss: () {}, // Handled by list removal
    );

    setState(() {
      _notifications.insert(0, notification);
      _listKey.currentState?.insertItem(0, duration: const Duration(milliseconds: 300));
    });

    // Auto dismiss
    Timer(const Duration(seconds: 5), () {
      if (mounted && _notifications.contains(notification)) {
        _removeNotification(notification);
      }
    });
  }

  void _removeNotification(ScanNotification notification) {
    final index = _notifications.indexOf(notification);
    if (index != -1) {
      setState(() {
        _notifications.removeAt(index);
        _listKey.currentState?.removeItem(
          index,
          (context, animation) => _buildNotificationItem(notification, animation),
          duration: const Duration(milliseconds: 300),
        );
      });
    }
  }

  Widget _buildNotificationItem(ScanNotification item, Animation<double> animation) {
    return SizeTransition(
      sizeFactor: animation,
      child: FadeTransition(
        opacity: animation,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: item,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Scanner
          MobileScanner(
            controller: _controller,
            onDetect: _handleScan,
          ),

          // Overlay
          Container(
            decoration: ShapeDecoration(
              shape: QrScannerOverlayShape(
                borderColor: AppTheme.primaryLight,
                borderRadius: 10,
                borderLength: 30,
                borderWidth: 10,
                cutOutSize: 300,
              ),
            ),
          ),

          // Controls
          SafeArea(
            child: Column(
              children: [
                // Top Bar
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 30),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Text(
                        'Scansiona QR',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: ValueListenableBuilder(
                          valueListenable: _controller,
                          builder: (context, state, child) {
                            if (!_isScannerInitialized) {
                              return const Icon(Icons.flash_off, color: Colors.grey, size: 30);
                            }
                            switch (state.torchState) {
                              case TorchState.off:
                                return const Icon(Icons.flash_off, color: Colors.white, size: 30);
                              case TorchState.on:
                                return const Icon(Icons.flash_on, color: Colors.yellow, size: 30);
                              default:
                                return const Icon(Icons.flash_off, color: Colors.white, size: 30);
                            }
                          },
                        ),
                        onPressed: _isScannerInitialized
                            ? () async {
                                try {
                                  await _controller.toggleTorch();
                                } catch (e) {
                                  print('Error toggling torch: $e');
                                }
                              }
                            : null,
                      ),
                    ],
                  ),
                ),

                // Manual Insert Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context, 'SEARCH_TRIGGER');
                    },
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Inserisci Manualmente'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.2),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: const BorderSide(color: Colors.white54),
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // Notifications Area
                Container(
                  height: 150, // Reduced height to fit recent scans
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: AnimatedList(
                    key: _listKey,
                    initialItemCount: _notifications.length,
                    reverse: true,
                    itemBuilder: (context, index, animation) {
                      return _buildNotificationItem(_notifications[index], animation);
                    },
                  ),
                ),
                
                // Recently Scanned
                if (_recentScans.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Scansionati di recente',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 60,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _recentScans.length,
                            itemBuilder: (context, index) {
                              final p = _recentScans[index];
                              return Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: ActionChip(
                                  avatar: const Icon(Icons.person, size: 16),
                                  label: Text('${p.person?['first_name']} ${p.person?['last_name']}'),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => PersonProfileScreen(
                                          personId: p.personId,
                                          eventId: widget.eventId,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Shape for Overlay
class QrScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  const QrScannerOverlayShape({
    this.borderColor = Colors.red,
    this.borderWidth = 10.0,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 80),
    this.borderRadius = 0,
    this.borderLength = 40,
    this.cutOutSize = 250,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(getOuterPath(rect), Offset.zero)
      ..addRect(
        Rect.fromCenter(
          center: rect.center,
          width: cutOutSize,
          height: cutOutSize,
        ),
      );
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    Path getLeftTopPath(Rect rect) {
      return Path()
        ..moveTo(rect.left, rect.bottom)
        ..lineTo(rect.left, rect.top)
        ..lineTo(rect.right, rect.top);
    }

    return getLeftTopPath(rect)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..close();
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final width = rect.width;
    final borderWidthSize = width / 2;
    final height = rect.height;
    final borderOffset = borderWidth / 2;
    final mBorderLength = borderLength > cutOutSize / 2 + borderWidth * 2
        ? borderWidthSize / 2
        : borderLength;
    final mCutOutSize = cutOutSize < width ? cutOutSize : width - borderWidth;

    final backgroundPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final boxPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.fill;

    final cutOutRect = Rect.fromCenter(
      center: rect.center,
      width: mCutOutSize,
      height: mCutOutSize,
    );

    canvas
      ..saveLayer(
        rect,
        backgroundPaint,
      )
      ..drawRect(
        rect,
        backgroundPaint,
      )
      ..drawRect(
        cutOutRect,
        Paint()..blendMode = BlendMode.clear,
      )
      ..restore();

    final path = Path()
      ..moveTo(cutOutRect.left, cutOutRect.top + mBorderLength)
      ..lineTo(cutOutRect.left, cutOutRect.top + borderRadius)
      ..quadraticBezierTo(
        cutOutRect.left,
        cutOutRect.top,
        cutOutRect.left + borderRadius,
        cutOutRect.top,
      )
      ..lineTo(cutOutRect.left + mBorderLength, cutOutRect.top)
      ..moveTo(cutOutRect.right, cutOutRect.top + mBorderLength)
      ..lineTo(cutOutRect.right, cutOutRect.top + borderRadius)
      ..quadraticBezierTo(
        cutOutRect.right,
        cutOutRect.top,
        cutOutRect.right - borderRadius,
        cutOutRect.top,
      )
      ..lineTo(cutOutRect.right - mBorderLength, cutOutRect.top)
      ..moveTo(cutOutRect.right, cutOutRect.bottom - mBorderLength)
      ..lineTo(cutOutRect.right, cutOutRect.bottom - borderRadius)
      ..quadraticBezierTo(
        cutOutRect.right,
        cutOutRect.bottom,
        cutOutRect.right - borderRadius,
        cutOutRect.bottom,
      )
      ..lineTo(cutOutRect.right - mBorderLength, cutOutRect.bottom)
      ..moveTo(cutOutRect.left, cutOutRect.bottom - mBorderLength)
      ..lineTo(cutOutRect.left, cutOutRect.bottom - borderRadius)
      ..quadraticBezierTo(
        cutOutRect.left,
        cutOutRect.bottom,
        cutOutRect.left + borderRadius,
        cutOutRect.bottom,
      )
      ..lineTo(cutOutRect.left + mBorderLength, cutOutRect.bottom);

    canvas.drawPath(path, borderPaint);
  }

  @override
  ShapeBorder scale(double t) {
    return QrScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth * t,
      overlayColor: overlayColor,
    );
  }
}

enum NotificationType { success, error, warning, info }

class ScanNotification extends StatelessWidget {
  final String title;
  final String message;
  final String? personId;
  final String? eventId;
  final NotificationType type;
  final VoidCallback onDismiss;

  const ScanNotification({
    super.key,
    required this.title,
    required this.message,
    this.personId,
    this.eventId,
    required this.type,
    required this.onDismiss,
  });

  Color get _color {
    switch (type) {
      case NotificationType.success:
        return Colors.green;
      case NotificationType.error:
        return Colors.red;
      case NotificationType.warning:
        return Colors.orange;
      case NotificationType.info:
        return Colors.blue;
    }
  }

  IconData get _icon {
    switch (type) {
      case NotificationType.success:
        return Icons.check_circle;
      case NotificationType.error:
        return Icons.error;
      case NotificationType.warning:
        return Icons.warning;
      case NotificationType.info:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (personId != null && eventId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PersonProfileScreen(
                personId: personId!,
                eventId: eventId!,
              ),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border(left: BorderSide(color: _color, width: 6)),
        ),
        child: Row(
          children: [
            Icon(_icon, color: _color, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            if (personId != null)
              Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}

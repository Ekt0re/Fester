import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:vibration/vibration.dart';
import '../../services/supabase/participation_service.dart';
import '../../services/supabase/models/participation.dart';
import '../../theme/app_theme.dart';
import '../profile/person_profile_screen.dart';
import '../../services/logger_service.dart';
import '../../services/permission_service.dart';

class QRScannerScreen extends StatefulWidget {
  final String eventId;
  final String? currentUserRole;

  const QRScannerScreen({
    super.key,
    required this.eventId,
    this.currentUserRole,
  });

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  static const String _tag = 'QRScannerScreen';
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    returnImage: false,
    autoStart: true,
  );
  final ParticipationService _participationService = ParticipationService();
  final TextEditingController _manualCodeController = TextEditingController();

  // Notification system
  final List<ScanNotification> _notifications = [];
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final GlobalKey _scannerKey = GlobalKey(debugLabel: 'qr_scanner_key');

  bool _isProcessing = false;
  bool _isScannerInitialized = false;
  DateTime? _lastScanTime;
  String? _lastScannedCode;
  int? _enteredStatusId;

  // Recent Scans
  final List<Participation> _recentScans = [];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_checkScannerStatus);
    _loadStatuses();
  }

  Future<void> _loadStatuses() async {
    try {
      final statuses = await _participationService.getParticipationStatuses();
      // Find the status that represents "entered" (is_inside = true)
      final enteredStatus = statuses.firstWhere(
        (s) => s['is_inside'] == true,
        orElse: () => <String, dynamic>{},
      );

      if (enteredStatus.isNotEmpty) {
        setState(() {
          _enteredStatusId = enteredStatus['id'] as int;
        });
      }
    } catch (e) {
      LoggerService.error('Error loading statuses', tag: _tag, error: e);
    }
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
    _manualCodeController.dispose();
    super.dispose();
  }

  void _handleScan(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code == null) return;

    _processCode(code);
  }

  Future<void> _processCode(String code) async {
    if (_isProcessing) return;

    // Debounce: prevent scanning the same code too quickly
    if (_lastScanTime != null &&
        _lastScannedCode == code &&
        DateTime.now().difference(_lastScanTime!) <
            const Duration(seconds: 5)) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _lastScanTime = DateTime.now();
      _lastScannedCode = code;
    });

    if (PermissionService.isReadOnly(widget.currentUserRole)) {
      _showNotification(
        title: 'qr.readonly_title'.tr(),
        message: 'qr.readonly_msg'.tr(),
        isWarning: true,
      );
      // We can still fetch participation to show info, but NO check-in.
    }

    // Feedback tattile immediato
    if (await Vibration.hasVibrator() == true) {
      Vibration.vibrate(duration: 50);
    }

    try {
      // 1. Validate Format: FEV-<UUID><CountOfA>
      String cleanCode = code.trim();

      if (!cleanCode.startsWith('FEV-')) {
        if (cleanCode.length == 36) {
          // Assume it's a valid UUID
        } else {
          _showNotification(
            title: 'qr.invalid_code'.tr(),
            message: 'qr.format_error'.tr(),
            isError: true,
          );
          return;
        }
      }

      String participationId;
      if (cleanCode.startsWith('FEV-')) {
        final String content = cleanCode.substring(4); // Remove FEV-
        if (content.length < 36) {
          _showNotification(
            title: 'qr.corrupt_code'.tr(),
            message: 'qr.length_error'.tr(),
            isError: true,
          );
          return;
        }
        participationId = content.substring(0, 36);
      } else {
        participationId = cleanCode;
      }

      // 2. Fetch Participation
      final participation = await _participationService.getParticipationById(
        participationId,
      );

      if (participation == null) {
        _showNotification(
          title: 'qr.not_found'.tr(),
          message: 'qr.participation_not_found'.tr(),
          isError: true,
        );
        return;
      }

      // 3. Verify Event Match
      if (participation.eventId != widget.eventId) {
        _showNotification(
          title: 'qr.wrong_event'.tr(),
          message: 'qr.wrong_event_msg'.tr(),
          isError: true,
        );
        return;
      }

      // 4. Check Status
      if (_enteredStatusId != null &&
          participation.statusId == _enteredStatusId) {
        _showNotification(
          title: 'qr.already_entered'.tr(),
          message:
              '${participation.person?['first_name'] ?? 'roles.guest'.tr()} ${'qr.is_inside'.tr()}',
          isWarning: true,
        );
        _addToRecentScans(participation);
        return;
      }

      // 5. Update Status to Entered
      if (_enteredStatusId != null) {
        if (PermissionService.isReadOnly(widget.currentUserRole)) {
          // Just success message or info, but no DB update
          _showNotification(
            title: 'qr.guest_info'.tr(),
            message:
                '${participation.person?['first_name'] ?? 'roles.guest'.tr()} ${'qr.found'.tr()}',
          );
        } else {
          await _participationService.checkInParticipant(
            participationId,
            _enteredStatusId!,
          );

          // 6. Success
          _showNotification(
            title: 'qr.access_granted'.tr(),
            message:
                '${'qr.welcome'.tr()} ${participation.person?['first_name'] ?? 'roles.guest'.tr()}!',
            isSuccess: true,
          );
        }
        _addToRecentScans(participation);
      } else {
        _showNotification(
          title: 'qr.config_error'.tr(),
          message: 'qr.status_not_found'.tr(),
          isError: true,
        );
      }
    } catch (e) {
      _showNotification(
        title: 'qr.error'.tr(),
        message: e.toString(),
        isError: true,
      );
    } finally {
      // Small delay before allowing next scan
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showNotification({
    required String title,
    required String message,
    bool isError = false,
    bool isSuccess = false,
    bool isWarning = false,
  }) {
    final notification = ScanNotification(
      title: title,
      message: message,
      type:
          isError
              ? NotificationType.error
              : isSuccess
              ? NotificationType.success
              : isWarning
              ? NotificationType.warning
              : NotificationType.info,
    );

    _notifications.insert(0, notification);
    _listKey.currentState?.insertItem(0);

    // Auto remove after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && _notifications.contains(notification)) {
        final index = _notifications.indexOf(notification);
        if (index != -1) {
          final removedItem = _notifications.removeAt(index);
          _listKey.currentState?.removeItem(
            index,
            (context, animation) =>
                _buildNotificationItem(removedItem, animation),
          );
        }
      }
    });
  }

  void _addToRecentScans(Participation participation) {
    setState(() {
      _recentScans.insert(0, participation);
      if (_recentScans.length > 20) {
        _recentScans.removeLast(); // Keep more history on desktop
      }
    });
  }

  Widget _buildNotificationItem(
    ScanNotification item,
    Animation<double> animation,
  ) {
    return SizeTransition(
      sizeFactor: animation,
      child: FadeTransition(
        opacity: animation,
        child: Padding(padding: const EdgeInsets.only(bottom: 8), child: item),
      ),
    );
  }

  void _showManualEntryDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('qr.manual_entry_title'.tr()),
            content: TextField(
              controller: _manualCodeController,
              decoration: InputDecoration(
                labelText: 'qr.manual_entry_label'.tr(),
                hintText: 'qr.manual_entry_hint'.tr(),
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('qr.cancel'.tr()),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  if (_manualCodeController.text.isNotEmpty) {
                    _processCode(_manualCodeController.text);
                    _manualCodeController.clear();
                  }
                },
                child: Text('qr.verify'.tr()),
              ),
            ],
          ),
    );
  }

  void _navigateToProfile(Participation scan) {
    if (scan.personId.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => PersonProfileScreen(
                personId: scan.personId,
                eventId: widget.eventId,
              ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 900;

          if (isDesktop) {
            return Row(
              children: [
                // Scanner Area (Left)
                Expanded(
                  flex: 2,
                  child: Stack(
                    children: [
                      MobileScanner(
                        key: _scannerKey,
                        controller: _controller,
                        onDetect: _handleScan,
                        fit: BoxFit.cover,
                      ),
                      // Overlay Border
                      Center(
                        child: Container(
                          width: 400,
                          height: 400,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: AppTheme.primaryLight.withOpacity(0.8),
                              width: 4,
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ),
                      // Back Button
                      Positioned(
                        top: 16,
                        left: 16,
                        child: IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                            size: 32,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      // Notifications Overlay
                      Positioned(
                        top: 16,
                        right: 16,
                        width: 400,
                        bottom: 16,
                        child: AnimatedList(
                          key: _listKey,
                          initialItemCount: _notifications.length,
                          itemBuilder: (context, index, animation) {
                            return _buildNotificationItem(
                              _notifications[index],
                              animation,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                // Side Panel (Right)
                Expanded(
                  flex: 1,
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'qr.title'.tr(),
                          style: GoogleFonts.outfit(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Controls
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed:
                                    _isScannerInitialized
                                        ? () => _controller.switchCamera()
                                        : null,
                                icon: const Icon(Icons.cameraswitch),
                                label: Text('qr.switch_camera'.tr()),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ValueListenableBuilder(
                                valueListenable: _controller,
                                builder: (context, state, child) {
                                  final isTorchOn =
                                      state.torchState == TorchState.on;
                                  return OutlinedButton.icon(
                                    onPressed:
                                        _isScannerInitialized
                                            ? () => _controller.toggleTorch()
                                            : null,
                                    icon: Icon(
                                      isTorchOn
                                          ? Icons.flash_on
                                          : Icons.flash_off,
                                      color:
                                          isTorchOn
                                              ? Colors.orange
                                              : Colors.grey,
                                    ),
                                    label: Text(
                                      isTorchOn
                                          ? 'qr.torch_on'.tr()
                                          : 'qr.torch_off'.tr(),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Manual Entry
                        Text(
                          'qr.manual_entry_title'.tr(),
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _manualCodeController,
                                decoration: InputDecoration(
                                  hintText: 'qr.manual_entry_label'.tr(),
                                  border: const OutlineInputBorder(),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 16,
                                  ),
                                ),
                                onSubmitted: (value) {
                                  if (value.isNotEmpty) {
                                    _processCode(value);
                                    _manualCodeController.clear();
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              onPressed: () {
                                if (_manualCodeController.text.isNotEmpty) {
                                  _processCode(_manualCodeController.text);
                                  _manualCodeController.clear();
                                }
                              },
                              icon: const Icon(Icons.arrow_forward),
                            ),
                          ],
                        ),

                        const SizedBox(height: 32),
                        Text(
                          'qr.recent_scans'.tr(),
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: ListView.separated(
                            itemCount: _recentScans.length,
                            separatorBuilder:
                                (context, index) => const Divider(),
                            itemBuilder: (context, index) {
                              final scan = _recentScans[index];
                              final person = scan.person;
                              final firstName =
                                  person?['first_name'] as String? ?? '?';
                              final lastName =
                                  person?['last_name'] as String? ?? '';
                              final imagePath =
                                  person?['image_path'] as String?;

                              return ListTile(
                                onTap: () => _navigateToProfile(scan),
                                leading: CircleAvatar(
                                  backgroundImage:
                                      imagePath != null
                                          ? NetworkImage(imagePath)
                                          : null,
                                  child:
                                      imagePath == null
                                          ? Text(firstName[0])
                                          : null,
                                ),
                                title: Text(
                                  '$firstName $lastName',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  '${'qr.access'.tr()}: ${scan.updatedAt?.hour.toString().padLeft(2, '0')}:${scan.updatedAt?.minute.toString().padLeft(2, '0')}',
                                  style: GoogleFonts.outfit(color: Colors.grey),
                                ),
                                trailing: const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          } else {
            // Mobile Layout
            return Stack(
              children: [
                MobileScanner(
                  key: _scannerKey,
                  controller: _controller,
                  onDetect: _handleScan,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, child) {
                    IconData icon;
                    String message;
                    switch (error.errorCode) {
                      case MobileScannerErrorCode.permissionDenied:
                        icon = Icons.no_photography;
                        message = 'qr.camera_error'.tr();
                        break;
                      default:
                        icon = Icons.error_outline;
                        message = 'qr.camera_not_found'.tr();
                    }
                    return Container(
                      color: Colors.black,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, color: Colors.white, size: 64),
                            const SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                              ),
                              child: Text(
                                message,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                // Dark Overlay with Cutout (IgnorePointer to prevent blocking buttons)
                IgnorePointer(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return CustomPaint(
                        painter: _ScannerOverlayPainter(
                          borderColor: AppTheme.primaryLight,
                          borderRadius: 24,
                          borderLength: 40,
                          borderWidth: 4,
                          cutOutSize: 280,
                        ),
                        size: Size(constraints.maxWidth, constraints.maxHeight),
                      );
                    },
                  ),
                ),

                // Top Bar (Controls)
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Back Button (Top Left)
                        IconButton.filled(
                          icon: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white,
                            size: 24,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black45,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),

                        // Flash & Camera Switch (Top Right)
                        Row(
                          children: [
                            IconButton.filled(
                              icon: const Icon(
                                Icons.cameraswitch_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.black45,
                              ),
                              onPressed: () {
                                if (_controller.value.isInitialized) {
                                  _controller.switchCamera();
                                }
                              },
                            ),
                            const SizedBox(width: 12),
                            ValueListenableBuilder(
                              valueListenable: _controller,
                              builder: (context, state, child) {
                                final isTorchOn =
                                    state.torchState == TorchState.on;
                                return IconButton.filled(
                                  icon: Icon(
                                    isTorchOn
                                        ? Icons.flash_on
                                        : Icons.flash_off,
                                    color:
                                        isTorchOn
                                            ? Colors.yellow
                                            : Colors.white,
                                    size: 24,
                                  ),
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.black45,
                                  ),
                                  onPressed: () {
                                    if (_controller.value.isInitialized) {
                                      _controller.toggleTorch();
                                    }
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom Area (Instructions & Manual Entry)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.8),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Inquadra il codice QR',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              shadows: [
                                const Shadow(
                                  blurRadius: 4,
                                  color: Colors.black,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Posiziona il codice all\'interno del riquadro',
                            style: GoogleFonts.outfit(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Notifications Overlay (Embedded here or floating)
                          SizedBox(
                            height: 60,
                            child: AnimatedList(
                              key: _listKey,
                              initialItemCount: _notifications.length,
                              itemBuilder: (context, index, animation) {
                                return _buildNotificationItem(
                                  _notifications[index],
                                  animation,
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Manual Entry Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _showManualEntryDialog,
                              icon: const Icon(Icons.keyboard_outlined),
                              label: Text('qr.manual_entry_button'.tr()),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          }
        },
      ),
    );
  }
}

enum NotificationType { success, error, warning, info }

class ScanNotification extends StatelessWidget {
  final String title;
  final String message;
  final NotificationType type;

  const ScanNotification({
    super.key,
    required this.title,
    required this.message,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color iconColor;
    IconData icon;

    switch (type) {
      case NotificationType.success:
        bgColor = Colors.green.shade100;
        iconColor = Colors.green.shade800;
        icon = Icons.check_circle;
        break;
      case NotificationType.error:
        bgColor = Colors.red.shade100;
        iconColor = Colors.red.shade800;
        icon = Icons.error;
        break;
      case NotificationType.warning:
        bgColor = Colors.orange.shade100;
        iconColor = Colors.orange.shade800;
        icon = Icons.warning;
        break;
      case NotificationType.info:
        bgColor = Colors.blue.shade100;
        iconColor = Colors.blue.shade800;
        icon = Icons.info;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
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
        ],
      ),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  final Color borderColor;
  final double borderRadius;
  final double borderLength;
  final double borderWidth;
  final double cutOutSize;

  _ScannerOverlayPainter({
    required this.borderColor,
    required this.borderRadius,
    required this.borderLength,
    required this.borderWidth,
    required this.cutOutSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final sh = size.height;
    final sw = size.width;

    final paint =
        Paint()
          ..color = borderColor
          ..strokeWidth = borderWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

    // DARK OVERLAY
    final backgroundPaint = Paint()..color = Colors.black.withOpacity(0.5);
    final backgroundPath = Path()..addRect(Rect.fromLTWH(0, 0, sw, sh));

    // CUTOUT
    final cutoutRect = Rect.fromCenter(
      center: Offset(sw / 2, sh / 2),
      width: cutOutSize,
      height: cutOutSize,
    );
    final cutoutRRect = RRect.fromRectAndRadius(
      cutoutRect,
      Radius.circular(borderRadius),
    );

    final finalPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      Path()..addRRect(cutoutRRect),
    );

    canvas.drawPath(finalPath, backgroundPaint);

    // BORDER (centered)
    final borderPath =
        Path()
          // Top Left
          ..moveTo(cutoutRect.left, cutoutRect.top + borderLength)
          ..lineTo(cutoutRect.left, cutoutRect.top + borderRadius)
          ..arcToPoint(
            Offset(cutoutRect.left + borderRadius, cutoutRect.top),
            radius: Radius.circular(borderRadius),
          )
          ..lineTo(cutoutRect.left + borderLength, cutoutRect.top)
          // Top Right
          ..moveTo(cutoutRect.right - borderLength, cutoutRect.top)
          ..lineTo(cutoutRect.right - borderRadius, cutoutRect.top)
          ..arcToPoint(
            Offset(cutoutRect.right, cutoutRect.top + borderRadius),
            radius: Radius.circular(borderRadius),
          )
          ..lineTo(cutoutRect.right, cutoutRect.top + borderLength)
          // Bottom Right
          ..moveTo(cutoutRect.right, cutoutRect.bottom - borderLength)
          ..lineTo(cutoutRect.right, cutoutRect.bottom - borderRadius)
          ..arcToPoint(
            Offset(cutoutRect.right - borderRadius, cutoutRect.bottom),
            radius: Radius.circular(borderRadius),
          )
          ..lineTo(cutoutRect.right - borderLength, cutoutRect.bottom)
          // Bottom Left
          ..moveTo(cutoutRect.left + borderLength, cutoutRect.bottom)
          ..lineTo(cutoutRect.left + borderRadius, cutoutRect.bottom)
          ..arcToPoint(
            Offset(cutoutRect.left, cutoutRect.bottom - borderRadius),
            radius: Radius.circular(borderRadius),
          )
          ..lineTo(cutoutRect.left, cutoutRect.bottom - borderLength);

    canvas.drawPath(borderPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

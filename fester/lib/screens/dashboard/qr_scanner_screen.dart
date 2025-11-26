import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
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
    autoStart: true,
  );
  final ParticipationService _participationService = ParticipationService();
  final TextEditingController _manualCodeController = TextEditingController();

  // Notification system
  final List<ScanNotification> _notifications = [];
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

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
      debugPrint('Error loading statuses: $e');
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
            title: 'Codice Non Valido',
            message: 'Formato non riconosciuto',
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
            title: 'Codice Corrotto',
            message: 'Lunghezza non valida',
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
          title: 'Non Trovato',
          message: 'Partecipazione inesistente',
          isError: true,
        );
        return;
      }

      // 3. Verify Event Match
      if (participation.eventId != widget.eventId) {
        _showNotification(
          title: 'Evento Errato',
          message: 'Il biglietto è per un altro evento',
          isError: true,
        );
        return;
      }

      // 4. Check Status
      if (_enteredStatusId != null &&
          participation.statusId == _enteredStatusId) {
        _showNotification(
          title: 'Già Entrato',
          message:
              '${participation.person?['first_name'] ?? 'Ospite'} è già dentro',
          isWarning: true,
        );
        _addToRecentScans(participation);
        return;
      }

      // 5. Update Status to Entered
      if (_enteredStatusId != null) {
        await _participationService.checkInParticipant(
          participationId,
          _enteredStatusId!,
        );

        // 6. Success
        _showNotification(
          title: 'Ingresso Autorizzato',
          message:
              'Benvenuto ${participation.person?['first_name'] ?? 'Ospite'}!',
          isSuccess: true,
        );
        _addToRecentScans(participation);
      } else {
        _showNotification(
          title: 'Errore Configurazione',
          message: 'Stato "Entrato" non trovato nel sistema',
          isError: true,
        );
      }
    } catch (e) {
      _showNotification(title: 'Errore', message: e.toString(), isError: true);
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
            title: const Text('Inserimento Manuale'),
            content: TextField(
              controller: _manualCodeController,
              decoration: const InputDecoration(
                labelText: 'Codice Biglietto',
                hintText: 'FEV-... o UUID',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annulla'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  if (_manualCodeController.text.isNotEmpty) {
                    _processCode(_manualCodeController.text);
                    _manualCodeController.clear();
                  }
                },
                child: const Text('Verifica'),
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
                          'Controllo Accessi',
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
                                onPressed: () => _controller.switchCamera(),
                                icon: const Icon(Icons.cameraswitch),
                                label: const Text('Cambia Camera'),
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
                                    onPressed: () => _controller.toggleTorch(),
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
                                      isTorchOn ? 'Torcia ON' : 'Torcia OFF',
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
                          'Inserimento Manuale',
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
                                decoration: const InputDecoration(
                                  hintText: 'Codice biglietto...',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
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
                          'Ultimi Ingressi',
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
                                  'Ingresso: ${scan.updatedAt?.hour.toString().padLeft(2, '0')}:${scan.updatedAt?.minute.toString().padLeft(2, '0')}',
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
                  controller: _controller,
                  onDetect: _handleScan,
                  fit: BoxFit.cover,
                ),

                // Overlay Border
                Center(
                  child: Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppTheme.primaryLight,
                        width: 4,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                // Controls Overlay
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
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 30,
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.cameraswitch_outlined,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                  onPressed: () => _controller.switchCamera(),
                                ),
                                IconButton(
                                  icon: ValueListenableBuilder(
                                    valueListenable: _controller,
                                    builder: (context, state, child) {
                                      return Icon(
                                        state.torchState == TorchState.on
                                            ? Icons.flash_on
                                            : Icons.flash_off,
                                        color:
                                            state.torchState == TorchState.on
                                                ? Colors.yellow
                                                : Colors.white,
                                        size: 30,
                                      );
                                    },
                                  ),
                                  onPressed: () => _controller.toggleTorch(),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Notifications
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
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
                      ),

                      // Bottom Controls
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            // Manual Entry Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _showManualEntryDialog,
                                icon: const Icon(Icons.keyboard),
                                label: const Text('INSERISCI CODICE'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Recent Scans Preview (Horizontal)
                            if (_recentScans.isNotEmpty)
                              SizedBox(
                                height: 80,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _recentScans.length,
                                  itemBuilder: (context, index) {
                                    final scan = _recentScans[index];
                                    final person = scan.person;
                                    final firstName =
                                        person?['first_name'] as String? ?? '?';
                                    final lastName =
                                        person?['last_name'] as String? ?? '';
                                    final imagePath =
                                        person?['image_path'] as String?;

                                    return GestureDetector(
                                      onTap: () => _navigateToProfile(scan),
                                      child: Container(
                                        width:
                                            200, // Increased width to fit name
                                        margin: const EdgeInsets.only(
                                          right: 12,
                                        ),
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.9),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              backgroundImage:
                                                  imagePath != null
                                                      ? NetworkImage(imagePath)
                                                      : null,
                                              child:
                                                  imagePath == null
                                                      ? Text(firstName[0])
                                                      : null,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    '$firstName $lastName',
                                                    style: GoogleFonts.outfit(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.black87,
                                                      fontSize: 14,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  Text(
                                                    '${scan.updatedAt?.hour.toString().padLeft(2, '0')}:${scan.updatedAt?.minute.toString().padLeft(2, '0')}',
                                                    style: GoogleFonts.outfit(
                                                      fontSize: 12,
                                                      color: Colors.black54,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const Icon(
                                              Icons.check_circle,
                                              color: Colors.green,
                                              size: 16,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
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

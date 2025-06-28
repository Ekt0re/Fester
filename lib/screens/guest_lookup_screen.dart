import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/guest_provider.dart';
import '../providers/auth_provider.dart';
import '../models/guest.dart';
import '../models/user.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/guest_card.dart';
import '../utils/app_colors.dart';
import '../services/camera_service.dart';
import 'add_edit_guest_screen.dart';
import 'code_scanner_screen.dart';

class GuestLookupScreen extends ConsumerStatefulWidget {
  const GuestLookupScreen({super.key});

  @override
  ConsumerState<GuestLookupScreen> createState() => _GuestLookupScreenState();
}

class _GuestLookupScreenState extends ConsumerState<GuestLookupScreen> 
    with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  final CameraService _cameraService = CameraService.instance;
  List<Guest> _searchResults = [];
  bool _isSearching = false;
  String _lastSearchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Listener per aggiornare l'UI quando cambia il testo di ricerca
    _searchController.addListener(() {
      setState(() {}); // Aggiorna l'UI per il header dinamico
    });
    
    // Sincronizza quando si apre la schermata
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(guestProvider.notifier).forceSync();
      // Mostra tutti gli ospiti all'inizio
      _performSearch('');
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Aggiorna i dati quando l'app torna in primo piano
      ref.read(guestProvider.notifier).forceSync();
    }
  }

  void _performSearch(String query) {
    if (query == _lastSearchQuery) return;
    
    setState(() {
      _isSearching = true;
      _lastSearchQuery = query;
    });

    final allGuests = ref.read(guestProvider).guests;
    
    if (query.isEmpty) {
      // Mostra tutti gli ospiti se la ricerca è vuota
      _searchResults = List.from(allGuests);
    } else {
      final queryLower = query.toLowerCase();
      _searchResults = allGuests.where((guest) {
        return guest.name.toLowerCase().contains(queryLower) ||
               guest.surname.toLowerCase().contains(queryLower) ||
               guest.code.toLowerCase().contains(queryLower) ||
               guest.qrCode.toLowerCase().contains(queryLower) ||
               guest.barcode.toLowerCase().contains(queryLower) ||
               '${guest.name} ${guest.surname}'.toLowerCase().contains(queryLower);
      }).toList();
    }

    setState(() {
      _isSearching = false;
    });
  }

  Future<void> _searchByQRCode(String qrCode) async {
    // Cerca ospiti che hanno questo QR code
    final allGuests = ref.read(guestProvider).guests;
    final foundGuests = allGuests.where((guest) => 
      guest.qrCode.toLowerCase() == qrCode.toLowerCase() ||
      guest.code.toLowerCase() == qrCode.toLowerCase() ||
      guest.barcode.toLowerCase() == qrCode.toLowerCase()
    ).toList();

    if (foundGuests.isNotEmpty) {
      // Vibrazione di successo
      HapticFeedback.lightImpact();
      
      setState(() {
        _searchResults = foundGuests;
        _searchController.text = qrCode;
        _lastSearchQuery = qrCode;
      });

      // Mostra messaggio di successo
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Trovato ${foundGuests.length} ospite(i) con codice $qrCode'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      // Vibrazione di errore
      HapticFeedback.heavyImpact();
      
      setState(() {
        _searchResults = [];
        _searchController.text = qrCode;
        _lastSearchQuery = qrCode;
      });

      // Mostra messaggio di errore
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Nessun ospite trovato con codice $qrCode'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _openScanner() async {
    // Se la piattaforma non supporta la fotocamera, mostra direttamente il dialog manuale
    if (!_cameraService.isPlatformSupported) {
      _manualCodeEntry();
      return;
    }

    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (context) => const CodeScannerScreen()),
    );

    if (result != null && result.isNotEmpty) {
      await _searchByQRCode(result);
    }
  }

  void _manualCodeEntry() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _cameraService.isPlatformSupported 
                ? Icons.edit_outlined 
                : Icons.qr_code,
              color: AppColors.primary,
            ),
            const SizedBox(width: 8),
            const Text('Inserisci Codice'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_cameraService.isPlatformSupported)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.accent.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.accent.withAlpha(100)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.desktop_windows,
                      color: AppColors.accent,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _cameraService.platformSupportMessage,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.accent.withAlpha(200),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Codice (QR, Barcode o Codice Ospite)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.qr_code),
                hintText: 'es: QR001, BC123, G456',
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cerca'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await _searchByQRCode(result);
    }
  }

  void _editGuest(Guest guest) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => AddEditGuestScreen(guest: guest),
      ),
    );
    
    if (result == true) {
      // Ricarica i risultati di ricerca se la modifica è andata a buon fine
      if (_searchController.text.isNotEmpty) {
        _performSearch(_searchController.text);
      }
    }
  }

  void _addNewGuest() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => const AddEditGuestScreen(),
      ),
    );
    
    if (result == true) {
      // Ricarica i risultati di ricerca se l'aggiunta è andata a buon fine
      if (_searchController.text.isNotEmpty) {
        _performSearch(_searchController.text);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final guestState = ref.watch(guestProvider);
    final isHost = authState.user?.role == UserRole.host;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Cerca Ospiti'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (isHost)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _addNewGuest,
              tooltip: 'Aggiungi Ospite',
            ),
        ],
      ),
      body: Column(
        children: [
          // Header dinamico con statistiche
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary,
                  AppColors.primary.withAlpha(200),
                ],
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Statistiche principali
                  Row(
                    children: [
                      _buildStatCard(
                        'Totale Ospiti',
                        '${guestState.guests.length}',
                        Icons.people,
                        Colors.white.withAlpha(200),
                      ),
                      const SizedBox(width: 16),
                      _buildStatCard(
                        'Risultati',
                        '${_searchResults.length}',
                        Icons.search,
                        Colors.white.withAlpha(200),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Header del contenuto
                  Text(
                    _searchController.text.isEmpty 
                      ? 'Tutti gli Ospiti'
                      : 'Risultati per "${_searchController.text}"',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  if (guestState.isLoading)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      child: const Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Sincronizzazione in corso...',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  CustomTextField(
                    controller: _searchController,
                    label: 'Cerca ospite...',
                    icon: Icons.search,
                    onChanged: _performSearch,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _openScanner,
                          icon: Icon(
                            _cameraService.isPlatformSupported 
                              ? Icons.qr_code_scanner
                              : Icons.edit_outlined,
                          ),
                          label: Text(
                            _cameraService.isPlatformSupported 
                              ? 'Scansiona QR' 
                              : 'Inserisci Codice',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      if (_cameraService.isPlatformSupported) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _manualCodeEntry,
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Inserisci Codice'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.surface,
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  
                  // Info platform se necessario
                  if (!_cameraService.isPlatformSupported)
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.accent.withAlpha(100)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: AppColors.accent,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _cameraService.platformSupportMessage,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.accent.withAlpha(200),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  const SizedBox(height: 8),
                  
                  // Lista risultati
                  Expanded(
                    child: _isSearching
                        ? const Center(
                            child: CircularProgressIndicator(),
                          )
                        : _searchResults.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _searchController.text.isEmpty 
                                        ? Icons.people_outline 
                                        : Icons.search_off,
                                      size: 64,
                                      color: AppColors.textSecondary,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _searchController.text.isEmpty
                                        ? 'Nessun ospite presente'
                                        : 'Nessun ospite trovato',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _searchController.text.isEmpty
                                        ? 'Aggiungi il primo ospite cliccando il pulsante +'
                                        : 'Prova con un altro termine di ricerca',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: _searchResults.length,
                                itemBuilder: (context, index) {
                                  final guest = _searchResults[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: GuestCard(
                                      guest: guest,
                                      onTap: () => _editGuest(guest),
                                      onEdit: isHost ? () => _editGuest(guest) : null,
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
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: AppColors.primary,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: AppColors.primary.withAlpha(180),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 
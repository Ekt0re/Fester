import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/guest_provider.dart';
import '../providers/auth_provider.dart';
import '../models/guest.dart';
import '../models/user.dart';
import '../widgets/custom_text_field.dart';
import '../utils/app_colors.dart';
import 'add_edit_guest_screen.dart';

class BarScreen extends ConsumerStatefulWidget {
  const BarScreen({super.key});

  @override
  ConsumerState<BarScreen> createState() => _BarScreenState();
}

class _BarScreenState extends ConsumerState<BarScreen> 
    with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  List<Guest> _filteredGuests = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _filteredGuests = [];
    // Sincronizza quando si apre la schermata
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(guestProvider.notifier).forceSync();
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
    super.didChangeAppLifecycleState(state);
    // Sincronizza quando l'app torna in foreground
    if (state == AppLifecycleState.resumed) {
      ref.read(guestProvider.notifier).forceSync();
      // Ricarica i risultati di ricerca se presenti
      if (_searchController.text.isNotEmpty) {
        _filterGuests(_searchController.text);
      }
    }
  }

  void _filterGuests(String query) {
    final allGuests = ref.read(guestProvider).guests;
    if (query.isEmpty) {
      setState(() => _filteredGuests = []);
      return;
    }

    setState(() {
      _filteredGuests = allGuests
          .where((guest) =>
              guest.name.toLowerCase().contains(query.toLowerCase()) ||
              guest.surname.toLowerCase().contains(query.toLowerCase()) ||
              guest.code.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  void _serveDrink(Guest guest) async {
    // Controlla se mostrare avvisi prima di aggiungere
    final shouldShowWarning = guest.drinksCount >= 3 || guest.flags.isNotEmpty;
    
    if (shouldShowWarning) {
      final confirmed = await _showDrinkConfirmation(guest);
      if (!confirmed) return; // Annullato dall'utente
    }
    
    // Aggiungi la bevanda
    ref.read(guestProvider.notifier).incrementDrinks(guest.id);
    
    if (!mounted) return;
    // Mostra messaggio di successo
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Bevanda aggiunta per ${guest.name}'),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<bool> _showDrinkConfirmation(Guest guest) async {
    final warnings = <String>[];
    
    // Controlla numero bevande
    if (guest.drinksCount >= 3) {
      warnings.add('⚠️ Ha già consumato ${guest.drinksCount} bevande');
    }
    
    // Controlla flags/segnalazioni
    if (guest.flags.isNotEmpty) {
      warnings.add('🚩 Segnalazioni attive:');
      for (final flag in guest.flags) {
        warnings.add('   • $flag');
      }
    }
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Conferma Bevanda'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vuoi servire una bevanda a ${guest.name} ${guest.surname}?',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...warnings.map((warning) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                warning,
                style: TextStyle(
                  color: warning.startsWith('🚩') || warning.startsWith('   •') 
                      ? AppColors.error 
                      : Colors.orange,
                ),
              ),
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Conferma'),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }

  void _editGuest(Guest guest) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => AddEditGuestScreen(guest: guest),
      ),
    );
    
    if (result == true) {
      // Ricarica i dati dopo la modifica
      setState(() {
        _filteredGuests = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final guestState = ref.watch(guestProvider);
    final authState = ref.watch(authProvider);
    final isHost = authState.user?.role == UserRole.host;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Bar / Bevande'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con informazioni
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gestione Bar',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Cerca ospiti e gestisci le bevande',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 192),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        'Totale Bevande: ${guestState.totalDrinks}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 128),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Ospiti Arrivati: ${guestState.arrivedGuests.length}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 128),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Barra di ricerca
            CustomTextField(
              controller: _searchController,
              label: 'Cerca ospite per servire bevande...',
              icon: Icons.search,
              onChanged: _filterGuests,
            ),

            const SizedBox(height: 16),

            // Lista ospiti filtrati
            Expanded(
              child: _filteredGuests.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      itemCount: _filteredGuests.length,
                      itemBuilder: (context, index) {
                        final guest = _filteredGuests[index];
                        return _BarGuestCard(
                          guest: guest,
                          onDrinkAdd: () => _serveDrink(guest),
                          onEdit: isHost ? () => _editGuest(guest) : null,
                          onTap: () {
                            Navigator.of(context).pushNamed(
                              '/guest-profile',
                              arguments: guest,
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.local_bar_outlined,
            size: 64,
            color: AppColors.textDisabled,
          ),
          const SizedBox(height: 16),
          Text(
            'Nessun ospite presente',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Gli ospiti arrivati appariranno qui',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textDisabled,
            ),
          ),
        ],
      ),
    );
  }
}

class _BarGuestCard extends StatelessWidget {
  final Guest guest;
  final VoidCallback onDrinkAdd;
  final VoidCallback? onEdit;
  final VoidCallback? onTap;

  const _BarGuestCard({
    required this.guest,
    required this.onDrinkAdd,
    this.onEdit,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${guest.name} ${guest.surname}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Codice: ${guest.code}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (onEdit != null) ...[
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit),
                  iconSize: 20,
                  color: AppColors.primary,
                  tooltip: 'Modifica ospite',
                ),
                const SizedBox(width: 8),
              ],
              ElevatedButton.icon(
                onPressed: onDrinkAdd,
                icon: const Icon(Icons.add),
                label: const Text('Drink'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 
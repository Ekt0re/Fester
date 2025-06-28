import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/guest.dart';
import '../models/user.dart';
import '../providers/guest_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/custom_button.dart';
import '../utils/app_colors.dart';
import 'add_edit_guest_screen.dart';

class GuestProfileScreen extends ConsumerStatefulWidget {
  const GuestProfileScreen({super.key});

  @override
  ConsumerState<GuestProfileScreen> createState() => _GuestProfileScreenState();
}

class _GuestProfileScreenState extends ConsumerState<GuestProfileScreen> 
    with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Sincronizza quando si apre la schermata
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(guestProvider.notifier).forceSync();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Sincronizza quando l'app torna in foreground
    if (state == AppLifecycleState.resumed) {
      ref.read(guestProvider.notifier).forceSync();
    }
  }

  @override
  Widget build(BuildContext context) {
    // L'ospite passato come argomento (fallback iniziale)
    final Guest initialGuest = ModalRoute.of(context)!.settings.arguments as Guest;

    // Stato aggiornato degli ospiti dal provider
    final guestState = ref.watch(guestProvider);
    final authState = ref.watch(authProvider);
    final isHost = authState.user?.role == UserRole.host;

    // Trova l'ospite aggiornato (se presente) altrimenti usa quello iniziale
    final Guest guest = guestState.guests.firstWhere(
      (g) => g.id == initialGuest.id,
      orElse: () => initialGuest,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('${guest.name} ${guest.surname}'),
        actions: [
          if (isHost)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (context) => AddEditGuestScreen(guest: guest),
                  ),
                );
                
                // Se la modifica è andata a buon fine, aggiorna la vista
                if (result == true) {
                  if (!mounted) return;
                  // La vista si aggiornerà automaticamente tramite Riverpod
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('✅ Ospite modificato con successo!'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Guest info card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: AppColors.primary,
                          child: Text(
                            '${guest.name[0]}${guest.surname[0]}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${guest.name} ${guest.surname}',
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Codice: ${guest.code}',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Status section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stato',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: CustomButton(
                            text: 'Non Arrivato',
                            backgroundColor: guest.status == GuestStatus.notArrived 
                              ? AppColors.statusNotArrived 
                              : AppColors.surfaceVariant,
                            textColor: guest.status == GuestStatus.notArrived 
                              ? Colors.white 
                              : AppColors.textSecondary,
                            onPressed: () => ref.read(guestProvider.notifier)
                              .updateGuestStatus(guest.id, GuestStatus.notArrived),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: CustomButton(
                            text: 'Arrivato',
                            backgroundColor: guest.status == GuestStatus.arrived 
                              ? AppColors.statusArrived 
                              : AppColors.surfaceVariant,
                            textColor: guest.status == GuestStatus.arrived 
                              ? Colors.white 
                              : AppColors.textSecondary,
                            onPressed: () => ref.read(guestProvider.notifier)
                              .updateGuestStatus(guest.id, GuestStatus.arrived),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: CustomButton(
                            text: 'Partito',
                            backgroundColor: guest.status == GuestStatus.left 
                              ? AppColors.statusLeft 
                              : AppColors.surfaceVariant,
                            textColor: guest.status == GuestStatus.left 
                              ? Colors.white 
                              : AppColors.textSecondary,
                            onPressed: () => ref.read(guestProvider.notifier)
                              .updateGuestStatus(guest.id, GuestStatus.left),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Drinks section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Bevande Consumate',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            if (guest.drinksCount >= 3) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withAlpha(25),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.orange.withAlpha(100)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.warning, color: Colors.orange, size: 16),
                                    SizedBox(width: 4),
                                    Text(
                                      'Limite',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.orange,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            Text(
                              '${guest.drinksCount}',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: guest.drinksCount >= 3 ? Colors.orange : AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: CustomButton(
                            text: 'Rimuovi Bevanda',
                            icon: Icons.remove,
                            isOutlined: true,
                            onPressed: guest.drinksCount > 0 
                                ? () => ref.read(guestProvider.notifier)
                                    .decrementDrinks(guest.id)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CustomButton(
                            text: 'Aggiungi Bevanda',
                            icon: Icons.add,
                            onPressed: () => _serveDrink(context, ref, guest),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Flags section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Avvisi e Flag',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (guest.flags.isEmpty)
                      Text(
                        'Nessun avviso presente',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: guest.flags.map((flag) => Chip(
                          label: Text(flag),
                          backgroundColor: AppColors.warning.withAlpha((0.1 * 255).toInt()),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () => ref.read(guestProvider.notifier)
                            .removeFlag(guest.id, flag),
                        )).toList(),
                      ),
                    const SizedBox(height: 12),
                    CustomButton(
                      text: 'Aggiungi Avviso',
                      icon: Icons.flag,
                      isOutlined: true,
                      onPressed: () => _showAddFlagDialog(context, ref, guest.id),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showAddFlagDialog(BuildContext context, WidgetRef ref, String guestId) {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aggiungi Avviso'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Inserisci il testo dell\'avviso',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                ref.read(guestProvider.notifier).addFlag(guestId, controller.text);
                Navigator.of(context).pop();
              }
            },
            child: const Text('Aggiungi'),
          ),
        ],
      ),
    );
  }

  Future<void> _serveDrink(BuildContext context, WidgetRef ref, Guest guest) async {
    // Controlla se mostrare avvisi prima di aggiungere
    final shouldShowWarning = guest.drinksCount >= 2 || guest.flags.isNotEmpty;
    
    if (shouldShowWarning) {
      final confirmed = await _showDrinkConfirmation(context, guest);
      if (!confirmed) return; // Annullato dall'utente
    }
    
    // Aggiungi la bevanda
    ref.read(guestProvider.notifier).incrementDrinks(guest.id);
    
    // Mostra messaggio di successo
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Bevanda aggiunta per ${guest.name}'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<bool> _showDrinkConfirmation(BuildContext context, Guest guest) async {
    final warnings = <String>[];
    
    // Controlla numero bevande
    if (guest.drinksCount >= 2) {
      warnings.add('⚠️ Avrà consumato ${guest.drinksCount + 1} bevande');
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
            if (warnings.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withAlpha(100)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Verifica che sia appropriato servire una bevanda',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
} 
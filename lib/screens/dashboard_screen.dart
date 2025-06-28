import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/guest_provider.dart';
import '../widgets/stat_card.dart';
import '../utils/app_colors.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> 
    with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Sincronizza immediatamente quando si apre la dashboard
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
    final authState = ref.watch(authProvider);
    final guestState = ref.watch(guestProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('FESTER Dashboard'),
        actions: [
          // Indicatore di sincronizzazione
          if (guestState.isSyncing)
            const Padding(
              padding: EdgeInsets.only(right: 8.0),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
          // Pulsante sync manuale
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: guestState.isSyncing 
                ? null 
                : () => ref.read(guestProvider.notifier).forceSync(),
            tooltip: 'Sincronizza dati',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).pushNamed('/settings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(guestProvider.notifier).forceSync(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Benvenuto, ${authState.user?.username ?? 'Utente'}!',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Gestisci il tuo evento con facilità',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 192),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          color: Colors.white.withValues(alpha: 192),
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          guestState.lastSyncTime != null
                              ? 'Ultimo sync: ${_formatSyncTime(guestState.lastSyncTime!)}'
                              : 'Sincronizzazione in corso...',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 192),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Statistics cards
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      title: 'Ospiti Totali',
                      value: '${guestState.guests.length}',
                      icon: Icons.people,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: StatCard(
                      title: 'Arrivati',
                      value: '${guestState.arrivedGuests.length}',
                      icon: Icons.check_circle,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      title: 'Bevande Servite',
                      value: '${guestState.totalDrinks}',
                      icon: Icons.local_bar,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: StatCard(
                      title: 'In Attesa',
                      value: '${guestState.notArrivedGuests.length}',
                      icon: Icons.schedule,
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Quick actions
              Text(
                'Azioni Rapide',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 16),

              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.5,
                children: [
                  _QuickActionCard(
                    title: 'Cerca Ospiti',
                    subtitle: 'Trova per nome o codice',
                    icon: Icons.search,
                    onTap: () => Navigator.of(context).pushNamed('/guest-lookup'),
                  ),
                  _QuickActionCard(
                    title: 'Bar / Bevande',
                    subtitle: 'Gestisci consumazioni',
                    icon: Icons.local_bar,
                    onTap: () => Navigator.of(context).pushNamed('/bar'),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Sync status
              if (guestState.error != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 26),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.error.withValues(alpha: 77)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: AppColors.error),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Errore di Sincronizzazione',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.error,
                              ),
                            ),
                            Text(
                              guestState.error!,
                              style: const TextStyle(color: AppColors.error),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          ref.read(guestProvider.notifier).clearError();
                          ref.read(guestProvider.notifier).forceSync();
                        },
                        child: const Text('Riprova'),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  String _formatSyncTime(DateTime syncTime) {
    final now = DateTime.now();
    final difference = now.difference(syncTime);
    
    if (difference.inMinutes < 1) {
      return 'ora';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m fa';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h fa';
    } else {
      return '${difference.inDays}g fa';
    }
  }
}

class _QuickActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 32,
                color: AppColors.primary,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
} 
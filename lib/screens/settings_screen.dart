import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/guest_provider.dart';
import '../providers/settings_provider.dart';
import '../models/app_settings.dart';
import '../utils/app_colors.dart';
import '../services/local_database_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final appSettings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Impostazioni'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: AppColors.primary,
                      child: Text(
                        authState.user?.username[0].toUpperCase() ?? 'U',
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
                            authState.user?.username ?? 'Utente',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Ruolo: ${authState.user?.role.name.toUpperCase() ?? 'N/A'}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            'DB: ${ref.read(settingsProvider.notifier).currentConnectionString}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Database Configuration
            Text(
              'Configurazione Database',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.cloud, color: AppColors.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Modalità Database',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Database mode switch
                    SegmentedButton<DatabaseMode>(
                      segments: const [
                        ButtonSegment(
                          value: DatabaseMode.supabase,
                          label: Text('Supabase'),
                          icon: Icon(Icons.cloud),
                        ),
                        ButtonSegment(
                          value: DatabaseMode.mongodb,
                          label: Text('MongoDB'),
                          icon: Icon(Icons.storage),
                        ),
                      ],
                      selected: {appSettings.databaseMode},
                      onSelectionChanged: (Set<DatabaseMode> selection) {
                        ref.read(settingsProvider.notifier)
                            .updateDatabaseMode(selection.first);
                      },
                    ),
                    
                    if (appSettings.databaseMode == DatabaseMode.mongodb) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),
                      
                      // MongoDB configuration
                      Row(
                        children: [
                          const Icon(Icons.computer, color: AppColors.primary),
                          const SizedBox(width: 12),
                          Text(
                            'Configurazione MongoDB',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Host/IP',
                                hintText: 'es. 192.168.1.42',
                                border: OutlineInputBorder(),
                              ),
                              initialValue: appSettings.mongoDbHost ?? '',
                              onChanged: (value) {
                                ref.read(settingsProvider.notifier)
                                    .updateMongoDbConfig(host: value);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Porta',
                                hintText: '27017',
                                border: OutlineInputBorder(),
                              ),
                              initialValue: appSettings.mongoDbPort?.toString() ?? '27017',
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                final port = int.tryParse(value);
                                if (port != null) {
                                  ref.read(settingsProvider.notifier)
                                      .updateMongoDbConfig(port: port);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, 
                                color: AppColors.primary, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Stringa connessione: ${appSettings.mongoConnectionString}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Authentication settings
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.security, color: AppColors.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Autenticazione',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Switch(
                          value: appSettings.useRealAuth,
                          onChanged: (value) {
                            ref.read(settingsProvider.notifier).toggleRealAuth(value);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      appSettings.useRealAuth 
                          ? 'Usa Supabase Auth per login e registrazione.'
                          : 'Usa utente demo locale (admin/admin123).',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Data section
            Text(
              'Gestione Dati',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _SettingsAction(
                      icon: Icons.sync,
                      title: 'Forza Sincronizzazione Completa',
                      subtitle: 'Scarica tutti i dati dal server e sovrascrivi la cache locale.',
                      buttonText: 'Sincronizza',
                      onAction: () async {
                        await _showConfirmationDialog(
                          context,
                          title: 'Conferma Sincronizzazione',
                          content: 'Sei sicuro di voler forzare una sincronizzazione completa? I dati locali non sincronizzati potrebbero essere persi.',
                          onConfirm: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              await ref.read(guestProvider.notifier).fullSync();
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('✅ Sincronizzazione completata!'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            } catch (e) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('❌ Errore sync: $e'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),

                    const Divider(),

                    _SettingsAction(
                      icon: Icons.delete_sweep,
                      title: 'Pulisci Cache Locale',
                      subtitle: 'Rimuovi tutti i dati degli ospiti dalla memoria locale del dispositivo.',
                      buttonText: 'Pulisci',
                      buttonColor: AppColors.warning,
                      onAction: () async {
                        await _showConfirmationDialog(
                          context,
                          title: 'Conferma Pulizia Cache',
                          content: 'Questa azione rimuoverà tutti i dati degli ospiti salvati localmente. Procedere?',
                          onConfirm: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              await LocalDatabaseService.clearGuestData();
                              await ref.read(guestProvider.notifier).refreshGuests();
                              
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('🗑️ Cache locale pulita.'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            } catch (e) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('❌ Errore pulizia: $e'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),

                    const Divider(),

                    _SettingsAction(
                      icon: Icons.logout,
                      title: 'Logout',
                      subtitle: 'Esci dall\'account corrente.',
                      buttonText: 'Logout',
                      buttonColor: AppColors.error,
                      onAction: () async {
                        final navigator = Navigator.of(context);
                        final confirmed = await _showConfirmationDialog(
                          context,
                          title: 'Conferma Logout',
                          content: 'Sei sicuro di voler effettuare il logout?',
                          onConfirm: () => Navigator.of(context).pop(true),
                        );
                        
                        if (confirmed == true) {
                          await ref.read(authProvider.notifier).signOut();
                          if (!mounted) return;
                          navigator.pushNamedAndRemoveUntil('/login', (route) => false);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // App section
            Text(
              'Applicazione',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            
            _SettingsItem(
              icon: Icons.info_outline,
              title: 'Informazioni App',
              subtitle: 'FESTER v2.0.0',
              onTap: () => _showAppInfo(context),
            ),
            
            _SettingsItem(
              icon: Icons.help_outline,
              title: 'Aiuto',
              subtitle: 'Guida all\'utilizzo',
              onTap: () => _showHelp(context),
            ),
            
            _SettingsItem(
              icon: Icons.restore,
              title: 'Reset Impostazioni',
              subtitle: 'Ripristina configurazione default',
              onTap: () => _resetSettings(context, ref),
              isDestructive: true,
            ),
            
            const SizedBox(height: 32),
            
            // Version info
            Center(
              child: Text(
                'FESTER v2.0.0\nGestione Eventi e Ospiti\nNext-Gen Database Configuration',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textDisabled,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showConfirmationDialog(
    BuildContext context, {
    required String title,
    required String content,
    required VoidCallback onConfirm,
  }) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(true);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: title.contains('Logout') || title.contains('Pulisci')
                  ? AppColors.error
                  : AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Conferma'),
          ),
        ],
      ),
    );
  }

  void _showAppInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('FESTER'),
        content: const Text(
          'App di gestione eventi e ospiti\n\n'
          'Versione: 1.0.0\n'
          'Sviluppato con Flutter e Supabase\n\n'
          'Funzionalità:\n'
          '• Gestione ospiti\n'
          '• Controllo bevande\n'
          '• Scanner QR/Barcode\n'
          '• Sincronizzazione offline',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aiuto'),
        content: const Text(
          'Come usare FESTER:\n\n'
          '1. Dashboard: Visualizza statistiche generali\n'
          '2. Cerca Ospiti: Trova ospiti per nome o codice\n'
          '3. Bar: Gestisci le consumazioni\n'
          '4. Impostazioni: Configura l\'app\n\n'
          'Per scansionare QR codes, usa il pulsante scanner nelle schermate di ricerca.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _resetSettings(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Impostazioni'),
        content: const Text(
          'Sei sicuro di voler ripristinare tutte le impostazioni ai valori predefiniti?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await ref.read(settingsProvider.notifier).resetToDefaults();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Impostazioni ripristinate'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          icon,
          color: isDestructive ? AppColors.error : AppColors.primary,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isDestructive ? AppColors.error : AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _SettingsAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonText;
  final Color? buttonColor;
  final VoidCallback onAction;

  const _SettingsAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    this.buttonColor,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Icon(icon, color: buttonColor ?? AppColors.primary, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: onAction,
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor ?? AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(buttonText),
          ),
        ],
      ),
    );
  }
} 
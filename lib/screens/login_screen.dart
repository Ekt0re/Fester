import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/custom_button.dart';
import '../widgets/register_as_host_button.dart';
import '../utils/app_colors.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _useEmailLogin = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      bool success;
      
      if (_useEmailLogin) {
        // Login con email
        success = await ref.read(authProvider.notifier).signInWithEmail(
          email: _usernameController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        // Login con username (mantiene compatibilità demo)
        success = await ref.read(authProvider.notifier).signInWithUsername(
          username: _usernameController.text.trim(),
          password: _passwordController.text,
        );
      }

      if (success && mounted) {
        Navigator.of(context).pushReplacementNamed('/dashboard');
      } else if (mounted) {
        final authState = ref.read(authProvider);
        _showErrorDialog(authState.error ?? 'Credenziali non valide');
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Errore durante il login: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Errore'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _getInputLabel() {
    final appSettings = ref.watch(settingsProvider);
    
    if (!appSettings.useRealAuth) {
      return 'Username Demo';
    }
    
    return _useEmailLogin ? 'Email' : 'Username';
  }

  Widget _buildDatabaseStatus() {
    final appSettings = ref.watch(settingsProvider);
    final connectionString = ref.read(settingsProvider.notifier).currentConnectionString;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: appSettings.databaseMode.name == 'supabase' 
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            appSettings.databaseMode.name == 'supabase' ? Icons.cloud : Icons.storage,
            size: 16,
            color: appSettings.databaseMode.name == 'supabase' ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'DB: $connectionString',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: appSettings.databaseMode.name == 'supabase' ? Colors.green : Colors.orange,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appSettings = ref.watch(settingsProvider);
    
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo and title
                const Icon(
                  Icons.event,
                  size: 80,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'FESTER 2.0',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Gestione Eventi e Ospiti',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                
                // Database status
                _buildDatabaseStatus(),
                const SizedBox(height: 32),
                
                // Login type toggle (only for real auth)
                if (appSettings.useRealAuth) ...[
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        label: Text('Username'),
                        icon: Icon(Icons.person),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text('Email'),
                        icon: Icon(Icons.email),
                      ),
                    ],
                    selected: {_useEmailLogin},
                    onSelectionChanged: (Set<bool> selection) {
                      setState(() {
                        _useEmailLogin = selection.first;
                        _usernameController.clear(); // Clear on switch
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                ],
                
                // Username/Email field
                CustomTextField(
                  controller: _usernameController,
                  label: _getInputLabel(),
                  icon: _useEmailLogin ? Icons.email_outlined : Icons.person_outline,
                  keyboardType: _useEmailLogin ? TextInputType.emailAddress : TextInputType.text,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Inserisci ${_getInputLabel().toLowerCase()}';
                    }
                    
                    if (_useEmailLogin && !value.contains('@')) {
                      return 'Inserisci un email valida';
                    }
                    
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Password field
                CustomTextField(
                  controller: _passwordController,
                  label: 'Password',
                  icon: Icons.lock_outline,
                  isPassword: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Inserisci la tua password';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                
                // Login button
                CustomButton(
                  text: 'ACCEDI',
                  onPressed: _isLoading ? null : _handleLogin,
                  isLoading: _isLoading,
                ),
                
                const SizedBox(height: 24),
                
                // Auth mode info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            appSettings.useRealAuth ? Icons.security : Icons.science,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            appSettings.useRealAuth ? 'Autenticazione Reale' : 'Modalità Demo',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (!appSettings.useRealAuth) ...[
                        Text(
                          'Username: admin\nPassword: admin123',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ] else ...[
                        Text(
                          appSettings.databaseMode.name == 'supabase'
                              ? 'Usa le credenziali del tuo account Supabase'
                              : 'Usa le credenziali del database MongoDB locale',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Settings link
                TextButton(
                  onPressed: () => Navigator.of(context).pushNamed('/settings'),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.settings, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Configura Database',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                
                // Host Registration Section
                if (appSettings.useRealAuth) ...[
                  const Divider(),
                  const SizedBox(height: 20),
                  
                  Row(
                    children: [
                      const Icon(Icons.star, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Vuoi organizzare un evento?',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  const RegisterAsHostButton(),
                  
                  const SizedBox(height: 8),
                  Text(
                    'Crea il tuo evento e invita i tuoi ospiti',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
} 
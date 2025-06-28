import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/custom_button.dart';
import '../widgets/register_as_host_button.dart';
import '../utils/app_colors.dart';

class HostLoginScreen extends ConsumerStatefulWidget {
  const HostLoginScreen({super.key});

  @override
  ConsumerState<HostLoginScreen> createState() => _HostLoginScreenState();
}

class _HostLoginScreenState extends ConsumerState<HostLoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSignUp = false; // Toggle between login/signup

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      bool success;
      
      if (_isSignUp) {
        // Registrazione nuovo host
        success = await ref.read(authProvider.notifier).signUpWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        
        if (success && mounted) {
          _showSuccessDialog('Account creato con successo! Ora puoi creare il tuo evento.');
        }
      } else {
        // Login host esistente
        success = await ref.read(authProvider.notifier).signInWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }

      if (!success && mounted) {
        final authState = ref.read(authProvider);
        _showErrorDialog(authState.error ?? 'Errore durante l\'operazione');
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Errore: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Successo'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Continua'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: AppColors.error),
            SizedBox(width: 8),
            Text('Errore'),
          ],
        ),
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
    final authState = ref.watch(authProvider);
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Host Portal',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Hero section
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary.withValues(alpha: 0.1),
                        AppColors.primary.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.star,
                        size: 64,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Diventa Host',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Crea e gestisci i tuoi eventi con FESTER',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Database status
                _buildDatabaseStatus(),
                const SizedBox(height: 24),
                
                // Toggle between login/signup
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      label: Text('Accedi'),
                      icon: Icon(Icons.login),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text('Registrati'),
                      icon: Icon(Icons.person_add),
                    ),
                  ],
                  selected: {_isSignUp},
                  onSelectionChanged: (Set<bool> selection) {
                    setState(() {
                      _isSignUp = selection.first;
                      _emailController.clear();
                      _passwordController.clear();
                    });
                  },
                ),
                const SizedBox(height: 24),
                
                // Email field
                CustomTextField(
                  controller: _emailController,
                  label: 'Email',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Inserisci la tua email';
                    }
                    
                    if (!value.contains('@')) {
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
                    
                    if (_isSignUp && value.length < 6) {
                      return 'La password deve essere di almeno 6 caratteri';
                    }
                    
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                
                // Submit button
                CustomButton(
                  text: _isSignUp ? 'CREA ACCOUNT HOST' : 'ACCEDI COME HOST',
                  icon: _isSignUp ? Icons.star_border : Icons.star,
                  onPressed: _isLoading ? null : _handleSubmit,
                  isLoading: _isLoading,
                ),
                
                const SizedBox(height: 24),
                
                // Create event section (only when authenticated)
                if (authState.isAuthenticated) ...[
                  const Divider(),
                  const SizedBox(height: 24),
                  
                  Text(
                    '🎉 Perfetto! Ora puoi creare il tuo evento',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  
                  const RegisterAsHostButton(),
                  
                  const SizedBox(height: 16),
                  
                  TextButton(
                    onPressed: () => Navigator.of(context).pushReplacementNamed('/dashboard'),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.dashboard, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Vai alla Dashboard',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
                
                // Back to main login
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_back, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Torna al Login Principale',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 
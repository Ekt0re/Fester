import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import '../services/SupabaseServicies/supabase_config.dart';
import '../services/SupabaseServicies/deep_link_handler.dart';

class SetNewPasswordPage extends StatefulWidget {
  const SetNewPasswordPage({super.key});
  @override
  State<SetNewPasswordPage> createState() => _SetNewPasswordPageState();
}

class _SetNewPasswordPageState extends State<SetNewPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Non fare signOut! Permetti di arrivare a questa schermata anche da autenticato
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await SupabaseConfig.client.auth.updateUser(
        UserAttributes(password: _passwordController.text),
      );
      if (mounted) {
        // RESETTA recovery mode flag - password cambiata con successo
        DeepLinkHandler.setRecoveryMode(false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password aggiornata! Accedi subito.')),
        );
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore:  ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F0FE),
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(40),
          width: 400,
          decoration: BoxDecoration(
            color: const Color(0xFFB8D4F1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Imposta una nuova password',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Nuova password',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v != null && v.length >= 8 ? null : 'Minimo 8 caratteri',
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5B8BC9),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Salva'),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacementNamed('/login');
                  },
                  child: const Text('Annulla'),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase/email_service.dart';
import '../../services/permission_service.dart';
import '../../theme/app_theme.dart';

class SmtpConfigScreen extends StatefulWidget {
  final String eventId;

  const SmtpConfigScreen({super.key, required this.eventId});

  @override
  State<SmtpConfigScreen> createState() => _SmtpConfigScreenState();
}

class _SmtpConfigScreenState extends State<SmtpConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;
  final _emailService = EmailService();

  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '587');
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _senderNameController = TextEditingController();
  final _senderEmailController = TextEditingController();

  bool _useSSL = true;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isTesting = false;
  bool _obscurePassword = true;
  String? _configId;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _senderNameController.dispose();
    _senderEmailController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    try {
      // Controllo permessi locale (oltre a RLS)
      final userId = _supabase.auth.currentUser?.id;
      final staffResponse =
          await _supabase
              .from('event_staff')
              .select('role:role_id(name)')
              .eq('event_id', widget.eventId)
              .eq('staff_user_id', userId as Object)
              .maybeSingle();

      final role = staffResponse?['role']?['name'] as String?;
      if (!PermissionService.canManageSmtp(role)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('common.permission_denied'.tr())),
          );
          Navigator.pop(context);
        }
        return;
      }

      final response =
          await _supabase
              .from('event_smtp_config')
              .select()
              .eq('event_id', widget.eventId)
              .maybeSingle();

      if (response != null) {
        _configId = response['id'];
        _hostController.text = response['host'] ?? '';
        _portController.text = (response['port'] ?? 587).toString();
        _usernameController.text = response['username'] ?? '';
        _passwordController.text = response['password'] ?? '';
        _senderNameController.text = response['sender_name'] ?? '';
        _senderEmailController.text = response['sender_email'] ?? '';
        _useSSL = response['ssl'] ?? (_portController.text == '465');
      }
    } catch (e) {
      debugPrint('SMTP config load error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final data = {
        'event_id': widget.eventId,
        'host': _hostController.text.trim(),
        'port': int.tryParse(_portController.text) ?? 587,
        'username': _usernameController.text.trim(),
        'password': _passwordController.text,
        'sender_name': _senderNameController.text.trim(),
        'sender_email': _senderEmailController.text.trim(),
        'ssl': _useSSL,
      };

      if (_configId != null) {
        await _supabase
            .from('event_smtp_config')
            .update(data)
            .eq('id', _configId!);
      } else {
        await _supabase.from('event_smtp_config').insert(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('smtp_config.save_success'.tr())),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'smtp_config.save_error'.tr()}$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isTesting = true);

    try {
      final config = SmtpConfig(
        host: _hostController.text.trim(),
        port: int.tryParse(_portController.text) ?? 587,
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        ssl: _useSSL,
        senderName: _senderNameController.text.trim(),
        senderEmail: _senderEmailController.text.trim(),
      );

      final success = await _emailService.testConnection(config);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'smtp_config.test_success'.tr()
                  : 'smtp_config.test_failed'.tr(),
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${'smtp_config.test_error'.tr()}$e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  void _applyGmailPreset() {
    setState(() {
      _hostController.text = 'smtp.gmail.com';
      _portController.text = '587';
      _useSSL = false; // Gmail su 587 usa STARTTLS, non SSL diretto
      if (_senderNameController.text.isEmpty) {
        _senderNameController.text = 'Fester App';
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('smtp_config.use_gmail_preset'.tr())),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('smtp_config.title'.tr())),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('smtp_config.title'.tr()),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(onPressed: _saveConfig, child: Text('common.save'.tr())),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildInfoCard(theme),
            const SizedBox(height: 16),
            _buildGmailTipCard(theme),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionTitle(theme, 'smtp_config.server_section'.tr()),
                TextButton.icon(
                  onPressed: _applyGmailPreset,
                  icon: const Icon(Icons.mail, size: 18),
                  label: Text('smtp_config.use_gmail_preset'.tr()),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            _buildTextField(
              controller: _hostController,
              label: 'smtp_config.host'.tr(),
              hint: 'smtp.gmail.com',
              icon: Icons.dns,
              validator:
                  (v) =>
                      v?.isEmpty == true
                          ? 'validation.field_required'.tr()
                          : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildTextField(
                    controller: _portController,
                    label: 'smtp_config.port'.tr(),
                    hint: '587',
                    icon: Icons.numbers,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock),
                        const SizedBox(width: 12),
                        Expanded(child: Text('smtp_config.ssl'.tr())),
                        Switch(
                          value: _useSSL,
                          onChanged: (v) => setState(() => _useSSL = v),
                          activeColor: AppTheme.primaryLight,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSectionTitle(theme, 'smtp_config.auth_section'.tr()),
            _buildTextField(
              controller: _usernameController,
              label: 'smtp_config.username'.tr(),
              hint: 'your-email@gmail.com',
              icon: Icons.person,
              validator:
                  (v) =>
                      v?.isEmpty == true
                          ? 'validation.field_required'.tr()
                          : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'smtp_config.password'.tr(),
                hintText: '••••••••',
                prefixIcon: const Icon(Icons.key),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed:
                      () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                ),
                filled: true,
                fillColor: theme.cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              validator:
                  (v) =>
                      v?.isEmpty == true
                          ? 'validation.field_required'.tr()
                          : null,
            ),
            const SizedBox(height: 24),
            _buildSectionTitle(theme, 'smtp_config.sender_section'.tr()),
            _buildTextField(
              controller: _senderNameController,
              label: 'smtp_config.sender_name'.tr(),
              hint: 'Fester Events',
              icon: Icons.badge,
              validator:
                  (v) =>
                      v?.isEmpty == true
                          ? 'validation.field_required'.tr()
                          : null,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _senderEmailController,
              label: 'smtp_config.sender_email'.tr(),
              hint: 'noreply@example.com',
              icon: Icons.email,
              keyboardType: TextInputType.emailAddress,
              validator:
                  (v) =>
                      v?.isEmpty == true
                          ? 'validation.field_required'.tr()
                          : null,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _isTesting ? null : _testConnection,
              icon:
                  _isTesting
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.send_and_archive),
              label: Text(
                _isTesting
                    ? 'smtp_config.testing'.tr()
                    : 'smtp_config.test_connection'.tr(),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: theme.colorScheme.secondary,
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'smtp_config.info_message'.tr(),
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    final theme = Theme.of(context);
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: theme.cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildGmailTipCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.security, color: Colors.redAccent, size: 20),
              const SizedBox(width: 8),
              Text(
                'smtp_config.gmail_info_title'.tr(),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'smtp_config.gmail_info_body'.tr(),
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

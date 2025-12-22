import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase/email_service.dart';
import '../../services/supabase/person_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/qr_code_generator.dart';

class CommunicationsScreen extends StatefulWidget {
  final String eventId;
  final String? currentUserRole;

  const CommunicationsScreen({
    super.key,
    required this.eventId,
    this.currentUserRole,
  });

  @override
  State<CommunicationsScreen> createState() => _CommunicationsScreenState();
}

class _CommunicationsScreenState extends State<CommunicationsScreen> {
  final _supabase = Supabase.instance.client;
  final _personService = PersonService();
  final _emailService = EmailService();

  List<Map<String, dynamic>> _participants = [];
  Set<String> _selectedIds = {};
  bool _isLoading = true;
  bool _isSending = false;
  SmtpConfig? _smtpConfig;
  String? _eventName;
  String? _eventDate;
  String? _eventLocation;

  // Stato per la creazione del messaggio
  String _messageType = 'email'; // 'email' o 'sms'
  String? _selectedTemplateId;
  List<Map<String, dynamic>> _templates = [];
  final _subjectController = TextEditingController();
  final _customHtmlController = TextEditingController();
  final _customCssController = TextEditingController();
  bool _useCustomTemplate = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _customHtmlController.dispose();
    _customCssController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Carica partecipanti
      final participants = await _personService.getEventParticipants(
        widget.eventId,
      );

      // Carica info evento
      final eventResponse =
          await _supabase
              .from('event')
              .select('name')
              .eq('id', widget.eventId)
              .single();

      final settingsResponse =
          await _supabase
              .from('event_settings')
              .select('start_at, location')
              .eq('event_id', widget.eventId)
              .maybeSingle();

      // Carica config SMTP
      try {
        final smtpResponse =
            await _supabase
                .from('event_smtp_config')
                .select()
                .eq('event_id', widget.eventId)
                .maybeSingle();

        if (smtpResponse != null) {
          _smtpConfig = SmtpConfig.fromJson(smtpResponse);
        }
      } catch (e) {
        debugPrint('SMTP config not found: $e');
      }

      // Carica templates
      await _loadTemplates();

      if (mounted) {
        setState(() {
          _participants = participants;
          _eventName = eventResponse['name'];
          if (settingsResponse != null) {
            final startAt = settingsResponse['start_at'];
            if (startAt != null) {
              final date = DateTime.parse(startAt);
              _eventDate = '${date.day}/${date.month}/${date.year}';
            }
            _eventLocation = settingsResponse['location'];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'communications.load_error'.tr()}$e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadTemplates() async {
    try {
      final jsonString = await rootBundle.loadString(
        'assets/templates/email_templates.json',
      );
      final data = json.decode(jsonString);
      final templateList = List<Map<String, dynamic>>.from(
        data['templates'] ?? [],
      );

      // Carica il contenuto HTML reale dai file .html se presenti
      for (var i = 0; i < templateList.length; i++) {
        try {
          final htmlPath = 'assets/templates/${templateList[i]['id']}.html';
          final htmlContent = await rootBundle.loadString(htmlPath);
          templateList[i]['html'] = htmlContent;
        } catch (e) {
          debugPrint(
            'Could not load separate HTML for ${templateList[i]['id']}, using JSON content.',
          );
        }
      }

      setState(() {
        _templates = templateList;
        if (_templates.isNotEmpty) {
          _selectedTemplateId = _templates.first['id'];
          _updateControllersWithTemplate(_templates.first);
        }
      });
    } catch (e) {
      debugPrint('Error loading templates: $e');
    }
  }

  void _updateControllersWithTemplate(Map<String, dynamic> template) {
    if (!_useCustomTemplate) {
      _customHtmlController.text = template['html'] ?? '';
      _customCssController.text = template['css'] ?? '';
    }
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedIds.length == _participants.length) {
        _selectedIds.clear();
      } else {
        _selectedIds = _participants.map((p) => p['id'].toString()).toSet();
      }
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _sendMessages() async {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('communications.no_selection'.tr())),
      );
      return;
    }

    if (_messageType == 'email' && _smtpConfig == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('communications.no_smtp_config'.tr()),
          action: SnackBarAction(
            label: 'communications.configure'.tr(),
            onPressed: () {
              context.push('/event/${widget.eventId}/smtp-config');
            },
          ),
        ),
      );
      return;
    }

    // Conferma invio
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('communications.confirm_send_title'.tr()),
            content: Text(
              'communications.confirm_send_message'.tr(
                args: [_selectedIds.length.toString()],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('common.cancel'.tr()),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('communications.send'.tr()),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    setState(() => _isSending = true);

    try {
      if (_messageType == 'email') {
        await _sendEmails();
      } else {
        // SMS non implementato in questa versione
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('communications.sms_not_available'.tr())),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _sendEmails() async {
    final selectedParticipants =
        _participants
            .where((p) => _selectedIds.contains(p['id'].toString()))
            .toList();

    final validEmails = <String, Map<String, dynamic>>{};
    for (final p in selectedParticipants) {
      final person = p['person'];
      final email = person?['email'];
      if (email != null && email.toString().isNotEmpty) {
        validEmails[email] = p;
      }
    }

    if (validEmails.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('communications.no_valid_emails'.tr())),
      );
      return;
    }

    // Mostra progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildProgressDialog(validEmails.length),
    );

    final results = <SendResult>[];

    for (final entry in validEmails.entries) {
      final email = entry.key;
      final participant = entry.value;
      final person = participant['person'];
      final guestName =
          '${person?['first_name'] ?? ''} ${person?['last_name'] ?? ''}'.trim();
      final participationId = participant['id'].toString();
      final qrData = QRCodeGenerator.generate(participationId);

      String htmlBody;
      if (_useCustomTemplate) {
        htmlBody = _processTemplate(
          _customHtmlController.text,
          _customCssController.text,
          guestName,
          qrData,
        );
      } else {
        final template = _templates.firstWhere(
          (t) => t['id'] == _selectedTemplateId,
          orElse: () => _templates.first,
        );
        htmlBody = _processTemplate(
          template['html'],
          template['css'],
          guestName,
          qrData,
        );
      }

      final result = await _emailService.sendEmail(
        config: _smtpConfig!,
        recipientEmail: email,
        subject:
            _subjectController.text.isNotEmpty
                ? _subjectController.text
                : 'Biglietto per $_eventName',
        htmlBody: htmlBody,
      );

      results.add(result);
      // Aggiorna progress (se il dialog è ancora visibile)
    }

    // Chiudi progress dialog
    if (mounted) Navigator.of(context).pop();

    // Mostra report
    final report = BulkSendReport(
      totalSent: results.length,
      successCount: results.where((r) => r.success).length,
      failureCount: results.where((r) => !r.success).length,
      results: results,
    );

    _showReportDialog(report);
  }

  String _processTemplate(
    String html,
    String css,
    String guestName,
    String qrData,
  ) {
    return html
        .replaceAll('{{css}}', css)
        .replaceAll('{{event_name}}', _eventName ?? '')
        .replaceAll('{{guest_name}}', guestName)
        .replaceAll('{{event_date}}', _eventDate ?? '')
        .replaceAll('{{event_location}}', _eventLocation ?? '')
        .replaceAll('{{qr_data}}', Uri.encodeComponent(qrData));
  }

  Widget _buildProgressDialog(int total) {
    return AlertDialog(
      title: Text('communications.sending'.tr()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text('communications.sending_progress'.tr(args: [total.toString()])),
        ],
      ),
    );
  }

  void _showReportDialog(BulkSendReport report) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  report.failureCount == 0 ? Icons.check_circle : Icons.warning,
                  color:
                      report.failureCount == 0 ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text('communications.report_title'.tr()),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildReportRow(
                  Icons.send,
                  'communications.total_sent'.tr(),
                  report.totalSent.toString(),
                ),
                _buildReportRow(
                  Icons.check,
                  'communications.success_count'.tr(),
                  report.successCount.toString(),
                  Colors.green,
                ),
                _buildReportRow(
                  Icons.error,
                  'communications.failure_count'.tr(),
                  report.failureCount.toString(),
                  Colors.red,
                ),
                if (report.failureCount > 0) ...[
                  const Divider(),
                  Text(
                    'communications.failed_emails'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...report.results
                      .where((r) => !r.success)
                      .take(5)
                      .map(
                        (r) => Text(
                          '• ${r.recipientEmail}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('common.close'.tr()),
              ),
            ],
          ),
    );
  }

  Widget _buildReportRow(
    IconData icon,
    String label,
    String value, [
    Color? color,
  ]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('communications.title'.tr())),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('communications.title'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'smtp_config.title'.tr(),
            onPressed: () {
              context.push('/event/${widget.eventId}/smtp-config');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra di selezione e azioni
          _buildActionBar(theme),

          // Tabella partecipanti
          Expanded(child: _buildParticipantsTable(theme)),

          // Pannello composizione messaggio
          _buildMessagePanel(theme),
        ],
      ),
    );
  }

  Widget _buildActionBar(ThemeData theme) {
    final hasEmail =
        _selectedIds.isNotEmpty &&
        _participants.any(
          (p) =>
              _selectedIds.contains(p['id'].toString()) &&
              (p['person']?['email']?.isNotEmpty ?? false),
        );

    final hasPhone =
        _selectedIds.isNotEmpty &&
        _participants.any(
          (p) =>
              _selectedIds.contains(p['id'].toString()) &&
              (p['person']?['phone']?.isNotEmpty ?? false),
        );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Checkbox(
            value:
                _selectedIds.length == _participants.length &&
                _participants.isNotEmpty,
            tristate: true,
            onChanged: (_) => _toggleSelectAll(),
          ),
          Text(
            'communications.selected'.tr(
              args: [_selectedIds.length.toString()],
            ),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(width: 16),
          if (hasEmail)
            Chip(
              avatar: const Icon(Icons.email, size: 16),
              label: Text('communications.email_available'.tr()),
              backgroundColor: Colors.green.withOpacity(0.2),
            ),
          if (hasPhone) ...[
            const SizedBox(width: 8),
            Chip(
              avatar: const Icon(Icons.phone, size: 16),
              label: Text('communications.phone_available'.tr()),
              backgroundColor: Colors.blue.withOpacity(0.2),
            ),
          ],
          const Spacer(),
          if (_smtpConfig == null)
            TextButton.icon(
              onPressed: () {
                context.push('/event/${widget.eventId}/smtp-config');
              },
              icon: const Icon(Icons.warning, color: Colors.orange),
              label: Text('communications.configure_smtp'.tr()),
            ),
        ],
      ),
    );
  }

  Widget _buildParticipantsTable(ThemeData theme) {
    return ListView.builder(
      itemCount: _participants.length,
      itemBuilder: (context, index) {
        final participant = _participants[index];
        final person = participant['person'] ?? {};
        final id = participant['id'].toString();
        final name =
            '${person['first_name'] ?? ''} ${person['last_name'] ?? ''}'.trim();
        final email = person['email'] ?? '';
        final phone = person['phone'] ?? '';
        final hasEmail = email.isNotEmpty;
        final hasPhone = phone.isNotEmpty;

        return ListTile(
          leading: Checkbox(
            value: _selectedIds.contains(id),
            onChanged: (_) => _toggleSelection(id),
          ),
          title: Text(name.isEmpty ? 'communications.no_name'.tr() : name),
          subtitle: Row(
            children: [
              if (hasEmail) ...[
                Icon(Icons.email, size: 14, color: Colors.green),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    email,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
              if (hasEmail && hasPhone) const SizedBox(width: 12),
              if (hasPhone) ...[
                Icon(Icons.phone, size: 14, color: Colors.blue),
                const SizedBox(width: 4),
                Text(phone, style: const TextStyle(fontSize: 12)),
              ],
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!hasEmail && !hasPhone)
                const Icon(Icons.warning, color: Colors.orange, size: 20),
            ],
          ),
          onTap: () => _toggleSelection(id),
        );
      },
    );
  }

  Widget _buildMessagePanel(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(top: BorderSide(color: theme.dividerColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tipo messaggio
          Row(
            children: [
              Expanded(
                child: SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'email',
                      label: Text('Email'),
                      icon: const Icon(Icons.email),
                    ),
                    ButtonSegment(
                      value: 'sms',
                      label: Text('SMS'),
                      icon: const Icon(Icons.sms),
                      enabled: false, // SMS non ancora implementato
                    ),
                  ],
                  selected: {_messageType},
                  onSelectionChanged:
                      (v) => setState(() => _messageType = v.first),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Selezione template
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedTemplateId,
                  decoration: InputDecoration(
                    labelText: 'communications.select_template'.tr(),
                    prefixIcon: const Icon(Icons.article),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  items:
                      _templates
                          .map(
                            (t) => DropdownMenuItem(
                              value: t['id'] as String,
                              child: Text(t['name'] as String),
                            ),
                          )
                          .toList(),
                  onChanged:
                      (v) => setState(() {
                        _selectedTemplateId = v;
                        final template = _templates.firstWhere(
                          (t) => t['id'] == v,
                        );
                        _updateControllersWithTemplate(template);
                      }),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(_useCustomTemplate ? Icons.edit_off : Icons.edit),
                tooltip: 'communications.custom_template'.tr(),
                onPressed: () {
                  final template = _templates.firstWhere(
                    (t) => t['id'] == _selectedTemplateId,
                  );
                  setState(() {
                    _useCustomTemplate = !_useCustomTemplate;
                    if (_useCustomTemplate) {
                      _customHtmlController.text = template['html'] ?? '';
                      _customCssController.text = template['css'] ?? '';
                    }
                  });
                },
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.remove_red_eye),
                tooltip: 'communications.preview'.tr(),
                onPressed: () => _showPreviewDialog(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_useCustomTemplate) ...[
            Text(
              'Editor HTML/CSS',
              style: theme.textTheme.titleSmall?.copyWith(color: Colors.orange),
            ),
            const SizedBox(height: 8),
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: theme.dividerColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _customHtmlController,
                maxLines: null,
                expands: true,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                decoration: const InputDecoration(
                  hintText: 'Codice HTML...',
                  contentPadding: EdgeInsets.all(8),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Oggetto
          TextField(
            controller: _subjectController,
            decoration: InputDecoration(
              labelText: 'communications.subject'.tr(),
              hintText: 'Il tuo biglietto per $_eventName',
              prefixIcon: const Icon(Icons.subject),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Pulsante invio
          ElevatedButton.icon(
            onPressed:
                _isSending || _selectedIds.isEmpty ? null : _sendMessages,
            icon:
                _isSending
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                    : const Icon(Icons.send),
            label: Text(
              _isSending
                  ? 'communications.sending'.tr()
                  : 'communications.send_to'.tr(
                    args: [_selectedIds.length.toString()],
                  ),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: AppTheme.primaryLight,
            ),
          ),
        ],
      ),
    );
  }

  void _showPreviewDialog() {
    final template =
        _useCustomTemplate
            ? {
              'html': _customHtmlController.text,
              'css': _customCssController.text,
            }
            : _templates.firstWhere((t) => t['id'] == _selectedTemplateId);

    final previewHtml = _processTemplate(
      template['html'],
      template['css'],
      'Mario Rossi', // Guest di esempio
      'PREVIEW-QR-123',
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('communications.preview'.tr()),
            content: SizedBox(
              width: 600,
              height: 800,
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          previewHtml,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Nota: L'anteprima visuale nativa è disponibile nell'email inviata. Qui vedi il codice generato.",
                    style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('common.close'.tr()),
              ),
            ],
          ),
    );
  }
}

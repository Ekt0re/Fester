import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../services/supabase/email_service.dart';
import '../../../services/supabase/person_service.dart';
import '../../../utils/qr_code_generator.dart';

import 'communications/participant_selection_step.dart';
import 'communications/template_config_step.dart';
import 'communications/send_review_step.dart';
import 'communications/step_indicator.dart';
import 'communications/template_model.dart';

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

  int _currentStep = 0;
  bool _isLoading = true;
  bool _isSending = false;

  // Dati Caricati
  List<Map<String, dynamic>> _participants = [];
  List<TemplateModel> _templates = [];
  SmtpConfig? _smtpConfig;
  String? _eventName;
  String? _eventDate;
  String? _eventLocation;

  // Stato Selezione
  Set<String> _selectedIds = {};
  TemplateModel? _selectedTemplate;
  final _subjectController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Carica partecipanti
      final participants = await _personService.getEventParticipants(
        widget.eventId,
      );

      // 2. Carica info evento
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

      // 3. Carica config SMTP
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

      // 4. Carica templates
      await _loadTemplates();

      if (mounted) {
        setState(() {
          _participants = participants;
          _eventName = eventResponse['name'];
          if (settingsResponse != null) {
            final startAt = settingsResponse['start_at'];
            if (startAt != null) {
              final date = DateTime.parse(startAt);
              _eventDate = DateFormat('dd/MM/yyyy').format(date);
            }
            _eventLocation = settingsResponse['location'] ?? '';
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('communications.load_error'.tr() + e.toString()),
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadTemplates() async {
    try {
      // Carichiamo l'elenco degli asset dal manifesto di Flutter
      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = json.decode(manifestContent);

      // Filtriamo per i file .html nella cartella templates
      final templatePaths =
          manifestMap.keys
              .where(
                (String key) =>
                    key.startsWith('assets/templates/') &&
                    key.endsWith('.html'),
              )
              .toList();

      List<TemplateModel> models = [];
      for (var path in templatePaths) {
        final htmlContent = await rootBundle.loadString(path);

        // Estraiamo il nome dal file (es: default_ticket.html -> DEFAULT TICKET)
        final fileName = path.split('/').last.split('.').first;
        final name = fileName.replaceAll('_', ' ').toUpperCase();

        models.add(
          TemplateModel(
            id: fileName,
            name: name,
            description: 'Template caricato da $fileName.html',
            html: htmlContent,
            css: '', // Il CSS è già incluso negli <style> dei file HTML
            variables: [], // Variabili dinamiche
          ),
        );
      }

      if (mounted) {
        setState(() {
          _templates = models;
          if (_templates.isNotEmpty) _selectedTemplate = _templates.first;
        });
      }
    } catch (e) {
      debugPrint('Error loading templates: $e');
    }
  }

  void _onNextStep() {
    if (_currentStep == 0 && _selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('communications.no_selection'.tr())),
      );
      return;
    }

    if (_currentStep == 1 && _selectedTemplate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Seleziona un template')));
      return;
    }

    if (_currentStep == 2) {
      _sendEmails();
      return;
    }

    setState(() => _currentStep++);
  }

  void _onPrevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      context.pop();
    }
  }

  Future<void> _sendEmails() async {
    if (_smtpConfig == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('communications.no_smtp_config'.tr()),
          action: SnackBarAction(
            label: 'communications.configure'.tr(),
            onPressed:
                () => context.push('/event/${widget.eventId}/smtp-config'),
          ),
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      final selectedParticipants =
          _participants
              .where((p) => _selectedIds.contains(p['id'].toString()))
              .toList();
      final results = <SendResult>[];

      for (final participant in selectedParticipants) {
        final email = participant['person']?['email'];
        if (email == null || email.isEmpty) continue;

        final person = participant['person'];
        final guestName =
            '${person?['first_name'] ?? ''} ${person?['last_name'] ?? ''}'
                .trim();
        final participationId = participant['id'].toString();
        final qrData = QRCodeGenerator.generate(participationId);

        final htmlBody = _selectedTemplate!.html
            .replaceAll('{{event_name}}', _eventName ?? '')
            .replaceAll('{{guest_name}}', guestName)
            .replaceAll('{{event_date}}', _eventDate ?? '')
            .replaceAll('{{event_location}}', _eventLocation ?? '')
            .replaceAll('{{qr_data}}', Uri.encodeComponent(qrData));

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
      }

      if (mounted) {
        _showReport(results);
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showReport(List<SendResult> results) {
    final successCount = results.where((r) => r.success).length;
    final failureCount = results.length - successCount;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('communications.report_title'.tr()),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.check_circle, color: Colors.green),
                  title: Text('Inviati: $successCount'),
                ),
                ListTile(
                  leading: const Icon(Icons.error, color: Colors.red),
                  title: Text('Falliti: $failureCount'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('OK'),
              ),
            ],
          ),
    ).then((_) {
      if (mounted) context.pop();
    });
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
        title: Text(
          'communications.title'.tr(),
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: _onPrevStep,
        ),
        actions: [
          if (_currentStep == 0)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed:
                  () => context.push('/event/${widget.eventId}/smtp-config'),
            ),
        ],
      ),
      body: Column(
        children: [
          CommunicationsStepIndicator(
            currentStep: _currentStep,
            steps: const ['Destinatari', 'Template', 'Inviato'],
          ),
          Expanded(child: _buildCurrentStep()),
          _buildBottomBar(theme),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return ParticipantSelectionStep(
          participants: _participants,
          selectedIds: _selectedIds,
          onToggle:
              (id) => setState(
                () =>
                    _selectedIds.contains(id)
                        ? _selectedIds.remove(id)
                        : _selectedIds.add(id),
              ),
          onToggleAll:
              () => setState(
                () =>
                    _selectedIds.length == _participants.length
                        ? _selectedIds.clear()
                        : _selectedIds =
                            _participants
                                .map((p) => p['id'].toString())
                                .toSet(),
              ),
        );
      case 1:
        return TemplateConfigStep(
          templates: _templates,
          selectedTemplate: _selectedTemplate,
          onTemplateSelected: (t) {
            setState(() {
              _selectedTemplate = t;
              // Se è un template custom (es. caricato da PC), lo aggiungiamo alla lista se non presente
              if (t.id.startsWith('custom_') &&
                  !_templates.any((tmp) => tmp.id == t.id)) {
                _templates.insert(0, t); // Mostra per primo nella lista
              }
            });
          },
          eventName: _eventName ?? '',
          eventDate: _eventDate ?? '',
          eventLocation: _eventLocation ?? '',
        );
      case 2:
        return SendReviewStep(
          recipientCount: _selectedIds.length,
          templateName: _selectedTemplate?.name ?? '',
          subject: _subjectController.text,
          isSending: _isSending,
          onSend: _sendEmails,
        );
      default:
        return const Center(child: Text('Step non trovato'));
    }
  }

  Widget _buildBottomBar(ThemeData theme) {
    if (_currentStep == 2) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _onPrevStep,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('INDIETRO'),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _onNextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE94560),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _currentStep == 2 ? 'INVIA' : 'AVANTI',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

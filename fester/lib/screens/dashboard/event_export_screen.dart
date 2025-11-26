import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

enum ExportFormat { csv, excel, pdf }

class EventExportScreen extends StatefulWidget {
  final String eventId;
  final String eventName;

  const EventExportScreen({
    super.key,
    required this.eventId,
    required this.eventName,
  });

  @override
  State<EventExportScreen> createState() => _EventExportScreenState();
}

class _EventExportScreenState extends State<EventExportScreen> {
  ExportFormat _selectedFormat = ExportFormat.csv;
  bool _isExporting = false;

  // Event data
  bool _includeEventInfo = true;
  bool _includeEventSettings = false;
  bool _includeEventStats = true;

  // Person + Participation data (merged as requested)
  bool _includePersonName = true;
  bool _includePersonEmail = true;
  bool _includePersonPhone = true;
  bool _includePersonBirthDate = false;
  bool _includePersonImage = false;
  bool _includePersonNotes = false;
  bool _includeParticipationId = true;
  bool _includeParticipationStatus = true;
  bool _includeParticipationTimestamps = true;
  bool _includeParticipationReferrer = false;
  bool _includeParticipationGuests = false;
  bool _includeParticipationTable = false;

  // Transactions
  bool _includeTransactionHistory = false;
  bool _includeTransactionDetails = false;
  bool _includeTransactionStaff = false;
  bool _includeTransactionSummary = false;
  bool _includeTransactionBalance = false;

  // Event Staff
  bool _includeEventStaffList = false;
  bool _includeEventStaffDetails = false;
  bool _includeEventStaffRoles = false;
  bool _includeEventStaffContacts = false;

  // Groups
  bool _includeGroupsList = false;
  bool _includeGroupsMembers = false;
  bool _includeSubgroups = false;
  bool _includeGroupsHierarchy = false;

  // Menu
  bool _includeMenuItems = false;
  bool _includeMenuStats = false;
  bool _includeMenuAlcoholic = false;

  int get _estimatedRecords {
    int count = 0;
    if (_includeEventInfo) count += 5;
    if (_includeEventStats) count += 10;
    if (_includePersonName || _includePersonEmail) count += 100; // estimate
    if (_includeTransactionHistory) count += 500;
    if (_includeEventStaffList) count += 20;
    if (_includeGroupsList) count += 15;
    if (_includeMenuItems) count += 30;
    return count;
  }

  double get _estimatedSizeMB {
    return (_estimatedRecords * 0.002); // rough estimate
  }

  Future<void> _performExport() async {
    setState(() => _isExporting = true);

    try {
      // Simulate export process
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Export ${_selectedFormat.name.toUpperCase()} completato!',
            style: GoogleFonts.outfit(),
          ),
          backgroundColor: AppTheme.statusConfirmed,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore durante export: $e'),
          backgroundColor: AppTheme.errorLight,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Esporta Dati Evento',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Event name
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        isDark ? AppTheme.primaryDark : AppTheme.primaryLight,
                        isDark
                            ? AppTheme.primaryDark.withOpacity(0.7)
                            : AppTheme.primaryLight.withOpacity(0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.event,
                        color: isDark ? Colors.black : Colors.white,
                        size: 32,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.eventName,
                              style: GoogleFonts.outfit(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.black : Colors.white,
                              ),
                            ),
                            Text(
                              'Seleziona i dati da esportare',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                color:
                                    isDark
                                        ? Colors.black87
                                        : Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Format selection
                _buildSection(
                  theme: theme,
                  title: 'FORMATO EXPORT',
                  icon: Icons.description,
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildFormatOption(
                          theme,
                          ExportFormat.csv,
                          'CSV',
                          Icons.table_chart,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildFormatOption(
                          theme,
                          ExportFormat.excel,
                          'Excel',
                          Icons.grid_on,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildFormatOption(
                          theme,
                          ExportFormat.pdf,
                          'PDF',
                          Icons.picture_as_pdf,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Data selection
                _buildSection(
                  theme: theme,
                  title: 'SELEZIONA DATI DA INCLUDERE',
                  icon: Icons.checklist,
                  child: Column(
                    children: [
                      _buildDataCategory(
                        theme: theme,
                        title: 'Dati Evento',
                        icon: Icons.event_note,
                        children: [
                          _buildCheckbox(
                            'Informazioni base',
                            _includeEventInfo,
                            (v) => setState(() => _includeEventInfo = v!),
                          ),
                          _buildCheckbox(
                            'Impostazioni evento',
                            _includeEventSettings,
                            (v) => setState(() => _includeEventSettings = v!),
                          ),
                          _buildCheckbox(
                            'Statistiche generali',
                            _includeEventStats,
                            (v) => setState(() => _includeEventStats = v!),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildDataCategory(
                        theme: theme,
                        title: 'Dati Ospiti (Persone & Partecipazioni)',
                        icon: Icons.people,
                        children: [
                          Text(
                            'Dati Persona:',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          _buildCheckbox(
                            'Nome completo',
                            _includePersonName,
                            (v) => setState(() => _includePersonName = v!),
                          ),
                          _buildCheckbox(
                            'Email',
                            _includePersonEmail,
                            (v) => setState(() => _includePersonEmail = v!),
                          ),
                          _buildCheckbox(
                            'Telefono',
                            _includePersonPhone,
                            (v) => setState(() => _includePersonPhone = v!),
                          ),
                          _buildCheckbox(
                            'Data di nascita',
                            _includePersonBirthDate,
                            (v) => setState(() => _includePersonBirthDate = v!),
                          ),
                          _buildCheckbox(
                            'Immagine profilo',
                            _includePersonImage,
                            (v) => setState(() => _includePersonImage = v!),
                          ),
                          _buildCheckbox(
                            'Note',
                            _includePersonNotes,
                            (v) => setState(() => _includePersonNotes = v!),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Dati Partecipazione:',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          _buildCheckbox(
                            'ID partecipazione',
                            _includeParticipationId,
                            (v) => setState(() => _includeParticipationId = v!),
                          ),
                          _buildCheckbox(
                            'Stato partecipazione',
                            _includeParticipationStatus,
                            (v) => setState(
                              () => _includeParticipationStatus = v!,
                            ),
                          ),
                          _buildCheckbox(
                            'Timestamp creazione/aggiornamento',
                            _includeParticipationTimestamps,
                            (v) => setState(
                              () => _includeParticipationTimestamps = v!,
                            ),
                          ),
                          _buildCheckbox(
                            'Invitato da (referrer)',
                            _includeParticipationReferrer,
                            (v) => setState(
                              () => _includeParticipationReferrer = v!,
                            ),
                          ),
                          _buildCheckbox(
                            'Numero accompagnatori',
                            _includeParticipationGuests,
                            (v) => setState(
                              () => _includeParticipationGuests = v!,
                            ),
                          ),
                          _buildCheckbox(
                            'Tavolo assegnato',
                            _includeParticipationTable,
                            (v) =>
                                setState(() => _includeParticipationTable = v!),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildDataCategory(
                        theme: theme,
                        title: 'Transazioni',
                        icon: Icons.attach_money,
                        children: [
                          _buildCheckbox(
                            'Storico completo',
                            _includeTransactionHistory,
                            (v) =>
                                setState(() => _includeTransactionHistory = v!),
                          ),
                          _buildCheckbox(
                            'Dettagli transazione (ID, timestamp, tipo)',
                            _includeTransactionDetails,
                            (v) =>
                                setState(() => _includeTransactionDetails = v!),
                          ),
                          _buildCheckbox(
                            'Staff che ha effettuato la transazione',
                            _includeTransactionStaff,
                            (v) =>
                                setState(() => _includeTransactionStaff = v!),
                          ),
                          _buildCheckbox(
                            'Riepilogo per tipo',
                            _includeTransactionSummary,
                            (v) =>
                                setState(() => _includeTransactionSummary = v!),
                          ),
                          _buildCheckbox(
                            'Saldo finale',
                            _includeTransactionBalance,
                            (v) =>
                                setState(() => _includeTransactionBalance = v!),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildDataCategory(
                        theme: theme,
                        title: 'Staff Evento',
                        icon: Icons.badge,
                        children: [
                          _buildCheckbox(
                            'Lista staff assegnato',
                            _includeEventStaffList,
                            (v) => setState(() => _includeEventStaffList = v!),
                          ),
                          _buildCheckbox(
                            'Dati personali staff',
                            _includeEventStaffDetails,
                            (v) =>
                                setState(() => _includeEventStaffDetails = v!),
                          ),
                          _buildCheckbox(
                            'Ruoli e permessi',
                            _includeEventStaffRoles,
                            (v) => setState(() => _includeEventStaffRoles = v!),
                          ),
                          _buildCheckbox(
                            'Email e contatti',
                            _includeEventStaffContacts,
                            (v) =>
                                setState(() => _includeEventStaffContacts = v!),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildDataCategory(
                        theme: theme,
                        title: 'Gruppi e Sottogruppi',
                        icon: Icons.group_work,
                        children: [
                          _buildCheckbox(
                            'Lista gruppi evento',
                            _includeGroupsList,
                            (v) => setState(() => _includeGroupsList = v!),
                          ),
                          _buildCheckbox(
                            'Membri per gruppo',
                            _includeGroupsMembers,
                            (v) => setState(() => _includeGroupsMembers = v!),
                          ),
                          _buildCheckbox(
                            'Sottogruppi',
                            _includeSubgroups,
                            (v) => setState(() => _includeSubgroups = v!),
                          ),
                          _buildCheckbox(
                            'Gerarchia gruppi',
                            _includeGroupsHierarchy,
                            (v) => setState(() => _includeGroupsHierarchy = v!),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildDataCategory(
                        theme: theme,
                        title: 'Menù',
                        icon: Icons.restaurant_menu,
                        children: [
                          _buildCheckbox(
                            'Lista items menù',
                            _includeMenuItems,
                            (v) => setState(() => _includeMenuItems = v!),
                          ),
                          _buildCheckbox(
                            'Statistiche vendite',
                            _includeMenuStats,
                            (v) => setState(() => _includeMenuStats = v!),
                          ),
                          _buildCheckbox(
                            'Indicatore items alcolici',
                            _includeMenuAlcoholic,
                            (v) => setState(() => _includeMenuAlcoholic = v!),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Preview
                _buildSection(
                  theme: theme,
                  title: 'ANTEPRIMA',
                  icon: Icons.preview,
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildPreviewStat(
                          theme,
                          Icons.dataset,
                          '~$_estimatedRecords',
                          'record',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildPreviewStat(
                          theme,
                          Icons.storage,
                          '~${_estimatedSizeMB.toStringAsFixed(1)} MB',
                          'dimensione',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Download button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isExporting ? null : _performExport,
                    icon:
                        _isExporting
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : const Icon(Icons.download, size: 28),
                    label: Text(
                      _isExporting ? 'ESPORTAZIONE...' : 'SCARICA REPORT',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isDark ? AppTheme.primaryDark : AppTheme.primaryLight,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required ThemeData theme,
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary, size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildFormatOption(
    ThemeData theme,
    ExportFormat format,
    String label,
    IconData icon,
  ) {
    final isSelected = _selectedFormat == format;
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: () => setState(() => _selectedFormat = format),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? (isDark ? AppTheme.primaryDark : AppTheme.primaryLight)
                      .withOpacity(0.1)
                  : theme.colorScheme.surface,
          border: Border.all(
            color:
                isSelected
                    ? (isDark ? AppTheme.primaryDark : AppTheme.primaryLight)
                    : theme.colorScheme.outline.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color:
                  isSelected
                      ? (isDark ? AppTheme.primaryDark : AppTheme.primaryLight)
                      : theme.colorScheme.onSurface.withOpacity(0.6),
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color:
                    isSelected
                        ? (isDark
                            ? AppTheme.primaryDark
                            : AppTheme.primaryLight)
                        : theme.colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataCategory({
    required ThemeData theme,
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _buildCheckbox(
    String label,
    bool value,
    ValueChanged<bool?> onChanged,
  ) {
    return CheckboxListTile(
      title: Text(label, style: GoogleFonts.outfit(fontSize: 14)),
      value: value,
      onChanged: onChanged,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  Widget _buildPreviewStat(
    ThemeData theme,
    IconData icon,
    String value,
    String label,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io'
    show
        File; // Restricted import to avoid conflict if any, though dart:io is core
import '../../../theme/app_theme.dart';
import '../../../services/export_service.dart';

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
      final service = ExportService();
      final xFile = await service.exportData(
        eventId: widget.eventId,
        eventName: widget.eventName,
        format: _selectedFormat.name,
        includeEventInfo: _includeEventInfo,
        includeEventSettings: _includeEventSettings,
        includeEventStats: _includeEventStats,
        includePersonName: _includePersonName,
        includePersonEmail: _includePersonEmail,
        includePersonPhone: _includePersonPhone,
        includePersonBirthDate: _includePersonBirthDate,
        includePersonImage: _includePersonImage,
        includePersonNotes: _includePersonNotes,
        includeParticipationId: _includeParticipationId,
        includeParticipationStatus: _includeParticipationStatus,
        includeParticipationTimestamps: _includeParticipationTimestamps,
        includeParticipationReferrer: _includeParticipationReferrer,
        includeParticipationGuests: _includeParticipationGuests,
        includeParticipationTable: _includeParticipationTable,
        includeTransactionHistory: _includeTransactionHistory,
        includeTransactionDetails: _includeTransactionDetails,
        includeTransactionStaff: _includeTransactionStaff,
        includeTransactionSummary: _includeTransactionSummary,
        includeTransactionBalance: _includeTransactionBalance,
        includeEventStaffList: _includeEventStaffList,
        includeEventStaffDetails: _includeEventStaffDetails,
        includeEventStaffRoles: _includeEventStaffRoles,
        includeEventStaffContacts: _includeEventStaffContacts,
        includeGroupsList: _includeGroupsList,
        includeGroupsMembers: _includeGroupsMembers,
        includeSubgroups: _includeSubgroups,
        includeGroupsHierarchy: _includeGroupsHierarchy,
        includeMenuItems: _includeMenuItems,
        includeMenuStats: _includeMenuStats,
        includeMenuAlcoholic: _includeMenuAlcoholic,
      );

      if (!mounted) return;

      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.windows ||
              defaultTargetPlatform == TargetPlatform.macOS ||
              defaultTargetPlatform == TargetPlatform.linux)) {
        // Desktop: Save File Modal
        final outputPath = await FilePicker.platform.saveFile(
          dialogTitle: 'export.save_as'.tr(),
          fileName: xFile.name,
          lockParentWindow: true,
        );

        if (outputPath != null) {
          final file = File(outputPath);
          await file.writeAsBytes(await xFile.readAsBytes());
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'export.success'.tr(
                    args: [_selectedFormat.name.toUpperCase()],
                  ),
                  style: GoogleFonts.outfit(),
                ),
                backgroundColor: AppTheme.statusConfirmed,
              ),
            );
          }
        }
      } else {
        // Mobile / Web
        if (kIsWeb) {
          if (mounted) {
            showDialog(
              context: context,
              builder:
                  (context) => AlertDialog(
                    title: Text('export.file_ready'.tr()),
                    content: Text('export.file_ready_msg'.tr()),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Share.shareXFiles([
                            xFile,
                          ], text: 'Export ${widget.eventName}');
                        },
                        child: Text('export.download_share'.tr()),
                      ),
                    ],
                  ),
            );
          }
        } else {
          await Share.shareXFiles([xFile], text: 'Export ${widget.eventName}');
        }
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${'export.error'.tr()}$e'),
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
          'export.title'.tr(),
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
                              'export.subtitle'.tr(),
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
                  title: 'export.format_title'.tr(),
                  icon: Icons.description,
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildFormatOption(
                          theme,
                          ExportFormat.csv,
                          'export.format_csv'.tr(),
                          Icons.table_chart,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildFormatOption(
                          theme,
                          ExportFormat.excel,
                          'export.format_excel'.tr(),
                          Icons.grid_on,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildFormatOption(
                          theme,
                          ExportFormat.pdf,
                          'export.format_pdf'.tr(),
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
                  title: 'export.data_selection_title'.tr(),
                  icon: Icons.checklist,
                  child: Column(
                    children: [
                      _buildDataCategory(
                        theme: theme,
                        title: 'export.category.event'.tr(),
                        icon: Icons.event_note,
                        children: [
                          _buildCheckbox(
                            'export.option.event_info'.tr(),
                            _includeEventInfo,
                            (v) => setState(() => _includeEventInfo = v!),
                          ),
                          _buildCheckbox(
                            'export.option.event_settings'.tr(),
                            _includeEventSettings,
                            (v) => setState(() => _includeEventSettings = v!),
                          ),
                          _buildCheckbox(
                            'export.option.event_stats'.tr(),
                            _includeEventStats,
                            (v) => setState(() => _includeEventStats = v!),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildDataCategory(
                        theme: theme,
                        title: 'export.category.guests'.tr(),
                        icon: Icons.people,
                        children: [
                          Text(
                            'export.subcategory.person'.tr(),
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          _buildCheckbox(
                            'export.option.person_name'.tr(),
                            _includePersonName,
                            (v) => setState(() => _includePersonName = v!),
                          ),
                          _buildCheckbox(
                            'export.option.person_email'.tr(),
                            _includePersonEmail,
                            (v) => setState(() => _includePersonEmail = v!),
                          ),
                          _buildCheckbox(
                            'export.option.person_phone'.tr(),
                            _includePersonPhone,
                            (v) => setState(() => _includePersonPhone = v!),
                          ),
                          _buildCheckbox(
                            'export.option.person_birth_date'.tr(),
                            _includePersonBirthDate,
                            (v) => setState(() => _includePersonBirthDate = v!),
                          ),
                          _buildCheckbox(
                            'export.option.person_image'.tr(),
                            _includePersonImage,
                            (v) => setState(() => _includePersonImage = v!),
                          ),
                          _buildCheckbox(
                            'export.option.person_notes'.tr(),
                            _includePersonNotes,
                            (v) => setState(() => _includePersonNotes = v!),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'export.subcategory.participation'.tr(),
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          _buildCheckbox(
                            'export.option.participation_id'.tr(),
                            _includeParticipationId,
                            (v) => setState(() => _includeParticipationId = v!),
                          ),
                          _buildCheckbox(
                            'export.option.participation_status'.tr(),
                            _includeParticipationStatus,
                            (v) => setState(
                              () => _includeParticipationStatus = v!,
                            ),
                          ),
                          _buildCheckbox(
                            'export.option.participation_timestamps'.tr(),
                            _includeParticipationTimestamps,
                            (v) => setState(
                              () => _includeParticipationTimestamps = v!,
                            ),
                          ),
                          _buildCheckbox(
                            'export.option.participation_referrer'.tr(),
                            _includeParticipationReferrer,
                            (v) => setState(
                              () => _includeParticipationReferrer = v!,
                            ),
                          ),
                          _buildCheckbox(
                            'export.option.participation_guests'.tr(),
                            _includeParticipationGuests,
                            (v) => setState(
                              () => _includeParticipationGuests = v!,
                            ),
                          ),
                          _buildCheckbox(
                            'export.option.participation_table'.tr(),
                            _includeParticipationTable,
                            (v) =>
                                setState(() => _includeParticipationTable = v!),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildDataCategory(
                        theme: theme,
                        title: 'export.category.transactions'.tr(),
                        icon: Icons.attach_money,
                        children: [
                          _buildCheckbox(
                            'export.option.transaction_history'.tr(),
                            _includeTransactionHistory,
                            (v) =>
                                setState(() => _includeTransactionHistory = v!),
                          ),
                          _buildCheckbox(
                            'export.option.transaction_details'.tr(),
                            _includeTransactionDetails,
                            (v) =>
                                setState(() => _includeTransactionDetails = v!),
                          ),
                          _buildCheckbox(
                            'export.option.transaction_staff'.tr(),
                            _includeTransactionStaff,
                            (v) =>
                                setState(() => _includeTransactionStaff = v!),
                          ),
                          _buildCheckbox(
                            'export.option.transaction_summary'.tr(),
                            _includeTransactionSummary,
                            (v) =>
                                setState(() => _includeTransactionSummary = v!),
                          ),
                          _buildCheckbox(
                            'export.option.transaction_balance'.tr(),
                            _includeTransactionBalance,
                            (v) =>
                                setState(() => _includeTransactionBalance = v!),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildDataCategory(
                        theme: theme,
                        title: 'export.category.staff'.tr(),
                        icon: Icons.badge,
                        children: [
                          _buildCheckbox(
                            'export.option.staff_list'.tr(),
                            _includeEventStaffList,
                            (v) => setState(() => _includeEventStaffList = v!),
                          ),
                          _buildCheckbox(
                            'export.option.staff_details'.tr(),
                            _includeEventStaffDetails,
                            (v) =>
                                setState(() => _includeEventStaffDetails = v!),
                          ),
                          _buildCheckbox(
                            'export.option.staff_roles'.tr(),
                            _includeEventStaffRoles,
                            (v) => setState(() => _includeEventStaffRoles = v!),
                          ),
                          _buildCheckbox(
                            'export.option.staff_contacts'.tr(),
                            _includeEventStaffContacts,
                            (v) =>
                                setState(() => _includeEventStaffContacts = v!),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildDataCategory(
                        theme: theme,
                        title: 'export.category.groups'.tr(),
                        icon: Icons.group_work,
                        children: [
                          _buildCheckbox(
                            'export.option.groups_list'.tr(),
                            _includeGroupsList,
                            (v) => setState(() => _includeGroupsList = v!),
                          ),
                          _buildCheckbox(
                            'export.option.groups_members'.tr(),
                            _includeGroupsMembers,
                            (v) => setState(() => _includeGroupsMembers = v!),
                          ),
                          _buildCheckbox(
                            'export.option.subgroups'.tr(),
                            _includeSubgroups,
                            (v) => setState(() => _includeSubgroups = v!),
                          ),
                          _buildCheckbox(
                            'export.option.groups_hierarchy'.tr(),
                            _includeGroupsHierarchy,
                            (v) => setState(() => _includeGroupsHierarchy = v!),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildDataCategory(
                        theme: theme,
                        title: 'export.category.menu'.tr(),
                        icon: Icons.restaurant_menu,
                        children: [
                          _buildCheckbox(
                            'export.option.menu_items'.tr(),
                            _includeMenuItems,
                            (v) => setState(() => _includeMenuItems = v!),
                          ),
                          _buildCheckbox(
                            'export.option.menu_stats'.tr(),
                            _includeMenuStats,
                            (v) => setState(() => _includeMenuStats = v!),
                          ),
                          _buildCheckbox(
                            'export.option.menu_alcoholic'.tr(),
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
                  title: 'export.preview_title'.tr(),
                  icon: Icons.preview,
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildPreviewStat(
                          theme,
                          Icons.dataset,
                          '~$_estimatedRecords',
                          'export.preview_record'.tr(),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildPreviewStat(
                          theme,
                          Icons.storage,
                          '~${_estimatedSizeMB.toStringAsFixed(1)} MB',
                          'export.preview_size'.tr(),
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
                      _isExporting
                          ? 'export.button_exporting'.tr()
                          : 'export.button_download'.tr(),
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

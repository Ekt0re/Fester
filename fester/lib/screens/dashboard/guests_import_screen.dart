import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/SupabaseServicies/bulk_import_service.dart';
import '../../services/SupabaseServicies/person_service.dart';
import '../../services/SupabaseServicies/participation_service.dart';

class GuestsImportScreen extends StatefulWidget {
  final String eventId;

  const GuestsImportScreen({super.key, required this.eventId});

  @override
  State<GuestsImportScreen> createState() => _GuestsImportScreenState();
}

class _GuestsImportScreenState extends State<GuestsImportScreen> {
  final BulkImportService _importService = BulkImportService();
  final PersonService _personService = PersonService();
  final ParticipationService _participationService = ParticipationService();

  int _currentStep = 0;
  bool _isLoading = false;

  // Step 1: File
  PlatformFile? _selectedFile;
  List<List<dynamic>> _rawRows = [];
  int _headerRowIndex = 0; // 0-based
  int _firstDataRowIndex = 1; // 0-based

  // Step 2: Mapping
  // Key: App Field (e.g. 'first_name'), Value: Column Index in CSV/Excel
  final Map<String, int> _columnMapping = {};
  List<String> _fileHeaders = [];

  // Step 3: Processing
  List<ImportResult> _results = [];
  int _successCount = 0;
  int _failCount = 0;
  bool _isProcessing = false;
  double _progress = 0.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.primary,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: theme.colorScheme.onPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'import_guests.title'.tr(),
          style: GoogleFonts.outfit(
            color: theme.colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Stepper(
        type: StepperType.horizontal,
        currentStep: _currentStep,
        onStepContinue: _onStepContinue,
        onStepCancel: _onStepCancel,
        controlsBuilder: _controlsBuilder,
        steps: [
          Step(
            title: Text('import_guests.file_step_title'.tr()),
            content: _buildFileSelectionStep(theme),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.editing,
          ),
          Step(
            title: Text('import_guests.mapping'.tr()),
            content: _buildMappingStep(theme),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.editing,
          ),
          Step(
            title: Text('import_guests.importing'.tr()),
            content: _buildProcessingStep(theme),
            isActive: _currentStep >= 2,
            state: _currentStep > 2 ? StepState.complete : StepState.editing,
          ),
          Step(
            title: Text('import_guests.results'.tr()),
            content: _buildResultsStep(theme),
            isActive: _currentStep >= 3,
            state: _currentStep == 3 ? StepState.complete : StepState.editing,
          ),
        ],
      ),
    );
  }

  // --- Step 1: File Selection ---

  Widget _buildFileSelectionStep(ThemeData theme) {
    return Column(
      children: [
        const SizedBox(height: 20),
        Icon(Icons.upload_file, size: 64, color: theme.colorScheme.primary),
        const SizedBox(height: 20),
        Text(
          'import_guests.select_file_description'.tr(),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 20),
        if (_selectedFile == null) ...[
          ElevatedButton.icon(
            onPressed: _pickFile,
            icon: const Icon(Icons.folder_open),
            label: Text('import_guests.choose_file'.tr()),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ] else ...[
          Card(
            child: ListTile(
              leading: const Icon(Icons.insert_drive_file),
              title: Text(_selectedFile!.name),
              subtitle: Text(
                '${(_selectedFile!.size / 1024).toStringAsFixed(2)} KB',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _selectedFile = null;
                    _rawRows = [];
                    _fileHeaders = [];
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          // File Loaded: Show options
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        decoration: InputDecoration(
                          labelText: 'import_guests.header_row'.tr(),
                        ),
                        value: _headerRowIndex,
                        items: List.generate(10, (index) {
                          return DropdownMenuItem(
                            value: index,
                            child: Text(
                              'import_guests.row_prefix'.tr(
                                args: [(index + 1).toString()],
                              ),
                            ),
                          );
                        }),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _headerRowIndex = val;
                              if (_firstDataRowIndex <= val) {
                                _firstDataRowIndex = val + 1;
                              }
                              if (_rawRows.length > val) {
                                _fileHeaders =
                                    _rawRows[val]
                                        .map((e) => e.toString())
                                        .toList();
                                _autoMapHeaders();
                              }
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        decoration: InputDecoration(
                          labelText: 'import_guests.start_row'.tr(),
                        ),
                        value: _firstDataRowIndex,
                        items:
                            List.generate(20, (index) {
                              if (index <= _headerRowIndex) {
                                return null; // Skip invalid
                              }
                              return DropdownMenuItem(
                                value: index,
                                child: Text(
                                  'import_guests.row_prefix'.tr(
                                    args: [(index + 1).toString()],
                                  ),
                                ),
                              );
                            }).whereType<DropdownMenuItem<int>>().toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _firstDataRowIndex = val);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        if (_isLoading) const CircularProgressIndicator(),
      ],
    );
  }

  Future<void> _pickFile() async {
    setState(() => _isLoading = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls'],
      );

      if (result != null) {
        final file = result.files.single;
        final rows = await _importService.parseFile(file);

        setState(() {
          _selectedFile = file;
          _rawRows = rows;
          if (rows.isNotEmpty) {
            // Default to 0 and 1, or keep previous if valid? Reset for new file.
            _headerRowIndex = 0;
            _firstDataRowIndex = 1;

            if (rows.length > _headerRowIndex) {
              _fileHeaders =
                  rows[_headerRowIndex].map((e) => e.toString()).toList();
              _autoMapHeaders();
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'import_guests.file_read_error'.tr(args: [e.toString()]),
            ),
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _autoMapHeaders() {
    _columnMapping.clear();
    final fields = BulkImportService.availableFields;

    // Simple heuristic: check if header contains field name
    for (int i = 0; i < _fileHeaders.length; i++) {
      final header = _fileHeaders[i].toLowerCase();
      fields.forEach((key, label) {
        if (!_columnMapping.containsKey(key)) {
          // Check match with key (e.g. 'email') or label (e.g. 'Nome')
          if (header.contains(key) ||
              header.contains(label.split('(')[0].trim().toLowerCase())) {
            _columnMapping[key] = i;
          }
        }
      });
    }
  }

  // --- Step 2: Mapping ---

  Widget _buildMappingStep(ThemeData theme) {
    if (_fileHeaders.isEmpty) {
      return Text('import_guests.no_data_found'.tr());
    }

    final fields = BulkImportService.availableFields;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'import_guests.map_columns_description'.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: fields.length,
          separatorBuilder: (ctx, i) => const Divider(),
          itemBuilder: (context, index) {
            final key = fields.keys.elementAt(index);
            final label = fields[key]!;
            final selectedColIndex = _columnMapping[key];

            return Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                const Icon(Icons.arrow_right_alt),
                Expanded(
                  flex: 3,
                  child: DropdownButton<int>(
                    isExpanded: true,
                    value: selectedColIndex,
                    hint: Text('import_guests.ignore'.tr()),
                    items: [
                      DropdownMenuItem<int>(
                        value: null,
                        child: Text(
                          'import_guests.ignore'.tr(),
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ),
                      ...List.generate(_fileHeaders.length, (i) {
                        return DropdownMenuItem<int>(
                          value: i,
                          child: Text(
                            _fileHeaders[i],
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }),
                    ],
                    onChanged: (val) {
                      setState(() {
                        if (val == null) {
                          _columnMapping.remove(key);
                        } else {
                          _columnMapping[key] = val;
                        }
                      });
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  // --- Step 3: Processing ---

  Widget _buildProcessingStep(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_isProcessing) ...[
            CircularProgressIndicator(value: _progress),
            const SizedBox(height: 20),
            Text(
              'import_guests.importing_progress'.tr(
                args: [(_progress * 100).toInt().toString()],
              ),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Text(
              'import_guests.success_errors'.tr(
                args: [_successCount.toString(), _failCount.toString()],
              ),
            ),
          ] else ...[
            const Icon(Icons.check_circle, size: 64, color: Colors.green),
            const SizedBox(height: 20),
            Text(
              'import_guests.import_completed'.tr(),
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Text(
              'import_guests.guests_added'.tr(args: [_successCount.toString()]),
            ),
            Text(
              'import_guests.guests_failed'.tr(args: [_failCount.toString()]),
              style: TextStyle(
                color: _failCount > 0 ? Colors.red : Colors.grey,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- Step 4: Results ---

  Widget _buildResultsStep(ThemeData theme) {
    if (_failCount == 0) {
      return Center(
        child: Column(
          children: [
            const Icon(Icons.celebration, size: 64, color: Colors.orange),
            const SizedBox(height: 20),
            Text('import_guests.all_success'.tr()),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: Text('import_guests.back_to_dashboard'.tr()),
            ),
          ],
        ),
      );
    }

    // Show list of failed imports
    final failures = _results.where((r) => !r.success).toList();

    return Column(
      children: [
        Text(
          'import_guests.some_failed'.tr(),
          style: TextStyle(color: theme.colorScheme.error),
        ),
        const SizedBox(height: 10),
        ListView.builder(
          shrinkWrap: true,
          physics:
              const NeverScrollableScrollPhysics(), // Use ScrollView for parent
          itemCount: failures.length,
          itemBuilder: (context, index) {
            final failure = failures[index];
            final data = failure.data;
            return Card(
              color: theme.colorScheme.errorContainer.withOpacity(0.3),
              child: ListTile(
                title: Text(
                  '${data['first_name'] ?? '?'} ${data['last_name'] ?? '?'}',
                ),
                subtitle: Text(
                  failure.error ?? 'import_guests.unknown_error'.tr(),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editAndRetry(failure, index),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _editAndRetry(ImportResult result, int index) async {
    // Show a dialog to fix the data
    final data = Map<String, dynamic>.from(result.data);
    final formKey = GlobalKey<FormState>();

    // Controllers
    final nameCtrl = TextEditingController(text: data['first_name']);
    final surnameCtrl = TextEditingController(text: data['last_name']);
    final emailCtrl = TextEditingController(text: data['email']);

    await showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text('import_guests.fix_data'.tr()),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    validator:
                        (v) =>
                            (v == null || v.isEmpty)
                                ? 'add_guest.name_required'.tr()
                                : null,
                  ),
                  TextFormField(
                    controller: surnameCtrl,
                    decoration: InputDecoration(
                      labelText: 'add_guest.surname'.tr(),
                    ),
                    validator:
                        (v) =>
                            (v == null || v.isEmpty)
                                ? 'add_guest.surname_required'.tr()
                                : null,
                  ),
                  TextFormField(
                    controller: emailCtrl,
                    decoration: InputDecoration(
                      labelText: 'staff.email_label'.tr(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('common.cancel'.tr()),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(ctx);

                    // Update data
                    data['first_name'] = nameCtrl.text.trim();
                    data['last_name'] = surnameCtrl.text.trim();
                    data['email'] = emailCtrl.text.trim();

                    // Retry import
                    // Ideally this logic should be reusable, but for now simple inline retry
                    try {
                      // Get next event ID (inefficient but safe)
                      final idEvent = await _generateNextIdEvent();
                      await _personService
                          .createPerson(
                            firstName: data['first_name'],
                            lastName: data['last_name'],
                            email: data['email'],
                            phone: data['phone'],
                            codiceFiscale: data['codice_fiscale'],
                            indirizzo: data['indirizzo'],
                            idEvent: idEvent,
                          )
                          .then((person) async {
                            await _participationService.createParticipation(
                              personId: person['id'],
                              eventId: widget.eventId,
                              statusId: 1, // Default Pending/Added
                              roleId: 2, // Default Guest
                            );
                          });

                      // Success: remove from failures list
                      setState(() {
                        _results.removeWhere((r) => r == result);
                        // If processed data was used, update it too if needed, but results drive the UI
                        _failCount--;
                        _successCount++;
                      });

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('add_guest.guest_added'.tr())),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${'import_guests.unknown_error'.tr()}: $e',
                            ),
                          ),
                        );
                      }
                    }
                  }
                },
                child: Text('import_guests.save_retry'.tr()),
              ),
            ],
          ),
    );
  }

  // --- Logic ---

  Future<void> _startImport() async {
    setState(() {
      _isProcessing = true;
      _results = [];
      _successCount = 0;
      _failCount = 0;
      _progress = 0;
    });

    List<List<dynamic>> rowsToProcess = [];
    if (_rawRows.length > _firstDataRowIndex) {
      rowsToProcess = _rawRows.sublist(_firstDataRowIndex);
    }

    final dataToImport = _importService.mapData(rowsToProcess, _columnMapping);
    final total = dataToImport.length;

    // We need to fetch/maintain the next id_event counter to avoid querying it every loop
    int nextIdEvent = 1;

    try {
      final initialNextIdStr = await _generateNextIdEvent();
      nextIdEvent = int.tryParse(initialNextIdStr) ?? 1;
    } catch (_) {}

    for (int i = 0; i < total; i++) {
      final item = dataToImport[i];

      // Basic Validation
      if (item['first_name'] == null ||
          item['first_name'].toString().isEmpty ||
          item['last_name'] == null ||
          item['last_name'].toString().isEmpty) {
        _results.add(
          ImportResult(
            item,
            false,
            error: 'import_guests.name_missing_error'.tr(),
          ),
        );
        _failCount++;
        continue;
      }

      DateTime? birthDate;
      if (item['birth_date'] != null) {
        birthDate = _parseDate(item['birth_date'].toString());
      }

      try {
        final currentIdEventStr = nextIdEvent.toString();

        final person = await _personService.createPerson(
          firstName: item['first_name'].toString(),
          lastName: item['last_name'].toString(),
          email: item['email']?.toString(),
          phone: item['phone']?.toString(),
          codiceFiscale: item['codice_fiscale']?.toString(),
          indirizzo: item['indirizzo']?.toString(),
          dateOfBirth: birthDate,
          idEvent: currentIdEventStr,
        );

        await _participationService.createParticipation(
          personId: person['id'],
          eventId: widget.eventId,
          statusId: 1, // Default
          roleId: 2, // Default Guest
        );

        _results.add(ImportResult(item, true));
        _successCount++;
        nextIdEvent++; // Increment locally
      } catch (e) {
        _results.add(ImportResult(item, false, error: e.toString()));
        _failCount++;
      }

      if (mounted) {
        setState(() {
          _progress = (i + 1) / total;
        });
      }
    }

    setState(() {
      _isProcessing = false;
      _currentStep++; // Move to Results
    });
  }

  // Reusing logic from AddGuestScreen
  Future<String> _generateNextIdEvent() async {
    try {
      final participations = await _participationService.getEventParticipations(
        widget.eventId,
      );
      int maxId = 0;
      for (var participation in participations) {
        final person = participation['person'];
        if (person != null && person['id_event'] != null) {
          final idEvent = person['id_event'].toString();
          final numId = int.tryParse(idEvent);
          if (numId != null && numId > maxId) {
            maxId = numId;
          }
        }
      }
      return (maxId + 1).toString();
    } catch (e) {
      return '1';
    }
  }

  // --- Controls ---

  void _onStepContinue() {
    if (_currentStep == 0) {
      if (_selectedFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('import_guests.select_file_error'.tr())),
        );
        return;
      }
      setState(() => _currentStep++);
    } else if (_currentStep == 1) {
      // Validate mapping
      if (!_columnMapping.containsKey('first_name') ||
          !_columnMapping.containsKey('last_name')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('import_guests.mapping_required_error'.tr())),
        );
        return;
      }
      setState(() => _currentStep++);
      _startImport();
    } else if (_currentStep == 2) {
      // Should happen automatically when finished, but button is there
      if (!_isProcessing) {
        setState(() => _currentStep++);
      }
    } else {
      // Finish
      Navigator.pop(context);
    }
  }

  void _onStepCancel() {
    if (_currentStep > 0 && !_isProcessing) {
      setState(() => _currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

  Widget _controlsBuilder(BuildContext context, ControlsDetails details) {
    if (_currentStep == 2) {
      return const SizedBox.shrink(); // No buttons during processing (custom handling)
    }

    if (_currentStep == 3) {
      // Results step controls handled inside step content usually, or here
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Row(
        children: [
          ElevatedButton(
            onPressed: details.onStepContinue,
            child: Text(
              _currentStep == 1
                  ? 'import_guests.import_button'.tr()
                  : 'import_guests.next_button'.tr(),
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: details.onStepCancel,
            child: Text(
              _currentStep == 0
                  ? 'common.cancel'.tr()
                  : 'import_guests.back_button'.tr(),
            ),
          ),
        ],
      ),
    );
  }
}

class ImportResult {
  final Map<String, dynamic> data;
  final bool success;
  final String? error;

  ImportResult(this.data, this.success, {this.error});
}

DateTime? _parseDate(String dateStr) {
  if (dateStr.isEmpty) return null;
  // Try ISO first
  try {
    return DateTime.parse(dateStr);
  } catch (_) {}

  // Try IT format dd/MM/yyyy
  try {
    final parts = dateStr.split('/');
    if (parts.length == 3) {
      return DateTime(
        int.parse(parts[2]),
        int.parse(parts[1]),
        int.parse(parts[0]),
      );
    }
  } catch (_) {}

  // Try IT format dd-MM-yyyy
  try {
    final parts = dateStr.split('-');
    if (parts.length == 3) {
      return DateTime(
        int.parse(parts[2]),
        int.parse(parts[1]),
        int.parse(parts[0]),
      );
    }
  } catch (_) {}

  return null;
}

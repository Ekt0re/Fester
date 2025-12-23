import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:universal_platform/universal_platform.dart';
import 'package:webview_windows/webview_windows.dart';
import 'template_model.dart';

class TemplateConfigStep extends StatefulWidget {
  final List<TemplateModel> templates;
  final TemplateModel? selectedTemplate;
  final Function(TemplateModel) onTemplateSelected;
  final String eventName;
  final String eventDate;
  final String eventLocation;

  const TemplateConfigStep({
    super.key,
    required this.templates,
    required this.selectedTemplate,
    required this.onTemplateSelected,
    required this.eventName,
    required this.eventDate,
    required this.eventLocation,
  });

  @override
  State<TemplateConfigStep> createState() => _TemplateConfigStepState();
}

class _TemplateConfigStepState extends State<TemplateConfigStep> {
  late TemplateModel _editingTemplate;
  String _sourceHtml = '';

  // WebView controller per Windows
  WebviewController? _webviewController;
  bool _webviewReady = false;

  // Stili modificabili
  Color _mainColor = const Color(0xFFE94560);
  Color _secondaryColor = const Color(0xFFFF6B9D);
  Color _backgroundColor = const Color(0xFF1A1A2E);
  Color _textColor = const Color(0xFFFFFFFF);
  double _borderRadius = 20.0;
  double _shadowBlur = 40.0;

  @override
  void initState() {
    super.initState();
    // Inizializzazione sicura per evitare LateInitializationError
    if (widget.selectedTemplate != null) {
      _editingTemplate = widget.selectedTemplate!;
    } else if (widget.templates.isNotEmpty) {
      _editingTemplate = widget.templates.first;
    } else {
      // Fallback se la lista è vuota
      _editingTemplate = TemplateModel(
        id: 'empty',
        name: 'Nessun Template',
        description: '',
        html:
            '<html><body><div style="color:white; padding:20px;">Carica un template per iniziare.</div></body></html>',
      );
    }

    _sourceHtml = _editingTemplate.html;

    // Inizializza WebView su Windows
    if (UniversalPlatform.isWindows) {
      _initWebView();
    }
  }

  Future<void> _initWebView() async {
    _webviewController = WebviewController();
    await _webviewController!.initialize();
    setState(() => _webviewReady = true);
    _updateWebViewContent();
  }

  @override
  void dispose() {
    _webviewController?.dispose();
    super.dispose();
  }

  void _updateWebViewContent() {
    if (_webviewController == null || !_webviewReady) return;

    final html =
        _editingTemplate.id == 'empty'
            ? _editingTemplate.html
            : _editingTemplate.html
                .replaceAll('{{event_name}}', widget.eventName)
                .replaceAll('{{guest_name}}', 'Mario Rossi')
                .replaceAll('{{event_date}}', widget.eventDate)
                .replaceAll('{{event_location}}', widget.eventLocation)
                .replaceAll(
                  '{{qr_data}}',
                  Uri.encodeComponent('FEV-PREVIEW-123'),
                );

    // Carica l'HTML come data URI
    final dataUri =
        Uri.dataFromString(
          html,
          mimeType: 'text/html',
          encoding: Encoding.getByName('utf-8'),
        ).toString();

    _webviewController!.loadUrl(dataUri);
  }

  @override
  void didUpdateWidget(TemplateConfigStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedTemplate != oldWidget.selectedTemplate &&
        widget.selectedTemplate != null) {
      setState(() {
        _editingTemplate = widget.selectedTemplate!;
        // Se l'ID è diverso, resettiamo la sorgente (nuovo template selezionato)
        if (widget.selectedTemplate?.id != oldWidget.selectedTemplate?.id) {
          _sourceHtml = _editingTemplate.html;
        }
      });
      _updateWebViewContent();
    }
  }

  void _updateTemplate() {
    String mainHex =
        '#${_mainColor.value.toRadixString(16).padLeft(8, '0').substring(2)}';
    String secondaryHex =
        '#${_secondaryColor.value.toRadixString(16).padLeft(8, '0').substring(2)}';
    String bgHex =
        '#${_backgroundColor.value.toRadixString(16).padLeft(8, '0').substring(2)}';
    String textHex =
        '#${_textColor.value.toRadixString(16).padLeft(8, '0').substring(2)}';

    String modifiedHtml = _sourceHtml
        // Colore primario
        .replaceAll('#e94560', mainHex)
        .replaceAll('#E94560', mainHex)
        .replaceAll('{{main_color}}', mainHex)
        // Colore secondario/gradiente
        .replaceAll('#ff6b9d', secondaryHex)
        .replaceAll('#FF6B9D', secondaryHex)
        .replaceAll('{{secondary_color}}', secondaryHex)
        // Sfondo
        .replaceAll('#1a1a2e', bgHex)
        .replaceAll('#1A1A2E', bgHex)
        .replaceAll('#16213e', bgHex)
        .replaceAll('#0f0f23', bgHex)
        .replaceAll('{{bg_color}}', bgHex)
        // Testo
        .replaceAll('{{text_color}}', textHex)
        // Bordi
        .replaceAll(
          RegExp(r'border-radius:\s*\d+px'),
          'border-radius: ${_borderRadius.toInt()}px',
        )
        // Ombre
        .replaceAll(
          RegExp(r'box-shadow:[^;]+;'),
          'box-shadow: 0 10px ${_shadowBlur.toInt()}px rgba(0,0,0,0.5);',
        );

    setState(() {
      _editingTemplate = _editingTemplate.copyWith(html: modifiedHtml);
    });
    _updateWebViewContent(); // Sincronizza WebView
    widget.onTemplateSelected(_editingTemplate);
  }

  void _selectTemplate(TemplateModel t) {
    setState(() {
      _sourceHtml = t.html;
      _editingTemplate = t;
      // Reset stili ai default
      _mainColor = const Color(0xFFE94560);
      _secondaryColor = const Color(0xFFFF6B9D);
      _backgroundColor = const Color(0xFF1A1A2E);
      _textColor = const Color(0xFFFFFFFF);
      _borderRadius = 20.0;
      _shadowBlur = 40.0;
    });
    _updateWebViewContent(); // Sincronizza WebView
    widget.onTemplateSelected(_editingTemplate);
  }

  Future<void> _pickCustomHtml() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['html'],
    );

    if (result != null) {
      final bytes = result.files.first.bytes;
      if (bytes == null) return;
      final content = utf8.decode(bytes);
      final newId = 'custom_${DateTime.now().millisecondsSinceEpoch}';

      setState(() {
        _sourceHtml = content; // Nuova sorgente dal PC
        _editingTemplate = TemplateModel(
          id: newId,
          name: result.files.first.name.toUpperCase(),
          description: 'Template caricato da PC',
          html: content,
        );
      });
      _updateTemplate();
    }
  }

  Future<void> _pickLogo() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );

    if (result != null) {
      final bytes = result.files.first.bytes;
      if (bytes != null) {
        String base64Image = base64Encode(bytes);
        String dataUri =
            'data:image/${result.files.first.extension};base64,$base64Image';

        setState(() {
          // Sostituisce la prima immagine trovata nel template oppure aggiunge header
          final imgRegex = RegExp(r'<img[^>]+src="[^"]+"');
          if (imgRegex.hasMatch(_sourceHtml)) {
            _sourceHtml = _sourceHtml.replaceFirst(
              imgRegex,
              '<img src="$dataUri"',
            );
          } else if (_sourceHtml.contains('{{logo_url}}')) {
            _sourceHtml = _sourceHtml.replaceAll('{{logo_url}}', dataUri);
          } else {
            _sourceHtml =
                '<div style="text-align:center; padding: 20px;"><img src="$dataUri" style="max-height:80px"></div>\n$_sourceHtml';
          }
        });
        _updateTemplate();
      }
    }
  }

  void _showCssEditor() {
    // Mostra un dialog per modificare direttamente il CSS
    final cssController = TextEditingController();

    // Estrae il contenuto tra i tag <style>
    final styleMatch = RegExp(
      r'<style[^>]*>([\s\S]*?)</style>',
    ).firstMatch(_sourceHtml);
    cssController.text = styleMatch?.group(1) ?? '';

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.code, color: Color(0xFFE94560)),
                const SizedBox(width: 8),
                const Text('Editor CSS'),
              ],
            ),
            content: SizedBox(
              width: 500,
              height: 400,
              child: TextField(
                controller: cssController,
                maxLines: null,
                expands: true,
                style: GoogleFonts.firaCode(fontSize: 12),
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'body { background: #1a1a2e; }',
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annulla'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE94560),
                ),
                onPressed: () {
                  // Sostituisce il CSS nel template
                  setState(() {
                    if (styleMatch != null) {
                      _sourceHtml = _sourceHtml.replaceFirst(
                        styleMatch.group(0)!,
                        '<style>${cssController.text}</style>',
                      );
                    } else {
                      // Aggiunge un tag style se non esiste
                      _sourceHtml =
                          '<style>${cssController.text}</style>\n$_sourceHtml';
                    }
                  });
                  _updateTemplate();
                  Navigator.pop(context);
                },
                child: const Text(
                  'Applica',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Preview Area
        Expanded(
          flex: 4,
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.dividerColor),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _buildPreview(),
            ),
          ),
        ),

        // Configuration Tools
        Expanded(
          flex: 3,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              border: Border(top: BorderSide(color: theme.dividerColor)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Template'),
                  _buildTemplateSelector(),
                  const SizedBox(height: 20),

                  _buildSectionTitle('Design & Colori'),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildColorButton('Primario', _mainColor, (color) {
                        setState(() => _mainColor = color);
                        _updateTemplate();
                      }),
                      _buildColorButton('Secondario', _secondaryColor, (color) {
                        setState(() => _secondaryColor = color);
                        _updateTemplate();
                      }),
                      _buildColorButton('Sfondo', _backgroundColor, (color) {
                        setState(() => _backgroundColor = color);
                        _updateTemplate();
                      }),
                      _buildColorButton('Testo', _textColor, (color) {
                        setState(() => _textColor = color);
                        _updateTemplate();
                      }),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Slider per bordi e ombre
                  _buildSliderControl(
                    'Bordi Arrotondati',
                    _borderRadius,
                    0,
                    50,
                    (value) {
                      setState(() => _borderRadius = value);
                      _updateTemplate();
                    },
                  ),
                  _buildSliderControl('Intensità Ombra', _shadowBlur, 0, 100, (
                    value,
                  ) {
                    setState(() => _shadowBlur = value);
                    _updateTemplate();
                  }),

                  _buildSectionTitle('Elementi Visivi'),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _buildActionButton(
                        Icons.image_outlined,
                        'Cambia Immagine',
                        _pickLogo,
                      ),
                      _buildActionButton(
                        Icons.upload_file,
                        'Carica HTML',
                        _pickCustomHtml,
                      ),
                      _buildActionButton(
                        Icons.code,
                        'Modifica CSS',
                        _showCssEditor,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildTemplateSelector() {
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: widget.templates.length,
        itemBuilder: (context, index) {
          final t = widget.templates[index];
          final isSelected = t.id == _editingTemplate.id;

          return GestureDetector(
            onTap: () => _selectTemplate(t),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color:
                    isSelected
                        ? const Color(0xFFE94560)
                        : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(30),
                border:
                    isSelected
                        ? null
                        : Border.all(color: Colors.grey.withOpacity(0.3)),
              ),
              child: Center(
                child: Text(
                  t.name,
                  style: GoogleFonts.outfit(
                    color: isSelected ? Colors.white : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPreview() {
    if (UniversalPlatform.isWindows) {
      if (_webviewController == null || !_webviewReady) {
        return const Center(
          child: CircularProgressIndicator(color: Color(0xFFE94560)),
        );
      }

      return Stack(
        children: [
          Webview(_webviewController!),
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE94560),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE94560).withOpacity(0.4),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Text(
                'WEBVIEW LIVE',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Fallback per altre piattaforme (semplificato)
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.important_devices, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Preview avanzata disponibile su Windows',
            style: GoogleFonts.outfit(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildColorButton(
    String label,
    Color color,
    Function(Color) onPicked,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder:
                  (context) => AlertDialog(
                    title: const Text('Scegli Colore'),
                    content: SingleChildScrollView(
                      child: ColorPicker(
                        pickerColor: color,
                        onColorChanged: onPicked,
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
            );
          },
          child: Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFFE94560)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderControl(
    String label,
    double value,
    double min,
    double max,
    Function(double) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: const Color(0xFFE94560),
                inactiveTrackColor: Colors.grey.withOpacity(0.3),
                thumbColor: const Color(0xFFE94560),
                overlayColor: const Color(0xFFE94560).withOpacity(0.2),
                trackHeight: 4,
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              '${value.toInt()}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:uuid/uuid.dart';
import '../../models/custom_theme.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_theme.dart'; // For static createTheme if needed, or fallback

class ThemeEditorScreen extends StatefulWidget {
  final CustomTheme? initialTheme;

  const ThemeEditorScreen({super.key, this.initialTheme});

  @override
  State<ThemeEditorScreen> createState() => _ThemeEditorScreenState();
}

class _ThemeEditorScreenState extends State<ThemeEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late bool _isDark;
  late Color _primaryColor;
  late Color _secondaryColor;
  late Color _backgroundColor;
  late Color _surfaceColor;
  late Color _errorColor;
  late Color _textColor;

  @override
  void initState() {
    super.initState();
    final theme = widget.initialTheme;
    _nameController = TextEditingController(text: theme?.name ?? '');
    _isDark = theme?.isDark ?? false;
    _primaryColor =
        theme != null ? Color(theme.primaryColor) : AppTheme.primaryLight;
    _secondaryColor =
        theme != null ? Color(theme.secondaryColor) : AppTheme.secondaryLight;
    _backgroundColor =
        theme != null ? Color(theme.backgroundColor) : AppTheme.backgroundLight;
    _surfaceColor =
        theme != null ? Color(theme.surfaceColor) : AppTheme.surfaceLight;
    _errorColor = theme != null ? Color(theme.errorColor) : AppTheme.errorLight;
    _textColor = theme != null ? Color(theme.textColor) : AppTheme.textLight;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _saveTheme() {
    if (_formKey.currentState!.validate()) {
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      final newTheme = CustomTheme(
        id: widget.initialTheme?.id ?? const Uuid().v4(),
        name: _nameController.text.trim(),
        isDark: _isDark,
        primaryColor: _primaryColor.value,
        secondaryColor: _secondaryColor.value,
        backgroundColor: _backgroundColor.value,
        surfaceColor: _surfaceColor.value,
        errorColor: _errorColor.value,
        textColor: _textColor.value,
      );

      if (widget.initialTheme != null) {
        themeProvider.updateCustomTheme(newTheme);
      } else {
        themeProvider.addCustomTheme(newTheme);
      }

      Navigator.pop(context);
    }
  }

  void _pickColor(
    String title,
    Color currentColor,
    ValueChanged<Color> onColorChanged,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(
              child: ColorPicker(
                pickerColor: currentColor,
                onColorChanged: onColorChanged,
                enableAlpha: false,
                // ignore: deprecated_member_use
                showLabel: true,
                pickerAreaHeightPercent: 0.8,
              ),
            ),
            actions: [
              TextButton(
                child: const Text('OK'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Generate current verification theme data for preview
    final previewTheme = AppTheme.createTheme(
      isDark: _isDark,
      primary: _primaryColor,
      secondary: _secondaryColor,
      background: _backgroundColor,
      surface: _surfaceColor,
      error: _errorColor,
      text: _textColor,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialTheme != null ? 'Edit Theme' : 'New Theme'),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveTheme),
        ],
      ),
      body: Row(
        children: [
          // Editor Side
          Expanded(
            flex: 1,
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Theme Name',
                      hintText: 'e.g. Cyberpunk',
                    ),
                    validator:
                        (value) =>
                            value == null || value.isEmpty
                                ? 'Name required'
                                : null,
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Dark Mode Base'),
                    value: _isDark,
                    onChanged: (val) => setState(() => _isDark = val),
                  ),
                  const Divider(),
                  _buildColorTile(
                    'Primary Color',
                    _primaryColor,
                    (c) => setState(() => _primaryColor = c),
                  ),
                  _buildColorTile(
                    'Secondary Color',
                    _secondaryColor,
                    (c) => setState(() => _secondaryColor = c),
                  ),
                  _buildColorTile(
                    'Background Color',
                    _backgroundColor,
                    (c) => setState(() => _backgroundColor = c),
                  ),
                  _buildColorTile(
                    'Surface Color',
                    _surfaceColor,
                    (c) => setState(() => _surfaceColor = c),
                  ),
                  _buildColorTile(
                    'Error Color',
                    _errorColor,
                    (c) => setState(() => _errorColor = c),
                  ),
                  _buildColorTile(
                    'Text Color',
                    _textColor,
                    (c) => setState(() => _textColor = c),
                  ),
                ],
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          // Preview Side
          Expanded(
            flex: 1,
            child: Theme(
              data: previewTheme,
              child: Scaffold(
                appBar: AppBar(title: const Text('Preview')),
                floatingActionButton: FloatingActionButton(
                  onPressed: () {},
                  child: const Icon(Icons.add),
                ),
                body: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Card Title',
                              style: previewTheme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'This is a card description example.',
                              style: previewTheme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {},
                              child: const Text('Primary Action'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      decoration: InputDecoration(
                        labelText: 'Input Field',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: Icon(Icons.person, color: _primaryColor),
                      title: const Text('List Tile'),
                      subtitle: const Text('Subtitle'),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorTile(
    String label,
    Color color,
    ValueChanged<Color> onChanged,
  ) {
    return ListTile(
      title: Text(label),
      trailing: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey),
        ),
      ),
      onTap: () => _pickColor(label, color, onChanged),
    );
  }
}

// lib/screens/create_menu_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';


class CreateMenuScreen extends StatefulWidget {
  final String? eventId; // Opzionale per caricare menu esistente
  final String? initialMenuName;
  final String? initialMenuDescription;
  final List<Map<String, dynamic>>? initialMenuItems;

  const CreateMenuScreen({
    super.key,
    this.eventId,
    this.initialMenuName,
    this.initialMenuDescription,
    this.initialMenuItems,
  });

  @override
  State<CreateMenuScreen> createState() => _CreateMenuScreenState();
}

class _CreateMenuScreenState extends State<CreateMenuScreen> {
  final _formKey = GlobalKey<FormState>();
  final _menuNameController = TextEditingController();
  final _menuDescriptionController = TextEditingController();

  final List<MenuItemData> _menuItems = [];
  List<Map<String, dynamic>> _transactionTypes = [];
  final Set<String> _expandedItems = {}; // Item espansi
  final Set<String> _confirmedItems = {}; // Item confermati (collassati)
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _loadTransactionTypes();
  }

  void _initializeData() {
    // Se abbiamo dati iniziali passati (dal flusso di creazione), usiamo quelli
    if (widget.initialMenuName != null) {
      _menuNameController.text = widget.initialMenuName!;
      _menuDescriptionController.text = widget.initialMenuDescription ?? '';

      if (widget.initialMenuItems != null) {
        final items =
            widget.initialMenuItems!.map((item) {
              return MenuItemData(
                tempId:
                    DateTime.now().millisecondsSinceEpoch.toString() +
                    item['name'], // unique id
                transactionTypeId: item['transaction_type_id'] as int?,
                name: item['name'] as String?,
                description: item['description'] as String?,
                price: (item['price'] as num?)?.toDouble(),
                availableQuantity: item['available_quantity'] as int?,
                isAlcoholic: item['is_alcoholic'] as bool? ?? false,
              );
            }).toList();

        setState(() {
          _menuItems.addAll(items);
          // Items caricati sono confermati
          _confirmedItems.addAll(items.map((i) => i.tempId));
        });
      }
    } else {
      // Altrimenti proviamo a caricare dal DB se c'è un eventId
      _loadExistingMenu();
    }
  }

  Future<void> _loadTransactionTypes() async {
    try {
      final response = await Supabase.instance.client
          .from('transaction_type')
          .select()
          .order('id', ascending: true);
      setState(() {
        _transactionTypes = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint('create_menu.load_transaction_types_error'.tr() + e.toString());
      // Fallback to hardcoded values
      setState(() {
        _transactionTypes = [
          {'id': 1, 'name': 'transaction_type.drink'.tr()},
          {'id': 2, 'name': 'transaction_type.food'.tr()},
          {'id': 3, 'name': 'transaction_type.ticket'.tr()},
          {'id': 4, 'name': 'transaction_type.fine'.tr()},
          {'id': 5, 'name': 'transaction_type.sanction'.tr()},
          {'id': 6, 'name': 'transaction_type.report'.tr()},
          {'id': 7, 'name': 'transaction_type.refund'.tr()},
          {'id': 8, 'name': 'transaction_type.fee'.tr()},
          {'id': 9, 'name': 'transaction_type.note'.tr()},
        ];
      });
    }
  }

  @override
  void dispose() {
    _menuNameController.dispose();
    _menuDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingMenu() async {
    if (widget.eventId == null) return;

    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;

      // Carica menu esistente
      final menuResponse =
          await supabase
              .from('menu')
              .select()
              .eq('event_id', widget.eventId!)
              .maybeSingle();

      if (menuResponse != null) {
        _menuNameController.text = menuResponse['name'] as String? ?? '';
        _menuDescriptionController.text =
            menuResponse['description'] as String? ?? '';

        // Carica menu items
        final itemsResponse = await supabase
            .from('menu_item')
            .select()
            .eq('menu_id', menuResponse['id'] as String)
            .order('sort_order', ascending: true);

        final items =
            (itemsResponse as List).map((item) {
              return MenuItemData(
                id: item['id'] as String?,
                tempId: item['id'] as String,
                transactionTypeId: item['transaction_type_id'] as int,
                name: item['name'] as String,
                description: item['description'] as String?,
                price: (item['price'] as num).toDouble(),
                availableQuantity: item['available_quantity'] as int?,
                isAlcoholic: item['is_alcoholic'] as bool? ?? false,
              );
            }).toList();

        setState(() {
          _menuItems.addAll(items);
          // Tutti gli item esistenti sono confermati (collassati)
          _confirmedItems.addAll(items.map((item) => item.tempId));
        });
      }
    } catch (e) {
      debugPrint('${'create_menu.load_existing_menu_error'.tr()} $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _addMenuItem() {
    setState(() {
      final newItem = MenuItemData(
        tempId: DateTime.now().millisecondsSinceEpoch.toString(),
      );
      _menuItems.add(newItem);
      _expandedItems.add(newItem.tempId); // Nuovo item è espanso
    });
  }

  void _confirmMenuItem(String itemId) {
    final item = _menuItems.firstWhere((i) => i.tempId == itemId);
    if (!item.isValid()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('create_menu.fill_all_fields'.tr())),
      );
      return;
    }
    setState(() {
      _confirmedItems.add(itemId);
      _expandedItems.remove(itemId);
    });
  }

  void _editMenuItem(String itemId) {
    setState(() {
      _expandedItems.add(itemId);
      _confirmedItems.remove(itemId);
    });
  }

  void _removeMenuItem(int index) {
    setState(() {
      _menuItems.removeAt(index);
    });
  }

  Future<void> _saveMenu() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_menuItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('create_menu.add_at_least_one_item'.tr())),
      );
      return;
    }

    // Valida tutti gli item
    for (var item in _menuItems) {
      if (!item.isValid()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('create_menu.fill_all_fields'.tr()),
          ),
        );
        return;
      }
    }

    // Prepara i dati del menù da restituire (salvati in memoria)
    final menuName = _menuNameController.text.trim();
    final menuDescription =
        _menuDescriptionController.text.trim().isEmpty
            ? null
            : _menuDescriptionController.text.trim();

    final menuItemsData =
        _menuItems.map((item) {
          return {
            'transaction_type_id': item.transactionTypeId!,
            'name': item.name!,
            'description':
                item.description?.isEmpty ?? true ? null : item.description,
            'price': item.price!,
            'available_quantity': item.availableQuantity,
            'is_alcoholic': item.isAlcoholic,
          };
        }).toList();

    // Restituisci i dati senza salvare nel database
    if (mounted) {
      Navigator.pop(context, {
        'menuName': menuName,
        'menuDescription': menuDescription,
        'menuItems': menuItemsData,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'create_menu.title'.tr(),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(24.0),
                  children: [
                    Text(
                      'create_menu.title'.tr(),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Nome menù
                    _buildTextField(
                      context: context,
                      controller: _menuNameController,
                      label: 'create_menu.name_label'.tr(),
                      hint: 'create_menu.name_menu_hint'.tr(),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'create_menu.name_error'.tr();
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Descrizione menù
                    _buildTextField(
                      context: context,
                      controller: _menuDescriptionController,
                      label: 'create_menu.description_label'.tr(),
                      hint: 'create_menu.description_hint'.tr(),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 32),

                    // Header items
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'create_menu.item'.tr(),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          onPressed: _addMenuItem,
                          icon: const Icon(Icons.add_circle),
                          color: theme.colorScheme.primary,
                          iconSize: 32,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Lista menu items
                    if (_menuItems.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: theme.cardTheme.color?.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.outline.withOpacity(0.3),
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.restaurant_menu,
                              size: 48,
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.3,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'create_menu.no_item'.tr(),
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.6,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'create_menu.new_item'.tr(),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ..._menuItems.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        final isExpanded = _expandedItems.contains(item.tempId);
                        final isConfirmed = _confirmedItems.contains(
                          item.tempId,
                        );
                        return _MenuItemCard(
                          item: item,
                          index: index,
                          isExpanded: isExpanded,
                          isConfirmed: isConfirmed,
                          transactionTypes: _transactionTypes,
                          onRemove: () => _removeMenuItem(index),
                          onChanged: () => setState(() {}),
                          onConfirm: () => _confirmMenuItem(item.tempId),
                          onEdit: () => _editMenuItem(item.tempId),
                        );
                      }),

                    const SizedBox(height: 32),

                    // Pulsante salva
                    ElevatedButton(
                      onPressed: _saveMenu,
                      child: Text('create_menu.save'.tr()),
                    ),
                    const SizedBox(height: 16),

                    // Pulsante salta
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'create_menu.skip'.tr(),
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildTextField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.3),
            ),
          ),
          child: TextFormField(
            controller: controller,
            maxLines: maxLines,
            validator: validator,
            style: theme.textTheme.bodyLarge,
            decoration: InputDecoration(
              hintText: hint,
              contentPadding: const EdgeInsets.all(16),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }
}

// Card per singolo menu item
class _MenuItemCard extends StatefulWidget {
  final MenuItemData item;
  final int index;
  final bool isExpanded;
  final bool isConfirmed;
  final List<Map<String, dynamic>> transactionTypes;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  final VoidCallback onConfirm;
  final VoidCallback onEdit;

  const _MenuItemCard({
    required this.item,
    required this.index,
    required this.isExpanded,
    required this.isConfirmed,
    required this.transactionTypes,
    required this.onRemove,
    required this.onChanged,
    required this.onConfirm,
    required this.onEdit,
  });

  @override
  State<_MenuItemCard> createState() => _MenuItemCardState();
}

class _MenuItemCardState extends State<_MenuItemCard> {
  IconData _getTypeIcon(int? transactionTypeId) {
    switch (transactionTypeId) {
      case 1: // Bevanda
        return Icons.local_bar;
      case 2: // Cibo
        return Icons.restaurant;
      case 3: // Biglietto
        return Icons.local_activity;
      case 4: // Extra
        return Icons.more_horiz;
      default:
        return Icons.category;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isExpanded = widget.isExpanded;
    final isConfirmed = widget.isConfirmed;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              isConfirmed
                  ? theme.colorScheme.primary.withOpacity(0.5)
                  : theme.colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: widget.onEdit,
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(12),
              bottom: Radius.circular(isExpanded ? 0 : 12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:
                          isConfirmed
                              ? theme.colorScheme.primary.withOpacity(0.2)
                              : theme.colorScheme.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getTypeIcon(widget.item.transactionTypeId),
                      color:
                          isConfirmed
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface.withOpacity(0.6),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.item.name?.isEmpty ?? true
                              ? '${'create_menu.new_item'.tr()} #${widget.index + 1}'
                              : widget.item.name!,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (isConfirmed && widget.item.price != null)
                          Text(
                            '€${widget.item.price!.toStringAsFixed(2)}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (isConfirmed) ...[
                    if (widget.item.availableQuantity != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${'create_menu.quantity_label'.tr()}: ${widget.item.availableQuantity}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.secondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    if (widget.item.isAlcoholic)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.local_bar,
                              size: 12,
                              color: Colors.orange.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'create_menu.alcoholic_label'.tr(),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.edit_outlined,
                      size: 20,
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                    ),
                  ] else
                    IconButton(
                      onPressed: widget.onRemove,
                      icon: const Icon(Icons.delete_outline),
                      color: theme.colorScheme.error,
                      iconSize: 20,
                    ),
                ],
              ),
            ),
          ),

          // Expanded content
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  const SizedBox(height: 16),

                  // Tipo transazione
                  _buildDropdown(
                    theme: theme,
                    label: 'create_menu.type_label'.tr(),
                    value: widget.item.transactionTypeId,
                    items: widget.transactionTypes,
                    onChanged: (value) {
                      widget.item.transactionTypeId = value;
                      // Reset alcoholic flag if not a drink
                      if (value != 1) {
                        widget.item.isAlcoholic = false;
                      }
                      widget.onChanged();
                    },
                  ),
                  const SizedBox(height: 12),

                  // Alcoholic toggle (solo per bevande)
                  if (widget.item.transactionTypeId == 1)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Row(
                        children: [
                          Icon(
                            Icons.local_bar,
                            size: 20,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'create_menu.alcoholic'.tr(),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      value: widget.item.isAlcoholic,
                      onChanged: (value) {
                        widget.item.isAlcoholic = value;
                        widget.onChanged();
                      },
                    ),
                  if (widget.item.transactionTypeId == 1)
                    const SizedBox(height: 12),

                  // Nome
                  _buildItemTextField(
                    theme: theme,
                    label: 'create_menu.name_label'.tr(),
                    hint: 'create_menu.name_hint'.tr(),
                    value: widget.item.name,
                    onChanged: (value) {
                      widget.item.name = value;
                      widget.onChanged();
                    },
                  ),
                  const SizedBox(height: 12),

                  // Descrizione
                  _buildItemTextField(
                    theme: theme,
                    label: 'create_menu.description_label'.tr(),
                    hint: 'create_menu.description_hint'.tr(),
                    value: widget.item.description,
                    onChanged: (value) {
                      widget.item.description = value;
                      widget.onChanged();
                    },
                  ),
                  const SizedBox(height: 12),

                  // Prezzo e quantità
                  Row(
                    children: [
                      Expanded(
                        child: _buildPriceTextField(
                          theme: theme,
                          label: 'create_menu.price_label'.tr(),
                          hint: 'create_menu.price_hint'.tr(),
                          initialValue: widget.item.price,
                          onChanged: (value) {
                            widget.item.price = value;
                            widget.onChanged();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildItemTextField(
                          theme: theme,
                          label: 'create_menu.quantity'.tr(),
                          hint: 'create_menu.unlimited'.tr(),
                          value: widget.item.availableQuantity?.toString(),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            widget.item.availableQuantity = int.tryParse(value);
                            widget.onChanged();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Pulsante conferma
                  ElevatedButton.icon(
                    onPressed: widget.onConfirm,
                    icon: const Icon(Icons.check),
                    label: Text('create_menu.confirm_item'.tr()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      minimumSize: const Size(double.infinity, 44),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required ThemeData theme,
    required String label,
    required int? value,
    required List<Map<String, dynamic>> items,
    required ValueChanged<int?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.3),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: value,
              isExpanded: true,
              hint: Text('create_menu.select_type'.tr(), style: theme.textTheme.bodyMedium),
              dropdownColor: theme.colorScheme.surface,
              style: theme.textTheme.bodyLarge,
              items:
                  items.map((item) {
                    return DropdownMenuItem<int>(
                      value: item['id'] as int,
                      child: Text(item['name'] as String),
                    );
                  }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItemTextField({
    required ThemeData theme,
    required String label,
    required String hint,
    String? value,
    required ValueChanged<String> onChanged,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.3),
            ),
          ),
          child: TextField(
            controller: TextEditingController(text: value)
              ..selection = TextSelection.collapsed(offset: value?.length ?? 0),
            onChanged: onChanged,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            style: theme.textTheme.bodyLarge,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
              contentPadding: const EdgeInsets.all(12),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceTextField({
    required ThemeData theme,
    required String label,
    required String hint,
    double? initialValue,
    required ValueChanged<double?> onChanged,
  }) {
    return _PriceTextField(
      theme: theme,
      label: label,
      hint: hint,
      initialValue: initialValue,
      onChanged: onChanged,
    );
  }
}

// Stateful widget per gestire il campo prezzo con la virgola senza far saltare il cursore
class _PriceTextField extends StatefulWidget {
  final ThemeData theme;
  final String label;
  final String hint;
  final double? initialValue;
  final ValueChanged<double?> onChanged;

  const _PriceTextField({
    required this.theme,
    required this.label,
    required this.hint,
    required this.initialValue,
    required this.onChanged,
  });

  @override
  State<_PriceTextField> createState() => _PriceTextFieldState();
}

class _PriceTextFieldState extends State<_PriceTextField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text:
          widget.initialValue != null
              ? widget.initialValue!.toStringAsFixed(2).replaceAll('.', ',')
              : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: widget.theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: widget.theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.theme.colorScheme.outline.withOpacity(0.3),
            ),
          ),
          child: TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*[,.]?\d{0,2}')),
            ],
            style: widget.theme.textTheme.bodyLarge,
            onChanged: (value) {
              if (value.isEmpty) {
                widget.onChanged(null);
              } else {
                final normalized = value.replaceAll(',', '.');
                final parsed = double.tryParse(normalized);
                widget.onChanged(parsed);
              }
            },
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: widget.theme.textTheme.bodyMedium?.copyWith(
                color: widget.theme.colorScheme.onSurface.withOpacity(0.4),
              ),
              contentPadding: const EdgeInsets.all(12),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }
}

// Classe per gestire i dati temporanei degli item
class MenuItemData {
  String? id;
  final String tempId;
  int? transactionTypeId;
  String? name;
  String? description;
  double? price;
  int? availableQuantity;
  bool isAlcoholic;

  MenuItemData({
    this.id,
    required this.tempId,
    this.transactionTypeId,
    this.name,
    this.description,
    this.price,
    this.availableQuantity,
    this.isAlcoholic = false,
  });

  bool isValid() {
    return transactionTypeId != null &&
        name != null &&
        name!.isNotEmpty &&
        price != null &&
        price! >= 0;
  }
}

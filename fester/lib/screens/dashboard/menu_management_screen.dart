import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MenuManagementScreen extends StatefulWidget {
  final String eventId;

  const MenuManagementScreen({super.key, required this.eventId});

  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _menuNameController = TextEditingController();
  final _menuDescriptionController = TextEditingController();

  bool _isLoading = true;
  String? _menuId;
  List<MenuItemData> _menuItems = [];
  List<Map<String, dynamic>> _transactionTypes = [];
  final Set<String> _expandedItems = {};
  final Set<String> _confirmedItems = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _menuNameController.dispose();
    _menuDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Load transaction types
      final typesResponse = await _supabase
          .from('transaction_type')
          .select()
          .order('id', ascending: true);
      _transactionTypes = List<Map<String, dynamic>>.from(typesResponse);

      // Load menu
      final menuResponse =
          await _supabase
              .from('menu')
              .select()
              .eq('event_id', widget.eventId)
              .maybeSingle();

      if (menuResponse != null) {
        _menuId = menuResponse['id'];
        _menuNameController.text = menuResponse['name'] ?? '';
        _menuDescriptionController.text = menuResponse['description'] ?? '';

        // Load menu items
        final itemsResponse = await _supabase
            .from('menu_item')
            .select()
            .eq('menu_id', _menuId!)
            .order('sort_order', ascending: true);

        _menuItems =
            (itemsResponse as List).map((item) {
              final menuItem = MenuItemData(
                id: item['id'] as String?,
                tempId: item['id'] as String,
                transactionTypeId: item['transaction_type_id'] as int,
                name: item['name'] as String,
                description: item['description'] as String?,
                price: (item['price'] as num?)?.toDouble(),
                availableQuantity: item['available_quantity'] as int?,
                isAlcoholic: item['is_alcoholic'] as bool? ?? false,
              );
              _confirmedItems.add(menuItem.tempId);
              return menuItem;
            }).toList();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${'menu.load_error'.tr()}$e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createMenu() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final menuData = {
        'event_id': widget.eventId,
        'name': _menuNameController.text.trim(),
        'description':
            _menuDescriptionController.text.trim().isEmpty
                ? null
                : _menuDescriptionController.text.trim(),
      };

      final menuResponse =
          await _supabase.from('menu').insert(menuData).select().single();

      _menuId = menuResponse['id'];

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('menu.created_success'.tr())));
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'menu.create_error'.tr()}$e')),
        );
      }
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
      _expandedItems.add(newItem.tempId);
    });
  }

  void _confirmMenuItem(String itemId) async {
    final item = _menuItems.firstWhere((i) => i.tempId == itemId);
    if (!item.isValid()) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('menu.complete_fields'.tr())));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final itemData = {
        'menu_id': _menuId!,
        'transaction_type_id': item.transactionTypeId!,
        'name': item.name!,
        'description':
            item.description?.isEmpty ?? true ? null : item.description,
        'price': item.price,
        'available_quantity': item.availableQuantity,
        'is_alcoholic': item.isAlcoholic,
        'sort_order': _menuItems.indexOf(item),
      };

      if (item.id == null) {
        // Create new
        final response =
            await _supabase
                .from('menu_item')
                .insert(itemData)
                .select()
                .single();
        item.id = response['id'];
      } else {
        // Update existing
        await _supabase.from('menu_item').update(itemData).eq('id', item.id!);
      }

      setState(() {
        _confirmedItems.add(itemId);
        _expandedItems.remove(itemId);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${'menu.save_error'.tr()}$e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _editMenuItem(String itemId) {
    setState(() {
      _expandedItems.add(itemId);
      _confirmedItems.remove(itemId);
    });
  }

  Future<void> _removeMenuItem(int index) async {
    final item = _menuItems[index];
    if (item.id != null) {
      try {
        await _supabase.from('menu_item').delete().eq('id', item.id!);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${'menu.delete_error'.tr()}$e')),
          );
        }
        return;
      }
    }
    setState(() {
      _menuItems.removeAt(index);
      _expandedItems.remove(item.tempId);
      _confirmedItems.remove(item.tempId);
    });
  }

  int? _selectedItemIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(title: Text('menu.title'.tr())),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // If no menu exists, show create form
    if (_menuId == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(title: Text('menu.create_title'.tr())),
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(24.0),
                children: [
                  Text(
                    'menu.create_header'.tr(),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildTextField(
                    context: context,
                    controller: _menuNameController,
                    label: 'menu.name_label'.tr(),
                    hint: 'menu.name_hint'.tr(),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'menu.name_error'.tr();
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    context: context,
                    controller: _menuDescriptionController,
                    label: 'menu.description_label'.tr(),
                    hint: 'menu.description_hint'.tr(),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _createMenu,
                    child: Text('menu.create_button'.tr()),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Menu exists, show items management
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_menuNameController.text),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              _addMenuItem();
              // Auto-select the new item on desktop
              if (MediaQuery.of(context).size.width > 900) {
                setState(() {
                  _selectedItemIndex = _menuItems.length - 1;
                });
              }
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 900;

          if (_menuItems.isEmpty) {
            return Center(
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: theme.cardTheme.color?.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.restaurant_menu,
                      size: 48,
                      color: theme.colorScheme.onSurface.withOpacity(0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'menu.no_items'.tr(),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'menu.add_hint'.tr(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          if (isDesktop) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: List of Items
                Expanded(
                  flex: 1,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _menuItems.length,
                    itemBuilder: (context, index) {
                      final item = _menuItems[index];
                      final isConfirmed = _confirmedItems.contains(item.tempId);
                      final isSelected = _selectedItemIndex == index;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color:
                              isSelected
                                  ? theme.colorScheme.primary.withOpacity(0.1)
                                  : theme.cardTheme.color,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                isSelected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.outline.withOpacity(
                                      0.1,
                                    ),
                          ),
                        ),
                        child: _MenuItemHeader(
                          item: item,
                          index: index,
                          isConfirmed: isConfirmed,
                          isExpanded: isSelected,
                          transactionTypes: _transactionTypes,
                          onEdit: () {
                            setState(() {
                              _selectedItemIndex = index;
                            });
                          },
                          onRemove: () {
                            _removeMenuItem(index);
                            if (_selectedItemIndex == index) {
                              setState(() {
                                _selectedItemIndex = null;
                              });
                            } else if (_selectedItemIndex != null &&
                                _selectedItemIndex! > index) {
                              setState(() {
                                _selectedItemIndex = _selectedItemIndex! - 1;
                              });
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
                // Vertical Divider
                Container(
                  width: 1,
                  color: theme.colorScheme.outline.withOpacity(0.2),
                ),
                // Right: Editor
                Expanded(
                  flex: 2,
                  child:
                      _selectedItemIndex != null &&
                              _selectedItemIndex! < _menuItems.length
                          ? SingleChildScrollView(
                            padding: const EdgeInsets.all(32),
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: theme.cardTheme.color,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: theme.colorScheme.outline.withOpacity(
                                    0.2,
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'menu.edit_item'.tr(),
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  _MenuItemEditor(
                                    item: _menuItems[_selectedItemIndex!],
                                    transactionTypes: _transactionTypes,
                                    onChanged: () => setState(() {}),
                                    onConfirm:
                                        () => _confirmMenuItem(
                                          _menuItems[_selectedItemIndex!]
                                              .tempId,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.touch_app,
                                  size: 64,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.2),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'menu.select_edit'.tr(),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                ),
              ],
            );
          } else {
            // Mobile Layout
            return ListView(
              padding: const EdgeInsets.all(16.0),
              children:
                  _menuItems.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final isExpanded = _expandedItems.contains(item.tempId);
                    final isConfirmed = _confirmedItems.contains(item.tempId);
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
                  }).toList(),
            );
          }
        },
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

// Menu Item Card Widget (Mobile/Combined)
class _MenuItemCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
          _MenuItemHeader(
            item: item,
            index: index,
            isConfirmed: isConfirmed,
            isExpanded: isExpanded,
            transactionTypes: transactionTypes,
            onEdit: onEdit,
            onRemove: onRemove,
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  const Divider(),
                  const SizedBox(height: 16),
                  _MenuItemEditor(
                    item: item,
                    transactionTypes: transactionTypes,
                    onChanged: onChanged,
                    onConfirm: onConfirm,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MenuItemHeader extends StatelessWidget {
  final MenuItemData item;
  final int index;
  final bool isConfirmed;
  final bool isExpanded;
  final List<Map<String, dynamic>> transactionTypes;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const _MenuItemHeader({
    required this.item,
    required this.index,
    required this.isConfirmed,
    required this.isExpanded,
    required this.transactionTypes,
    required this.onEdit,
    required this.onRemove,
  });

  IconData _getTypeIcon(int? transactionTypeId) {
    if (transactionTypeId == null) return Icons.category;
    final type = transactionTypes.firstWhere(
      (t) => t['id'] == transactionTypeId,
      orElse: () => {},
    );
    final name = (type['name'] as String?)?.toLowerCase() ?? '';

    if (name.contains('drink') || name.contains('bevanda')) {
      return Icons.local_bar;
    }
    if (name.contains('food') || name.contains('cibo')) return Icons.restaurant;
    if (name.contains('ticket') || name.contains('biglietto')) {
      return Icons.confirmation_number;
    }
    if (name.contains('sanction')) return Icons.block;
    if (name.contains('report')) return Icons.warning;
    if (name.contains('refund') || name.contains('rimborso')) {
      return Icons.replay_circle_filled;
    }
    if (name.contains('fee') || name.contains('tassa')) {
      return Icons.monetization_on;
    }
    if (name.contains('fine') || name.contains('multa')) return Icons.gavel;

    return Icons.attach_money;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onEdit,
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
                _getTypeIcon(item.transactionTypeId),
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
                    item.name?.isEmpty ?? true
                        ? 'menu.new_item'.tr(args: [(index + 1).toString()])
                        : item.name!,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (isConfirmed && item.price != null)
                    Text(
                      '€${item.price!.toStringAsFixed(2)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
            if (isConfirmed) ...[
              if (item.availableQuantity != null)
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
                    'menu.qty'.tr(args: [item.availableQuantity.toString()]),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.secondary,
                      fontWeight: FontWeight.w600,
                    ),
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
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
                color: theme.colorScheme.error,
                iconSize: 20,
              ),
          ],
        ),
      ),
    );
  }
}

class _MenuItemEditor extends StatefulWidget {
  final MenuItemData item;
  final List<Map<String, dynamic>> transactionTypes;
  final VoidCallback onChanged;
  final VoidCallback onConfirm;

  const _MenuItemEditor({
    required this.item,
    required this.transactionTypes,
    required this.onChanged,
    required this.onConfirm,
  });

  @override
  State<_MenuItemEditor> createState() => _MenuItemEditorState();
}

class _MenuItemEditorState extends State<_MenuItemEditor> {
  bool _isBeverage() {
    if (widget.item.transactionTypeId == null) return false;
    final type = widget.transactionTypes.firstWhere(
      (t) => t['id'] == widget.item.transactionTypeId,
      orElse: () => {},
    );
    final name = (type['name'] as String?)?.toLowerCase() ?? '';
    return name.contains('drink') || name.contains('bevanda');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Transaction Type Dropdown
        _buildDropdown(
          theme: theme,
          label: 'menu.type_label'.tr(),
          value: widget.item.transactionTypeId,
          items: widget.transactionTypes,
          onChanged: (value) {
            widget.item.transactionTypeId = value;
            widget.onChanged();
            setState(() {}); // Update for _isBeverage check
          },
        ),
        const SizedBox(height: 12),

        // Name
        _buildItemTextField(
          theme: theme,
          label: 'menu.item_name_label'.tr(),
          hint: 'menu.item_name_hint'.tr(),
          value: widget.item.name,
          onChanged: (value) {
            widget.item.name = value;
            widget.onChanged();
          },
        ),
        const SizedBox(height: 12),

        // Description
        _buildItemTextField(
          theme: theme,
          label: 'menu.description_label'.tr(),
          hint: 'menu.item_description_hint'.tr(),
          value: widget.item.description,
          onChanged: (value) {
            widget.item.description = value;
            widget.onChanged();
          },
        ),
        const SizedBox(height: 12),

        // Price and Quantity
        Row(
          children: [
            Expanded(
              child: _buildPriceTextField(
                theme: theme,
                label: 'menu.price_label'.tr(),
                hint: '0,00',
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
                label: 'menu.quantity_label'.tr(),
                hint: 'menu.quantity_hint'.tr(),
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
        const SizedBox(height: 12),

        // Alcoholic checkbox (only for beverages)
        if (_isBeverage())
          CheckboxListTile(
            title: Text('menu.alcoholic'.tr()),
            value: widget.item.isAlcoholic,
            onChanged: (value) {
              setState(() {
                widget.item.isAlcoholic = value ?? false;
                widget.onChanged();
              });
            },
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
          ),

        const SizedBox(height: 16),

        // Confirm button
        ElevatedButton.icon(
          onPressed: widget.onConfirm,
          icon: const Icon(Icons.check),
          label: Text('menu.confirm_item'.tr()),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            minimumSize: const Size(double.infinity, 44),
          ),
        ),
      ],
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
              hint: Text(
                'menu.select_type'.tr(),
                style: theme.textTheme.bodyMedium,
              ),
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

// Price TextField Widget
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

// Menu Item Data Class
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

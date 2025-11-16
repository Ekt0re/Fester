// lib/screens/create_menu_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreateMenuScreen extends StatefulWidget {
  final String? eventId; // Opzionale per caricare menu esistente
  
  const CreateMenuScreen({Key? key, this.eventId}) : super(key: key);

  @override
  State<CreateMenuScreen> createState() => _CreateMenuScreenState();
}

class _CreateMenuScreenState extends State<CreateMenuScreen> {
  final _formKey = GlobalKey<FormState>();
  final _menuNameController = TextEditingController();
  final _menuDescriptionController = TextEditingController();
  
  final List<MenuItemData> _menuItems = [];
  final Set<String> _expandedItems = {}; // Item espansi
  final Set<String> _confirmedItems = {}; // Item confermati (collassati)
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadExistingMenu();
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
      final menuResponse = await supabase
          .from('menu')
          .select()
          .eq('event_id', widget.eventId!)
          .maybeSingle();
      
      if (menuResponse != null) {
        _menuNameController.text = menuResponse['name'] as String? ?? '';
        _menuDescriptionController.text = menuResponse['description'] as String? ?? '';
        
        // Carica menu items
        final itemsResponse = await supabase
            .from('menu_item')
            .select()
            .eq('menu_id', menuResponse['id'] as String)
            .order('sort_order', ascending: true);
        
        final items = (itemsResponse as List).map((item) {
          return MenuItemData(
            tempId: item['id'] as String,
            transactionTypeId: item['transaction_type_id'] as int,
            name: item['name'] as String,
            description: item['description'] as String?,
            price: (item['price'] as num).toDouble(),
            availableQuantity: item['available_quantity'] as int?,
          );
        }).toList();
        
        setState(() {
          _menuItems.addAll(items);
          // Tutti gli item esistenti sono confermati (collassati)
          _confirmedItems.addAll(items.map((item) => item.tempId));
        });
      }
    } catch (e) {
      debugPrint('Errore caricamento menu: $e');
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
        const SnackBar(content: Text('Completa tutti i campi obbligatori')),
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
        const SnackBar(content: Text('Aggiungi almeno un item al menù')),
      );
      return;
    }

    // Valida tutti gli item
    for (var item in _menuItems) {
      if (!item.isValid()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Completa tutti i campi degli item del menù'),
          ),
        );
        return;
      }
    }

    // Prepara i dati del menù da restituire (salvati in memoria)
    final menuName = _menuNameController.text.trim();
    final menuDescription = _menuDescriptionController.text.trim().isEmpty
        ? null
        : _menuDescriptionController.text.trim();
    
    final menuItemsData = _menuItems.map((item) {
      return {
        'transaction_type_id': item.transactionTypeId!,
        'name': item.name!,
        'description': item.description?.isEmpty ?? true ? null : item.description,
        'price': item.price!,
        'available_quantity': item.availableQuantity,
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
    return Scaffold(
      backgroundColor: const Color(0xFFB8D4E8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFB8D4E8),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Crea Menù',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(24.0),
                children: [
                  const Text(
                    'CREA MENÙ E PREZIARIO',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Nome menù
                  _buildTextField(
                    controller: _menuNameController,
                    label: 'Nome Menù',
                    hint: 'Es: Menù Principale',
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Inserisci il nome del menù';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Descrizione menù
                  _buildTextField(
                    controller: _menuDescriptionController,
                    label: 'Descrizione (opzionale)',
                    hint: 'Descrivi il menù...',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 32),

                  // Header items
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Item del Menù',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: _addMenuItem,
                        icon: const Icon(Icons.add_circle),
                        color: Colors.green,
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
                        color: Colors.white.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.black12,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.restaurant_menu,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Nessun item aggiunto',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Premi + per aggiungere',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 14,
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
                      final isConfirmed = _confirmedItems.contains(item.tempId);
                      return _MenuItemCard(
                        item: item,
                        index: index,
                        isExpanded: isExpanded,
                        isConfirmed: isConfirmed,
                        onRemove: () => _removeMenuItem(index),
                        onChanged: () => setState(() {}),
                        onConfirm: () => _confirmMenuItem(item.tempId),
                        onEdit: () => _editMenuItem(item.tempId),
                      );
                    }).toList(),

                  const SizedBox(height: 32),

                  // Pulsante salva
                  ElevatedButton(
                    onPressed: _saveMenu,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      backgroundColor: Colors.black87,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Salva Menù',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Pulsante salta
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Salta per ora',
                      style: TextStyle(
                        color: Colors.black54,
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
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.black12),
          ),
          child: TextFormField(
            controller: controller,
            maxLines: maxLines,
            validator: validator,
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
class _MenuItemCard extends StatelessWidget {
  final MenuItemData item;
  final int index;
  final bool isExpanded;
  final bool isConfirmed;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  final VoidCallback onConfirm;
  final VoidCallback onEdit;

  const _MenuItemCard({
    required this.item,
    required this.index,
    required this.isExpanded,
    required this.isConfirmed,
    required this.onRemove,
    required this.onChanged,
    required this.onConfirm,
    required this.onEdit,
  });

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
    if (isConfirmed && !isExpanded) {
      // Vista collassata: mostra solo nome, prezzo, quantità e icona
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withOpacity(0.3), width: 2),
        ),
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icona tipo
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getTypeIcon(item.transactionTypeId),
                    color: Colors.green[700],
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                // Nome
                Expanded(
                  child: Text(
                    item.name ?? 'Senza nome',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Prezzo
                Text(
                  '€${item.price?.toStringAsFixed(2) ?? '0.00'}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
                const SizedBox(width: 12),
                // Quantità
                Text(
                  item.availableQuantity != null
                      ? 'Qty: ${item.availableQuantity}'
                      : 'Illimitata',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 8),
                // Icona edit
                Icon(
                  Icons.edit,
                  size: 20,
                  color: Colors.grey[600],
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Vista espansa: mostra tutti i campi
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        children: [
          // Header con numero e rimuovi
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (item.transactionTypeId != null)
                      Icon(
                        _getTypeIcon(item.transactionTypeId),
                        color: Colors.white,
                        size: 20,
                      ),
                    const SizedBox(width: 8),
                    Text(
                      'Item #${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete),
                  color: Colors.red[300],
                  iconSize: 20,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tipo transazione
                _buildDropdown(
                  label: 'Tipo',
                  value: item.transactionTypeId,
                  items: const [
                    {'id': 1, 'name': 'Bevanda'},
                    {'id': 2, 'name': 'Cibo'},
                    {'id': 3, 'name': 'Biglietto'},
                    {'id': 4, 'name': 'Extra'},
                  ],
                  onChanged: (value) {
                    item.transactionTypeId = value;
                    onChanged();
                  },
                ),
                const SizedBox(height: 12),

                // Nome
                _buildItemTextField(
                  label: 'Nome',
                  hint: 'Es: Birra Media',
                  value: item.name,
                  onChanged: (value) {
                    item.name = value;
                    onChanged();
                  },
                ),
                const SizedBox(height: 12),

                // Descrizione
                _buildItemTextField(
                  label: 'Descrizione (opzionale)',
                  hint: 'Dettagli...',
                  value: item.description,
                  onChanged: (value) {
                    item.description = value;
                    onChanged();
                  },
                ),
                const SizedBox(height: 12),

                // Prezzo e quantità
                Row(
                  children: [
                    Expanded(
                      child: _buildItemTextField(
                        label: 'Prezzo (€)',
                        hint: '0.00',
                        value: item.price?.toStringAsFixed(2),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                        onChanged: (value) {
                          item.price = double.tryParse(value.replaceAll(',', '.'));
                          onChanged();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildItemTextField(
                        label: 'Quantità (opz.)',
                        hint: 'Illimitata',
                        value: item.availableQuantity?.toString(),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          item.availableQuantity = int.tryParse(value);
                          onChanged();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Pulsante conferma
                ElevatedButton.icon(
                  onPressed: onConfirm,
                  icon: const Icon(Icons.check),
                  label: const Text('Conferma Item'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
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
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.black12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: value,
              isExpanded: true,
              hint: const Text('Seleziona tipo'),
              items: items.map((item) {
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
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.black12),
          ),
          child: TextField(
            controller: TextEditingController(text: value)
              ..selection = TextSelection.collapsed(
                offset: value?.length ?? 0,
              ),
            onChanged: onChanged,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            decoration: InputDecoration(
              hintText: hint,
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
  final String tempId;
  int? transactionTypeId;
  String? name;
  String? description;
  double? price;
  int? availableQuantity;

  MenuItemData({
    required this.tempId,
    this.transactionTypeId,
    this.name,
    this.description,
    this.price,
    this.availableQuantity,
  });

  bool isValid() {
    return transactionTypeId != null &&
        name != null &&
        name!.isNotEmpty &&
        price != null &&
        price! >= 0;
  }
}
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/SupabaseServicies/event_service.dart';
import '../../../services/SupabaseServicies/transaction_service.dart';
import '../../../services/SupabaseServicies/person_service.dart';
import '../../../theme/app_theme.dart';

class TransactionCreationSheet extends StatefulWidget {
  final String eventId;
  final String participationId;
  final String? initialTransactionType;
  final VoidCallback onSuccess;

  const TransactionCreationSheet({
    super.key,
    required this.eventId,
    required this.participationId,
    this.initialTransactionType,
    required this.onSuccess,
  });

  @override
  State<TransactionCreationSheet> createState() => _TransactionCreationSheetState();
}

class _TransactionCreationSheetState extends State<TransactionCreationSheet> {
  final EventService _eventService = EventService();
  final TransactionService _transactionService = TransactionService();
  final PersonService _personService = PersonService();
  
  List<Map<String, dynamic>> _menuItems = [];
  List<Map<String, dynamic>> _transactionTypes = [];
  bool _isLoading = true;
  
  // Form State
  String? _selectedMenuItemId;
  dynamic _selectedTypeId; // Changed to dynamic to handle int or String (UUID)
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  int _quantity = 1;
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      print('Loading transaction creation data...');
      
      // Load transaction types first (CRITICAL)
      final types = await _personService.getTransactionTypes();
      print('Loaded ${types.length} transaction types');
      
      // Load menu items (OPTIONAL)
      List<Map<String, dynamic>> items = [];
      try {
        items = await _eventService.getEventMenuItems(widget.eventId);
        print('Loaded ${items.length} menu items');
      } catch (e) {
        print('Error loading menu items (non-fatal): $e');
        // We continue without menu items
      }
      
      if (mounted) {
        setState(() {
          _menuItems = items;
          _transactionTypes = types;
          _isLoading = false;
          
          // Preselect type if provided
          if (widget.initialTransactionType != null) {
            final type = _transactionTypes.firstWhere(
              (t) => (t['name'] as String).toLowerCase() == widget.initialTransactionType!.toLowerCase(),
              orElse: () => _transactionTypes.isNotEmpty ? _transactionTypes.first : {},
            );
            if (type.isNotEmpty) {
              _selectedTypeId = type['id'];
            }
          } 
          
          // If still null and we have types, select the first one
          if (_selectedTypeId == null && _transactionTypes.isNotEmpty) {
             _selectedTypeId = _transactionTypes.first['id'];
          }
          
          print('Selected Type ID: $_selectedTypeId');
        });
      }
    } catch (e, stackTrace) {
      print('Error loading critical data: $e');
      print(stackTrace);
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore caricamento dati: $e')),
        );
      }
    }
  }

  void _onMenuItemSelected(String? itemId) {
    setState(() {
      _selectedMenuItemId = itemId;
      if (itemId != null) {
        final item = _menuItems.firstWhere((i) => i['id'] == itemId);
        _nameController.text = item['name'];
        _amountController.text = item['price'].toString();
      } else {
        _nameController.clear();
        _amountController.clear();
      }
    });
  }

  Future<void> _createTransaction() async {
    if (_selectedTypeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona un tipo di transazione')),
      );
      return;
    }
    
    // Get selected type details
    final type = _transactionTypes.firstWhere(
      (t) => t['id'] == _selectedTypeId,
      orElse: () => {},
    );
    
    if (type.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Errore: Tipo transazione non valido')),
      );
      return;
    }

    final isMonetary = type['is_monetary'] ?? true;

    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci un nome')),
      );
      return;
    }

    double amount = 0.0;
    
    if (isMonetary) {
      final parsedAmount = double.tryParse(_amountController.text.replaceAll(',', '.'));
      if (parsedAmount == null || parsedAmount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Inserisci un prezzo valido (maggiore di 0)'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }
      amount = parsedAmount;
    }

    setState(() => _isLoading = true);
    try {
      await _transactionService.createTransaction(
        participationId: widget.participationId,
        transactionTypeId: _selectedTypeId!,
        menuItemId: _selectedMenuItemId,
        name: _nameController.text,
        description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
        quantity: _quantity,
        amount: amount,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transazione aggiunta!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // Determine if current type is monetary
    bool isMonetary = true;
    if (_selectedTypeId != null && _transactionTypes.isNotEmpty) {
      final type = _transactionTypes.firstWhere(
        (t) => t['id'] == _selectedTypeId,
        orElse: () => {},
      );
      if (type.isNotEmpty) {
        isMonetary = type['is_monetary'] ?? true;
      }
    }

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 24,
        left: 24,
        right: 24,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          Text(
            'Nuova Transazione',
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.bodyLarge?.color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else ...[
            // Type Selector
            if (_transactionTypes.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.amber),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Nessun tipo di transazione disponibile. Contatta l\'amministratore.',
                        style: GoogleFonts.outfit(color: theme.textTheme.bodyLarge?.color),
                      ),
                    ),
                  ],
                ),
              )
            else
              DropdownButtonFormField<dynamic>(
                value: _selectedTypeId,
                decoration: _inputDecoration('Tipo Transazione', theme),
                items: _transactionTypes.map((type) {
                  final name = (type['name'] as String).toUpperCase();
                  final affectsDrink = type['affects_drink_count'] == true;
                  return DropdownMenuItem<dynamic>(
                    value: type['id'],
                    child: Row(
                      children: [
                        Text(name, style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color)),
                        if (affectsDrink) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.local_bar, size: 16, color: Colors.grey),
                        ],
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedTypeId = value),
                dropdownColor: theme.cardColor,
              ),
            const SizedBox(height: 16),

            // Menu Item Dropdown
            DropdownButtonFormField<String>(
              value: _selectedMenuItemId,
              decoration: _inputDecoration('Seleziona dal Menu (Opzionale)', theme),
              items: [
                DropdownMenuItem<String>(
                  value: null,
                  child: Text(
                    'Nessuno (Personalizzato)',
                    style: GoogleFonts.outfit(color: Colors.grey[600]),
                  ),
                ),
                ..._menuItems.map((item) => DropdownMenuItem<String>(
                  value: item['id'],
                  child: Text(
                    '${item['name']} - €${item['price']}',
                    style: GoogleFonts.outfit(color: theme.textTheme.bodyLarge?.color),
                  ),
                )),
              ],
              onChanged: _onMenuItemSelected,
              dropdownColor: theme.cardColor,
            ),
            const SizedBox(height: 16),

            // Name
            TextField(
              controller: _nameController,
              decoration: _inputDecoration('Nome', theme),
              style: GoogleFonts.outfit(color: theme.textTheme.bodyLarge?.color),
            ),
            const SizedBox(height: 16),
            
            // Description
            TextField(
              controller: _descriptionController,
              decoration: _inputDecoration('Descrizione (Opzionale)', theme),
              style: GoogleFonts.outfit(color: theme.textTheme.bodyLarge?.color),
            ),
            const SizedBox(height: 16),

            // Price & Quantity Row
            Row(
              children: [
                Expanded(
                  child: Opacity(
                    opacity: isMonetary ? 1.0 : 0.5,
                    child: TextField(
                      controller: _amountController,
                      enabled: isMonetary,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      decoration: _inputDecoration(
                        isMonetary ? 'Prezzo (€)' : 'Prezzo (Non applicabile)', 
                        theme
                      ),
                      style: GoogleFonts.outfit(color: theme.textTheme.bodyLarge?.color),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          if (_quantity > 1) setState(() => _quantity--);
                        },
                        icon: Icon(Icons.remove, color: colorScheme.primary),
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: EdgeInsets.zero,
                      ),
                      SizedBox(
                        width: 30,
                        child: Text(
                          '$_quantity',
                          style: GoogleFonts.outfit(
                            fontSize: 18, 
                            fontWeight: FontWeight.bold,
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      IconButton(
                        onPressed: () => setState(() => _quantity++),
                        icon: Icon(Icons.add, color: colorScheme.primary),
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _createTransaction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                  shadowColor: colorScheme.primary.withOpacity(0.4),
                ),
                child: Text(
                  'AGGIUNGI TRANSAZIONE',
                  style: GoogleFonts.outfit(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, ThemeData theme) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.outfit(color: Colors.grey[600]),
      filled: true,
      fillColor: theme.cardColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}

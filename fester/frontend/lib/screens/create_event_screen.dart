import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:fester_frontend/blocs/event/event_bloc.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({Key? key}) : super(key: key);

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  DateTime selectedDateTime = DateTime.now().add(const Duration(days: 1));

  late final FormGroup form = FormGroup({
    'nome': FormControl<String>(
      validators: [Validators.required],
    ),
    'luogo': FormControl<String>(
      validators: [Validators.required],
    ),
    'data_ora': FormControl<DateTime>(
      value: selectedDateTime,
      validators: [Validators.required],
    ),
    'regole': FormControl<Map<String, dynamic>>(
      value: {},
    ),
  });

  final List<Map<String, dynamic>> regoleList = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crea Evento'),
      ),
      body: BlocListener<EventBloc, EventState>(
        listener: (context, state) {
          if (state is EventOperationSuccess) {
            // Mostra messaggio di successo
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
            // Torna alla home
            context.go('/home');
          } else if (state is EventFailure) {
            // Mostra errore
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: ReactiveForm(
            formGroup: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Informazioni Evento',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Nome evento
                ReactiveTextField<String>(
                  formControlName: 'nome',
                  decoration: const InputDecoration(
                    labelText: 'Nome Evento *',
                    hintText: 'Es. Festa di compleanno',
                    border: OutlineInputBorder(),
                  ),
                  validationMessages: {
                    'required': (error) => 'Il nome dell\'evento è obbligatorio',
                  },
                ),
                const SizedBox(height: 16),
                
                // Luogo
                ReactiveTextField<String>(
                  formControlName: 'luogo',
                  decoration: const InputDecoration(
                    labelText: 'Luogo *',
                    hintText: 'Es. Sala Eventi, Via Roma 123',
                    border: OutlineInputBorder(),
                  ),
                  validationMessages: {
                    'required': (error) => 'Il luogo è obbligatorio',
                  },
                ),
                const SizedBox(height: 16),
                
                // Data e ora
                InkWell(
                  onTap: () => _selectDateTime(context),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Data e Ora *',
                      border: OutlineInputBorder(),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('dd/MM/yyyy HH:mm').format(selectedDateTime),
                        ),
                        const Icon(Icons.calendar_today),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Sezione regole
                const Text(
                  'Regole dell\'Evento',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Aggiungi regole o informazioni specifiche per il tuo evento',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Lista regole
                ...regoleList.map((regola) => _buildRegolaItem(regola)).toList(),
                
                // Pulsante aggiungi regola
                OutlinedButton.icon(
                  onPressed: () => _showAddRegolaDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('Aggiungi Regola'),
                ),
                
                const SizedBox(height: 32),
                
                // Pulsante crea evento
                BlocBuilder<EventBloc, EventState>(
                  builder: (context, state) {
                    return SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: state is EventLoading
                            ? null
                            : () {
                                if (form.valid) {
                                  final nome = form.control('nome').value as String;
                                  final luogo = form.control('luogo').value as String;
                                  
                                  // Converte la lista di regole in mappa
                                  final Map<String, dynamic> regoleMap = {};
                                  for (var regola in regoleList) {
                                    regoleMap[regola['nome']] = regola['valore'];
                                  }
                                  
                                  context.read<EventBloc>().add(
                                    EventCreateRequested(
                                      eventData: {
                                        'nome': nome,
                                        'luogo': luogo,
                                        'data_ora': selectedDateTime.toIso8601String(),
                                        'regole': regoleMap,
                                      },
                                    ),
                                  );
                                } else {
                                  form.markAllAsTouched();
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: state is EventLoading
                            ? const CircularProgressIndicator()
                            : const Text(
                                'CREA EVENTO',
                                style: TextStyle(fontSize: 16),
                              ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRegolaItem(Map<String, dynamic> regola) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    regola['nome'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(regola['valore']),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () {
                setState(() {
                  regoleList.remove(regola);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDateTime(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    
    if (pickedDate != null && mounted) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(selectedDateTime),
      );
      
      if (pickedTime != null && mounted) {
        setState(() {
          selectedDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
          form.control('data_ora').value = selectedDateTime;
        });
      }
    }
  }

  void _showAddRegolaDialog() {
    final formDialog = FormGroup({
      'nome': FormControl<String>(validators: [Validators.required]),
      'valore': FormControl<String>(validators: [Validators.required]),
    });
    
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Aggiungi Regola'),
          content: ReactiveForm(
            formGroup: formDialog,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ReactiveTextField<String>(
                  formControlName: 'nome',
                  decoration: const InputDecoration(
                    labelText: 'Nome Regola',
                    hintText: 'Es. Dress Code',
                  ),
                  validationMessages: {
                    'required': (error) => 'Questo campo è obbligatorio',
                  },
                ),
                const SizedBox(height: 16),
                ReactiveTextField<String>(
                  formControlName: 'valore',
                  decoration: const InputDecoration(
                    labelText: 'Valore',
                    hintText: 'Es. Elegante',
                  ),
                  validationMessages: {
                    'required': (error) => 'Questo campo è obbligatorio',
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('ANNULLA'),
            ),
            ReactiveFormConsumer(
              builder: (dialogContext, form, child) {
                return TextButton(
                  onPressed: form.valid
                      ? () {
                          final nome = formDialog.control('nome').value as String;
                          final valore = formDialog.control('valore').value as String;
                          
                          setState(() {
                            regoleList.add({
                              'nome': nome,
                              'valore': valore,
                            });
                          });
                          
                          Navigator.of(dialogContext).pop();
                        }
                      : null,
                  child: const Text('AGGIUNGI'),
                );
              },
            ),
          ],
        ),
      );
    }
  }
} 
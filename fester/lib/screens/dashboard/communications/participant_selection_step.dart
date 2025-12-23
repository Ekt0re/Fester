import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class ParticipantSelectionStep extends StatefulWidget {
  final List<Map<String, dynamic>> participants;
  final Set<String> selectedIds;
  final Function(String) onToggle;
  final VoidCallback onToggleAll;

  const ParticipantSelectionStep({
    super.key,
    required this.participants,
    required this.selectedIds,
    required this.onToggle,
    required this.onToggleAll,
  });

  @override
  State<ParticipantSelectionStep> createState() =>
      _ParticipantSelectionStepState();
}

class _ParticipantSelectionStepState extends State<ParticipantSelectionStep> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredParticipants = [];

  @override
  void initState() {
    super.initState();
    _filteredParticipants = widget.participants;
    _searchController.addListener(_filterParticipants);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterParticipants() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredParticipants =
          widget.participants.where((p) {
            final person = p['person'] ?? {};
            final name =
                '${person['first_name'] ?? ''} ${person['last_name'] ?? ''}'
                    .toLowerCase();
            final email = (person['email'] ?? '').toLowerCase();
            return name.contains(query) || email.contains(query);
          }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'guest_list.search_placeholder'.tr(),
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: theme.cardColor.withOpacity(0.5),
          child: Row(
            children: [
              Checkbox(
                value:
                    widget.selectedIds.length == widget.participants.length &&
                    widget.participants.isNotEmpty,
                tristate:
                    widget.selectedIds.isNotEmpty &&
                    widget.selectedIds.length < widget.participants.length,
                onChanged: (_) => widget.onToggleAll(),
              ),
              Text(
                'communications.selected'.tr(
                  args: [widget.selectedIds.length.toString()],
                ),
                style: theme.textTheme.titleSmall,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _filteredParticipants.length,
            itemBuilder: (context, index) {
              final participant = _filteredParticipants[index];
              final person = participant['person'] ?? {};
              final id = participant['id'].toString();
              final name =
                  '${person['first_name'] ?? ''} ${person['last_name'] ?? ''}'
                      .trim();
              final email = person['email'] ?? '';
              final hasEmail = email.isNotEmpty;

              return ListTile(
                leading: Checkbox(
                  value: widget.selectedIds.contains(id),
                  onChanged: (_) => widget.onToggle(id),
                ),
                title: Text(
                  name.isEmpty ? 'communications.no_name'.tr() : name,
                ),
                subtitle:
                    hasEmail
                        ? Text(email, style: const TextStyle(fontSize: 12))
                        : Text(
                          'common.no_email'.tr(),
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.error,
                          ),
                        ),
                trailing:
                    hasEmail
                        ? const Icon(
                          Icons.email_outlined,
                          size: 20,
                          color: Colors.green,
                        )
                        : const Icon(
                          Icons.warning_amber_rounded,
                          size: 20,
                          color: Colors.orange,
                        ),
                onTap: () => widget.onToggle(id),
              );
            },
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../services/supabase/participation_service.dart';
import '../qr_scanner_screen.dart';

class PeopleSearchSheet extends StatefulWidget {
  final String eventId;
  final String? filterAreaId; // If set, only show people in this area
  final bool
  excludePeopleInAreas; // If set, exclude people already in ANY area (optional)
  final String?
  excludePeopleInSpecificAreaId; // If set, exclude people in THIS specific area

  const PeopleSearchSheet({
    super.key,
    required this.eventId,
    this.filterAreaId,
    this.excludePeopleInAreas = false,
    this.excludePeopleInSpecificAreaId,
  });

  @override
  State<PeopleSearchSheet> createState() => _PeopleSearchSheetState();
}

class _PeopleSearchSheetState extends State<PeopleSearchSheet> {
  final ParticipationService _service = ParticipationService();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allParticipations = [];
  List<Map<String, dynamic>> _filteredParticipations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final data = await _service.getEventParticipations(widget.eventId);

      List<Map<String, dynamic>> filtered = data;

      // Apply initial filters
      if (widget.filterAreaId != null) {
        filtered =
            filtered
                .where((p) => p['current_area_id'] == widget.filterAreaId)
                .toList();
      } else if (widget.excludePeopleInAreas) {
        filtered = filtered.where((p) => p['current_area_id'] == null).toList();
      } else if (widget.excludePeopleInSpecificAreaId != null) {
        // Exclude people who are currently in the specific area (prevent adding same person twice)
        filtered =
            filtered
                .where(
                  (p) =>
                      p['current_area_id'] !=
                      widget.excludePeopleInSpecificAreaId,
                )
                .toList();
      }

      if (mounted) {
        setState(() {
          _allParticipations = filtered;
          _filteredParticipations = filtered;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _filter(String query) {
    setState(() {
      _filteredParticipations =
          _allParticipations.where((p) {
            final person = p['person'] ?? {};
            final name = (person['first_name'] ?? '').toString().toLowerCase();
            final surname =
                (person['last_name'] ?? '').toString().toLowerCase();
            final personId = (person['id'] ?? '').toString().toLowerCase();
            final participationId = (p['id'] ?? '').toString().toLowerCase();

            final q = query.toLowerCase();

            return name.contains(q) ||
                surname.contains(q) ||
                personId == q ||
                participationId == q;
          }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Use a clear, distinguishable background color, or fallback to modal color
    final backgroundColor =
        theme.bottomSheetTheme.modalBackgroundColor ?? theme.cardColor;

    return Container(
      padding: const EdgeInsets.all(16),
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: backgroundColor, // Apply background color
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Slider Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: theme.dividerColor.withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'add_guest.search_person'.tr(),
                    filled: true,
                    fillColor: theme.cardColor.withOpacity(
                      0.5,
                    ), // Slightly specialized input bg
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: _filter,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => QRScannerScreen(eventId: widget.eventId),
                    ),
                  );

                  if (result != null && result is String && mounted) {
                    _searchController.text = result;
                    _filter(result);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                      itemCount: _filteredParticipations.length,
                      itemBuilder: (context, index) {
                        final item = _filteredParticipations[index];
                        final person = item['person'] ?? {};
                        // Check if they are in an area to show visual hint?
                        final currentAreaId = item['current_area_id'];
                        final isInArea = currentAreaId != null;

                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              (person['first_name']?[0] ?? '?')
                                  .toString()
                                  .toUpperCase(),
                            ),
                          ),
                          title: Text(
                            '${person['first_name']} ${person['last_name']}',
                          ),
                          subtitle: Text(
                            isInArea
                                ? (item['current_area']?['name'] ??
                                    'common.in_area'.tr())
                                : (item['status']?['name']
                                        ?.toString()
                                        .toUpperCase() ??
                                    'common.unknown'.tr().toUpperCase()),
                            style:
                                isInArea
                                    ? TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    )
                                    : null,
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                          ),
                          onTap: () {
                            Navigator.pop(
                              context,
                              item['id'],
                            ); // Return Participation ID
                          },
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}

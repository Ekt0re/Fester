import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/SupabaseServicies/event_service.dart';
import '../../services/SupabaseServicies/models/event_staff.dart';
import '../../theme/app_theme.dart';
import 'widgets/staff_card.dart';
import '../profile/staff_profile_screen.dart';

class StaffListScreen extends StatefulWidget {
  final String eventId;

  const StaffListScreen({super.key, required this.eventId});

  @override
  State<StaffListScreen> createState() => _StaffListScreenState();
}

class _StaffListScreenState extends State<StaffListScreen> {
  final EventService _eventService = EventService();
  final TextEditingController _searchController = TextEditingController();
  
  List<EventStaff> _allStaff = [];
  List<EventStaff> _filteredStaff = [];
  bool _isLoading = true;


  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final staffList = await _eventService.getEventStaff(widget.eventId);
      
      if (mounted) {
        setState(() {
          _allStaff = staffList;
          _filteredStaff = staffList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore caricamento staff: $e')),
        );
      }
    }
  }

  void _filterList(String query) {
    setState(() {

      if (query.isEmpty) {
        _filteredStaff = _allStaff;
      } else {
        _filteredStaff = _allStaff.where((s) {
          final name = (s.staff?.firstName ?? '').toLowerCase();
          final surname = (s.staff?.lastName ?? '').toLowerCase();
          final email = (s.staff?.email ?? '').toLowerCase();
          final role = (s.roleName ?? '').toLowerCase();
          final q = query.toLowerCase();
          return name.contains(q) || surname.contains(q) || email.contains(q) || role.contains(q);
        }).toList();
      }
    });
  }

  Widget _buildStaffItem(BuildContext context, int index) {
    final staffMember = _filteredStaff[index];
    final staffUser = staffMember.staff;
    final roleName = staffMember.roleName ?? 'Unknown';

    return StaffCard(
      name: staffUser?.firstName ?? 'Unknown',
      surname: staffUser?.lastName ?? '',
      role: roleName,
      imageUrl: staffUser?.imagePath, // Assuming imagePath is a full URL or handled by StaffCard
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StaffProfileScreen(
              eventStaff: staffMember,
              eventId: widget.eventId,
            ),
          ),
        );
        // Reload list when returning, in case of edits
        _loadData();
      },
    );
  }

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
        title: Column(
          children: [
            Text(
              'Staff Evento',
              style: GoogleFonts.outfit(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.bold),
            ),
            Text(
              'Totale: ${_allStaff.length}',
              style: GoogleFonts.outfit(color: theme.colorScheme.onPrimary.withOpacity(0.7), fontSize: 12),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.sync, color: theme.colorScheme.onPrimary),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search
          Container(
            padding: const EdgeInsets.all(16),
            color: theme.colorScheme.primary.withOpacity(0.1),
            child: TextField(
              controller: _searchController,
              onChanged: _filterList,
              decoration: InputDecoration(
                hintText: 'Cerca membro staff...',
                prefixIcon: const Icon(Icons.search),
                fillColor: theme.colorScheme.surface,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          
          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth > 900) {
                        return Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1200),
                            child: GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 3.5, 
                              ),
                              itemCount: _filteredStaff.length,
                              itemBuilder: _buildStaffItem,
                            ),
                          ),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredStaff.length,
                        itemBuilder: _buildStaffItem,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

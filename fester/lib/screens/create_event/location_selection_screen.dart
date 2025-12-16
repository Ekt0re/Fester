import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:http/http.dart' as http;

class LocationSelectionScreen extends StatefulWidget {
  final LatLng? initialLocation;

  const LocationSelectionScreen({super.key, this.initialLocation});

  @override
  State<LocationSelectionScreen> createState() =>
      _LocationSelectionScreenState();
}

class _LocationSelectionScreenState extends State<LocationSelectionScreen> {
  late LatLng _selectedLocation;
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  // Search results
  List<dynamic> _searchResults = [];
  bool _isSearching = false;
  String _selectedName = '';

  @override
  void initState() {
    super.initState();
    // Default to Rome if no location provided
    _selectedLocation =
        widget.initialLocation ?? const LatLng(41.9028, 12.4964);
  }

  void _onTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      _selectedLocation = point;
      _selectedName = ''; // Reset name on manual tap as we don't know it yet
      // Optionally could reverse geocode here too
    });
  }

  Future<void> _searchLocations(String query) async {
    if (query.isEmpty) return;

    setState(() => _isSearching = true);
    try {
      final bounds = _mapController.camera.visibleBounds;
      final viewbox =
          '${bounds.west},${bounds.north},${bounds.east},${bounds.south}';

      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$query&format=json&addressdetails=1&limit=10&viewbox=$viewbox&bounded=0',
      );
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'FesterApp/1.0', // Important for OSM API usage policy
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        setState(() {
          _searchResults = data;
        });
      }
    } catch (e) {
      debugPrint('Error searching location: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error searching location: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _selectSearchResult(dynamic result) {
    final lat = double.parse(result['lat']);
    final lon = double.parse(result['lon']);
    final displayName = result['display_name'];

    final point = LatLng(lat, lon);

    setState(() {
      _selectedLocation = point;
      _selectedName = displayName.split(',').first; // Just take the main name
      _searchController.text = _selectedName;
      _searchResults = []; // Clear results and hide list
    });

    _mapController.move(point, 15.0);
    FocusManager.instance.primaryFocus?.unfocus(); // Hide keyboard
  }

  void _confirmSelection() {
    // Return a map or a custom object.
    // For now returning a map to be flexible or we can return the LocationHelper formatted string directly?
    // The plan said: "Return both LatLng and the Location Name to the previous screen."
    // Let's return a Map for flexibility: {'coords': LatLng, 'name': String}
    Navigator.pop(context, {
      'coords': _selectedLocation,
      'name': _selectedName.isNotEmpty ? _selectedName : 'Selected Location',
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('create_event.select_location'.tr())),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedLocation,
              initialZoom: 13.0,
              onTap: _onTap,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.fester',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _selectedLocation,
                    width: 80,
                    height: 80,
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Search Interface
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search location...',
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      suffixIcon: IconButton(
                        icon:
                            _isSearching
                                ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Icon(Icons.search),
                        onPressed:
                            () => _searchLocations(_searchController.text),
                      ),
                    ),
                    onSubmitted: _searchLocations,
                  ),
                ),

                // Quick Search Chips
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildQuickSearchChip(
                          'create_event.search_bar'.tr(),
                          'bar',
                          Icons.local_bar,
                        ),
                        _buildQuickSearchChip(
                          'create_event.search_club'.tr(),
                          'nightclub',
                          Icons.music_note,
                        ),
                        _buildQuickSearchChip(
                          'create_event.search_restaurant'.tr(),
                          'restaurant',
                          Icons.restaurant,
                        ),
                        _buildQuickSearchChip(
                          'create_event.search_pub'.tr(),
                          'pub',
                          Icons.sports_bar,
                        ),
                      ],
                    ),
                  ),
                ),

                // Search Results List
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    constraints: const BoxConstraints(maxHeight: 250),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final item = _searchResults[index];
                        final type = item['type'] ?? '';
                        // final category = item['class'] ?? '';

                        IconData icon;
                        if (type == 'bar' || type == 'pub') {
                          icon = Icons.local_bar;
                        } else if (type == 'restaurant') {
                          icon = Icons.restaurant;
                        } else if (type == 'nightclub') {
                          icon = Icons.music_note;
                        } else {
                          icon = Icons.location_on_outlined;
                        }

                        return ListTile(
                          title: Text(
                            item['name'] != null &&
                                    item['name'].toString().isNotEmpty
                                ? item['name']
                                : (item['display_name'] ?? '').split(',').first,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            item['display_name'] ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.6,
                              ),
                            ),
                          ),
                          leading: Icon(icon, color: theme.colorScheme.primary),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              type.toString().toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          onTap: () => _selectSearchResult(item),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // Confirm Button
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: ElevatedButton(
              onPressed: _confirmSelection,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
              child: Text(
                'create_event.confirm_location'.tr(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSearchChip(String label, String query, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ActionChip(
        avatar: Icon(icon, size: 16),
        label: Text(label),
        onPressed: () {
          _searchController.text = query;
          _searchLocations(query);
        },
      ),
    );
  }
}

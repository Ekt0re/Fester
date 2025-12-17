import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../../services/overpass_service.dart';

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
  bool _isLoadingLocation = true;
  final OverpassService _overpassService = OverpassService();

  // Overpass markers
  // using a map to track markers by ID might be better but list is fine for now
  List<Marker> _poiMarkers = [];
  String? _activeCategory; // To highlight the active chip

  @override
  void initState() {
    super.initState();
    // Default to Rome if no location provided, then try GPS
    _selectedLocation =
        widget.initialLocation ?? const LatLng(41.9028, 12.4964);
    _initCurrentLocation();
  }

  /// Gets current GPS location and centers the map on it
  Future<void> _initCurrentLocation() async {
    // If we already have an initial location, use that
    if (widget.initialLocation != null) {
      setState(() => _isLoadingLocation = false);
      return;
    }

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isLoadingLocation = false);
        return;
      }

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isLoadingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _isLoadingLocation = false);
        return;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      final currentLocation = LatLng(position.latitude, position.longitude);

      if (mounted) {
        setState(() {
          _selectedLocation = currentLocation;
          _isLoadingLocation = false;
        });

        // Move map to current location
        _mapController.move(currentLocation, 13.0);
      }
    } catch (e) {
      debugPrint('Error getting current location: $e');
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  /// Button to recenter on current GPS location
  Future<void> _goToCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('create_event.location_disabled'.tr())),
          );
        }
        setState(() => _isLoadingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('create_event.location_permission_denied'.tr()),
            ),
          );
        }
        setState(() => _isLoadingLocation = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final currentLocation = LatLng(position.latitude, position.longitude);

      if (mounted) {
        setState(() {
          _selectedLocation = currentLocation;
          _selectedName = '';
          _isLoadingLocation = false;
        });
        _mapController.move(currentLocation, 15.0);
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('create_event.location_error'.tr())),
        );
        setState(() => _isLoadingLocation = false);
      }
    }
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

  /// Searches for specific categories (amenities) using Overpass API
  Future<void> _searchNearbyCategory(String category) async {
    setState(() {
      _isLoadingLocation = true; // Show loading indicator
      _activeCategory = category;
      _searchResults = []; // Clear text results
      _poiMarkers = []; // Clear existing map markers
    });

    try {
      final bounds = _mapController.camera.visibleBounds;

      final results = await _overpassService.searchInBounds(
        south: bounds.south,
        west: bounds.west,
        north: bounds.north,
        east: bounds.east,
        category: category,
      );

      if (mounted) {
        setState(() {
          _poiMarkers =
              results.map((poi) {
                final poiLat = poi['lat'];
                final poiLon = poi['lon'];
                final poiName = poi['name'];

                return Marker(
                  point: LatLng(poiLat, poiLon),
                  width: 40,
                  height: 40,
                  child: GestureDetector(
                    onTap: () {
                      _selectSearchResult({
                        'lat': poiLat.toString(),
                        'lon': poiLon.toString(),
                        'display_name': poiName,
                        'name': poiName,
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black26, blurRadius: 4),
                        ],
                        border: Border.all(
                          color: _getCategoryColor(category),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        _getCategoryIcon(category),
                        color: _getCategoryColor(category),
                        size: 24,
                      ),
                    ),
                  ),
                );
              }).toList();
        });

        if (results.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('create_event.no_results_found'.tr())),
          );
        }
      }
    } catch (e) {
      debugPrint('Overpass Error: $e');
      if (mounted) {
        String errorMessage = 'Error searching area';
        if (e.toString().contains('Area too large')) {
          errorMessage = 'Area too large. Please zoom in to find places.';
        } else {
          errorMessage = 'Error: $e';
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage)));
      }
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'bar':
        return Colors.orange;
      case 'nightclub':
        return Colors.purple;
      case 'restaurant':
        return Colors.red;
      case 'pub':
        return Colors.amber.shade900;
      case 'parking':
        return Colors.blue;
      default:
        return Colors.teal;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'bar':
        return Icons.local_bar;
      case 'nightclub':
        return Icons.music_note;
      case 'restaurant':
        return Icons.restaurant;
      case 'pub':
        return Icons.sports_bar;
      case 'parking':
        return Icons.local_parking;
      default:
        return Icons.place;
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
                  // Selected location marker
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
                  // POI Markers
                  ..._poiMarkers,
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
                        _buildQuickSearchChip(
                          'Parcheggi',
                          'parking',
                          Icons.local_parking,
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

          // GPS Button
          Positioned(
            bottom: 90,
            right: 24,
            child: FloatingActionButton(
              mini: true,
              onPressed: _isLoadingLocation ? null : _goToCurrentLocation,
              backgroundColor: theme.cardColor,
              child:
                  _isLoadingLocation
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : Icon(
                        Icons.my_location,
                        color: theme.colorScheme.primary,
                      ),
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

  Widget _buildQuickSearchChip(String label, String category, IconData icon) {
    final isSelected = _activeCategory == category;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        avatar: isSelected ? null : Icon(icon, size: 16),
        label: Text(label),
        selected: isSelected,
        showCheckmark: false,
        selectedColor: theme.colorScheme.primaryContainer,
        checkmarkColor: theme.colorScheme.primary,
        onSelected: (bool selected) {
          if (selected) {
            FocusManager.instance.primaryFocus
                ?.unfocus(); // Close keyboard if open
            _searchNearbyCategory(category);
          } else {
            setState(() {
              _activeCategory = null;
              _poiMarkers = [];
            });
          }
        },
      ),
    );
  }
}

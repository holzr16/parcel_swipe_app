import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:logger/logger.dart';
import 'services/database_service.dart'; // Corrected import path

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Retrieve the access token from the environment
  String accessToken =
      "pk.eyJ1IjoicGFyY2VsLXN3aXBlIiwiYSI6ImNtMWkzNWxlcjBwMzkycXMybDZyOXRubjkifQ.wYCDUei4VOUyjMnzI5BASQ";

  // Set the access token for Mapbox
  MapboxOptions.setAccessToken(accessToken);

  runApp(const MyApp()); // Root widget
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parcel Swipe App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late MapboxMap _mapboxMap;
  List<Map<String, dynamic>> _features = []; // List of parcels fetched
  Map<String, dynamic>? _geoJsonData; // GeoJSON data
  List<Map<String, dynamic>> _filteredFeatures = []; // For filtered features
  int _currentIndex = 0; // Current polygon index
  double? _minAcres;
  double? _maxAcres;
  String? _selectedCounty;
  String? _selectedBuiltUpArea;
  String? _selectedRegion;
  String? _selectedLocalAuthorityDistrict;
  int _totalParcels = 0; // Total number of parcels based on filters
  int _pageNumber = 0;
  final int _pageSize = 100; // Number of parcels per page
  bool _isLoading = false;

  final DatabaseService _dbService = DatabaseService();
  final Logger _logger = Logger();
  final Map<int, List<Map<String, dynamic>>> _pageCache = {}; // Cache for fetched pages

  // Lists to hold filter options
  List<String> _countyOptions = [];
  List<String> _builtUpAreaOptions = [];
  List<String> _regionOptions = [];
  List<String> _localAuthorityDistrictOptions = [];

  @override
  void initState() {
    super.initState();
    _initializeDatabaseAndFilters();
  }

  /// Initializes the database connection and fetches filter options
  Future<void> _initializeDatabaseAndFilters() async {
    try {
      await _dbService.connect();
      await _fetchFilterOptions();
      setState(() {
        // Update UI to indicate filters are ready
      });
    } catch (e) {
      _logger.e('Error during initialization: $e');
    }
  }

  /// Fetch distinct filter options from the database
  Future<void> _fetchFilterOptions() async {
    try {
      _countyOptions = await _dbService.fetchDistinctCounties();
      _builtUpAreaOptions = await _dbService.fetchDistinctBuiltUpAreas();
      _regionOptions = await _dbService.fetchDistinctRegions();
      _localAuthorityDistrictOptions =
          await _dbService.fetchDistinctLocalAuthorityDistricts();

      setState(() {
        // Update the UI after fetching filter options
      });
    } catch (e) {
      _logger.e('Error fetching filter options: $e');
    }
  }

  /// Applies filters and refreshes data
  Future<void> _applyFiltersAndRefresh() async {
    setState(() {
      _isLoading = true;
      _pageNumber = 0;
      _features.clear();
      _filteredFeatures.clear();
      _pageCache.clear();
    });

    try {
      // Fetch parcels based on new filters
      await _fetchParcels();
    } catch (e) {
      _logger.e('Error applying filters and refreshing data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Fetches parcels based on current filters
  Future<void> _fetchParcels() async {
    try {
      // Fetch total parcels count based on filters
      int total = await _dbService.getTotalParcels(
        countyName: _selectedCounty,
        builtUpAreaName: _selectedBuiltUpArea,
        regionName: _selectedRegion,
        localAuthorityDistrictName: _selectedLocalAuthorityDistrict,
        minAcres: _minAcres,
        maxAcres: _maxAcres,
      );

      // Fetch first page of parcels based on filters
      List<Map<String, dynamic>> parcels = await _dbService.fetchParcels(
        pageNumber: _pageNumber,
        pageSize: _pageSize,
        countyName: _selectedCounty,
        builtUpAreaName: _selectedBuiltUpArea,
        regionName: _selectedRegion,
        localAuthorityDistrictName: _selectedLocalAuthorityDistrict,
        minAcres: _minAcres,
        maxAcres: _maxAcres,
      );

      _pageCache[_pageNumber] = parcels; // Cache the first page

      setState(() {
        _features = parcels;
        _filteredFeatures = List.from(_features);
        _totalParcels = total;
        _isLoading = false;
        _currentIndex = 0; // Reset to first polygon
      });

      // Load GeoJSON data from the new features
      await _loadGeoJsonData();

      if (_filteredFeatures.isNotEmpty) {
        // Add or update the GeoJSON layer
        await _addGeoJsonLayer();
      }
    } catch (e) {
      _logger.e('Error fetching parcels: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Loads GeoJSON data from the fetched features
  Future<void> _loadGeoJsonData() async {
    try {
      _geoJsonData = {
        "type": "FeatureCollection",
        "features": _filteredFeatures.map((feature) {
          return {
            "type": "Feature",
            "properties": {
              "inspireid": feature['inspireid'],
              "acres": feature['acres'],
              "gml_id": feature['gml_id'],
            },
            "geometry": jsonDecode(feature['geom']),
          };
        }).toList(),
      };
    } catch (e) {
      _logger.e('Error loading GeoJSON data: $e');
    }
  }

  /// Opens the filter dialog
  void _openFilterDialog() {
    double? minAcresInput = _minAcres;
    double? maxAcresInput = _maxAcres;
    String? selectedCountyInput = _selectedCounty;
    String? selectedBuiltUpAreaInput = _selectedBuiltUpArea;
    String? selectedRegionInput = _selectedRegion;
    String? selectedLocalAuthorityDistrictInput =
        _selectedLocalAuthorityDistrict;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Set Filters'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // County Filter
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'County'),
                  value: selectedCountyInput,
                  items: _countyOptions
                      .map((county) => DropdownMenuItem(
                            value: county,
                            child: Text(county),
                          ))
                      .toList(),
                  onChanged: (value) {
                    selectedCountyInput = value;
                  },
                  isExpanded: true,
                ),
                const SizedBox(height: 10),
                // Built-Up Area Filter
                DropdownButtonFormField<String>(
                  decoration:
                      const InputDecoration(labelText: 'Built-Up Area'),
                  value: selectedBuiltUpAreaInput,
                  items: _builtUpAreaOptions
                      .map((bua) => DropdownMenuItem(
                            value: bua,
                            child: Text(bua),
                          ))
                      .toList(),
                  onChanged: (value) {
                    selectedBuiltUpAreaInput = value;
                  },
                  isExpanded: true,
                ),
                const SizedBox(height: 10),
                // Region Filter
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Region'),
                  value: selectedRegionInput,
                  items: _regionOptions
                      .map((region) => DropdownMenuItem(
                            value: region,
                            child: Text(region),
                          ))
                      .toList(),
                  onChanged: (value) {
                    selectedRegionInput = value;
                  },
                  isExpanded: true,
                ),
                const SizedBox(height: 10),
                // Local Authority District Filter
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                      labelText: 'Local Authority District'),
                  value: selectedLocalAuthorityDistrictInput,
                  items: _localAuthorityDistrictOptions
                      .map((lad) => DropdownMenuItem(
                            value: lad,
                            child: Text(lad),
                          ))
                      .toList(),
                  onChanged: (value) {
                    selectedLocalAuthorityDistrictInput = value;
                  },
                  isExpanded: true,
                ),
                const SizedBox(height: 10),
                // Min Acres Filter
                TextField(
                  decoration: const InputDecoration(labelText: 'Min Acres'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  onChanged: (value) {
                    minAcresInput = double.tryParse(value);
                  },
                ),
                const SizedBox(height: 10),
                // Max Acres Filter
                TextField(
                  decoration: const InputDecoration(labelText: 'Max Acres'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  onChanged: (value) {
                    maxAcresInput = double.tryParse(value);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Apply filters
                setState(() {
                  _selectedCounty = selectedCountyInput;
                  _selectedBuiltUpArea = selectedBuiltUpAreaInput;
                  _selectedRegion = selectedRegionInput;
                  _selectedLocalAuthorityDistrict =
                      selectedLocalAuthorityDistrictInput;
                  _minAcres = minAcresInput;
                  _maxAcres = maxAcresInput;
                });
                _applyFiltersAndRefresh();
                Navigator.of(context).pop();
              },
              child: const Text('Set Filters'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context)
                    .pop(); // Close the dialog without applying
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  /// Dispose the database connection when the widget is disposed
  @override
  void dispose() {
    // Initiate the asynchronous close without awaiting
    _dbService.close().catchError((e) {
      _logger.e('Error closing database connection: $e');
    });

    super.dispose();
  }

  /// Map creation callback
  void _onMapCreated(MapboxMap map) async {
    _mapboxMap = map;

    try {
      await _mapboxMap.loadStyleURI(MapboxStyles.SATELLITE_STREETS);

      // The style loaded event will be handled by the onStyleLoadedListener
    } catch (e) {
      _logger.e('Error during map creation: $e');
    }
  }

  /// Style loaded event handler
  void _onStyleLoaded(StyleLoadedEventData eventData) async {
    _logger.d('Style has been loaded.');

    if (_geoJsonData != null && _filteredFeatures.isNotEmpty) {
      await _addGeoJsonLayer();
    }
  }

  /// Adds or updates the GeoJSON layer on the map
  Future<void> _addGeoJsonLayer() async {
    // Ensure that _geoJsonData and _filteredFeatures are not null or empty
    if (_geoJsonData == null || _filteredFeatures.isEmpty) {
      _logger.w(
          '_geoJsonData is null or _filteredFeatures is empty. Skipping layer addition.');
      return;
    }

    try {
      // Check if the GeoJSON source already exists
      bool sourceExists =
          await _mapboxMap.style.styleSourceExists('my-geojson-source');

      if (sourceExists) {
        _logger.d('GeoJSON source exists. Updating source data.');

        // Update the existing source with new data
        await _mapboxMap.style.setStyleSourceProperty(
          'my-geojson-source',
          'data',
          jsonEncode(_geoJsonData!), // Convert Map to JSON String
        );
      } else {
        _logger.d('GeoJSON source does not exist. Adding new source and layer.');

        // Add a new GeoJSON source
        await _mapboxMap.style.addSource(
          GeoJsonSource(
            id: 'my-geojson-source',
            data: jsonEncode(_geoJsonData!), // Convert Map to JSON String
          ),
        );

        // Layer Positioning: Add the layer above an existing layer (e.g., 'water')
        String existingLayerId = 'water'; // Example layer ID

        // Check if the existing layer exists
        bool layerExists =
            await _mapboxMap.style.styleLayerExists(existingLayerId);

        if (layerExists) {
          _logger.d(
              'Existing layer "$existingLayerId" found. Adding "my-fill-layer" above it.');

          // Add the fill layer above the existing layer using addLayerAt
          await _mapboxMap.style.addLayerAt(
            FillLayer(
              id: 'my-fill-layer',
              sourceId: 'my-geojson-source',
              fillColor: Colors.red.value, // Use Colors.red for clarity
              fillOpacity: 0.5,
            ),
            LayerPosition(above: existingLayerId),
          );
        } else {
          _logger.w(
              'Existing layer "$existingLayerId" not found. Adding "my-fill-layer" without specifying position.');

          // Add the fill layer without specifying position
          await _mapboxMap.style.addLayer(
            FillLayer(
              id: 'my-fill-layer',
              sourceId: 'my-geojson-source',
              fillColor: Colors.red.value, // Use Colors.red for clarity
              fillOpacity: 0.5,
            ),
          );
        }
      }

      // Update the current polygon after adding/updating the layer
      await _updatePolygon();
    } catch (e) {
      _logger.e('Error adding or updating GeoJSON layer: $e');
    }
  }

  /// Updates the currently displayed polygon on the map
  Future<void> _updatePolygon() async {
    if (_filteredFeatures.isEmpty) {
      _logger.w('No features available to display.');
      return;
    }

    var currentFeature = _filteredFeatures[_currentIndex];
    _logger.d('Current Feature: $currentFeature');

    // Access 'inspireid' directly from currentFeature
    var currentInspireId = currentFeature['inspireid'];

    // Validate 'inspireid'
    if (currentInspireId == null) {
      _logger.e('inspireid is null for currentFeature: $currentFeature');
      _nextPolygon(); // Skip to the next polygon
      return;
    }

    var geometry = _geoJsonData?['features'][_currentIndex]['geometry'];

    if (geometry == null || geometry['coordinates'] == null) {
      _logger.e(
          'Geometry is null or malformed for currentFeature: $currentFeature');
      _nextPolygon(); // Skip to the next polygon
      return;
    }

    try {
      var layer = await _mapboxMap.style.getLayer('my-fill-layer');

      if (layer != null && layer is FillLayer) {
        _logger.d(
            'Found "my-fill-layer". Applying filter for inspireid: $currentInspireId');

        // Apply filter to show only the current polygon
        layer.filter = [
          '==',
          ['get', 'inspireid'],
          currentInspireId,
        ];

        await _mapboxMap.style.updateLayer(layer);
      } else {
        _logger.e('FillLayer "my-fill-layer" not found.');
        return;
      }

      var coordinateBounds = _getFeatureBounds(geometry);

      var cameraOptions = await _mapboxMap.cameraForCoordinateBounds(
        coordinateBounds,
        MbxEdgeInsets(
          left: 20.0,
          top: 20.0,
          right: 20.0,
          bottom: 20.0,
        ),
        0.0,
        null,
        null,
        null,
      );

      await _mapboxMap.setCamera(cameraOptions);
      _logger.d('Camera updated to show the current polygon.');
    } catch (e) {
      _logger.e('Error updating polygon: $e');
    }
  }

  /// Helper function to get the coordinate bounds of a feature
  CoordinateBounds _getFeatureBounds(Map<String, dynamic> geometry) {
    if (geometry['coordinates'] == null) {
      return CoordinateBounds(
        southwest: Point(
          coordinates: Position(-180, -90),
        ),
        northeast: Point(
          coordinates: Position(180, 90),
        ),
        infiniteBounds: false,
      );
    }

    String type = geometry['type'];
    List<dynamic> coordinates;

    if (type == 'Polygon') {
      if (geometry['coordinates'].isEmpty) {
        return CoordinateBounds(
          southwest: Point(
            coordinates: Position(-180, -90),
          ),
          northeast: Point(
            coordinates: Position(180, 90),
          ),
          infiniteBounds: false,
        );
      }
      coordinates = geometry['coordinates'][0];
    } else if (type == 'MultiPolygon') {
      if (geometry['coordinates'].isEmpty ||
          geometry['coordinates'][0].isEmpty) {
        return CoordinateBounds(
          southwest: Point(
            coordinates: Position(-180, -90),
          ),
          northeast: Point(
            coordinates: Position(180, 90),
          ),
          infiniteBounds: false,
        );
      }
      coordinates = geometry['coordinates'][0][0];
    } else {
      return CoordinateBounds(
        southwest: Point(
          coordinates: Position(-180, -90),
        ),
        northeast: Point(
          coordinates: Position(180, 90),
        ),
        infiniteBounds: false,
      );
    }

    // Ensure coordinates are valid
    if (coordinates.isEmpty || coordinates.first.length < 2) {
      return CoordinateBounds(
        southwest: Point(
          coordinates: Position(-180, -90),
        ),
        northeast: Point(
          coordinates: Position(180, 90),
        ),
        infiniteBounds: false,
      );
    }

    double minLat = coordinates[0][1];
    double minLng = coordinates[0][0];
    double maxLat = coordinates[0][1];
    double maxLng = coordinates[0][0];

    for (var coord in coordinates) {
      if (coord.length < 2) continue; // Skip invalid coordinates
      double lng = coord[0];
      double lat = coord[1];
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }

    return CoordinateBounds(
      southwest: Point(
        coordinates: Position(minLng, minLat),
      ),
      northeast: Point(
        coordinates: Position(maxLng, maxLat),
      ),
      infiniteBounds: false,
    );
  }

  /// Navigates to the previous polygon
  void _previousPolygon() {
    if (_filteredFeatures.isEmpty) return;
    setState(() {
      _currentIndex =
          (_currentIndex - 1 + _filteredFeatures.length) % _filteredFeatures.length;
    });
    _updatePolygon();
  }

  /// Navigates to the next polygon
  void _nextPolygon() {
    if (_filteredFeatures.isEmpty) return;
    setState(() {
      _currentIndex = (_currentIndex + 1) % _filteredFeatures.length;
    });
    _updatePolygon();
  }

  @override
  Widget build(BuildContext context) {
    // Define initial camera options
    CameraOptions cameraOptions = CameraOptions(
      center: Point(
        coordinates: Position(-1.5, 53.1), // Center of England
      ),
      zoom: 5.0,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Parcel Swipe App')),
      body: Column(
        children: [
          // Display the total number of parcels
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Total Parcels: $_totalParcels',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: MapWidget(
              key: const ValueKey("mapWidget"),
              cameraOptions: cameraOptions,
              styleUri: MapboxStyles.SATELLITE_STREETS,
              onMapCreated:
                  _onMapCreated, // Hook to perform actions after map creation
              onStyleLoadedListener: _onStyleLoaded, // Updated listener
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _previousPolygon,
                  child: const Text('Back'),
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  onPressed: _nextPolygon,
                  child: const Text('Next'),
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  onPressed: _openFilterDialog,
                  child: const Text('Filter'),
                ),
              ],
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, FilteringTextInputFormatter;
import 'dart:convert'; // To handle GeoJSON data
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Retrieve the access token from the environment
  String accessToken = const String.fromEnvironment("ACCESS_TOKEN");

  // Set the access token for Mapbox
  MapboxOptions.setAccessToken(accessToken);

  runApp(const MyApp()); // Root widget
}

class MyApp extends StatelessWidget { // Changed to StatelessWidget
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const MyHomePage(), // Reference to the new stateful widget
    );
  }
}

class MyHomePage extends StatefulWidget { // New stateful widget
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late MapboxMap _mapboxMap;
  List<dynamic>? _features; // Changed to nullable to handle initialization
  List<dynamic>? _filteredFeatures; // For filtered features
  int _currentIndex = 0; // Current polygon index
  Map<String, dynamic>? _geoJsonData;
  double? _minAcres;
  double? _maxAcres;
  int _totalParcels = 0; // Total number of parcels

  @override
  void initState() {
    super.initState();
    _loadGeoJsonData();
  }

  // Load GeoJSON data
  Future<void> _loadGeoJsonData() async {
    try {
      // **Updated JSON file path**
      String data = await rootBundle.loadString('lib/geojson/api_test.json');
      _geoJsonData = jsonDecode(data);

      // Extract the list of features (polygons)
      List<dynamic> allFeatures = _geoJsonData!['features'];

      // Filter features to include only Polygon and MultiPolygon types
      _features = allFeatures.where((feature) {
        String type = feature['geometry']['type'];
        return type == 'Polygon' || type == 'MultiPolygon';
      }).toList();

      _totalParcels = _features!.length;
      _filteredFeatures = List.from(_features!); // Initialize filtered features

      if (_features == null || _features!.isEmpty) {
        print('No valid Polygon or MultiPolygon features found in GeoJSON data.');
      } else {
        print('Loaded ${_features!.length} Polygon/MultiPolygon features.');
      }
    } catch (e) {
      print('Error loading GeoJSON data: $e');
    }
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
      appBar: AppBar(title: const Text('Mapbox Map Test')),
      body: Column(
        children: [
          // Display the total number of parcels
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Total Parcels: ${_filteredFeatures?.length ?? 0}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: MapWidget(
              key: const ValueKey("mapWidget"),
              cameraOptions: cameraOptions,
              styleUri: MapboxStyles.SATELLITE_STREETS,
              onMapCreated: _onMapCreated, // Hook to perform actions after map creation
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
        ],
      ),
    );
  }

  void _previousPolygon() {
    if (_filteredFeatures == null || _filteredFeatures!.isEmpty) return;
    setState(() {
      _currentIndex = (_currentIndex - 1 + _filteredFeatures!.length) % _filteredFeatures!.length;
      _updatePolygon();
    });
  }

  void _nextPolygon() {
    if (_filteredFeatures == null || _filteredFeatures!.isEmpty) return;
    setState(() {
      _currentIndex = (_currentIndex + 1) % _filteredFeatures!.length;
      _updatePolygon();
    });
  }

  void _onMapCreated(MapboxMap map) async {
    _mapboxMap = map;

    try {
      // Wait for GeoJSON data to be loaded
      if (_geoJsonData == null || _features == null) {
        await _loadGeoJsonData();
      }

      await _mapboxMap.loadStyleURI(MapboxStyles.SATELLITE_STREETS);

      // Once style is loaded, add the GeoJSON layer
      await _addGeoJsonLayer();
    } catch (e) {
      print('Error in _onMapCreated: $e');
    }
  }

  Future<void> _addGeoJsonLayer() async {
    // Ensure that _geoJsonData and _features are not null
    if (_geoJsonData == null || _features == null) {
      print('GeoJSON data is not loaded.');
      return;
    }

    // Convert the GeoJSON data to a string
    String geoJsonString = jsonEncode(_geoJsonData);

    // Add a GeoJSON source
    await _mapboxMap.style.addSource(GeoJsonSource(
      id: 'my-geojson-source',
      data: geoJsonString, // Pass the GeoJSON string
    ));

    // Add a fill layer using the GeoJSON source
    await _mapboxMap.style.addLayer(FillLayer(
      id: 'my-fill-layer',
      sourceId: 'my-geojson-source',
      fillColor: Colors.red.value, // Use Colors.red for clarity
      fillOpacity: 0.5,
    ));

    // Display the current polygon
    await _updatePolygon();
  }

  Future<void> _updatePolygon() async {
    if (_filteredFeatures == null || _filteredFeatures!.isEmpty) {
      print('No features available to update.');
      return;
    }

    // Get the current feature's properties
    var currentFeature = _filteredFeatures![_currentIndex];
    var properties = currentFeature['properties'];

    // **Updated property name to match new JSON**
    var currentInspireId = properties['inspireid']; // Changed from 'INSPIREID' to 'inspireid'

    var geometry = currentFeature['geometry'];

    // Log the INSPIREID and geometry type
    print('Processing INSPIREID: $currentInspireId, Geometry Type: ${geometry['type']}');

    // Check if geometry and coordinates exist
    if (geometry == null || geometry['coordinates'] == null) {
      print('Invalid geometry for INSPIREID: $currentInspireId. Skipping.');
      _nextPolygon();
      return;
    }

    // **Extract coordinates based on geometry type**
    List<dynamic> coordinates;
    String type = geometry['type'];

    if (type == 'Polygon') {
      if (geometry['coordinates'].isEmpty) {
        print('Polygon coordinates are empty for INSPIREID: $currentInspireId. Skipping.');
        _nextPolygon();
        return;
      }
      coordinates = geometry['coordinates'][0];
    } else if (type == 'MultiPolygon') {
      if (geometry['coordinates'].isEmpty || geometry['coordinates'][0].isEmpty) {
        print('MultiPolygon coordinates are empty for INSPIREID: $currentInspireId. Skipping.');
        _nextPolygon();
        return;
      }
      coordinates = geometry['coordinates'][0][0];
    } else {
      print('Unsupported geometry type: $type for INSPIREID: $currentInspireId. Skipping.');
      _nextPolygon();
      return;
    }

    // Ensure coordinates are valid
    if (coordinates.isEmpty || coordinates.first.length < 2) {
      print('Invalid coordinates structure for INSPIREID: $currentInspireId. Skipping.');
      _nextPolygon();
      return;
    }

    // **Using 'inspireid' as Unique Identifier**
    var currentInspireIdValue = properties['inspireid']; // Changed from 'INSPIREID'

    // Access the layer using the layer ID
    var layer = await _mapboxMap.style.getLayer('my-fill-layer');

    if (layer != null && layer is FillLayer) {
      // Set a filter on the layer to display only the current polygon
      layer.filter = [
        '==',
        ['get', 'inspireid'], // Changed from 'INSPIREID'
        currentInspireIdValue,
      ];

      // Update the layer with the new filter
      await _mapboxMap.style.updateLayer(layer);
    }

    // Adjust the camera to fit the current polygon
    var coordinateBounds = _getFeatureBounds(geometry);

    // Compute camera options to fit the coordinate bounds
    var cameraOptions = await _mapboxMap.cameraForCoordinateBounds(
      coordinateBounds,
      MbxEdgeInsets(
        left: 20.0,   // Adjust these values as needed
        top: 20.0,
        right: 20.0,
        bottom: 20.0,
      ),
      0.0,      // bearing
      null,     // pitch
      null,     // maxZoom
      null,     // offset
    );

    // **Replace `easeTo` with `setCamera` for instant camera movement**
    await _mapboxMap.setCamera(
      cameraOptions,
    );
  }

  // Helper function to get the coordinate bounds of a feature
  CoordinateBounds _getFeatureBounds(Map<String, dynamic> geometry) {
    if (geometry == null || geometry['coordinates'] == null) {
      print('Geometry or coordinates are null.');
      // Return default bounds or handle as needed
      return CoordinateBounds(
        southwest: Point(coordinates: Position(-180, -90)),
        northeast: Point(coordinates: Position(180, 90)),
        infiniteBounds: false,
      );
    }

    String type = geometry['type'];
    List<dynamic> coordinates;

    if (type == 'Polygon') {
      if (geometry['coordinates'].isEmpty) {
        print('Polygon coordinates are empty.');
        return CoordinateBounds(
          southwest: Point(coordinates: Position(-180, -90)),
          northeast: Point(coordinates: Position(180, 90)),
          infiniteBounds: false,
        );
      }
      coordinates = geometry['coordinates'][0];
    } else if (type == 'MultiPolygon') {
      if (geometry['coordinates'].isEmpty || geometry['coordinates'][0].isEmpty) {
        print('MultiPolygon coordinates are empty.');
        return CoordinateBounds(
          southwest: Point(coordinates: Position(-180, -90)),
          northeast: Point(coordinates: Position(180, 90)),
          infiniteBounds: false,
        );
      }
      coordinates = geometry['coordinates'][0][0];
    } else {
      print('Unsupported geometry type: $type');
      return CoordinateBounds(
        southwest: Point(coordinates: Position(-180, -90)),
        northeast: Point(coordinates: Position(180, 90)),
        infiniteBounds: false,
      );
    }

    // Ensure coordinates are valid
    if (coordinates.isEmpty || coordinates.first.length < 2) {
      print('Invalid coordinates structure.');
      return CoordinateBounds(
        southwest: Point(coordinates: Position(-180, -90)),
        northeast: Point(coordinates: Position(180, 90)),
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
      southwest: Point(coordinates: Position(minLng, minLat)),
      northeast: Point(coordinates: Position(maxLng, maxLat)),
      infiniteBounds: false,
    );
  }

  void _openFilterDialog() {
    double? minAcresInput = _minAcres;
    double? maxAcresInput = _maxAcres;

    showDialog(
      context: context, // Correct context
      builder: (context) {
        return AlertDialog(
          title: const Text('Set Acre Filters'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'Min Acres'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                onChanged: (value) {
                  minAcresInput = double.tryParse(value);
                },
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'Max Acres'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                onChanged: (value) {
                  maxAcresInput = double.tryParse(value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Apply filters
                setState(() {
                  _minAcres = minAcresInput;
                  _maxAcres = maxAcresInput;
                  _applyFilters();
                  _currentIndex = 0; // Reset to first polygon
                  _updatePolygon();
                });
                Navigator.of(context).pop();
              },
              child: const Text('Set Filters'),
            ),
          ],
        );
      },
    );
  }

  void _applyFilters() {
    if (_features == null) return;

    _filteredFeatures = _features!.where((feature) {
      // **Updated property name to match new JSON**
      var acres = feature['properties']['acres']; // Changed from 'Acres'
      if (acres == null) return false;

      double acresValue;
      if (acres is String) {
        acresValue = double.tryParse(acres) ?? 0.0;
      } else if (acres is num) {
        acresValue = acres.toDouble();
      } else {
        return false;
      }

      bool passesMin = _minAcres == null || acresValue >= _minAcres!;
      bool passesMax = _maxAcres == null || acresValue <= _maxAcres!;
      return passesMin && passesMax;
    }).toList();

    // Update total parcels display
    setState(() {
      _totalParcels = _filteredFeatures!.length;
    });
  }
}

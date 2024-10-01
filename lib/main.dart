import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert'; // To handle GeoJSON data
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Retrieve the access token from the environment
  String accessToken = const String.fromEnvironment("ACCESS_TOKEN");

  // Set the access token for Mapbox
  MapboxOptions.setAccessToken(accessToken);

  runApp(const MyApp());
}

class MyApp extends StatefulWidget { // Changed to StatefulWidget to manage state
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late MapboxMap _mapboxMap;
  List<dynamic>? _features; // Changed to nullable to handle initialization
  int _currentIndex = 0; // Current polygon index
  Map<String, dynamic>? _geoJsonData;

  @override
  void initState() {
    super.initState();
    // Do not call _loadGeoJsonData here
  }

  // Load GeoJSON data
  Future<void> _loadGeoJsonData() async {
    try {
      String data = await rootBundle.loadString('lib/geojson/sample_geojson.json');
      _geoJsonData = jsonDecode(data);

      // Extract the list of features (polygons)
      _features = _geoJsonData!['features'];

      if (_features == null || _features!.isEmpty) {
        print('No features found in GeoJSON data.');
      } else {
        print('Loaded ${_features!.length} features.');
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

    // Define the AppCompat theme
    ThemeData appTheme = ThemeData(
      platform: TargetPlatform.android,
    );

    Theme appCompatTheme = Theme(
      data: appTheme.copyWith(
        // Define AppCompat theme properties if necessary
      ),
      child: MapWidget(
        key: const ValueKey("mapWidget"),
        cameraOptions: cameraOptions,
        styleUri: MapboxStyles.SATELLITE_STREETS,
        onMapCreated: _onMapCreated, // Hook to perform actions after map creation
      ),
    );

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Mapbox Map Test')),
        body: Column(
          children: [
            Expanded(
              child: appCompatTheme,
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _previousPolygon() {
    if (_features == null || _features!.isEmpty) return;
    setState(() {
      _currentIndex = (_currentIndex - 1 + _features!.length) % _features!.length;
      _updatePolygon();
    });
  }

  void _nextPolygon() {
    if (_features == null || _features!.isEmpty) return;
    setState(() {
      _currentIndex = (_currentIndex + 1) % _features!.length;
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
    if (_features == null || _features!.isEmpty) {
      print('No features available to update.');
      return;
    }

    // Get the current feature's entity
    int currentEntity = _features![_currentIndex]['properties']['entity'];

    // Access the layer using the layer ID
    var layer = await _mapboxMap.style.getLayer('my-fill-layer');

    if (layer != null && layer is FillLayer) {
      // Set a filter on the layer to display only the current polygon
      layer.filter = [
        '==',
        ['get', 'entity'],
        currentEntity,
      ];

      // Update the layer with the new filter
      await _mapboxMap.style.updateLayer(layer);
    }

    // Adjust the camera to fit the current polygon
    var geometry = _features![_currentIndex]['geometry'];

    // Calculate the coordinate bounds of the feature
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

    // Animate the camera to fit the bounding box
    await _mapboxMap.easeTo(
      cameraOptions,
      MapAnimationOptions(duration: 1000),
    );
  }

  // Helper function to get the coordinate bounds of a feature
  CoordinateBounds _getFeatureBounds(Map<String, dynamic> geometry) {
    List<dynamic> coordinates = geometry['coordinates'][0];
    double minLat = coordinates[0][1];
    double minLng = coordinates[0][0];
    double maxLat = coordinates[0][1];
    double maxLng = coordinates[0][0];

    for (var coord in coordinates) {
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
      infiniteBounds: false, // Required named parameter
    );
  }
}

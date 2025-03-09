// lib\widgets\map_mode_widget.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:logger/logger.dart';
import 'package:geolocator/geolocator.dart' as geo;
import '../services/database_service.dart';

class MapModeWidget extends StatefulWidget {
  final DatabaseService dbService;
  final Logger logger;
  final bool buaOnly;
  final String? selectedCounty;
  final String? selectedBuiltUpArea;
  final String? selectedRegion;
  final String? selectedLocalAuthorityDistrict;
  final String? selectedStatus;
  final double? minAcres;
  final double? maxAcres;
  final int totalParcels;

  const MapModeWidget({
    super.key,
    required this.dbService,
    required this.logger,
    required this.buaOnly,
    this.selectedCounty,
    this.selectedBuiltUpArea,
    this.selectedRegion,
    this.selectedLocalAuthorityDistrict,
    this.selectedStatus,
    this.minAcres,
    this.maxAcres,
    required this.totalParcels,
  });

  @override
  State<MapModeWidget> createState() => _MapModeWidgetState();
}

class _MapModeWidgetState extends State<MapModeWidget> {
  mapbox.MapboxMap? _mapboxMap;
  bool _isStyleLoaded = false;
  bool _isLocationEnabled = false;
  bool _isFollowingUser = false; // Track if camera is following user
  StreamSubscription<geo.Position>? _positionStreamSubscription;
  String? _selectedParcelId;
  Map<String, dynamic>? _selectedFeatureGeometry; // Store geometry when found
  
  // TRY CHANGING THIS TO TEST DIFFERENT SOURCE LAYER NAMES
  final String _sourceLayer = 'aug_parcels_output---combined_filtered';
  
  String get _tileSourceUrl {
    return 'http://100.90.129.100:3000/aug_parcels_output---combined_filtered/{z}/{x}/{y}';
  }

  @override
  void dispose() {
    // Remove the tap listener
    if (_mapboxMap != null) {
      _mapboxMap!.setOnMapTapListener(null);
    }
    
    // Make sure to cancel any active position streams when the widget is disposed
    _stopLocationUpdates();
    super.dispose();
  }

  void _stopLocationUpdates() {
    if (_positionStreamSubscription != null) {
      _positionStreamSubscription!.cancel();
      _positionStreamSubscription = null;
      widget.logger.d('Position stream subscription cancelled');
    }
  }

  @override
Widget build(BuildContext context) {
  return Column(
    children: [
      Expanded(
        child: Stack(
          children: [
            mapbox.MapWidget(
              styleUri: mapbox.MapboxStyles.SATELLITE_STREETS,
              cameraOptions: mapbox.CameraOptions(
                center: mapbox.Point(coordinates: mapbox.Position(-1.5, 53.1)),
                zoom: 15.0, // Start at the minimum zoom level for vector tiles
              ),
              onMapCreated: _onMapCreated,
              onStyleLoadedListener: _onStyleLoaded,
            ),
            // Add a zoom info overlay to help users understand the zoom requirement
            Positioned(
              top: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(204),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  "Zoom in to level 15+ to see parcel boundaries",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            // Add location button
            Positioned(
              bottom: 100,
              right: 20,
              child: FloatingActionButton(
                backgroundColor: _isLocationEnabled ? Colors.blue : Colors.grey,
                mini: true,
                onPressed: _toggleUserLocation,
                child: Icon(_isFollowingUser ? Icons.gps_fixed : Icons.my_location),
              ),
            ),
            // Display parcel info modal when a parcel is selected
            if (_selectedParcelId != null)
              _buildParcelInfoModal(context),
          ],
        ),
      ),
    ],
  );
}

  // Method to build the parcel info modal sheet
Widget _buildParcelInfoModal(BuildContext context) {
  return Positioned(
    bottom: 0,
    left: 0,
    right: 0,
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16.0),
          topRight: Radius.circular(16.0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Parcel title
                Text(
                  'Parcel ID: $_selectedParcelId',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Parcel info (placeholder)
                const Text(
                  'Parcel Information',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text('Status: Placeholder status'),
                const Text('Area: Placeholder area'),
                const Text('County: Placeholder county'),
                const Text('Region: Placeholder region'),
                
                const SizedBox(height: 16),
                
                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      // No action needed for now
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Save functionality will be implemented soon'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Save Parcel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Close button
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      // Clear selection when closed
                      setState(() {
                        _selectedParcelId = null;
                        _selectedFeatureGeometry = null;
                      });
                      _removeExistingHighlights();
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

// Update your _queryParcelAtLocation method to fetch more parcel info when available
// This is a placeholder for when you want to show real data in the modal
Future<void> _fetchParcelInfo(String parcelId) async {
  // For future implementation - fetch parcel data from your database
  // You would update your state with real data here
}

  void _onMapCreated(mapbox.MapboxMap mapboxMap) async {
    widget.logger.d('Map created in Map Mode');
    _mapboxMap = mapboxMap;

    try {
      await _mapboxMap!.loadStyleURI(mapbox.MapboxStyles.SATELLITE_STREETS);
      widget.logger.d('Loaded style: ${mapbox.MapboxStyles.SATELLITE_STREETS}');
      
      // Set camera to display UK centered at zoom 15
      await _mapboxMap!.setCamera(
        mapbox.CameraOptions(
          center: mapbox.Point(coordinates: mapbox.Position(-1.5, 53.1)),
          zoom: 15.0, // Set to minimum zoom level for seeing vector tiles
        ),
      );
      widget.logger.d('Set initial camera position: center=[-1.5, 53.1], zoom=15.0');
      
      // Set tap gesture listener
      _mapboxMap!.setOnMapTapListener(_onMapTap);
      widget.logger.d('Registered tap gesture listener');
      
    } catch (e) {
      widget.logger.e('Error during map creation in Map Mode: $e');
    }
  }

  void _onStyleLoaded(mapbox.StyleLoadedEventData eventData) async {
    widget.logger.d('Style loaded in Map Mode');
    setState(() {
      _isStyleLoaded = true;
    });

    // Add the vector source when the style is loaded
    await _addVectorSource();
  }
  
  // Method to handle tap gesture and select parcels
  void _onMapTap(mapbox.MapContentGestureContext context) async {
    widget.logger.d('Map tap detected at: ${context.touchPosition.x}, ${context.touchPosition.y}');
    
    if (_mapboxMap == null) {
      widget.logger.e('Map is null');
      return;
    }
    
    if (!_isStyleLoaded) {
      widget.logger.e('Style not loaded yet');
      return;
    }

    try {
      // Query for parcels at the tap location
      await _queryParcelAtLocation(context.touchPosition);
    } catch (e) {
      widget.logger.e('Error in map tap handler: $e');
    }
  }

  Future<void> _debugVectorTileSource() async {
    if (_mapboxMap == null || !_isStyleLoaded) return;
    
    try {
      // Check if source exists and get its properties
      bool sourceExists = await _mapboxMap!.style.styleSourceExists('parcels-vector-source');
      if (sourceExists) {
        final sourceProps = await _mapboxMap!.style.getStyleSourceProperties('parcels-vector-source');
        widget.logger.d('Source properties: $sourceProps');
        
        // Check if layer exists and get its properties
        bool layerExists = await _mapboxMap!.style.styleLayerExists('parcels-line-layer');
        if (layerExists) {
          final layerProps = await _mapboxMap!.style.getStyleLayerProperties('parcels-line-layer');
          widget.logger.d('Layer properties: $layerProps');
          
          // Check the current zoom level
          final cameraState = await _mapboxMap!.getCameraState();
          widget.logger.d('Current zoom level: ${cameraState.zoom}');
          
          // If zoom is less than 15, inform user
          if (cameraState.zoom < 15.0) {
            widget.logger.d('WARNING: Zoom level is below 15, vector tiles may not be loaded');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please zoom in to see and select parcels (zoom > 15)'),
                  duration: Duration(seconds: 3),
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      widget.logger.e('Error debugging vector source: $e');
    }
  }

Map<String, dynamic> _convertToGeoJsonGeometry(dynamic rawGeometry) {
  try {
    // Create a new Map instead of casting
    Map<String, dynamic> geoJsonGeometry = {};
    
    // Extract the type first
    if (rawGeometry is Map) {
      // Add the type
      if (rawGeometry.containsKey('type')) {
        geoJsonGeometry['type'] = rawGeometry['type'];
      } else {
        widget.logger.e('Geometry missing type property');
        return {'type': 'Point', 'coordinates': [-1.5, 53.1]}; // Fallback
      }
      
      // Add the coordinates - need to handle nested structure carefully
      if (rawGeometry.containsKey('coordinates')) {
        // For coordinates, we need to deep copy the structure
        dynamic rawCoords = rawGeometry['coordinates'];
        
        if (geoJsonGeometry['type'] == 'Point') {
          // Point coordinates are simple [lng, lat]
          if (rawCoords is List) {
            geoJsonGeometry['coordinates'] = List.from(rawCoords);
          }
        } else if (geoJsonGeometry['type'] == 'LineString') {
          // LineString coordinates are [[lng, lat], [lng, lat], ...]
          if (rawCoords is List) {
            geoJsonGeometry['coordinates'] = rawCoords.map((coord) => 
                coord is List ? List.from(coord) : coord).toList();
          }
        } else if (geoJsonGeometry['type'] == 'Polygon') {
          // Polygon coordinates are [[[lng, lat], [lng, lat], ...], ...]
          if (rawCoords is List) {
            geoJsonGeometry['coordinates'] = rawCoords.map((ring) {
              if (ring is List) {
                return ring.map((coord) => 
                    coord is List ? List.from(coord) : coord).toList();
              }
              return ring;
            }).toList();
          }
        } else if (geoJsonGeometry['type'] == 'MultiPolygon') {
          // Handle MultiPolygon with another nesting level
          if (rawCoords is List) {
            geoJsonGeometry['coordinates'] = rawCoords.map((polygon) {
              if (polygon is List) {
                return polygon.map((ring) {
                  if (ring is List) {
                    return ring.map((coord) => 
                        coord is List ? List.from(coord) : coord).toList();
                  }
                  return ring;
                }).toList();
              }
              return polygon;
            }).toList();
          }
        }
      } else {
        widget.logger.e('Geometry missing coordinates property');
        return {'type': 'Point', 'coordinates': [-1.5, 53.1]}; // Fallback
      }
      
      widget.logger.d('Successfully converted geometry object to Map');
      return geoJsonGeometry;
    } else {
      widget.logger.e('Geometry is not a Map object: ${rawGeometry.runtimeType}');
      return {'type': 'Point', 'coordinates': [-1.5, 53.1]}; // Fallback
    }
  } catch (e) {
    widget.logger.e('Error converting geometry: $e');
    return {'type': 'Point', 'coordinates': [-1.5, 53.1]}; // Fallback on any error
  }
}


// Update the query function to also check the fill layer
Future<void> _queryParcelAtLocation(mapbox.ScreenCoordinate point) async {
  if (_mapboxMap == null || !_isStyleLoaded) return;

  try {
    widget.logger.d('Querying features at tap location: ${point.x}, ${point.y}');
    
    // First, create a tap query with a small box
    final double boxSize = 5.0; // Small size for precise tapping
    
    final mapbox.RenderedQueryGeometry queryGeometry = mapbox.RenderedQueryGeometry.fromScreenBox(
      mapbox.ScreenBox(
        min: mapbox.ScreenCoordinate(x: point.x - boxSize, y: point.y - boxSize),
        max: mapbox.ScreenCoordinate(x: point.x + boxSize, y: point.y + boxSize),
      ),
    );
    
    // Debug the vector tiles and layers
    await _debugVectorTileSource();
    
    // Try querying without layer filtering first
    final allFeatures = await _mapboxMap!.queryRenderedFeatures(
      queryGeometry,
      mapbox.RenderedQueryOptions()
    );
    widget.logger.d('All features found at location: ${allFeatures.length}');
    
    if (allFeatures.isNotEmpty) {
      // Log the first feature to see its structure
      widget.logger.d('Sample feature: ${allFeatures.first?.queriedFeature.toString()}');
    }
    
    // First try the fill layer which should detect taps inside parcels
    final fillFeatures = await _mapboxMap!.queryRenderedFeatures(
      queryGeometry,
      mapbox.RenderedQueryOptions(
        layerIds: ['parcels-fill-layer'],
      ),
    );
    widget.logger.d('Fill layer features found: ${fillFeatures.length}');
    
    // Then try the line layer as fallback
    final lineFeatures = await _mapboxMap!.queryRenderedFeatures(
      queryGeometry,
      mapbox.RenderedQueryOptions(
        layerIds: ['parcels-line-layer'],
      ),
    );
    widget.logger.d('Line layer features found: ${lineFeatures.length}');
    
    // Process features from either layer
    final features = fillFeatures.isNotEmpty ? fillFeatures : lineFeatures;
    
    if (features.isNotEmpty && features.first != null) {
      final feature = features.first!;
      
      try {
        // Log the raw feature for debugging
        widget.logger.d('Feature data: ${feature.queriedFeature.feature.toString()}');
        widget.logger.d('Feature source: ${feature.queriedFeature.source}');
        widget.logger.d('Feature sourceLayer: ${feature.queriedFeature.sourceLayer}');
        
        // The feature.queriedFeature.feature is already a Map, so no need for type check
        final rawMap = feature.queriedFeature.feature;
        widget.logger.d('Raw map keys: ${rawMap.keys.toList()}');

        // Try to find the parcel ID
        dynamic parcelId;
        if (rawMap.containsKey('inspireid')) {
          parcelId = rawMap['inspireid'];
        } else if (rawMap.containsKey('properties') && rawMap['properties'] is Map) {
          final propertiesMap = rawMap['properties'] as Map;
          if (propertiesMap.containsKey('inspireid')) {
            parcelId = propertiesMap['inspireid'];
          }
        }

        if (parcelId != null) {
          widget.logger.d('Found parcel ID: $parcelId');
          
          // Using the helper method to properly convert geometry
          if (rawMap.containsKey('geometry')) {
            _selectedFeatureGeometry = _convertToGeoJsonGeometry(rawMap['geometry']);
          } else {
            widget.logger.e('No geometry found in feature');
          }
          
          // Set the selected parcel ID
          setState(() {
            _selectedParcelId = parcelId.toString();
          });
          
          // Highlight the selected parcel
          await _highlightSelectedParcel();
          return;
        }
      } catch (e) {
        widget.logger.e('Error accessing feature properties: $e');
      }
    }
    
    // If we get here, no features were found or property extraction failed
    await _tryFallbackHighlighting(point);
  } catch (e) {
    widget.logger.e('Error querying features: $e');
    // Use the fallback highlighting method as a backup in case of query errors
    await _tryFallbackHighlighting(point);
  }
}

  Future<void> _tryFallbackHighlighting(mapbox.ScreenCoordinate point) async {
    widget.logger.d('No features found, trying fallback highlighting');
    
    // Get the geographic coordinate from the screen point
    final geoPoint = await _mapboxMap!.coordinateForPixel(point);
    final longitude = geoPoint.coordinates.lng;
    final latitude = geoPoint.coordinates.lat;
    
    // Use the simpler highlight method with a circle
    await _highlightLocationWithCircle(longitude.toDouble(), latitude.toDouble());
    
    // Clear any previous selection
    setState(() {
      _selectedParcelId = null;
      _selectedFeatureGeometry = null;
    });
  }

  Future<void> _highlightLocationWithCircle(double longitude, double latitude) async {
    if (_mapboxMap == null || !_isStyleLoaded) return;

    try {
      // Remove existing highlight layer if it exists
      if (await _mapboxMap!.style.styleLayerExists('selected-parcel-layer')) {
        await _mapboxMap!.style.removeStyleLayer('selected-parcel-layer');
        widget.logger.d('Removed existing selection layer');
      }
      
      // Wait a small amount of time to ensure resources are properly released
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Remove existing highlight source if it exists
      if (await _mapboxMap!.style.styleSourceExists('highlight-source')) {
        await _mapboxMap!.style.removeStyleSource('highlight-source');
        widget.logger.d('Removed existing highlight source');
      }
      
      // Wait again to ensure resources are released
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Create a GeoJson source with a single point
      final pointGeoJson = {
        "type": "FeatureCollection",
        "features": [
          {
            "type": "Feature",
            "properties": {},
            "geometry": {
              "type": "Point",
              "coordinates": [longitude, latitude]
            }
          }
        ]
      };
      
      // Add the source
      await _mapboxMap!.style.addSource(
        mapbox.GeoJsonSource(
          id: 'highlight-source',
          data: jsonEncode(pointGeoJson),
        ),
      );
      widget.logger.d('Added point source at tap location');
      
      // Add a circle layer
      await _mapboxMap!.style.addLayer(
        mapbox.CircleLayer(
          id: 'selected-parcel-layer',
          sourceId: 'highlight-source',
          circleRadius: 10.0,  // Smaller radius for better precision
          circleColor: 0xFFFFFF00,  // Yellow color
          circleStrokeWidth: 2.0,
          circleStrokeColor: 0xFF000000,  // Black outline
          circleOpacity: 0.7,
        ),
      );
      widget.logger.d('Added circle selection layer');
    } catch (e) {
      widget.logger.e('Error in highlight with circle: $e');
    }
  }

Future<void> _highlightSelectedParcel() async {
  if (_mapboxMap == null || !_isStyleLoaded || _selectedParcelId == null || _selectedFeatureGeometry == null) return;

  try {
    widget.logger.d('Highlighting selected parcel: $_selectedParcelId');
    
    // First check if there are any existing highlight layers or sources
    await _removeExistingHighlights();
    
    // Wait a small amount of time to ensure resources are properly released
    await Future.delayed(const Duration(milliseconds: 200));
    
    // Create a feature with the stored geometry
    final feature = {
      "type": "Feature",
      "properties": {
        "highlight": true
      },
      "geometry": _selectedFeatureGeometry
    };
    
    // Create a GeoJSON source with just this feature
    final featureJson = {
      "type": "FeatureCollection",
      "features": [feature]
    };
    
    // Add the GeoJSON source
    await _mapboxMap!.style.addSource(
      mapbox.GeoJsonSource(
        id: 'highlight-geojson-source',
        data: jsonEncode(featureJson),
      ),
    );
    widget.logger.d('Added GeoJSON source for highlight');
    
    // Add a fill layer for the highlight with extreme colors for visibility
    await _mapboxMap!.style.addLayer(
      mapbox.FillLayer(
        id: 'selected-parcel-fill-layer',
        sourceId: 'highlight-geojson-source',
        fillColor: 0xFFFF00FF,  // Bright magenta (fully opaque)
        fillOpacity: 0.7,       // More transparent to see base map
      ),
    );
    widget.logger.d('Added fill highlight layer from GeoJSON');
    
    // Add a line layer for the boundary
    await _mapboxMap!.style.addLayer(
      mapbox.LineLayer(
        id: 'selected-parcel-line-layer',
        sourceId: 'highlight-geojson-source',
        lineColor: 0xFF00FFFF,  // Bright cyan
        lineWidth: 8.0,         // Very thick for visibility
        lineCap: mapbox.LineCap.ROUND,
        lineJoin: mapbox.LineJoin.ROUND,
      ),
    );
    widget.logger.d('Added line highlight layer from GeoJSON');
    
    // Move layers to the top of the stack to ensure visibility
    await _mapboxMap!.style.moveStyleLayer('selected-parcel-fill-layer', mapbox.LayerPosition());
    await _mapboxMap!.style.moveStyleLayer('selected-parcel-line-layer', mapbox.LayerPosition());
    widget.logger.d('Moved highlight layers to top of layer stack');
    
    // Explicitly set visibility
    await _mapboxMap!.style.setStyleLayerProperty(
      'selected-parcel-fill-layer', 'visibility', 'visible'
    );
    await _mapboxMap!.style.setStyleLayerProperty(
      'selected-parcel-line-layer', 'visibility', 'visible'
    );
    widget.logger.d('Set highlight layers to visible');
  } catch (e) {
    widget.logger.e('Error highlighting parcel with GeoJSON: $e');
    await _tryFallbackHighlighting(await _getScreenCenterCoordinate());
  }
}

Future<void> _removeExistingHighlights() async {
  try {
    // Check if the highlight layers exist and remove them
    if (await _mapboxMap!.style.styleLayerExists('selected-parcel-line-layer')) {
      await _mapboxMap!.style.removeStyleLayer('selected-parcel-line-layer');
      widget.logger.d('Removed existing line highlight layer');
    }
    
    if (await _mapboxMap!.style.styleLayerExists('selected-parcel-fill-layer')) {
      await _mapboxMap!.style.removeStyleLayer('selected-parcel-fill-layer');
      widget.logger.d('Removed existing fill highlight layer');
    }
    
    // Check if the circle highlight layer exists and remove it
    if (await _mapboxMap!.style.styleLayerExists('selected-parcel-layer')) {
      await _mapboxMap!.style.removeStyleLayer('selected-parcel-layer');
      widget.logger.d('Removed existing selection layer');
    }
    
    // Wait to ensure resources are properly released
    await Future.delayed(const Duration(milliseconds: 100));
    
    // Check if the GeoJSON highlight source exists and remove it
    if (await _mapboxMap!.style.styleSourceExists('highlight-geojson-source')) {
      await _mapboxMap!.style.removeStyleSource('highlight-geojson-source');
      widget.logger.d('Removed existing GeoJSON highlight source');
    }
    
    // Check if the circle highlight source exists and remove it
    if (await _mapboxMap!.style.styleSourceExists('highlight-source')) {
      await _mapboxMap!.style.removeStyleSource('highlight-source');
      widget.logger.d('Removed existing highlight source');
    }
  } catch (e) {
    widget.logger.e('Error removing existing highlights: $e');
  }
}

// Helper method to get screen center coordinate for fallback
Future<mapbox.ScreenCoordinate> _getScreenCenterCoordinate() async {
  final cameraState = await _mapboxMap!.getCameraState();
  // Use the center point directly without wrapping it in another Point
  final screenCoordinate = await _mapboxMap!.pixelForCoordinate(cameraState.center);
  return screenCoordinate;
}

  // Mock method to get a parcel centroid - in a real app, you would fetch this from your database
  Future<mapbox.Position?> _getParcelCentroid(String parcelId) async {
    // This would normally query your database or an API to get the centroid
    // For now, we'll return null and let the caller handle it
    return null;
  }

  Future<void> _toggleUserLocation() async {
    if (_mapboxMap == null || !_isStyleLoaded) {
      widget.logger.e('Map not ready for location tracking');
      return;
    }

    try {
      // If location is already enabled, disable it
      if (_isLocationEnabled) {
        await _disableUserLocation();
      } else {
        // Otherwise, enable location
        await _enableUserLocation();
      }
    } catch (e) {
      widget.logger.e('Error toggling user location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error toggling location: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Disable location tracking and resets the map view
  Future<void> _disableUserLocation() async {
    // Cancel any active location updates
    _stopLocationUpdates();
    
    // Disable location component
    await _mapboxMap!.location.updateSettings(
      mapbox.LocationComponentSettings(
        enabled: false,
      ),
    );
    
    // Reset camera to default view
    await _mapboxMap!.setCamera(
      mapbox.CameraOptions(
        center: mapbox.Point(coordinates: mapbox.Position(-1.5, 53.1)),
        zoom: 15.0,
      ),
    );
    
    setState(() {
      _isLocationEnabled = false;
      _isFollowingUser = false;
    });
    
    widget.logger.d('Location component disabled');
  }

  /// Enable location tracking and move camera to user's location
  Future<void> _enableUserLocation() async {
    // First check if location service is enabled
    bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      widget.logger.e('Location services are disabled');
      
      // Show message asking user to enable location services
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location services are disabled. Please enable location in your device settings.'),
            duration: Duration(seconds: 3),
          ),
        );
        
        // Try to open location settings
        bool settingsOpened = await geo.Geolocator.openLocationSettings();
        if (!settingsOpened) {
          widget.logger.e('Could not open location settings');
          return;
        }
        
        // Wait for the user to return from settings
        // Check again if location services are enabled
        serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          widget.logger.e('Location services are still disabled after settings opened');
          return;
        }
      } else {
        return;
      }
    }

    // Request location permissions
    geo.LocationPermission permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
      if (permission == geo.LocationPermission.denied) {
        widget.logger.e('Location permission denied');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission is required to show your location on the map'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }
    }
    
    if (permission == geo.LocationPermission.deniedForever) {
      widget.logger.e('Location permission permanently denied');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission is permanently denied. Please enable it in app settings.'),
            duration: Duration(seconds: 3),
          ),
        );
        
        // Try to open app settings
        bool settingsOpened = await geo.Geolocator.openAppSettings();
        if (!settingsOpened) {
          widget.logger.e('Could not open app settings');
        }
      }
      return;
    }
    
    // Permission is granted, proceed with location component
    setState(() {
      _isLocationEnabled = true;
    });
    
    // Show loading indicator
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Finding your location...'),
          duration: Duration(seconds: 2),
        ),
      );
    }
    
    // Get current position
    try {
      // Get the user's current position - pass in LocationSettings
      geo.Position position = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
        ),
      );
      
      widget.logger.d('Current position: ${position.latitude}, ${position.longitude}');
      
      // Enable the location component
      await _mapboxMap!.location.updateSettings(
        mapbox.LocationComponentSettings(
          enabled: true,
          pulsingEnabled: true,
          pulsingColor: 0xFF2196F3, // Blue color as integer
          pulsingMaxRadius: 50,
          showAccuracyRing: true,
          accuracyRingColor: 0x1A2196F3, // Blue with 10% opacity
          accuracyRingBorderColor: 0x4D2196F3, // Blue with 30% opacity
          puckBearingEnabled: true,
          puckBearing: mapbox.PuckBearing.HEADING,
          // Use the default location puck
          locationPuck: mapbox.LocationPuck(
            locationPuck2D: mapbox.DefaultLocationPuck2D(),
          ),
        ),
      );
      
      // Move camera to the user's actual location
      await _mapboxMap!.flyTo(
        mapbox.CameraOptions(
          center: mapbox.Point(coordinates: mapbox.Position(position.longitude, position.latitude)),
          zoom: 16.0,
          pitch: 45.0,
        ),
        mapbox.MapAnimationOptions(
          duration: 1500,
          startDelay: 0,
        ),
      );
      
      // Set following state to true
      setState(() {
        _isFollowingUser = true;
      });
      
      // Start listening to location updates to keep following the user
      _startLocationUpdates();
      
      widget.logger.d('Location component enabled and camera following user location');
    } catch (e) {
      widget.logger.e('Error getting current position: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error determining your location: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      
      // Disable location if there was an error
      setState(() {
        _isLocationEnabled = false;
        _isFollowingUser = false;
      });
    }
  }
  
  /// Start receiving location updates to follow the user's position
  void _startLocationUpdates() {
    // Cancel any existing subscription first
    _stopLocationUpdates();
    
    // Set up location settings for continuous updates
    final geo.LocationSettings locationSettings = geo.LocationSettings(
      accuracy: geo.LocationAccuracy.high,
      distanceFilter: 5, // Update when user moves more than 5 meters
    );
    
    // Start listening to position updates
    _positionStreamSubscription = geo.Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (geo.Position? position) {
        if (position != null && _isFollowingUser && _mapboxMap != null) {
          // Update camera to follow user
          _mapboxMap!.flyTo(
            mapbox.CameraOptions(
              center: mapbox.Point(coordinates: mapbox.Position(position.longitude, position.latitude)),
            ),
            mapbox.MapAnimationOptions(
              duration: 300, // Short duration for smooth tracking
            ),
          );
          
          widget.logger.d('Updated camera position to: ${position.latitude}, ${position.longitude}');
        }
      },
      onError: (Object error) {
        widget.logger.e('Error in position stream: $error');
        // Don't disable location on stream errors, just log them
      },
    );
    
    widget.logger.d('Started position updates stream');
  }

// Update the _addVectorSource method to add both line and fill layers
Future<void> _addVectorSource() async {
  if (_mapboxMap == null || !_isStyleLoaded) return;

  try {
    // Check if source exists
    bool sourceExists = await _mapboxMap!.style.styleSourceExists('parcels-vector-source');

    if (!sourceExists) {
      // Add vector source
      widget.logger.d('Adding vector source with URL: $_tileSourceUrl');
      
      await _mapboxMap!.style.addSource(
        mapbox.VectorSource(
          id: 'parcels-vector-source',
          tiles: [_tileSourceUrl],
          maxzoom: 22.0,
          minzoom: 15.0, // Match Martin server config minzoom
        ),
      );
      widget.logger.d('Added vector source for parcels');
      
      // Wait a small amount of time to ensure resource is properly added
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Add fill layer first for better tap detection
      widget.logger.d('Adding fill layer with source layer: "$_sourceLayer"');
      
      await _mapboxMap!.style.addLayer(
        mapbox.FillLayer(
          id: 'parcels-fill-layer',
          sourceId: 'parcels-vector-source',
          sourceLayer: _sourceLayer,
          fillColor: 0x00FFFFFF, // Transparent fill
          fillOpacity: 0.01, // Nearly invisible but detectable for taps
          minZoom: 15.0,
          maxZoom: 22.0,
        ),
      );
      widget.logger.d('Added fill layer for parcel areas');
      
      // Add line layer on top
      widget.logger.d('Adding line layer with source layer: "$_sourceLayer"');
      
      await _mapboxMap!.style.addLayer(
        mapbox.LineLayer(
          id: 'parcels-line-layer',
          sourceId: 'parcels-vector-source',
          sourceLayer: _sourceLayer,
          lineColor: 0xFFFF0000, // Red color for boundaries
          lineWidth: 2.0,
          lineCap: mapbox.LineCap.ROUND,
          lineJoin: mapbox.LineJoin.ROUND,
          minZoom: 15.0,
          maxZoom: 22.0,
        ),
      );
      widget.logger.d('Added line layer for parcel boundaries');
      
      // Try to get all layers to confirm source visibility
      try {
        final layers = await _mapboxMap!.style.getStyleLayers();
        widget.logger.d('All style layers: ${layers.map((layer) => layer?.id).toList()}');
      } catch (e) {
        widget.logger.e('Error getting style layers: $e');
      }
      
      // Apply filters
      await _applyFilters();
    } else {
      widget.logger.d('Vector source already exists, applying filters');
      await _applyFilters();
    }
  } catch (e) {
    widget.logger.e('Error adding vector source or layer: $e');
  }
}

  // Update the apply filters method to apply to both layers
Future<void> _applyFilters() async {
  if (_mapboxMap == null || !_isStyleLoaded) return;
  
  try {
    // Convert filter parameters into a Mapbox filter expression
    List<Object> filterExpression = ['all'] as List<Object>;
    
    if (widget.buaOnly) {
      filterExpression.add(['has', 'bua_name'] as Object);
    }
    
    if (widget.selectedCounty != null && widget.selectedCounty!.isNotEmpty) {
      filterExpression.add(['==', ['get', 'county_name'], widget.selectedCounty] as Object);
    }
    
    if (widget.selectedBuiltUpArea != null && widget.selectedBuiltUpArea!.isNotEmpty) {
      filterExpression.add(['==', ['get', 'bua_name'], widget.selectedBuiltUpArea] as Object);
    }
    
    if (widget.selectedRegion != null && widget.selectedRegion!.isNotEmpty) {
      filterExpression.add(['==', ['get', 'region_name'], widget.selectedRegion] as Object);
    }
    
    if (widget.selectedLocalAuthorityDistrict != null && widget.selectedLocalAuthorityDistrict!.isNotEmpty) {
      filterExpression.add(['==', ['get', 'lad_name'], widget.selectedLocalAuthorityDistrict] as Object);
    }
    
    if (widget.minAcres != null) {
      filterExpression.add(['>=', ['get', 'acres'], widget.minAcres] as Object);
    }
    
    if (widget.maxAcres != null) {
      filterExpression.add(['<=', ['get', 'acres'], widget.maxAcres] as Object);
    }
    
    // Apply filter to both layers
    if (filterExpression.length > 1) {
      // Apply to fill layer
      if (await _mapboxMap!.style.styleLayerExists('parcels-fill-layer')) {
        try {
          await _mapboxMap!.style.setStyleLayerProperty(
            'parcels-fill-layer',
            'filter',
            filterExpression,
          );
          widget.logger.d('Applied filters to fill layer');
        } catch (e) {
          widget.logger.e('Error setting fill layer filter: $e');
        }
      }
      
      // Apply to line layer
      if (await _mapboxMap!.style.styleLayerExists('parcels-line-layer')) {
        try {
          await _mapboxMap!.style.setStyleLayerProperty(
            'parcels-line-layer',
            'filter',
            filterExpression,
          );
          widget.logger.d('Applied filters to line layer');
        } catch (e) {
          widget.logger.e('Error setting line layer filter: $e');
        }
      }
    } else {
      widget.logger.d('No filters to apply');
    }
    
    // Ensure the layers are visible
    _ensureLayerVisibility('parcels-fill-layer');
    _ensureLayerVisibility('parcels-line-layer');
  } catch (e) {
    widget.logger.e('Error applying filters to vector layers: $e');
  }
}

// Helper to ensure layer visibility
Future<void> _ensureLayerVisibility(String layerId) async {
  try {
    if (await _mapboxMap!.style.styleLayerExists(layerId)) {
      final visibility = await _mapboxMap!.style.getStyleLayerProperty(
        layerId, 
        'visibility'
      );
      
      // If layer is not visible, make it visible
      final visibilityValue = visibility.toString();
      if (visibilityValue == 'none') {
        await _mapboxMap!.style.setStyleLayerProperty(
          layerId,
          'visibility',
          'visible'
        );
        widget.logger.d('Changed $layerId visibility to visible');
      }
    }
  } catch (e) {
    widget.logger.e('Error checking $layerId visibility: $e');
  }
}
}
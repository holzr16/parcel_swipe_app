import 'dart:async';

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
  
  // TRY CHANGING THIS TO TEST DIFFERENT SOURCE LAYER NAMES
  final String _sourceLayer = 'aug_parcels_output---combined_filtered';
  
  String get _tileSourceUrl {
    return 'http://100.90.129.100:3000/aug_parcels_output---combined_filtered/{z}/{x}/{y}';
  }

  @override
  void dispose() {
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
            ],
          ),
        ),
      ],
    );
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
        
        // Add layer with the specified source layer
        widget.logger.d('Adding line layer with source layer: "$_sourceLayer"');
        
        await _mapboxMap!.style.addLayer(
          mapbox.LineLayer(
            id: 'parcels-line-layer',
            sourceId: 'parcels-vector-source',
            sourceLayer: _sourceLayer, // Use the specified source layer
            lineColor: 0xFFFF0000, // Red color for boundaries
            lineWidth: 2.0, // Increased width for better visibility
            lineCap: mapbox.LineCap.ROUND,
            lineJoin: mapbox.LineJoin.ROUND,
            minZoom: 15.0, // Match Martin server config minzoom
            maxZoom: 22.0,
          ),
        );
        widget.logger.d('Added line layer for parcel boundaries');
        
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

  Future<void> _applyFilters() async {
    if (_mapboxMap == null || !_isStyleLoaded) return;
    
    try {
      // Convert filter parameters into a Mapbox filter expression
      List<dynamic> filterExpression = ['all'];
      
      if (widget.buaOnly) {
        filterExpression.add(['has', 'bua_name']);
      }
      
      if (widget.selectedCounty != null && widget.selectedCounty!.isNotEmpty) {
        filterExpression.add(['==', ['get', 'county_name'], widget.selectedCounty]);
      }
      
      if (widget.selectedBuiltUpArea != null && widget.selectedBuiltUpArea!.isNotEmpty) {
        filterExpression.add(['==', ['get', 'bua_name'], widget.selectedBuiltUpArea]);
      }
      
      if (widget.selectedRegion != null && widget.selectedRegion!.isNotEmpty) {
        filterExpression.add(['==', ['get', 'region_name'], widget.selectedRegion]);
      }
      
      if (widget.selectedLocalAuthorityDistrict != null && widget.selectedLocalAuthorityDistrict!.isNotEmpty) {
        filterExpression.add(['==', ['get', 'lad_name'], widget.selectedLocalAuthorityDistrict]);
      }
      
      if (widget.minAcres != null) {
        filterExpression.add(['>=', ['get', 'acres'], widget.minAcres]);
      }
      
      if (widget.maxAcres != null) {
        filterExpression.add(['<=', ['get', 'acres'], widget.maxAcres]);
      }
      
      // Apply filter to the layer
      if (filterExpression.length > 1 && await _mapboxMap!.style.styleLayerExists('parcels-line-layer')) {
        // Only apply if we have actual filters (more than just the 'all' operator)
        try {
          await _mapboxMap!.style.setStyleLayerProperty(
            'parcels-line-layer',
            'filter',
            filterExpression,
          );
          widget.logger.d('Applied filters to parcel layer: $filterExpression');
        } catch (e) {
          widget.logger.e('Error setting layer filter: $e');
        }
      } else {
        widget.logger.d('No filters to apply or layer does not exist');
      }
      
      // Ensure the layer is visible
      try {
        if (await _mapboxMap!.style.styleLayerExists('parcels-line-layer')) {
          final visibility = await _mapboxMap!.style.getStyleLayerProperty(
            'parcels-line-layer', 
            'visibility'
          );
          
          // If layer is not visible, make it visible
          final visibilityValue = visibility.toString();
          if (visibilityValue == 'none') {
            await _mapboxMap!.style.setStyleLayerProperty(
              'parcels-line-layer',
              'visibility',
              'visible'
            );
            widget.logger.d('Changed layer visibility to visible');
          }
        }
      } catch (e) {
        widget.logger.e('Error checking layer visibility: $e');
      }
    } catch (e) {
      widget.logger.e('Error applying filters to vector layer: $e');
    }
  }
}
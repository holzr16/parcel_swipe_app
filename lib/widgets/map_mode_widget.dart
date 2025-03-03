// lib\widgets\map_mode_widget.dart

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:logger/logger.dart';
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
  MapboxMap? _mapboxMap;
  bool _isStyleLoaded = false;
  
  // TRY CHANGING THIS TO TEST DIFFERENT SOURCE LAYER NAMES
  final String _sourceLayer = 'aug_parcels_output---combined_filtered';
  
  String get _tileSourceUrl {
    return 'http://100.90.129.100:3000/aug_parcels_output---combined_filtered/{z}/{x}/{y}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              MapWidget(
                styleUri: MapboxStyles.SATELLITE_STREETS,
                cameraOptions: CameraOptions(
                  center: Point(coordinates: Position(-1.5, 53.1)),
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
            ],
          ),
        ),
      ],
    );
  }

  void _onMapCreated(MapboxMap mapboxMap) async {
    widget.logger.d('Map created in Map Mode');
    _mapboxMap = mapboxMap;

    try {
      await _mapboxMap!.loadStyleURI(MapboxStyles.SATELLITE_STREETS);
      widget.logger.d('Loaded style: ${MapboxStyles.SATELLITE_STREETS}');
      
      // Set camera to display UK centered at zoom 15
      await _mapboxMap!.setCamera(
        CameraOptions(
          center: Point(coordinates: Position(-1.5, 53.1)),
          zoom: 15.0, // Set to minimum zoom level for seeing vector tiles
        ),
      );
      widget.logger.d('Set initial camera position: center=[-1.5, 53.1], zoom=15.0');
      
    } catch (e) {
      widget.logger.e('Error during map creation in Map Mode: $e');
    }
  }

  void _onStyleLoaded(StyleLoadedEventData eventData) async {
    widget.logger.d('Style loaded in Map Mode');
    setState(() {
      _isStyleLoaded = true;
    });

    // Add the vector source when the style is loaded
    await _addVectorSource();
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
          VectorSource(
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
          LineLayer(
            id: 'parcels-line-layer',
            sourceId: 'parcels-vector-source',
            sourceLayer: _sourceLayer, // Use the specified source layer
            lineColor: 0xFFFF0000, // Red color for boundaries
            lineWidth: 2.0, // Increased width for better visibility
            lineCap: LineCap.ROUND,
            lineJoin: LineJoin.ROUND,
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
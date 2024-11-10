// lib/screens/set_land_type_mode_screen.dart

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../services/database_service.dart';
import '../widgets/custom_navigation_button.dart';
import 'package:logger/logger.dart';
import 'dart:convert';
import '../widgets/dialogs/filter_dialog.dart';

class SetLandTypeModeScreen extends StatefulWidget {
  final DatabaseService dbService;
  final Logger logger;

  const SetLandTypeModeScreen({
    super.key,
    required this.dbService,
    required this.logger,
  });

  @override
  _SetLandTypeModeScreenState createState() => _SetLandTypeModeScreenState();
}

class _SetLandTypeModeScreenState extends State<SetLandTypeModeScreen> {
  late MapboxMap _mapboxMap;
  List<Map<String, dynamic>> _features = [];
  Map<String, dynamic>? _geoJsonData;
  List<Map<String, dynamic>> _filteredFeatures = [];
  int _currentIndex = 0;
  double? _minAcres;
  double? _maxAcres;
  String? _selectedCounty;
  String? _selectedBuiltUpArea;
  String? _selectedRegion;
  String? _selectedLocalAuthorityDistrict;
  String? _selectedLandType;
  int _totalParcels = 0;
  int _pageNumber = 0;
  final int _pageSize = 100;
  bool _isLoading = false;

  final Map<int, List<Map<String, dynamic>>> _pageCache = {};

  // Lists to hold filter options
  List<String> _countyOptions = [];
  List<String> _builtUpAreaOptions = [];
  List<String> _regionOptions = [];
  List<String> _localAuthorityDistrictOptions = [];
  List<String> _landTypeOptions = [];

  @override
  void initState() {
    super.initState();
    _initializeDatabaseAndFilters();
  }

  Future<void> _initializeDatabaseAndFilters() async {
    try {
      await widget.dbService.connect();
      await _fetchFilterOptions();
      await _fetchLandTypeOptions();
      if (!mounted) return;
      setState(() {});
      await _applyFiltersAndRefresh();
    } catch (e) {
      widget.logger.e('Error during initialization: $e');
      if (!mounted) return;
      _showErrorSnackbar('Initialization failed. Please try again.');
    }
  }

  Future<void> _fetchFilterOptions() async {
    try {
      _countyOptions = await widget.dbService.fetchDistinctCounties();
      _builtUpAreaOptions =
          await widget.dbService.fetchDistinctBuiltUpAreas();
      _regionOptions = await widget.dbService.fetchDistinctRegions();
      _localAuthorityDistrictOptions =
          await widget.dbService.fetchDistinctLocalAuthorityDistricts();

      if (!mounted) return;
      setState(() {});
    } catch (e) {
      widget.logger.e('Error fetching filter options: $e');
      if (!mounted) return;
      _showErrorSnackbar('Failed to load filter options.');
    }
  }

  Future<void> _fetchLandTypeOptions() async {
    try {
      _landTypeOptions = await widget.dbService.fetchDistinctLandTypes();
      _landTypeOptions.insert(0, 'Unseen');
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      widget.logger.e('Error fetching land type options: $e');
      if (!mounted) return;
      _showErrorSnackbar('Failed to load land type options.');
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _applyFiltersAndRefresh() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _pageNumber = 0;
      _features.clear();
      _filteredFeatures.clear();
      _pageCache.clear();
    });

    try {
      await _fetchParcels();
    } catch (e) {
      widget.logger.e('Error applying filters and refreshing data: $e');
      if (!mounted) return;
      _showErrorSnackbar('Failed to apply filters.');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchParcels() async {
    try {
      String? landTypeFilter = _selectedLandType;

      // Fetch total parcels count based on filters
      int total = await widget.dbService.getTotalParcels(
        countyName: _selectedCounty,
        builtUpAreaName: _selectedBuiltUpArea,
        regionName: _selectedRegion,
        localAuthorityDistrictName: _selectedLocalAuthorityDistrict,
        minAcres: _minAcres,
        maxAcres: _maxAcres,
        landType: landTypeFilter,
      );

      // Fetch first page of parcels based on filters
      List<Map<String, dynamic>> parcels =
          await widget.dbService.fetchParcels(
        pageNumber: _pageNumber,
        pageSize: _pageSize,
        countyName: _selectedCounty,
        builtUpAreaName: _selectedBuiltUpArea,
        regionName: _selectedRegion,
        localAuthorityDistrictName: _selectedLocalAuthorityDistrict,
        minAcres: _minAcres,
        maxAcres: _maxAcres,
        landType: landTypeFilter,
      );

      _pageCache[_pageNumber] = parcels;

      if (!mounted) return;
      setState(() {
        _features = parcels;
        _filteredFeatures = List.from(_features);
        _totalParcels = total;
        _isLoading = false;
        _currentIndex = 0;
      });

      await _loadGeoJsonData();

      if (_filteredFeatures.isNotEmpty) {
        await _addGeoJsonLayer();
      }
    } catch (e) {
      widget.logger.e('Error fetching parcels: $e');
      if (!mounted) return;
      _showErrorSnackbar('Failed to fetch parcels.');
      setState(() {
        _isLoading = false;
      });
    }
  }

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
      widget.logger.e('Error loading GeoJSON data: $e');
      if (!mounted) return;
      _showErrorSnackbar('Failed to load map data.');
    }
  }

  Future<void> _addGeoJsonLayer() async {
    if (_geoJsonData == null || _filteredFeatures.isEmpty) {
      widget.logger.w(
          '_geoJsonData is null or _filteredFeatures is empty. Skipping layer addition.');
      return;
    }

    try {
      bool sourceExists =
          await _mapboxMap.style.styleSourceExists('my-geojson-source');

      if (sourceExists) {
        widget.logger.d('GeoJSON source exists. Updating source data.');

        await _mapboxMap.style.setStyleSourceProperty(
          'my-geojson-source',
          'data',
          jsonEncode(_geoJsonData!),
        );
      } else {
        widget.logger.d(
            'GeoJSON source does not exist. Adding new source and layer.');

        await _mapboxMap.style.addSource(
          GeoJsonSource(
            id: 'my-geojson-source',
            data: jsonEncode(_geoJsonData!),
          ),
        );

        String existingLayerId = 'water';

        bool layerExists =
            await _mapboxMap.style.styleLayerExists(existingLayerId);

        if (layerExists) {
          widget.logger.d(
              'Existing layer "$existingLayerId" found. Adding "my-fill-layer" above it.');

          await _mapboxMap.style.addLayerAt(
            FillLayer(
              id: 'my-fill-layer',
              sourceId: 'my-geojson-source',
              fillColor: Colors.green.value,
              fillOpacity: 0.5,
            ),
            LayerPosition(above: existingLayerId),
          );
        } else {
          widget.logger.w(
              'Existing layer "$existingLayerId" not found. Adding "my-fill-layer" without specifying position.');

          await _mapboxMap.style.addLayer(
            FillLayer(
              id: 'my-fill-layer',
              sourceId: 'my-geojson-source',
              fillColor: Colors.green.value,
              fillOpacity: 0.5,
            ),
          );
        }
      }

      await _updateParcel();
    } catch (e) {
      widget.logger.e('Error adding or updating GeoJSON layer: $e');
      if (!mounted) return;
      _showErrorSnackbar('Failed to load map layers.');
    }
  }

  Future<void> _updateParcel() async {
    if (_filteredFeatures.isEmpty) {
      widget.logger.w('No features available to display.');
      return;
    }

    var currentFeature = _filteredFeatures[_currentIndex];
    widget.logger.d('Current Feature: $currentFeature');

    var currentInspireId = currentFeature['inspireid'];

    if (currentInspireId == null) {
      widget.logger.e('inspireid is null for currentFeature: $currentFeature');
      _nextParcel();
      return;
    }

    var geometry = _geoJsonData?['features'][_currentIndex]['geometry'];

    if (geometry == null || geometry['coordinates'] == null) {
      widget.logger.e(
          'Geometry is null or malformed for currentFeature: $currentFeature');
      _nextParcel();
      return;
    }

    try {
      var layer = await _mapboxMap.style.getLayer('my-fill-layer');

      if (layer != null && layer is FillLayer) {
        widget.logger.d(
            'Found "my-fill-layer". Applying filter for inspireid: $currentInspireId');

        layer.filter = [
          '==',
          ['get', 'inspireid'],
          currentInspireId,
        ];

        layer.fillColor = Colors.green.value;

        await _mapboxMap.style.updateLayer(layer);
      } else {
        widget.logger.e('FillLayer "my-fill-layer" not found.');
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
      widget.logger.d('Camera updated to show the current parcel.');
    } catch (e) {
      widget.logger.e('Error updating parcel: $e');
      if (!mounted) return;
      _showErrorSnackbar('Failed to update map view.');
    }
  }

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
      if (coord.length < 2) continue;
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

  void _nextParcel() {
    if (_filteredFeatures.isEmpty) return;
    setState(() {
      _currentIndex = (_currentIndex + 1) % _filteredFeatures.length;
    });
    _updateParcel();
  }

  void _openFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return FilterDialog(
          countyOptions: _countyOptions,
          builtUpAreaOptions: _builtUpAreaOptions,
          regionOptions: _regionOptions,
          localAuthorityDistrictOptions: _localAuthorityDistrictOptions,
          landTypeOptions: _landTypeOptions,
          initialMinAcres: _minAcres,
          initialMaxAcres: _maxAcres,
          initialSelectedCounty: _selectedCounty,
          initialSelectedBuiltUpArea: _selectedBuiltUpArea,
          initialSelectedRegion: _selectedRegion,
          initialSelectedLocalAuthorityDistrict: _selectedLocalAuthorityDistrict,
          initialSelectedLandType: _selectedLandType,
          onApply: ({
            double? minAcres,
            double? maxAcres,
            String? selectedCounty,
            String? selectedBuiltUpArea,
            String? selectedRegion,
            String? selectedLocalAuthorityDistrict,
            String? selectedLandType,
          }) {
            if (minAcres != null &&
                maxAcres != null &&
                minAcres > maxAcres) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Min Acres cannot be greater than Max Acres')),
              );
              return;
            }
            setState(() {
              _selectedCounty = selectedCounty;
              _selectedBuiltUpArea = selectedBuiltUpArea;
              _selectedRegion = selectedRegion;
              _selectedLocalAuthorityDistrict = selectedLocalAuthorityDistrict;
              _selectedLandType = selectedLandType;
              _minAcres = minAcres;
              _maxAcres = maxAcres;
            });
            _applyFiltersAndRefresh();
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  Future<void> _assignLandType(String landType) async {
    if (_filteredFeatures.isEmpty) return;

    var currentFeature = _filteredFeatures[_currentIndex];
    String inspireid = currentFeature['inspireid'].toString();

    try {
      await widget.dbService.assignLandType(inspireid, landType);
      widget.logger.i(
          'Land type "$landType" assigned successfully to parcel $inspireid.');
      _showSuccessSnackbar('Land type "$landType" assigned successfully.');
      await _applyFiltersAndRefresh();
    } catch (e) {
      widget.logger.e('Error assigning land type: $e');
      _showErrorSnackbar('Failed to assign land type "$landType".');
    }
  }

  void _onMapCreated(MapboxMap map) async {
    _mapboxMap = map;

    try {
      await _mapboxMap.loadStyleURI(MapboxStyles.SATELLITE_STREETS);
    } catch (e) {
      widget.logger.e('Error during map creation: $e');
      if (!mounted) return;
      _showErrorSnackbar('Failed to load map.');
    }
  }

  void _onStyleLoaded(StyleLoadedEventData eventData) async {
    widget.logger.d('Style has been loaded.');

    if (_geoJsonData != null && _filteredFeatures.isNotEmpty) {
      await _addGeoJsonLayer();
    }
  }

  @override
  Widget build(BuildContext context) {
    CameraOptions cameraOptions = CameraOptions(
      center: Point(
        coordinates: Position(-1.5, 53.1),
      ),
      zoom: 5.0,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Land Type Mode'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _openFilterDialog,
            tooltip: 'Filter',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Total Parcels: $_totalParcels',
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: MapWidget(
              key: const ValueKey("mapWidget"),
              cameraOptions: cameraOptions,
              styleUri: MapboxStyles.SATELLITE_STREETS,
              onMapCreated: _onMapCreated,
              onStyleLoadedListener: _onStyleLoaded,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CustomNavigationButton(
                  label: 'Greenfield',
                  onPressed: () => _assignLandType('Greenfield'),
                ),
                const SizedBox(width: 20),
                CustomNavigationButton(
                  label: 'Brownfield',
                  onPressed: () => _assignLandType('Brownfield'),
                ),
                const SizedBox(width: 20),
                CustomNavigationButton(
                  label: 'Unsure',
                  onPressed: () => _assignLandType('Unsure'),
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

// lib/screens/parcel_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:logger/logger.dart';
import 'package:another_flushbar/flushbar.dart';
import '../services/database_service.dart';
import '../widgets/dialogs/filter_dialog.dart';
import '../widgets/custom_navigation_button.dart';
import '../widgets/custom_map_widget.dart';
import '../models/parcel_mode.dart';

class ParcelScreen extends StatefulWidget {
  final DatabaseService dbService;
  final Logger logger;

  const ParcelScreen({
    Key? key,
    required this.dbService,
    required this.logger,
  }) : super(key: key);

  @override
  State<ParcelScreen> createState() => _ParcelScreenState();
}

class _ParcelScreenState extends State<ParcelScreen> {
  MapboxMap? _mapboxMap;
  Map<String, dynamic>? _geoJsonData;
  List<Map<String, dynamic>> _features = [];
  List<Map<String, dynamic>> _filteredFeatures = [];
  final Map<int, List<Map<String, dynamic>>> _pageCache = {};
  int _pageNumber = 0;
  final int _pageSize = 100;
  bool _isLoading = false;
  int _currentIndex = 0;
  bool _isConfirming = false;

  // Current mode
  ParcelMode _currentMode = ParcelMode.view;

  // Filter parameters
  String? _selectedCounty;
  String? _selectedBuiltUpArea;
  String? _selectedRegion;
  String? _selectedLocalAuthorityDistrict;
  String? _selectedStatus;
  double? _minAcres;
  double? _maxAcres;
  bool _buaOnly = false;

  // Filter options
  List<String> _countyOptions = [];
  List<String> _builtUpAreaOptions = [];
  List<String> _regionOptions = [];
  List<String> _localAuthorityDistrictOptions = [];
  List<String> _landTypeOptions = [];

  // Total parcels count
  int _totalParcels = 0;

  @override
  void initState() {
    super.initState();
    // Removed _connectToDatabase as it's handled in main.dart
  }

  Future<void> _applyFiltersAndRefresh() async {
    setState(() {
      _isLoading = true;
      _pageNumber = 0;
      _features.clear();
      _filteredFeatures.clear();
      _pageCache.clear();
      _currentIndex = 0;
    });

    widget.logger.d('Applying filters and refreshing parcels.');

    try {
      // Determine filter based on current mode
      String? viewStatus;
      String? landType;
      String? subType;

      switch (_currentMode) {
        case ParcelMode.view:
          viewStatus = _selectedStatus;
          break;
        case ParcelMode.landType:
          landType = _selectedStatus;
          break;
        case ParcelMode.landSubType:
          subType = _selectedStatus;
          break;
      }

      // Fetch total number of parcels based on filters
      int total = await widget.dbService.getTotalParcels(
        countyName: _selectedCounty,
        builtUpAreaName: _selectedBuiltUpArea,
        regionName: _selectedRegion,
        localAuthorityDistrictName: _selectedLocalAuthorityDistrict,
        minAcres: _minAcres,
        maxAcres: _maxAcres,
        viewStatus: viewStatus,
        landType: landType,
        subType: subType,
        buaOnly: _buaOnly,
      );

      widget.logger.d('Total parcels found: $total');

      // Fetch first page of parcels based on filters
      List<Map<String, dynamic>> parcels = await widget.dbService.fetchParcels(
        pageNumber: _pageNumber,
        pageSize: _pageSize,
        countyName: _selectedCounty,
        builtUpAreaName: _selectedBuiltUpArea,
        regionName: _selectedRegion,
        localAuthorityDistrictName: _selectedLocalAuthorityDistrict,
        minAcres: _minAcres,
        maxAcres: _maxAcres,
        viewStatus: viewStatus,
        landType: landType,
        subType: subType,
        buaOnly: _buaOnly,
      );

      _pageCache[_pageNumber] = parcels;

      if (!mounted) return;
      setState(() {
        _features = parcels;
        _filteredFeatures = List.from(_features);
        _totalParcels = total; // Assign the total parcels count
        _isLoading = false;
      });

      widget.logger.d('Fetched ${parcels.length} parcels for page $_pageNumber.');

      if (_filteredFeatures.isNotEmpty) {
        await _loadGeoJsonData();
        await _addGeoJsonLayer();
      } else {
        // Clear map when no parcels are found
        await _clearGeoJsonLayer();
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
              "landType": feature['land_type'] ?? 'Unseen',
              "subType": feature['sub_type'] ?? 'Unseen',
              "viewStatus": feature['view_status'] ?? 'Unseen',
            },
            "geometry": jsonDecode(feature['geom']),
          };
        }).toList(),
      };
      widget.logger.d('Loaded GeoJSON data for ${_filteredFeatures.length} features.');
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

    if (_mapboxMap == null) return;

    try {
      bool sourceExists =
          await _mapboxMap!.style.styleSourceExists('parcel-geojson-source');

      if (sourceExists) {
        widget.logger.d('GeoJSON source exists. Updating source data.');

        await _mapboxMap!.style.setStyleSourceProperty(
          'parcel-geojson-source',
          'data',
          jsonEncode(_geoJsonData!),
        );

        // Remove existing layer if any
        bool layerExists =
            await _mapboxMap!.style.styleLayerExists('parcel-line-layer');
        if (layerExists) {
          await _mapboxMap!.style.removeStyleLayer('parcel-line-layer');
          widget.logger.d('Removed existing parcel-line-layer.');
        }
      } else {
        widget.logger.d(
            'GeoJSON source does not exist. Adding new source and layer.');

        await _mapboxMap!.style.addSource(
          GeoJsonSource(
            id: 'parcel-geojson-source',
            data: jsonEncode(_geoJsonData!),
          ),
        );
        widget.logger.d('Added parcel-geojson-source.');
      }

      // Add the layer after ensuring the source exists
      bool layerExists =
          await _mapboxMap!.style.styleLayerExists('parcel-line-layer');

      if (!layerExists) {
        await _mapboxMap!.style.addLayer(
          LineLayer(
            id: 'parcel-line-layer',
            sourceId: 'parcel-geojson-source',
            lineColor: 0xFFFF0000, // #FF0000 in ARGB
            lineWidth: 2.0,
            lineCap: LineCap.BUTT,
            lineJoin: LineJoin.MITER,
            minZoom: 0.0,
            maxZoom: 22.0,
          ),
        );
        widget.logger.d('Added parcel-line-layer.');
      }

      await _updateParcel();
    } catch (e) {
      widget.logger.e('Error adding or updating GeoJSON layer: $e');
      if (!mounted) return;
      _showErrorSnackbar('Failed to load map layers.');
    }
  }

  Future<void> _clearGeoJsonLayer() async {
    if (_mapboxMap == null) return;

    try {
      bool sourceExists =
          await _mapboxMap!.style.styleSourceExists('parcel-geojson-source');

      if (sourceExists) {
        bool layerExists =
            await _mapboxMap!.style.styleLayerExists('parcel-line-layer');
        if (layerExists) {
          await _mapboxMap!.style.removeStyleLayer('parcel-line-layer');
          widget.logger.d('Removed parcel-line-layer.');
        }
        await _mapboxMap!.style.removeStyleSource('parcel-geojson-source');
        widget.logger.d('Removed parcel-geojson-source.');
      }

      // Optionally, show a message overlay or update UI to indicate no parcels found
      _showInfoSnackbar('No parcels found. Please adjust your filters.');
    } catch (e) {
      widget.logger.e('Error clearing GeoJSON layer: $e');
      if (!mounted) return;
      _showErrorSnackbar('Failed to clear map layers.');
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

    if (_mapboxMap == null) return;

    try {
      var layer = await _mapboxMap!.style.getLayer('parcel-line-layer');

      if (layer != null && layer is LineLayer) {
        widget.logger.d(
            'Found "parcel-line-layer". Applying filter for inspireid: $currentInspireId');

        layer.filter = [
          '==',
          ['get', 'inspireid'],
          currentInspireId,
        ];

        await _mapboxMap!.style.updateLayer(layer);
        widget.logger.d('Applied filter to parcel-line-layer.');
      } else {
        widget.logger.e('LineLayer "parcel-line-layer" not found.');
        return;
      }

      var coordinateBounds = _getFeatureBounds(geometry);

      var cameraOptions = await _mapboxMap!.cameraForCoordinateBounds(
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

      await _mapboxMap!.setCamera(cameraOptions);
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

  void _openFilterDialog() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Dynamically fetch filter options
      final counties = await widget.dbService.fetchDistinctCounties();
      final builtUpAreas = await widget.dbService.fetchDistinctBuiltUpAreas();
      final regions = await widget.dbService.fetchDistinctRegions();
      final localAuthorities =
          await widget.dbService.fetchDistinctLocalAuthorityDistricts();
      final landTypes = await widget.dbService.fetchDistinctLandTypes();

      widget.logger.d(
        'Fetched lists: counties=${counties.length}, '
        'bua=${builtUpAreas.length}, '
        'regions=${regions.length}, '
        'lads=${localAuthorities.length}, '
        'landTypes=${landTypes.length}',
      );

      setState(() {
        _countyOptions = counties;
        _builtUpAreaOptions = builtUpAreas;
        _regionOptions = regions;
        _localAuthorityDistrictOptions = localAuthorities;
        _landTypeOptions = landTypes;
        _isLoading = false;
      });

      widget.logger.d('Fetched filter options successfully.');

      // Open the filter dialog and wait for the result
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (dialogContext) {
          return FilterDialog(
            countyOptions: _countyOptions,
            builtUpAreaOptions: _builtUpAreaOptions,
            regionOptions: _regionOptions,
            localAuthorityDistrictOptions: _localAuthorityDistrictOptions,
            landTypeOptions: _landTypeOptions,
            currentMode: _currentMode,
            initialMinAcres: _minAcres,
            initialMaxAcres: _maxAcres,
            initialSelectedCounty: _selectedCounty,
            initialSelectedBuiltUpArea: _selectedBuiltUpArea,
            initialSelectedRegion: _selectedRegion,
            initialSelectedLocalAuthorityDistrict: _selectedLocalAuthorityDistrict,
            initialSelectedStatus: _selectedStatus,
            initialBUAOnly: _buaOnly,
          );
        },
      );

      if (result != null) {
        setState(() {
          _currentMode = result['selectedMode'];
          _selectedCounty = result['selectedCounty'];
          _selectedBuiltUpArea = result['selectedBuiltUpArea'];
          _selectedRegion = result['selectedRegion'];
          _selectedLocalAuthorityDistrict = result['selectedLocalAuthorityDistrict'];
          _selectedStatus = result['selectedStatus'];
          _minAcres = result['minAcres'];
          _maxAcres = result['maxAcres'];
          _buaOnly = result['buaOnly'];
        });
        widget.logger.d('Applied new filters: $result');
        _applyFiltersAndRefresh();
      } else {
        widget.logger.d('Filter dialog was dismissed without applying filters.');
      }
    } catch (e) {
      widget.logger.e('Error fetching filter options: $e');
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackbar('Failed to load filter options.');
    }
  }

  void _showErrorSnackbar(String message) {
    Flushbar(
      message: message,
      backgroundColor: Colors.red,
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(8),
      borderRadius: BorderRadius.circular(8),
      flushbarPosition: FlushbarPosition.TOP,
    ).show(context);
    widget.logger.d('Displayed error snackbar: $message');
  }

  void _showSuccessSnackbar(String message) {
    Flushbar(
      message: message,
      backgroundColor: Colors.green,
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(8),
      borderRadius: BorderRadius.circular(8),
      flushbarPosition: FlushbarPosition.TOP,
    ).show(context);
    widget.logger.d('Displayed success snackbar: $message');
  }

  void _showInfoSnackbar(String message) {
    Flushbar(
      message: message,
      backgroundColor: Colors.blue,
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(8),
      borderRadius: BorderRadius.circular(8),
      flushbarPosition: FlushbarPosition.TOP,
    ).show(context);
    widget.logger.d('Displayed info snackbar: $message');
  }

  Future<void> _assignStatus(String status) async {
    if (_filteredFeatures.isEmpty) return;

    var currentFeature = _filteredFeatures[_currentIndex];
    String inspireid = currentFeature['inspireid'].toString();

    // Determine current status based on mode
    String? currentStatus;
    switch (_currentMode) {
      case ParcelMode.view:
        currentStatus = currentFeature['view_status'];
        break;
      case ParcelMode.landType:
        currentStatus = currentFeature['land_type'];
        break;
      case ParcelMode.landSubType:
        currentStatus = currentFeature['sub_type'];
        break;
    }

    // If currentStatus is not null and not 'Unseen', show confirmation
    if (currentStatus != null && currentStatus != 'Unseen') {
      bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Confirm Reassignment'),
            content: Text(
                'This parcel is already assigned as "$currentStatus". Do you want to reassign it to "$status"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Confirm'),
              ),
            ],
          );
        },
      );

      if (confirm != true) {
        widget.logger.d('User canceled reassignment of parcel $inspireid.');
        return; // User canceled the reassignment
      }
    }

    // Disable buttons during assignment
    setState(() {
      _isConfirming = true;
    });

    // Validate status based on current mode
    switch (_currentMode) {
      case ParcelMode.view:
        if (!_isValidViewStatus(status)) {
          _showErrorSnackbar('Invalid status for View Mode.');
          widget.logger.w('Invalid status "$status" for View Mode.');
          setState(() {
            _isConfirming = false;
          });
          return;
        }
        break;
      case ParcelMode.landType:
        if (!_isValidLandType(status)) {
          _showErrorSnackbar('Invalid land type.');
          widget.logger.w('Invalid land type "$status".');
          setState(() {
            _isConfirming = false;
          });
          return;
        }
        break;
      case ParcelMode.landSubType:
        if (!_isValidLandSubType(status)) {
          _showErrorSnackbar('Invalid land sub-type.');
          widget.logger.w('Invalid land sub-type "$status".');
          setState(() {
            _isConfirming = false;
          });
          return;
        }
        break;
    }

    try {
      switch (_currentMode) {
        case ParcelMode.view:
          await widget.dbService.assignViewStatus(inspireid, status);
          break;
        case ParcelMode.landType:
          await widget.dbService.assignLandType(inspireid, status);
          break;
        case ParcelMode.landSubType:
          await widget.dbService.assignSubType(inspireid, status);
          break;
      }

      widget.logger.i(
          'Status "$status" assigned successfully to parcel $inspireid.');
      _showSuccessSnackbar('Status "$status" assigned successfully.');

      setState(() {
        // Update the feature's status locally
        switch (_currentMode) {
          case ParcelMode.view:
            _filteredFeatures[_currentIndex]['view_status'] = status;
            break;
          case ParcelMode.landType:
            _filteredFeatures[_currentIndex]['land_type'] = status;
            break;
          case ParcelMode.landSubType:
            _filteredFeatures[_currentIndex]['sub_type'] = status;
            break;
        }
        _isConfirming = false;
      });

      _nextParcel();
    } catch (e) {
      widget.logger.e('Error assigning status: $e');
      _showErrorSnackbar('Failed to assign status "$status".');
      setState(() {
        _isConfirming = false;
      });
    }
  }

  bool _isValidViewStatus(String status) {
    return widget.dbService.allowedViewStatuses.contains(status);
  }

  bool _isValidLandType(String landType) {
    return widget.dbService.allowedLandTypes.contains(landType);
  }

  bool _isValidLandSubType(String subType) {
    return widget.dbService.allowedLandSubTypes.contains(subType);
  }

  void _changeMode(ParcelMode mode) {
    setState(() {
      _currentMode = mode;
      // Reset selected status when mode changes
      _selectedStatus = null;
    });
    widget.logger.d('Mode changed to $_currentMode');
    _applyFiltersAndRefresh();
  }

  void _onMapCreated(MapboxMap map) async {
    _mapboxMap = map;

    try {
      await _mapboxMap!
          .loadStyleURI(MapboxStyles.SATELLITE_STREETS)
          .catchError((e) {
        widget.logger.e('Error loading style URI: $e');
        if (!mounted) return;
        _showErrorSnackbar('Failed to load map style.');
      });

      await _mapboxMap!.setCamera(
        CameraOptions(
          center: Point(coordinates: Position(-1.5, 53.1)),
          zoom: 5.0,
        ),
      );

      widget.logger.d('Map style loaded and camera set.');
    } catch (e) {
      widget.logger.e('Error during map creation: $e');
      if (!mounted) return;
      _showErrorSnackbar('Failed to load map.');
    }
  }

  void _onStyleLoaded(StyleLoadedEventData eventData) async {
    widget.logger.d('Style has been loaded.');
    // No longer using _mapIsReady check
    if (_geoJsonData != null && _filteredFeatures.isNotEmpty) {
      await _addGeoJsonLayer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parcel Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_alt),
            onPressed: _openFilterDialog,
            tooltip: 'Filter',
          ),
          // Removed the PopupMenuButton from AppBar
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
          if (_buaOnly)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Row(
                children: const [
                  Icon(Icons.check_box, color: Colors.blue),
                  SizedBox(width: 8),
                  Text(
                    'BUA Only Filter Applied',
                    style: TextStyle(
                        color: Colors.blue, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _totalParcels > 0
                ? CustomMapWidget(
                    key: const ValueKey("mapWidget"),
                    onMapCreated: _onMapCreated,
                    onStyleLoadedListener: _onStyleLoaded,
                  )
                : Center(
                    child: Text(
                      'No parcels found. Please adjust your filters.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[700],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Wrap(
              spacing: 20,
              children: [
                if (_currentMode == ParcelMode.view) ...[
                  CustomNavigationButton(
                    label: 'Save',
                    onPressed:
                        _isConfirming ? () {} : () => _assignStatus('Saved'),
                  ),
                  CustomNavigationButton(
                    label: 'Dismiss',
                    onPressed: _isConfirming
                        ? () {}
                        : () => _assignStatus('Dismissed'),
                  ),
                  CustomNavigationButton(
                    label: 'Skip',
                    onPressed: _isConfirming ? () {} : _nextParcel,
                  ),
                ],
                if (_currentMode == ParcelMode.landType)
                  ...widget.dbService.allowedLandTypes
                      .where((type) => type != 'Unseen')
                      .map((landType) {
                    return CustomNavigationButton(
                      label: landType,
                      onPressed: _isConfirming
                          ? () {}
                          : () => _assignStatus(landType),
                    );
                  }).toList(),
                if (_currentMode == ParcelMode.landSubType)
                  ...widget.dbService.allowedLandSubTypes
                      .where((subType) => subType != 'Unseen')
                      .map((subType) {
                    return CustomNavigationButton(
                      label: subType,
                      onPressed: _isConfirming
                          ? () {}
                          : () => _assignStatus(subType),
                    );
                  }).toList(),
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

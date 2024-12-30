// lib/widgets/dialogs/filter_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/parcel_mode.dart';
import 'package:logger/logger.dart'; // Ensure you have a logger instance

class FilterDialog extends StatefulWidget {
  final List<String> countyOptions;
  final List<String> builtUpAreaOptions;
  final List<String> regionOptions;
  final List<String> localAuthorityDistrictOptions;
  final List<String> landTypeOptions;
  final ParcelMode currentMode;
  final double? initialMinAcres;
  final double? initialMaxAcres;
  final String? initialSelectedCounty;
  final String? initialSelectedBuiltUpArea;
  final String? initialSelectedRegion;
  final String? initialSelectedLocalAuthorityDistrict;
  final String? initialSelectedStatus;
  final bool initialBUAOnly;

  const FilterDialog({
    Key? key,
    required this.countyOptions,
    required this.builtUpAreaOptions,
    required this.regionOptions,
    required this.localAuthorityDistrictOptions,
    required this.landTypeOptions,
    required this.currentMode,
    this.initialMinAcres,
    this.initialMaxAcres,
    this.initialSelectedCounty,
    this.initialSelectedBuiltUpArea,
    this.initialSelectedRegion,
    this.initialSelectedLocalAuthorityDistrict,
    this.initialSelectedStatus,
    this.initialBUAOnly = false,
  }) : super(key: key);

  @override
  State<FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<FilterDialog> {
  final Logger _logger = Logger(); // Initialize a logger instance

  ParcelMode _selectedMode = ParcelMode.view; // Mode selection
  String? _selectedCounty;
  String? _selectedBuiltUpArea;
  String? _selectedRegion;
  String? _selectedLocalAuthorityDistrict;
  String? _selectedStatus;
  double? _minAcres;
  double? _maxAcres;
  bool _buaOnly = false;

  late List<String> _statusOptions;

  // Controllers for Autocomplete fields
  late TextEditingController _countyController;
  late TextEditingController _builtUpAreaController;
  late TextEditingController _regionController;
  late TextEditingController _ladController;
  late TextEditingController _minAcresController;
  late TextEditingController _maxAcresController;

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.currentMode;
    _selectedCounty = widget.initialSelectedCounty;
    _selectedBuiltUpArea = widget.initialSelectedBuiltUpArea;
    _selectedRegion = widget.initialSelectedRegion;
    _selectedLocalAuthorityDistrict = widget.initialSelectedLocalAuthorityDistrict;
    _selectedStatus = widget.initialSelectedStatus;
    _minAcres = widget.initialMinAcres;
    _maxAcres = widget.initialMaxAcres;
    _buaOnly = widget.initialBUAOnly;

    _statusOptions = _getStatusOptionsForMode(_selectedMode);

    // Initialize controllers with initial values
    _countyController = TextEditingController(text: _selectedCounty);
    _builtUpAreaController = TextEditingController(text: _selectedBuiltUpArea);
    _regionController = TextEditingController(text: _selectedRegion);
    _ladController = TextEditingController(text: _selectedLocalAuthorityDistrict);
    _minAcresController = TextEditingController(
        text: _minAcres != null ? _minAcres!.toStringAsFixed(2) : '');
    _maxAcresController = TextEditingController(
        text: _maxAcres != null ? _maxAcres!.toStringAsFixed(2) : '');
  }

  List<String> _getStatusOptionsForMode(ParcelMode mode) {
    switch (mode) {
      case ParcelMode.view:
        return ['Saved', 'Dismissed', 'Unseen'];
      case ParcelMode.landType:
        return ['NA', 'Unsure', 'Vacant Land', 'Developed', 'Unseen'];
      case ParcelMode.landSubType:
        return ['Brownfield', 'Greenfield', 'NA', 'Unsure', 'Unseen'];
      default:
        return ['Unseen'];
    }
  }

  void _onModeChanged(ParcelMode? mode) {
    if (mode != null) {
      setState(() {
        _selectedMode = mode;
        _selectedStatus = null; // Reset status when mode changes
        _statusOptions = _getStatusOptionsForMode(_selectedMode);
      });
      _logger.d('Mode changed to $_selectedMode');
    }
  }

  void _resetFilters() {
    setState(() {
      _selectedMode = ParcelMode.view;
      _selectedCounty = null;
      _selectedBuiltUpArea = null;
      _selectedRegion = null;
      _selectedLocalAuthorityDistrict = null;
      _selectedStatus = null;
      _minAcres = null;
      _maxAcres = null;
      _buaOnly = false;
      _statusOptions = _getStatusOptionsForMode(_selectedMode);

      // Reset controllers
      _countyController.text = '';
      _builtUpAreaController.text = '';
      _regionController.text = '';
      _ladController.text = '';
      _minAcresController.text = '';
      _maxAcresController.text = '';
    });
    _logger.d('Filters have been reset');
  }

  @override
  void dispose() {
    _countyController.dispose();
    _builtUpAreaController.dispose();
    _regionController.dispose();
    _ladController.dispose();
    _minAcresController.dispose();
    _maxAcresController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    _logger.d('Applying filters: Mode=$_selectedMode, '
        'County=$_selectedCounty, '
        'BuiltUpArea=$_selectedBuiltUpArea, '
        'Region=$_selectedRegion, '
        'LocalAuthorityDistrict=$_selectedLocalAuthorityDistrict, '
        'Status=$_selectedStatus, '
        'MinAcres=$_minAcres, '
        'MaxAcres=$_maxAcres, '
        'BUAOnly=$_buaOnly');

    Navigator.of(context).pop({
      'selectedMode': _selectedMode,
      'minAcres': _minAcres,
      'maxAcres': _maxAcres,
      'selectedCounty': _selectedCounty,
      'selectedBuiltUpArea': _selectedBuiltUpArea,
      'selectedRegion': _selectedRegion,
      'selectedLocalAuthorityDistrict': _selectedLocalAuthorityDistrict,
      'selectedStatus': _selectedStatus,
      'buaOnly': _buaOnly,
    });
    _logger.d('Filters applied and dialog closed.');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filter Parcels'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Mode Selection Dropdown
            DropdownButtonFormField<ParcelMode>(
              decoration: const InputDecoration(
                labelText: 'Select Mode',
                border: OutlineInputBorder(),
              ),
              value: _selectedMode,
              items: ParcelMode.values.map((ParcelMode mode) {
                return DropdownMenuItem<ParcelMode>(
                  value: mode,
                  child: Text(mode.name),
                );
              }).toList(),
              onChanged: _onModeChanged,
              isExpanded: true,
              hint: const Text('Select Mode'),
            ),
            const SizedBox(height: 10),
            // County Autocomplete
            Autocomplete<String>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return const Iterable<String>.empty();
                }
                return widget.countyOptions.where((String option) {
                  return option.toLowerCase().contains(
                      textEditingValue.text.toLowerCase());
                });
              },
              onSelected: (String selection) {
                setState(() {
                  _selectedCounty = selection;
                  _countyController.text = selection;
                });
                _logger.d('Selected County: $selection');
              },
              fieldViewBuilder: (BuildContext context,
                  TextEditingController textEditingController,
                  FocusNode focusNode,
                  VoidCallback onFieldSubmitted) {
                return TextFormField(
                  controller: _countyController,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'County',
                    border: OutlineInputBorder(),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            // Built-Up Area Autocomplete
            Autocomplete<String>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return const Iterable<String>.empty();
                }
                return widget.builtUpAreaOptions.where((String option) {
                  return option.toLowerCase().contains(
                      textEditingValue.text.toLowerCase());
                });
              },
              onSelected: (String selection) {
                setState(() {
                  _selectedBuiltUpArea = selection;
                  _builtUpAreaController.text = selection;
                });
                _logger.d('Selected Built-Up Area: $selection');
              },
              fieldViewBuilder: (BuildContext context,
                  TextEditingController textEditingController,
                  FocusNode focusNode,
                  VoidCallback onFieldSubmitted) {
                return TextFormField(
                  controller: _builtUpAreaController,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'Built-Up Area',
                    border: OutlineInputBorder(),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            // Region Autocomplete
            Autocomplete<String>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return const Iterable<String>.empty();
                }
                return widget.regionOptions.where((String option) {
                  return option.toLowerCase().contains(
                      textEditingValue.text.toLowerCase());
                });
              },
              onSelected: (String selection) {
                setState(() {
                  _selectedRegion = selection;
                  _regionController.text = selection;
                });
                _logger.d('Selected Region: $selection');
              },
              fieldViewBuilder: (BuildContext context,
                  TextEditingController textEditingController,
                  FocusNode focusNode,
                  VoidCallback onFieldSubmitted) {
                return TextFormField(
                  controller: _regionController,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'Region',
                    border: OutlineInputBorder(),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            // Local Authority District Autocomplete
            Autocomplete<String>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return const Iterable<String>.empty();
                }
                return widget.localAuthorityDistrictOptions.where(
                    (String option) => option
                        .toLowerCase()
                        .contains(textEditingValue.text.toLowerCase()));
              },
              onSelected: (String selection) {
                setState(() {
                  _selectedLocalAuthorityDistrict = selection;
                  _ladController.text = selection;
                });
                _logger.d('Selected Local Authority District: $selection');
              },
              fieldViewBuilder: (BuildContext context,
                  TextEditingController textEditingController,
                  FocusNode focusNode,
                  VoidCallback onFieldSubmitted) {
                return TextFormField(
                  controller: _ladController,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'Local Authority District',
                    border: OutlineInputBorder(),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            // Status Dropdown
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
              ),
              value: _selectedStatus,
              items: _statusOptions
                  .map((status) => DropdownMenuItem(
                        value: status,
                        child: Text(status),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedStatus = value;
                });
                _logger.d('Selected Status: $value');
              },
              isExpanded: true,
              hint: const Text('Select Status'),
            ),
            const SizedBox(height: 10),
            // Min Acres with input formatter
            TextFormField(
              controller: _minAcresController,
              decoration: const InputDecoration(
                labelText: 'Minimum Acres',
                border: OutlineInputBorder(),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(r'^\d+\.?\d{0,2}')), // Allow up to 2 decimals
              ],
              onChanged: (value) {
                setState(() {
                  _minAcres =
                      value.isNotEmpty ? double.tryParse(value) : null;
                });
                _logger.d('Minimum Acres set to: $value');
              },
            ),
            const SizedBox(height: 10),
            // Max Acres with input formatter
            TextFormField(
              controller: _maxAcresController,
              decoration: const InputDecoration(
                labelText: 'Maximum Acres',
                border: OutlineInputBorder(),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(r'^\d+\.?\d{0,2}')), // Allow up to 2 decimals
              ],
              onChanged: (value) {
                setState(() {
                  _maxAcres =
                      value.isNotEmpty ? double.tryParse(value) : null;
                });
                _logger.d('Maximum Acres set to: $value');
              },
            ),
            const SizedBox(height: 10),
            // BUA Only Checkbox
            CheckboxListTile(
              title: const Text('BUA Only'),
              value: _buaOnly,
              onChanged: (value) {
                setState(() {
                  _buaOnly = value ?? false;
                });
                _logger.d('BUA Only set to $_buaOnly');
              },
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            _resetFilters();
          },
          child: const Text('Reset'),
        ),
        TextButton(
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
              _logger.d('Filter dialog canceled by user');
            } else {
              _logger.w('Attempted to pop dialog but Navigator cannot pop');
            }
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            _applyFilters(); // Apply and pop the dialog
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

// Extension to capitalize the first letter
extension StringCasingExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}

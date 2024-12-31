import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/parcel_mode.dart';
import 'package:logger/logger.dart';

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
  final Logger _logger = Logger();

  ParcelMode _selectedMode = ParcelMode.view;
  String? _selectedCounty;
  String? _selectedBuiltUpArea;
  String? _selectedRegion;
  String? _selectedLocalAuthorityDistrict;
  String? _selectedStatus;
  double? _minAcres;
  double? _maxAcres;
  bool _buaOnly = false;

  late List<String> _statusOptions;

  // Only keep controllers for numeric inputs
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

    _minAcresController = TextEditingController(
      text: _minAcres != null ? _minAcres!.toStringAsFixed(2) : '',
    );
    _maxAcresController = TextEditingController(
      text: _maxAcres != null ? _maxAcres!.toStringAsFixed(2) : '',
    );
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
        _selectedStatus = null;
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

      _minAcresController.text = '';
      _maxAcresController.text = '';
    });
    _logger.d('Filters have been reset');
  }

  @override
  void dispose() {
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

            Autocomplete<String>(
              initialValue: TextEditingValue(text: _selectedCounty ?? ''),
              optionsBuilder: (TextEditingValue textEditingValue) {
                _logger.d('County search: ${textEditingValue.text}');
                if (textEditingValue.text.isEmpty) {
                  return widget.countyOptions;
                }
                return widget.countyOptions.where((String option) {
                  return option.toLowerCase().contains(
                      textEditingValue.text.toLowerCase());
                });
              },
              onSelected: (String selection) {
                setState(() {
                  _selectedCounty = selection;
                });
                _logger.d('Selected County: $selection');
              },
              fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                return TextFormField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'County',
                    border: OutlineInputBorder(),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),

            Autocomplete<String>(
              initialValue: TextEditingValue(text: _selectedBuiltUpArea ?? ''),
              optionsBuilder: (TextEditingValue textEditingValue) {
                _logger.d('Built-Up Area search: ${textEditingValue.text}');
                if (textEditingValue.text.isEmpty) {
                  return widget.builtUpAreaOptions;
                }
                return widget.builtUpAreaOptions.where((String option) {
                  return option.toLowerCase().contains(
                      textEditingValue.text.toLowerCase());
                });
              },
              onSelected: (String selection) {
                setState(() {
                  _selectedBuiltUpArea = selection;
                });
                _logger.d('Selected Built-Up Area: $selection');
              },
              fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                return TextFormField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'Built-Up Area',
                    border: OutlineInputBorder(),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),

            Autocomplete<String>(
              initialValue: TextEditingValue(text: _selectedRegion ?? ''),
              optionsBuilder: (TextEditingValue textEditingValue) {
                _logger.d('Region search: ${textEditingValue.text}');
                if (textEditingValue.text.isEmpty) {
                  return widget.regionOptions;
                }
                return widget.regionOptions.where((String option) {
                  return option.toLowerCase().contains(
                      textEditingValue.text.toLowerCase());
                });
              },
              onSelected: (String selection) {
                setState(() {
                  _selectedRegion = selection;
                });
                _logger.d('Selected Region: $selection');
              },
              fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                return TextFormField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'Region',
                    border: OutlineInputBorder(),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),

            Autocomplete<String>(
              initialValue: TextEditingValue(text: _selectedLocalAuthorityDistrict ?? ''),
              optionsBuilder: (TextEditingValue textEditingValue) {
                _logger.d('LAD search: ${textEditingValue.text}');
                if (textEditingValue.text.isEmpty) {
                  return widget.localAuthorityDistrictOptions;
                }
                return widget.localAuthorityDistrictOptions.where((String option) {
                  return option.toLowerCase().contains(
                      textEditingValue.text.toLowerCase());
                });
              },
              onSelected: (String selection) {
                setState(() {
                  _selectedLocalAuthorityDistrict = selection;
                });
                _logger.d('Selected Local Authority District: $selection');
              },
              fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                return TextFormField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'Local Authority District',
                    border: OutlineInputBorder(),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),

            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
              ),
              value: _selectedStatus,
              items: _statusOptions.map((status) => DropdownMenuItem(
                value: status,
                child: Text(status),
              )).toList(),
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

            TextFormField(
              controller: _minAcresController,
              decoration: const InputDecoration(
                labelText: 'Minimum Acres',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              onChanged: (value) {
                setState(() {
                  _minAcres = value.isNotEmpty ? double.tryParse(value) : null;
                });
                _logger.d('Minimum Acres set to: $value');
              },
            ),
            const SizedBox(height: 10),

            TextFormField(
              controller: _maxAcresController,
              decoration: const InputDecoration(
                labelText: 'Maximum Acres',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              onChanged: (value) {
                setState(() {
                  _maxAcres = value.isNotEmpty ? double.tryParse(value) : null;
                });
                _logger.d('Maximum Acres set to: $value');
              },
            ),
            const SizedBox(height: 10),

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
          onPressed: _resetFilters,
          child: const Text('Reset'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            _logger.d('Filter dialog canceled');
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _applyFilters,
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
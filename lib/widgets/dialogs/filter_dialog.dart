// lib/widgets/dialogs/filter_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FilterDialog extends StatefulWidget {
  // Define the necessary parameters and callbacks
  final List<String> countyOptions;
  final List<String> builtUpAreaOptions;
  final List<String> regionOptions;
  final List<String> localAuthorityDistrictOptions;
  final List<String> landTypeOptions;
  final double? initialMinAcres;
  final double? initialMaxAcres;
  final String? initialSelectedCounty;
  final String? initialSelectedBuiltUpArea;
  final String? initialSelectedRegion;
  final String? initialSelectedLocalAuthorityDistrict;
  final String? initialSelectedLandType;
  final bool initialBUAOnly; // New parameter for BUA Only
  final Function({
    double? minAcres,
    double? maxAcres,
    String? selectedCounty,
    String? selectedBuiltUpArea,
    String? selectedRegion,
    String? selectedLocalAuthorityDistrict,
    String? selectedLandType,
    bool buaOnly, // New parameter
  }) onApply;

  const FilterDialog({
    super.key,
    required this.countyOptions,
    required this.builtUpAreaOptions,
    required this.regionOptions,
    required this.localAuthorityDistrictOptions,
    required this.landTypeOptions,
    this.initialMinAcres,
    this.initialMaxAcres,
    this.initialSelectedCounty,
    this.initialSelectedBuiltUpArea,
    this.initialSelectedRegion,
    this.initialSelectedLocalAuthorityDistrict,
    this.initialSelectedLandType,
    this.initialBUAOnly = false, // Default value
    required this.onApply,
  });

  @override
  _FilterDialogState createState() => _FilterDialogState();
}

class _FilterDialogState extends State<FilterDialog> {
  double? _minAcres;
  double? _maxAcres;
  String? _selectedCounty;
  String? _selectedBuiltUpArea;
  String? _selectedRegion;
  String? _selectedLocalAuthorityDistrict;
  String? _selectedLandType;
  bool _buaOnly = false; // New state variable

  final TextEditingController _minAcresController = TextEditingController();
  final TextEditingController _maxAcresController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _minAcres = widget.initialMinAcres;
    _maxAcres = widget.initialMaxAcres;
    _selectedCounty = widget.initialSelectedCounty;
    _selectedBuiltUpArea = widget.initialSelectedBuiltUpArea;
    _selectedRegion = widget.initialSelectedRegion;
    _selectedLocalAuthorityDistrict =
        widget.initialSelectedLocalAuthorityDistrict;
    _selectedLandType = widget.initialSelectedLandType;
    _buaOnly = widget.initialBUAOnly; // Initialize BUA Only

    _minAcresController.text =
        _minAcres != null ? _minAcres.toString() : '';
    _maxAcresController.text =
        _maxAcres != null ? _maxAcres.toString() : '';
  }

  @override
  void dispose() {
    _minAcresController.dispose();
    _maxAcresController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    if (_minAcres != null &&
        _maxAcres != null &&
        _minAcres! > _maxAcres!) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Min Acres cannot be greater than Max Acres')),
      );
      return;
    }

    widget.onApply(
      minAcres: _minAcres,
      maxAcres: _maxAcres,
      selectedCounty: _selectedCounty,
      selectedBuiltUpArea: _selectedBuiltUpArea,
      selectedRegion: _selectedRegion,
      selectedLocalAuthorityDistrict: _selectedLocalAuthorityDistrict,
      selectedLandType: _selectedLandType,
      buaOnly: _buaOnly, // Pass BUA Only state
    );
  }

  void _clearFilters() {
    setState(() {
      _minAcres = null;
      _maxAcres = null;
      _selectedCounty = null;
      _selectedBuiltUpArea = null;
      _selectedRegion = null;
      _selectedLocalAuthorityDistrict = null;
      _selectedLandType = null;
      _buaOnly = false; // Reset BUA Only
      _minAcresController.text = '';
      _maxAcresController.text = '';
    });
    widget.onApply(
      minAcres: null,
      maxAcres: null,
      selectedCounty: null,
      selectedBuiltUpArea: null,
      selectedRegion: null,
      selectedLocalAuthorityDistrict: null,
      selectedLandType: null,
      buaOnly: false, // Reset BUA Only
    );
    Navigator.of(context).pop(); // Close the dialog
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set Filters'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // County Filter
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'County'),
              value: _selectedCounty,
              items: widget.countyOptions
                  .map((county) => DropdownMenuItem(
                        value: county,
                        child: Text(county),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCounty = value;
                });
              },
              isExpanded: true,
            ),
            const SizedBox(height: 10),
            // Built-Up Area Filter
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Built-Up Area'),
              value: _selectedBuiltUpArea,
              items: widget.builtUpAreaOptions
                  .map((bua) => DropdownMenuItem(
                        value: bua,
                        child: Text(bua),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedBuiltUpArea = value;
                });
              },
              isExpanded: true,
            ),
            const SizedBox(height: 10),
            // Region Filter
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Region'),
              value: _selectedRegion,
              items: widget.regionOptions
                  .map((region) => DropdownMenuItem(
                        value: region,
                        child: Text(region),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedRegion = value;
                });
              },
              isExpanded: true,
            ),
            const SizedBox(height: 10),
            // Local Authority District Filter
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                  labelText: 'Local Authority District'),
              value: _selectedLocalAuthorityDistrict,
              items: widget.localAuthorityDistrictOptions
                  .map((lad) => DropdownMenuItem(
                        value: lad,
                        child: Text(lad),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedLocalAuthorityDistrict = value;
                });
              },
              isExpanded: true,
            ),
            const SizedBox(height: 10),
            // Land Type Filter
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Land Type'),
              value: _selectedLandType,
              items: widget.landTypeOptions
                  .map((lt) => DropdownMenuItem(
                        value: lt,
                        child: Text(lt),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedLandType = value;
                });
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
              controller: _minAcresController,
              onChanged: (value) {
                setState(() {
                  _minAcres = double.tryParse(value);
                });
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
              controller: _maxAcresController,
              onChanged: (value) {
                setState(() {
                  _maxAcres = double.tryParse(value);
                });
              },
            ),
            const SizedBox(height: 10),
            // BUA Only Checkbox
            CheckboxListTile(
              title: const Text('BUA Only'),
              value: _buaOnly,
              onChanged: (bool? value) {
                setState(() {
                  _buaOnly = value ?? false;
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _applyFilters,
          child: const Text('Set Filters'),
        ),
        TextButton(
          onPressed: _clearFilters,
          child: const Text('Clear Filters'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(); // Close the dialog without applying
          },
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

// lib/widgets/dialogs/aldi_lidl_filter_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AldiLidlFilterDialog extends StatefulWidget {
  // Define the necessary parameters and callbacks
  final List<String> builtUpAreaOptions;
  final List<String> statusOptions;
  final double? initialMinAcres;
  final double? initialMaxAcres;
  final String? initialSelectedBUA;
  final String? initialSelectedStatus;
  final Function({
    double? minAcres,
    double? maxAcres,
    String? selectedBUA,
    String? selectedStatus,
  }) onApply;

  const AldiLidlFilterDialog({
    super.key,
    required this.builtUpAreaOptions,
    required this.statusOptions,
    this.initialMinAcres,
    this.initialMaxAcres,
    this.initialSelectedBUA,
    this.initialSelectedStatus,
    required this.onApply,
  });

  @override
  _AldiLidlFilterDialogState createState() => _AldiLidlFilterDialogState();
}

class _AldiLidlFilterDialogState extends State<AldiLidlFilterDialog> {
  double? _minAcres;
  double? _maxAcres;
  String? _selectedBUA;
  String? _selectedStatus;

  final TextEditingController _minAcresController = TextEditingController();
  final TextEditingController _maxAcresController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _minAcres = widget.initialMinAcres;
    _maxAcres = widget.initialMaxAcres;
    _selectedBUA = widget.initialSelectedBUA;
    _selectedStatus = widget.initialSelectedStatus;

    _minAcresController.text =
        _minAcres != null ? _minAcres!.toStringAsFixed(2) : '';
    _maxAcresController.text =
        _maxAcres != null ? _maxAcres!.toStringAsFixed(2) : '';
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
      selectedBUA: _selectedBUA,
      selectedStatus: _selectedStatus,
    );
  }

  void _clearFilters() {
    setState(() {
      _minAcres = null;
      _maxAcres = null;
      _selectedBUA = null;
      _selectedStatus = null;
      _minAcresController.text = '';
      _maxAcresController.text = '';
    });
    widget.onApply(
      minAcres: null,
      maxAcres: null,
      selectedBUA: null,
      selectedStatus: null,
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
            // Built-Up Area Filter with Autocomplete
            Autocomplete<String>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return const Iterable<String>.empty();
                }
                return widget.builtUpAreaOptions.where((String option) {
                  return option
                      .toLowerCase()
                      .contains(textEditingValue.text.toLowerCase());
                });
              },
              onSelected: (String selection) {
                setState(() {
                  _selectedBUA = selection;
                });
              },
              fieldViewBuilder:
                  (context, controller, focusNode, onEditingComplete) {
                controller.text = _selectedBUA ?? '';
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'Select BUA',
                    border: OutlineInputBorder(),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^[a-zA-Z0-9\s]*$')),
                  ],
                );
              },
            ),
            const SizedBox(height: 10),

            // Status Filter
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Status'),
              value: _selectedStatus,
              items: widget.statusOptions
                  .map((status) => DropdownMenuItem(
                        value: status,
                        child: Text(status),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedStatus = value;
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
                FilteringTextInputFormatter.allow(RegExp(r'^\d+(\.\d{0,2})?$')),
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
                FilteringTextInputFormatter.allow(RegExp(r'^\d+(\.\d{0,2})?$')),
              ],
              controller: _maxAcresController,
              onChanged: (value) {
                setState(() {
                  _maxAcres = double.tryParse(value);
                });
              },
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

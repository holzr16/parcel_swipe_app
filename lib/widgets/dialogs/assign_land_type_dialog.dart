// lib/widgets/dialogs/assign_land_type_dialog.dart

import 'package:flutter/material.dart';

class AssignLandTypeDialog extends StatefulWidget {
  // Define the necessary parameters and callbacks
  final List<String> landTypeOptions;
  final String currentLandType;
  final Function(String selectedLandType) onAssign;

  const AssignLandTypeDialog({
    super.key,
    required this.landTypeOptions,
    required this.currentLandType,
    required this.onAssign,
  });

  @override
  _AssignLandTypeDialogState createState() => _AssignLandTypeDialogState();
}

class _AssignLandTypeDialogState extends State<AssignLandTypeDialog> {
  String? _selectedLandType;

  @override
  void initState() {
    super.initState();
    _selectedLandType = widget.currentLandType;
  }

  void _assignLandType() {
    if (_selectedLandType != null) {
      widget.onAssign(_selectedLandType!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Assign Land Type'),
      content: DropdownButtonFormField<String>(
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
      actions: [
        TextButton(
          onPressed: _selectedLandType != null ? _assignLandType : null,
          child: const Text('Assign'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(); // Close dialog
          },
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

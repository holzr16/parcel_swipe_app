// lib/widgets/dialogs/aldi_lidl_assign_status_dialog.dart

import 'package:flutter/material.dart';

class AldiLidlAssignStatusDialog extends StatefulWidget {
  // Define the necessary parameters and callbacks
  final List<String> statusOptions;
  final String currentStatus;
  final Function(String selectedStatus) onAssign;

  const AldiLidlAssignStatusDialog({
    super.key,
    required this.statusOptions,
    required this.currentStatus,
    required this.onAssign,
  });

  @override
  _AldiLidlAssignStatusDialogState createState() =>
      _AldiLidlAssignStatusDialogState();
}

class _AldiLidlAssignStatusDialogState
    extends State<AldiLidlAssignStatusDialog> {
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.currentStatus;
  }

  void _assignStatus() {
    if (_selectedStatus != null) {
      widget.onAssign(_selectedStatus!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Assign Status'),
      content: DropdownButtonFormField<String>(
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
      actions: [
        TextButton(
          onPressed: _selectedStatus != null ? _assignStatus : null,
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

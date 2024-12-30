// lib/widgets/assignment_buttons.dart

import 'package:flutter/material.dart';
import 'custom_navigation_button.dart';

class AssignmentButtons extends StatelessWidget {
  final List<AssignmentButtonData> buttons;

  const AssignmentButtons({Key? key, required this.buttons}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      alignment: WrapAlignment.center,
      children: buttons.map((buttonData) {
        return CustomNavigationButton(
          label: buttonData.label,
          onPressed: buttonData.onPressed,
        );
      }).toList(),
    );
  }
}

class AssignmentButtonData {
  final String label;
  final VoidCallback onPressed;

  AssignmentButtonData({required this.label, required this.onPressed});
}

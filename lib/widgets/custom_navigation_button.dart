// lib/widgets/custom_navigation_button.dart

import 'package:flutter/material.dart';

class CustomNavigationButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const CustomNavigationButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

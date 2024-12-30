// lib/widgets/custom_navigation_button.dart
import 'package:flutter/material.dart';

class CustomNavigationButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const CustomNavigationButton({
    Key? key,
    required this.label,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      child: Text(label),
    );
  }
}

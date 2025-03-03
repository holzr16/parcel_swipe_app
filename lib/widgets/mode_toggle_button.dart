// lib/widgets/mode_toggle_button.dart

import 'package:flutter/material.dart';

class ModeToggleButton extends StatelessWidget {
  final bool isMapMode;
  final Function(bool) onToggle;

  const ModeToggleButton({
    Key? key,
    required this.isMapMode,
    required this.onToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 20,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                spreadRadius: 1,
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildModeButton(
                  context: context,
                  isSelected: !isMapMode,
                  label: 'Fast',
                  icon: Icons.bolt,
                  onPressed: () => onToggle(false),
                ),
                _buildModeButton(
                  context: context,
                  isSelected: isMapMode,
                  label: 'Map',
                  icon: Icons.map,
                  onPressed: () => onToggle(true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeButton({
    required BuildContext context,
    required bool isSelected,
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.black54,
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black54,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
// lib/widgets/custom_map_widget.dart

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class CustomMapWidget extends StatefulWidget {
  final void Function(MapboxMap) onMapCreated;
  final void Function(StyleLoadedEventData) onStyleLoadedListener;

  const CustomMapWidget({
    super.key,
    required this.onMapCreated,
    required this.onStyleLoadedListener,
  });

  @override
  State<CustomMapWidget> createState() => _CustomMapWidgetState();
}

class _CustomMapWidgetState extends State<CustomMapWidget> {
  @override
  Widget build(BuildContext context) {
    return MapWidget(
      styleUri: MapboxStyles.SATELLITE_STREETS,
      cameraOptions: CameraOptions(
        center: Point(coordinates: Position(-1.5, 53.1)),
        zoom: 5.0,
      ),
      onMapCreated: (MapboxMap map) {
        widget.onMapCreated(map);
      },
      onStyleLoadedListener: widget.onStyleLoadedListener,
      // Removed 'const' as MapWidget's constructor isn't const
    );
  }
}

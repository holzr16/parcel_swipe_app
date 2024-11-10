// main.dart

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'services/database_service.dart';
import 'screens/view_mode_screen.dart';
import 'screens/set_land_type_mode_screen.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Retrieve the access token from the environment
  const String accessToken =
      "pk.eyJ1IjoicGFyY2VsLXN3aXBlIiwiYSI6ImNtMWkzNWxlcjBwMzkycXMybDZyOXRubjkifQ.wYCDUei4VOUyjMnzI5BASQ";

  // Set the access token for Mapbox
  MapboxOptions.setAccessToken(accessToken);

  runApp(
    MultiProvider(
      providers: [
        Provider<DatabaseService>(create: (_) => DatabaseService()),
        Provider<Logger>(create: (_) => Logger()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parcel Swipe App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const ModeSelectionScreen(),
    );
  }
}

enum AppMode {
  view,
  setLandType,
}

class ModeSelectionScreen extends StatefulWidget {
  const ModeSelectionScreen({super.key});

  @override
  _ModeSelectionScreenState createState() => _ModeSelectionScreenState();
}

class _ModeSelectionScreenState extends State<ModeSelectionScreen> {
  AppMode _currentMode = AppMode.view;

  void _switchMode(AppMode mode) {
    setState(() {
      _currentMode = mode;
    });
    _showModeChangeSnackbar(mode);
  }

  void _showModeChangeSnackbar(AppMode mode) {
    String modeName = mode == AppMode.view ? 'View Mode' : 'Set Land Type Mode';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Switched to $modeName')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final logger = Provider.of<Logger>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parcel Swipe App'),
        actions: [
          PopupMenuButton<AppMode>(
            onSelected: _switchMode,
            itemBuilder: (BuildContext context) => <PopupMenuEntry<AppMode>>[
              const PopupMenuItem<AppMode>(
                value: AppMode.view,
                child: Text('View Mode'),
              ),
              const PopupMenuItem<AppMode>(
                value: AppMode.setLandType,
                child: Text('Set Land Type Mode'),
              ),
            ],
          ),
        ],
      ),
      body: _currentMode == AppMode.view
          ? ViewModeScreen(dbService: dbService, logger: logger)
          : SetLandTypeModeScreen(dbService: dbService, logger: logger),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentMode == AppMode.view ? 0 : 1,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.visibility),
            label: 'View',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.edit),
            label: 'Set Land Type',
          ),
        ],
        onTap: (index) {
          if (index == 0) {
            _switchMode(AppMode.view);
          } else if (index == 1) {
            _switchMode(AppMode.setLandType);
          }
        },
      ),
    );
  }
}

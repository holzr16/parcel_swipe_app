// lib/main.dart

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'services/database_service.dart';
import 'screens/view_mode_screen.dart';
import 'screens/set_land_type_mode_screen.dart';
import 'screens/lidl_aldi_finder_screen.dart'; // Import the new screen
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
  lidlAldiFinder, // New mode
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
    String modeName;
    switch (mode) {
      case AppMode.view:
        modeName = 'View Mode';
        break;
      case AppMode.setLandType:
        modeName = 'Set Land Type Mode';
        break;
      case AppMode.lidlAldiFinder:
        modeName = 'Lidl/Aldi Site Finder';
        break;
    }
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
              const PopupMenuItem<AppMode>(
                value: AppMode.lidlAldiFinder,
                child: Text('Lidl/Aldi Site Finder'),
              ),
            ],
          ),
        ],
      ),
      body: _currentMode == AppMode.view
          ? ViewModeScreen(dbService: dbService, logger: logger)
          : _currentMode == AppMode.setLandType
              ? SetLandTypeModeScreen(dbService: dbService, logger: logger)
              : LidlAldiFinderScreen(dbService: dbService, logger: logger), // New screen
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentMode.index,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.visibility),
            label: 'View',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.edit),
            label: 'Set Land Type',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.store),
            label: 'Lidl/Aldi Finder',
          ),
        ],
        onTap: (index) {
          AppMode selectedMode;
          switch (index) {
            case 0:
              selectedMode = AppMode.view;
              break;
            case 1:
              selectedMode = AppMode.setLandType;
              break;
            case 2:
              selectedMode = AppMode.lidlAldiFinder;
              break;
            default:
              selectedMode = AppMode.view;
          }
          _switchMode(selectedMode);
        },
      ),
    );
  }
}

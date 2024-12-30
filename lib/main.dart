// lib/main.dart

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:overlay_support/overlay_support.dart';
import 'services/database_service.dart';
import 'screens/parcel_screen.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Retrieve the access token from the environment
  const String accessToken =
      "pk.eyJ1IjoicGFyY2VsLXN3aXBlIiwiYSI6ImNtMWkzNWxlcjBwMzkycXMybDZyOXRubjkifQ.wYCDUei4VOUyjMnzI5BASQ";

  // Set the access token for Mapbox
  MapboxOptions.setAccessToken(accessToken);

  // Initialize Logger
  final logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.none,
    ),
  );

  // Initialize DatabaseService and connect
  final dbService = DatabaseService();
  try {
    await dbService.connect();
    logger.d('Connected to the database successfully.');
  } catch (e) {
    logger.e('Database connection failed: $e');
    // Handle connection failure if necessary
  }

  runApp(
    OverlaySupport.global( // Wrap with OverlaySupport.global for notifications
      child: MultiProvider(
        providers: [
          Provider<DatabaseService>.value(value: dbService),
          Provider<Logger>.value(value: logger),
        ],
        child: const MyApp(),
      ),
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
      home: ParcelScreen(
        dbService: Provider.of<DatabaseService>(context, listen: false),
        logger: Provider.of<Logger>(context, listen: false),
      ), // Set ParcelScreen as the home screen
    );
  }
}

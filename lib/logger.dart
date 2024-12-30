// lib/logger.dart
import 'package:logger/logger.dart';

final Logger logger = Logger(
  printer: PrettyPrinter(
    methodCount: 0, // No method calls in log messages
    printEmojis: true, // Use emojis for log levels
    dateTimeFormat: DateTimeFormat.none, // Replaced deprecated printTime
  ),
);

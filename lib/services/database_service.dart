// lib/services/database_service.dart

import 'dart:convert';
import 'package:postgres/postgres.dart';
import 'package:logger/logger.dart';
import '../models/parcel_mode.dart';
import '../logger.dart';


class DatabaseService {
  // Singleton instance
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;

  late Connection _connection;
  final Logger logger = Logger();

  // Define allowed land types for validation
  final List<String> allowedLandTypes = [
    'NA',
    'Unsure',
    'Vacant Land',
    'Developed',
    'Unseen',
  ];

  // Define allowed land sub-types for validation
  final List<String> allowedLandSubTypes = [
    'Brownfield',
    'Greenfield',
    'NA',
    'Unsure',
    'Unseen',
  ];

  // Define allowed view statuses for validation
  final List<String> allowedViewStatuses = [
    'Saved',
    'Dismissed',
    'Unseen',
  ];

  DatabaseService._internal();

  /// Establishes a connection to the PostgreSQL database.
  Future<void> connect() async {
    final endpoint = Endpoint(
      host: '192.168.1.252',
      port: 5432,
      database: 'spatial_database',
      username: 'postgres',
      password: 'RAzza779!!',
    );

    final settings = ConnectionSettings(
          sslMode: SslMode.disable, // Disable SSL as the server does not support it
        );

    try {
      logger.i('Attempting to connect to PostgreSQL...');
      _connection = await Connection.open(
        endpoint,
        settings: settings, // Pass ConnectionSettings here
      );
      logger.i('Connected to PostgreSQL');
    } catch (e) {
      logger.e('Failed to connect to PostgreSQL: $e');
      rethrow; // Re-throw the exception for the caller to handle
    }
  }

  /// Closes the current connection.
  Future<void> close() async {
    try {
      await _connection.close();
      logger.i('PostgreSQL connection closed');
    } catch (e) {
      logger.e('Error closing PostgreSQL connection: $e');
      rethrow;
    }
  }

  /// Fetches parcels with pagination and filters.
  Future<List<Map<String, dynamic>>> fetchParcels({
    required int pageNumber,
    required int pageSize,
    String? countyName,
    String? builtUpAreaName,
    String? regionName,
    String? localAuthorityDistrictName,
    double? minAcres,
    double? maxAcres,
    String? viewStatus,
    String? landType,
    String? subType,
    bool buaOnly = false,
  }) async {
    final offset = pageNumber * pageSize;

    String query = '''
      SELECT 
          p.inspireid,
          ST_AsGeoJSON(p.geom) AS geom,
          p.fid,
          p.acres,
          p.gml_id,
          bua.bua_name,
          county.county_name,
          lad.lad_name,
          region.region_name,
          vs.view_status,
          lt.land_type,
          pst.sub_type
      FROM 
          "aug_parcels_output - combined_filtered" p
      LEFT JOIN bua_lookup bua ON p.inspireid = bua.inspireid
      LEFT JOIN county_lookup county ON p.inspireid = county.inspireid
      LEFT JOIN lad_lookup lad ON p.inspireid = lad.inspireid
      LEFT JOIN region_lookup region ON p.inspireid = region.inspireid
      LEFT JOIN parcel_view_status vs ON p.inspireid = vs.inspireid
      LEFT JOIN parcel_land_type lt ON p.inspireid = lt.inspireid
      LEFT JOIN parcel_sub_type pst ON p.inspireid = pst.inspireid
    ''';

    List<String> whereClauses = [];
    Map<String, dynamic> substitutionValues = {
      'limit': pageSize,
      'offset': offset,
    };

    if (countyName != null && countyName.isNotEmpty) {
      whereClauses.add('county.county_name = @countyName');
      substitutionValues['countyName'] = countyName;
    }
    if (builtUpAreaName != null && builtUpAreaName.isNotEmpty) {
      whereClauses.add('bua.bua_name = @builtUpAreaName');
      substitutionValues['builtUpAreaName'] = builtUpAreaName;
    }
    if (regionName != null && regionName.isNotEmpty) {
      whereClauses.add('region.region_name = @regionName');
      substitutionValues['regionName'] = regionName;
    }
    if (localAuthorityDistrictName != null && localAuthorityDistrictName.isNotEmpty) {
      whereClauses.add('lad.lad_name = @localAuthorityDistrictName');
      substitutionValues['localAuthorityDistrictName'] = localAuthorityDistrictName;
    }
    if (minAcres != null) {
      whereClauses.add('p.acres >= @minAcres');
      substitutionValues['minAcres'] = minAcres;
    }
    if (maxAcres != null) {
      whereClauses.add('p.acres <= @maxAcres');
      substitutionValues['maxAcres'] = maxAcres;
    }
    if (viewStatus != null && viewStatus.isNotEmpty) {
      if (viewStatus == 'Unseen') {
        whereClauses.add('vs.view_status IS NULL');
      } else {
        whereClauses.add('vs.view_status = @viewStatus');
        substitutionValues['viewStatus'] = viewStatus;
      }
    }
    if (landType != null && landType.isNotEmpty) {
      if (landType == 'Unseen') {
        whereClauses.add('lt.land_type IS NULL');
      } else {
        whereClauses.add('lt.land_type = @landType');
        substitutionValues['landType'] = landType;
      }
    }
    if (subType != null && subType.isNotEmpty) {
      if (subType == 'Unseen') {
        whereClauses.add('pst.sub_type IS NULL');
      } else {
        whereClauses.add('pst.sub_type = @subType');
        substitutionValues['subType'] = subType;
      }
    }
    if (buaOnly) {
      whereClauses.add('bua.bua_name IS NOT NULL');
    }

    if (whereClauses.isNotEmpty) {
      query += ' WHERE ${whereClauses.join(' AND ')}';
    }

    query += ' ORDER BY p.fid ASC LIMIT @limit OFFSET @offset;';

    try {
      List<List<dynamic>> result = await _connection.execute(
        Sql.named(query),
        parameters: substitutionValues,
      );

      // Convert Result to List<Map<String, dynamic>>
      List<Map<String, dynamic>> parcels = [];
      for (var row in result) {
        parcels.add({
          'inspireid': row[0],
          'geom': row[1],
          'fid': row[2],
          'acres': row[3],
          'gml_id': row[4],
          'bua_name': row[5],
          'county_name': row[6],
          'lad_name': row[7],
          'region_name': row[8],
          'view_status': row[9] ?? 'Unseen',
          'land_type': row[10] ?? 'Unseen',
          'sub_type': row[11] ?? 'Unseen',
        });
      }
      return parcels;
    } catch (e) {
      logger.e('Error fetching parcels: $e');
      return [];
    }
  }

  /// Retrieves the total number of parcels with optional filtering.
  Future<int> getTotalParcels({
    String? countyName,
    String? builtUpAreaName,
    String? regionName,
    String? localAuthorityDistrictName,
    double? minAcres,
    double? maxAcres,
    String? viewStatus,
    String? landType,
    String? subType,
    bool buaOnly = false,
  }) async {
    String query = '''
      SELECT COUNT(*) 
      FROM "aug_parcels_output - combined_filtered" p
      LEFT JOIN bua_lookup bua ON p.inspireid = bua.inspireid
      LEFT JOIN county_lookup county ON p.inspireid = county.inspireid
      LEFT JOIN lad_lookup lad ON p.inspireid = lad.inspireid
      LEFT JOIN region_lookup region ON p.inspireid = region.inspireid
      LEFT JOIN parcel_view_status vs ON p.inspireid = vs.inspireid
      LEFT JOIN parcel_land_type lt ON p.inspireid = lt.inspireid
      LEFT JOIN parcel_sub_type pst ON p.inspireid = pst.inspireid
    ''';

    List<String> whereClauses = [];
    Map<String, dynamic> substitutionValues = {};

    if (countyName != null && countyName.isNotEmpty) {
      whereClauses.add('county.county_name = @countyName');
      substitutionValues['countyName'] = countyName;
    }
    if (builtUpAreaName != null && builtUpAreaName.isNotEmpty) {
      whereClauses.add('bua.bua_name = @builtUpAreaName');
      substitutionValues['builtUpAreaName'] = builtUpAreaName;
    }
    if (regionName != null && regionName.isNotEmpty) {
      whereClauses.add('region.region_name = @regionName');
      substitutionValues['regionName'] = regionName;
    }
    if (localAuthorityDistrictName != null && localAuthorityDistrictName.isNotEmpty) {
      whereClauses.add('lad.lad_name = @localAuthorityDistrictName');
      substitutionValues['localAuthorityDistrictName'] = localAuthorityDistrictName;
    }
    if (minAcres != null) {
      whereClauses.add('p.acres >= @minAcres');
      substitutionValues['minAcres'] = minAcres;
    }
    if (maxAcres != null) {
      whereClauses.add('p.acres <= @maxAcres');
      substitutionValues['maxAcres'] = maxAcres;
    }
    if (viewStatus != null && viewStatus.isNotEmpty) {
      if (viewStatus == 'Unseen') {
        whereClauses.add('vs.view_status IS NULL');
      } else {
        whereClauses.add('vs.view_status = @viewStatus');
        substitutionValues['viewStatus'] = viewStatus;
      }
    }
    if (landType != null && landType.isNotEmpty) {
      if (landType == 'Unseen') {
        whereClauses.add('lt.land_type IS NULL');
      } else {
        whereClauses.add('lt.land_type = @landType');
        substitutionValues['landType'] = landType;
      }
    }
    if (subType != null && subType.isNotEmpty) {
      if (subType == 'Unseen') {
        whereClauses.add('pst.sub_type IS NULL');
      } else {
        whereClauses.add('pst.sub_type = @subType');
        substitutionValues['subType'] = subType;
      }
    }
    if (buaOnly) {
      whereClauses.add('bua.bua_name IS NOT NULL');
    }

    if (whereClauses.isNotEmpty) {
      query += ' WHERE ${whereClauses.join(' AND ')}';
    }

    try {
      List<List<dynamic>> result = await _connection.execute(
        Sql.named(query),
        parameters: substitutionValues,
      );

      if (result.isNotEmpty) {
        return result[0][0] as int;
      } else {
        return 0;
      }
    } catch (e) {
      logger.e('Error fetching total parcels count: $e');
      return 0;
    }
  }

  /// Fetches distinct county names for filter options.
  Future<List<String>> fetchDistinctCounties() async {
    String query = '''
      SELECT DISTINCT county_name
      FROM county_lookup
      WHERE county_name IS NOT NULL
      ORDER BY county_name ASC
    ''';

    try {
      List<List<dynamic>> result = await _connection.execute(
        Sql.named(query),
      );
      return result
          .map((row) => row[0] as String)
          .where((name) => name.isNotEmpty)
          .toList();
    } catch (e) {
      logger.e('Error fetching distinct counties: $e');
      return [];
    }
  }

  /// Fetches distinct built-up area names for filter options.
  Future<List<String>> fetchDistinctBuiltUpAreas() async {
    String query = '''
      SELECT DISTINCT bua_name
      FROM bua_lookup
      WHERE bua_name IS NOT NULL
      ORDER BY bua_name ASC
    ''';

    try {
      List<List<dynamic>> result = await _connection.execute(
        Sql.named(query),
      );
      return result
          .map((row) => row[0] as String)
          .where((name) => name.isNotEmpty)
          .toList();
    } catch (e) {
      logger.e('Error fetching distinct built-up areas: $e');
      return [];
    }
  }

  /// Fetches distinct region names for filter options.
  Future<List<String>> fetchDistinctRegions() async {
    String query = '''
      SELECT DISTINCT region_name
      FROM region_lookup
      WHERE region_name IS NOT NULL
      ORDER BY region_name ASC
    ''';

    try {
      List<List<dynamic>> result = await _connection.execute(
        Sql.named(query),
      );
      return result
          .map((row) => row[0] as String)
          .where((name) => name.isNotEmpty)
          .toList();
    } catch (e) {
      logger.e('Error fetching distinct regions: $e');
      return [];
    }
  }

  /// Fetches distinct local authority district names for filter options.
  Future<List<String>> fetchDistinctLocalAuthorityDistricts() async {
    String query = '''
      SELECT DISTINCT lad_name
      FROM lad_lookup
      WHERE lad_name IS NOT NULL
      ORDER BY lad_name ASC
    ''';

    try {
      List<List<dynamic>> result = await _connection.execute(
        Sql.named(query),
      );
      return result
          .map((row) => row[0] as String)
          .where((name) => name.isNotEmpty)
          .toList();
    } catch (e) {
      logger.e('Error fetching distinct local authority districts: $e');
      return [];
    }
  }

  /// Fetches distinct land types for filter options.
  Future<List<String>> fetchDistinctLandTypes() async {
    String query = '''
      SELECT DISTINCT land_type
      FROM parcel_land_type
      WHERE land_type IS NOT NULL
      ORDER BY land_type ASC
    ''';

    try {
      List<List<dynamic>> result = await _connection.execute(
        Sql.named(query),
      );
      return result
          .map((row) => row[0] as String)
          .where((type) => type.isNotEmpty)
          .toList();
    } catch (e) {
      logger.e('Error fetching distinct land types: $e');
      return [];
    }
  }

  /// Fetches distinct sub-types for filter options.
  Future<List<String>> fetchDistinctSubTypes() async {
    String query = '''
      SELECT DISTINCT sub_type
      FROM parcel_sub_type
      WHERE sub_type IS NOT NULL
      ORDER BY sub_type ASC
    ''';

    try {
      List<List<dynamic>> result = await _connection.execute(
        Sql.named(query),
      );
      return result
          .map((row) => row[0] as String)
          .where((type) => type.isNotEmpty)
          .toList();
    } catch (e) {
      logger.e('Error fetching distinct sub-types: $e');
      return [];
    }
  }

  /// Assigns a view status to a parcel.
  Future<void> assignViewStatus(String inspireid, String status) async {
    if (!_isValidViewStatus(status)) {
      logger.e('Invalid view status attempted to assign: $status');
      throw Exception('Invalid view status: $status');
    }

    String query = '''
      INSERT INTO parcel_view_status (inspireid, view_status, assigned_at)
      VALUES (@inspireid, @viewStatus, CURRENT_TIMESTAMP)
      ON CONFLICT (inspireid) 
      DO UPDATE SET view_status = @viewStatus,
                    assigned_at = CURRENT_TIMESTAMP;
    ''';

    try {
      await _connection.execute(
        Sql.named(query),
        parameters: {
          'inspireid': inspireid,
          'viewStatus': status,
        },
      );
      logger.i('Assigned view status "$status" to parcel "$inspireid".');
    } catch (e) {
      logger.e('Error assigning view status: $e');
      rethrow;
    }
  }

  /// Assigns a land type to a parcel with validation.
  Future<void> assignLandType(String inspireid, String landType) async {
    if (!_isValidLandType(landType)) {
      logger.e('Invalid land type attempted to assign: $landType');
      throw Exception('Invalid land type: $landType');
    }

    String query = '''
      INSERT INTO parcel_land_type (inspireid, land_type, assigned_at)
      VALUES (@inspireid, @landType, CURRENT_TIMESTAMP)
      ON CONFLICT (inspireid) 
      DO UPDATE SET land_type = @landType,
                    assigned_at = CURRENT_TIMESTAMP;
    ''';

    try {
      await _connection.execute(
        Sql.named(query),
        parameters: {
          'inspireid': inspireid,
          'landType': landType,
        },
      );
      logger.i('Assigned land type "$landType" to parcel "$inspireid".');
    } catch (e) {
      logger.e('Error assigning land type: $e');
      rethrow;
    }
  }

  /// Assigns a sub-type to a parcel with validation.
  Future<void> assignSubType(String inspireid, String subType) async {
    if (!_isValidLandSubType(subType)) {
      logger.e('Invalid sub-type attempted to assign: $subType');
      throw Exception('Invalid sub-type: $subType');
    }

    String query = '''
      INSERT INTO parcel_sub_type (inspireid, sub_type, assigned_at)
      VALUES (@inspireid, @subType, CURRENT_TIMESTAMP)
      ON CONFLICT (inspireid) 
      DO UPDATE SET sub_type = @subType,
                    assigned_at = CURRENT_TIMESTAMP;
    ''';

    try {
      await _connection.execute(
        Sql.named(query),
        parameters: {
          'inspireid': inspireid,
          'subType': subType,
        },
      );
      logger.i('Assigned sub-type "$subType" to parcel "$inspireid".');
    } catch (e) {
      logger.e('Error assigning sub-type: $e');
      rethrow;
    }
  }

  /// Validates if the provided land type is allowed.
  bool _isValidLandType(String landType) {
    return allowedLandTypes.contains(landType);
  }

  /// Validates if the provided land sub-type is allowed.
  bool _isValidLandSubType(String subType) {
    return allowedLandSubTypes.contains(subType);
  }

  /// Validates if the provided view status is allowed.
  bool _isValidViewStatus(String status) {
    return allowedViewStatuses.contains(status);
  }
}

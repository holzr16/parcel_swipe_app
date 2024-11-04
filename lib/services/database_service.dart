import 'package:postgres/postgres.dart';
import 'package:logger/logger.dart';

class DatabaseService {
  // Singleton instance
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;

  late Connection _connection;
  final Logger logger = Logger();

  DatabaseService._internal();

  /// Establishes a connection to the PostgreSQL database.
  Future<void> connect() async {
    final endpoint = Endpoint(
      host: '192.168.1.252',
      port: 5432,
      database: 'spatial_database',
      username: 'postgres',
      password: 'RAzza779!!',
      // No sslMode here
    );

    final settings = ConnectionSettings(
      sslMode: SslMode.disable, // Disable SSL
      // You can add other settings here if needed
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

  /// Returns the current connection.
  Connection get connection => _connection;

  /// Closes the current connection.
  Future<void> close() async {
    try {
      await _connection.close();
      logger.i('PostgreSQL connection closed');
    } catch (e) {
      logger.e('Error closing PostgreSQL connection: $e');
    }
  }

  /// Fetches parcels with optional filtering and pagination.
  Future<List<Map<String, dynamic>>> fetchParcels({
    required int pageNumber,
    required int pageSize,
    String? countyName,
    String? builtUpAreaName,
    String? regionName,
    String? localAuthorityDistrictName,
    double? minAcres,
    double? maxAcres,
  }) async {
    final offset = pageNumber * pageSize;

    String query = '''
      SELECT 
          parcels.inspireid,
          ST_AsGeoJSON(parcels.geom) AS geom,
          parcels.fid,
          parcels.acres,
          parcels.gml_id,
          bua.built_up_area_name,
          county.county_name,
          lad.local_authority_district_name,
          region.region_name
      FROM 
          "Final_Merged_parcels" parcels
      LEFT JOIN bua ON parcels.inspireid = bua.inspire_id
      LEFT JOIN county ON parcels.inspireid = county.inspire_id
      LEFT JOIN lad ON parcels.inspireid = lad.inspire_id
      LEFT JOIN region ON parcels.inspireid = region.inspire_id
    ''';

    List<String> whereClauses = [];
    Map<String, Object?> substitutionValues = {
      'limit': pageSize, // int
      'offset': offset,  // int
    };

    if (countyName != null && countyName.isNotEmpty) {
      whereClauses.add('county.county_name = @countyName');
      substitutionValues['countyName'] = countyName; // String
    }
    if (builtUpAreaName != null && builtUpAreaName.isNotEmpty) {
      whereClauses.add('bua.built_up_area_name = @builtUpAreaName');
      substitutionValues['builtUpAreaName'] = builtUpAreaName; // String
    }
    if (regionName != null && regionName.isNotEmpty) {
      whereClauses.add('region.region_name = @regionName');
      substitutionValues['regionName'] = regionName; // String
    }
    if (localAuthorityDistrictName != null && localAuthorityDistrictName.isNotEmpty) {
      whereClauses.add('lad.local_authority_district_name = @localAuthorityDistrictName');
      substitutionValues['localAuthorityDistrictName'] = localAuthorityDistrictName; // String
    }
    if (minAcres != null) {
      whereClauses.add('parcels.acres >= @minAcres');
      substitutionValues['minAcres'] = minAcres; // double
    }
    if (maxAcres != null) {
      whereClauses.add('parcels.acres <= @maxAcres');
      substitutionValues['maxAcres'] = maxAcres; // double
    }

    if (whereClauses.isNotEmpty) {
      query += ' WHERE ${whereClauses.join(' AND ')}';
    }

    query += ' ORDER BY parcels.fid ASC LIMIT @limit OFFSET @offset;';

    try {
      final result = await _connection.execute(
        Sql.named(query),
        parameters: substitutionValues,
      );

      // Convert each ResultRow to a Map<String, dynamic>
      return result.map((row) => row.toColumnMap()).toList();
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
  }) async {
    String query = '''
      SELECT COUNT(*) 
      FROM "Final_Merged_parcels" parcels
      LEFT JOIN bua ON parcels.inspireid = bua.inspire_id
      LEFT JOIN county ON parcels.inspireid = county.inspire_id
      LEFT JOIN lad ON parcels.inspireid = lad.inspire_id
      LEFT JOIN region ON parcels.inspireid = region.inspire_id
    ''';

    List<String> whereClauses = [];
    Map<String, Object?> substitutionValues = {};

    if (countyName != null && countyName.isNotEmpty) {
      whereClauses.add('county.county_name = @countyName');
      substitutionValues['countyName'] = countyName; // String
    }
    if (builtUpAreaName != null && builtUpAreaName.isNotEmpty) {
      whereClauses.add('bua.built_up_area_name = @builtUpAreaName');
      substitutionValues['builtUpAreaName'] = builtUpAreaName; // String
    }
    if (regionName != null && regionName.isNotEmpty) {
      whereClauses.add('region.region_name = @regionName');
      substitutionValues['regionName'] = regionName; // String
    }
    if (localAuthorityDistrictName != null && localAuthorityDistrictName.isNotEmpty) {
      whereClauses.add('lad.local_authority_district_name = @localAuthorityDistrictName');
      substitutionValues['localAuthorityDistrictName'] = localAuthorityDistrictName; // String
    }
    if (minAcres != null) {
      whereClauses.add('parcels.acres >= @minAcres');
      substitutionValues['minAcres'] = minAcres; // double
    }
    if (maxAcres != null) {
      whereClauses.add('parcels.acres <= @maxAcres');
      substitutionValues['maxAcres'] = maxAcres; // double
    }

    if (whereClauses.isNotEmpty) {
      query += ' WHERE ${whereClauses.join(' AND ')}';
    }

    try {
      final result = await _connection.execute(
        Sql.named(query),
        parameters: substitutionValues,
      );

      // PostgreSQL COUNT(*) returns a single row with a single column
      if (result.isNotEmpty && result.first.isNotEmpty) {
        final countValue = result.first[0];
        if (countValue is int) {
          return countValue;
        } else if (countValue is String) {
          return int.parse(countValue);
        } else {
          throw FormatException('Unexpected type for COUNT(*) result: ${countValue.runtimeType}');
        }
      } else {
        return 0;
      }
    } catch (e) {
      logger.e('Error fetching total parcels count: $e');
      return 0;
    }
  }

  /// Fetches distinct county names, excluding nulls.
  Future<List<String>> fetchDistinctCounties() async {
    String query = '''
      SELECT DISTINCT county_name
      FROM county
      WHERE county_name IS NOT NULL
      ORDER BY county_name ASC
    ''';

    try {
      final result = await _connection.execute(
        Sql.named(query),
      );

      // Log the raw result for debugging (optional)
      logger.d('fetchDistinctCounties result: $result');

      return result
          .map((row) {
            final countyName = row.toColumnMap()['county_name'];
            if (countyName == null) {
              logger.w('Encountered null county_name in row: $row');
              return null;
            }
            return countyName as String;
          })
          .where((name) => name != null) // Filter out nulls just in case
          .cast<String>() // Cast the iterable to List<String>
          .toList();
    } catch (e) {
      logger.e('Error fetching distinct counties: $e');
      return [];
    }
  }

  /// Fetches distinct built-up area names, excluding nulls.
  Future<List<String>> fetchDistinctBuiltUpAreas() async {
    String query = '''
      SELECT DISTINCT built_up_area_name
      FROM bua
      WHERE built_up_area_name IS NOT NULL
      ORDER BY built_up_area_name ASC
    ''';

    try {
      final result = await _connection.execute(
        Sql.named(query),
      );

      // Log the raw result for debugging (optional)
      logger.d('fetchDistinctBuiltUpAreas result: $result');

      return result
          .map((row) {
            final builtUpAreaName = row.toColumnMap()['built_up_area_name'];
            if (builtUpAreaName == null) {
              logger.w('Encountered null built_up_area_name in row: $row');
              return null;
            }
            return builtUpAreaName as String;
          })
          .where((name) => name != null) // Filter out nulls just in case
          .cast<String>() // Cast the iterable to List<String>
          .toList();
    } catch (e) {
      logger.e('Error fetching distinct built-up areas: $e');
      return [];
    }
  }

  /// Fetches distinct region names, excluding nulls.
  Future<List<String>> fetchDistinctRegions() async {
    String query = '''
      SELECT DISTINCT region_name
      FROM region
      WHERE region_name IS NOT NULL
      ORDER BY region_name ASC
    ''';

    try {
      final result = await _connection.execute(
        Sql.named(query),
      );

      // Log the raw result for debugging (optional)
      logger.d('fetchDistinctRegions result: $result');

      return result
          .map((row) {
            final regionName = row.toColumnMap()['region_name'];
            if (regionName == null) {
              logger.w('Encountered null region_name in row: $row');
              return null;
            }
            return regionName as String;
          })
          .where((name) => name != null) // Filter out nulls just in case
          .cast<String>() // Cast the iterable to List<String>
          .toList();
    } catch (e) {
      logger.e('Error fetching distinct regions: $e');
      return [];
    }
  }

  /// Fetches distinct local authority district names, excluding nulls.
  Future<List<String>> fetchDistinctLocalAuthorityDistricts() async {
    String query = '''
      SELECT DISTINCT local_authority_district_name
      FROM lad
      WHERE local_authority_district_name IS NOT NULL
      ORDER BY local_authority_district_name ASC
    ''';

    try {
      final result = await _connection.execute(
        Sql.named(query),
      );

      // Log the raw result for debugging (optional)
      logger.d('fetchDistinctLocalAuthorityDistricts result: $result');

      return result
          .map((row) {
            final ladName = row.toColumnMap()['local_authority_district_name'];
            if (ladName == null) {
              logger.w('Encountered null local_authority_district_name in row: $row');
              return null;
            }
            return ladName as String;
          })
          .where((name) => name != null) // Filter out nulls just in case
          .cast<String>() // Cast the iterable to List<String>
          .toList();
    } catch (e) {
      logger.e('Error fetching distinct local authority districts: $e');
      return [];
    }
  }
}
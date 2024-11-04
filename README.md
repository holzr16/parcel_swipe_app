Overview
The Parcel Swipe App is a Flutter-based mobile application designed to visualize and navigate through parcel data on a Mapbox map. Users can apply various filters to narrow down parcels based on attributes like county, region, and acreage. The app fetches spatial data from a PostgreSQL database and displays it interactively, allowing developers to understand its structure and functionality.

File Structure
lib/main.dart: The main application file that sets up the UI, map integration, and handles user interactions.
lib/services/database_service.dart: Manages database connections and executes queries to fetch and filter parcel data.
lib/main.dart
Imports
Flutter & Dart Libraries: Core libraries for building the UI and handling data.
Third-Party Packages:
mapbox_maps_flutter: Integrates Mapbox maps.
logger: Provides logging capabilities.
Custom Services:
DatabaseService for database interactions.
main Function
Initializes the Flutter widgets binding, sets the Mapbox access token, and runs the root widget MyApp.

dart
Copy code
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  String accessToken = "YOUR_MAPBOX_ACCESS_TOKEN";
  MapboxOptions.setAccessToken(accessToken);
  runApp(const MyApp());
}
MyApp Widget
A StatelessWidget that sets up the MaterialApp with a title, theme, and home screen (MyHomePage).

dart
Copy code
class MyApp extends StatelessWidget {
  // Widget setup
}
MyHomePage Widget
A StatefulWidget that manages the main functionality, including map display, data fetching, filtering, and navigation between parcels.

State Variables
Map & Data Management:
_mapboxMap: Instance of the Mapbox map.
_features, _filteredFeatures: Lists holding parcel data.
_geoJsonData: GeoJSON representation of parcels.
Filtering Parameters: _minAcres, _maxAcres, _selectedCounty, etc.
Pagination: _currentIndex, _pageNumber, _pageSize.
UI State: _isLoading, _totalParcels.
Services: _dbService (DatabaseService), _logger (Logger).
Filter Options: Lists for dropdown selections.
Initialization (initState)
Connects to the database and fetches distinct filter options.

dart
Copy code
@override
void initState() {
  super.initState();
  _initializeDatabaseAndFilters();
}
Database and Filter Initialization
_initializeDatabaseAndFilters: Connects to PostgreSQL and retrieves filter options.
_fetchFilterOptions: Retrieves distinct values for filters from the database.
Data Fetching and Filtering
_applyFiltersAndRefresh: Resets data and fetches parcels based on selected filters.
_fetchParcels: Retrieves parcel data and total count from the database, updates GeoJSON data, and adds it to the map.
_loadGeoJsonData: Converts fetched parcel data into GeoJSON format.
Map Integration
_onMapCreated: Initializes the map with a satellite streets style.
_onStyleLoaded: Adds GeoJSON layers once the map style is loaded.
_addGeoJsonLayer: Adds or updates the GeoJSON source and fill layer on the map.
_updatePolygon: Highlights the current parcel polygon and adjusts the camera view.
User Interface
AppBar: Displays the app title.
Body:
Parcel Count: Shows the total number of parcels.
MapWidget: Renders the Mapbox map.
Control Buttons: "Back", "Next", and "Filter" buttons for navigation and filtering.
Loading Indicator: Displays a spinner when data is loading.
Filtering Dialog
_openFilterDialog: Opens a dialog allowing users to set filter criteria using dropdowns and text fields.
Navigation
_previousPolygon & _nextPolygon: Navigate between parcels, updating the highlighted polygon on the map.
Resource Management
dispose: Closes the database connection when the widget is disposed.
lib/services/database_service.dart
Imports
postgres: PostgreSQL database connector.
logger: Logging utility.
DatabaseService Class
A singleton class that manages database connections and executes queries to fetch parcel data.

Singleton Implementation
Ensures only one instance of DatabaseService exists throughout the app.

dart
Copy code
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();

  factory DatabaseService() => _instance;

  DatabaseService._internal();
}
Connection Management
connect: Establishes a connection to the PostgreSQL database with specified settings.
close: Closes the active database connection.
Data Fetching Methods
fetchParcels

Retrieves parcel data with optional filtering and pagination.

Parameters:

pageNumber, pageSize: For pagination.
Filter criteria: countyName, builtUpAreaName, etc.
Functionality:

Constructs a SQL query with WHERE clauses based on filters. Executes the query and returns a list of parcel maps.

getTotalParcels

Gets the total count of parcels matching the current filters.

Parameters: Same as fetchParcels.

Functionality:

Executes a COUNT(*) SQL query with applied filters. Returns the total count as an integer.

Fetching Distinct Filter Options

fetchDistinctCounties: Retrieves unique county names.
fetchDistinctBuiltUpAreas: Retrieves unique built-up area names.
fetchDistinctRegions: Retrieves unique region names.
fetchDistinctLocalAuthorityDistricts: Retrieves unique local authority district names.
Each method executes a DISTINCT SQL query on the respective table and returns a list of strings, excluding any null values.

Key Functions and Their Responsibilities
main.dart
_initializeDatabaseAndFilters: Sets up the database connection and initializes filter options.
_fetchFilterOptions: Retrieves distinct values for each filter category from the database.
_applyFiltersAndRefresh: Applies selected filters and refreshes the displayed parcel data.
_fetchParcels: Fetches paginated parcel data based on current filters and updates the map.
_loadGeoJsonData: Converts fetched parcel data into GeoJSON format for map rendering.
_addGeoJsonLayer: Adds or updates the GeoJSON source and layer on the Mapbox map.
_updatePolygon: Highlights the current parcel polygon on the map and adjusts the camera view.
_openFilterDialog: Opens a dialog for users to set filter criteria.
_previousPolygon & _nextPolygon: Navigate through the list of parcels.
database_service.dart
connect: Establishes a connection to the PostgreSQL database.
close: Closes the active database connection.
fetchParcels: Retrieves parcels from the database with optional filters and pagination.
getTotalParcels: Retrieves the total number of parcels matching the current filters.
fetchDistinctCounties, fetchDistinctBuiltUpAreas, fetchDistinctRegions, fetchDistinctLocalAuthorityDistricts: Fetch distinct values for each filter category.
Error Handling and Logging
Utilizes the logger package to log informational messages, warnings, and errors. Catches and logs exceptions during database operations, map loading, and data processing to facilitate debugging.

User Experience
Map Interaction: Displays parcels on a Mapbox map with the ability to navigate between them.
Filtering: Users can apply multiple filters to refine the displayed parcels.
Pagination: Efficiently handles large datasets by loading parcels in pages.
Responsive UI: Shows loading indicators during data fetches and updates the UI accordingly.
Conclusion
The Parcel Swipe App combines Flutter's robust UI capabilities with Mapbox's mapping features and PostgreSQL's powerful data handling to provide an interactive platform for visualizing and navigating parcel data. The structured approach in both UI management and database interactions ensures scalability and maintainability, making it a solid foundation for further development and feature additions.
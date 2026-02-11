
// This screen displays the full race results for the selected day
// It groups boats by class (White Sail 1, Spinnaker 1, etc.) and shows a sortable table including:
// Sail Number
// Boat Name
// Rating
// Elapsed Time
// Code
// Corrected Time/ Final position 

// The data comes from the FastAPI backend via `/race-results` and updates automatically based on today's date

import 'package:flutter/material.dart'; // Flutter UI framework
import 'package:dio/dio.dart'; // HTTP client package for API requests
import 'package:url_launcher/url_launcher.dart'; // Opens the export CSV link in browser (download/share)

// RaceResultsPage is a stateful widget because:
// It loads data from the network
// It needs to update when results arrive
// It manages loading/error states


// `isAdmin` controls whether admin-only UI (Export button) is shown
// Key Architecture Patterns
// 1. Two-phase loading: GET /boats to find classes, then GET /race-results for each class
// 2. Grouped display: Card per class with DataTable inside
// 3. Admin feature flag: widget.isAdmin controls export button visibility
// 4. Sailwave integration: Exports results in format compatible with Sailwave scoring software
// Summary of Key Methods
// _loadResults(): 
  // 1. GET /boats to extract class names
  // 2. For each class: GET /race-results?race_date=...&class_name=...
  // 3. Store in resultsByClass map
// _formatDuration(): Converts seconds to HH:MM:SS string
// _exportSailwaveCsv(): 
  // 1. SimpleDialog to select class
  // 2. AlertDialog to enter race number
  // 3. Build URL: /export/sailwave-race-csv?race_date=...&class_name=...&race_no=...
  // 4. launchUrl() to open in browser (triggers download)
// _buildClassTable(): Creates Card with class name and DataTable

class RaceResultsPage extends StatefulWidget {
  const RaceResultsPage({
    super.key,

    // If true, show the "Export to Sailwave CSV" button in the AppBar.
    // If false, the user can still view results but cannot export files.
    required this.isAdmin,
  });

  // Controls admin-only features on this page (like exporting results)
  final bool isAdmin;

  @override
  State<RaceResultsPage> createState() => _RaceResultsPageState();
}

/// State class that contains all logic for fetching and displaying results
class _RaceResultsPageState extends State<RaceResultsPage> {
  // Dio client for backend API communication
  final dio = Dio(BaseOptions(baseUrl: "http://127.0.0.1:8000"));

  // Today's date formatted as YYYY-MM-DD (backend uses this format)
  late String todayDate;

  // Controls the loading state on screen
  bool loading = true;

  // Stores any error message if an API call fails.
  String? error;

  // A map where:
  // KEY = class name (e.g., "White Sail 1")
  // VALUE = list of boats and result data from backend
  //
  // Example:
  // {
  //   "White Sail 1": [
  //      { "sail_no": "IRL123", "elapsed_seconds": 3600, ... },
  //   ],
  //   "Spinnaker 1": [...],
  // }
  final Map<String, List<Map<String, dynamic>>> resultsByClass = {};

  // Called automatically when the page first loads
  @override
  void initState() {
    super.initState();

    // Build today's date in YYYY-MM-DD format
    final now = DateTime.now();
    todayDate =
        "${now.year.toString().padLeft(4, '0')}"
        "-${now.month.toString().padLeft(2, '0')}"
        "-${now.day.toString().padLeft(2, '0')}";

    // Trigger the API fetch
    _loadResults();
  }

  // Loads results from the backend:
  // 1. Get all boats - extract class names
  // 2. For each class - fetch results using:
  //       GET /race-results?race_date=YYYY-MM-DD&class_name=CLASS
  // 3. Store results into resultsByClass map
  // Reference: Dio GET with queryParameters, nested API calls [D1]
  Future<void> _loadResults() async {
    setState(() {
      loading = true; // Show loading spinner
      error = null; // Clear previous errors
    });

    try {
      //  STEP 1: Load all boats to detect which classes exist
      final boatsRes = await dio.get("/boats"); // API request
      final boats = boatsRes.data as List<dynamic>;

      // A set automatically prevents duplicates
      final classes = <String>{};

      for (final b in boats) {
        // Every boat contains a "class_name" field
        classes.add((b as Map<String, dynamic>)["class_name"] as String);
      }

      // Clear old results before fetching new ones
      resultsByClass.clear();

      // STEP 2: Fetch results for each class
      for (final className in classes) {
        final res = await dio.get(
          "/race-results",
          queryParameters: {
            "race_date": todayDate,
            "class_name": className,
          },
        );

        // Convert dynamic - Map<String, dynamic>
        final list = (res.data as List<dynamic>)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

        // Store the result list under this class
        resultsByClass[className] = list;
      }

      // Re-render the UI now that results are loaded
      setState(() {});
    } catch (e) {
      // Any network / server / parsing error will be caught here
      setState(() {
        error = "Failed to load results";
      });
    } finally {
      // Stop showing the loading spinner no matter what happened
      setState(() {
        loading = false;
      });
    }
  }

  // Converts seconds (int or double) into HH:MM:SS string
  // If value is null (e.g., boat not finished yet), return
  String _formatDuration(num? seconds) {
    if (seconds == null) return "—";

    final d = Duration(seconds: seconds.toInt());

    String two(int n) => n.toString().padLeft(2, '0');

    final h = two(d.inHours);
    final m = two(d.inMinutes.remainder(60));
    final s = two(d.inSeconds.remainder(60));

    return "$h:$m:$s";
  }


  // Admin Export: Export current day's results to Sailwave CSV


  // Sailwave can import race results from CSV and recognises result fields such as:
  // RaceNo, Start, Finish, Elapsed, Code, Place and the guide shows an example CSV header like:
  // raceno, class, sailno, start, finish

  // References:
  // Sailwave CSV Import Format and Race Scoring [S1]
  // Flutter Dialogs (showDialog, SimpleDialog, AlertDialog) [F7][F16]
  // Flutter TextField & user input handling [F4]
  // url_launcher for opening external download links [F17]
  
  // This function:
  // 1) asks admin which class they want to export (because results are grouped by class)
  // 2) asks admin the race number (weekly race number in Sailwave)
  // 3) builds the export URL and opens it in the browser (download/share)
  Future<void> _exportSailwaveCsv() async {
    // Safety: if no results loaded, there's nothing to export.
    if (resultsByClass.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No results available to export.")),
        );
      }
      return;
    }

    // Step 1: Choose which class to export (White Sail 1, Spinnaker 1, etc.)
    final classNames = resultsByClass.keys.toList()..sort();

    final selectedClass = await showDialog<String>(
      context: context,
      // Reference: SimpleDialog and SimpleDialogOption for lightweight selection dialogs [F16]
      builder: (context) => SimpleDialog(
        title: const Text("Export which class?"),
        children: [
          for (final c in classNames)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, c),
              child: Text(c),
            ),
        ],
      ),
    );

    // If dialog was cancelled, stop.
    if (selectedClass == null) return;

    // Step 2: Ask for the Sailwave race number (e.g., "5" for Week 5)
  
    // Sailwave uses RaceNo during CSV import to map results to a specific race column.
    final raceNoController = TextEditingController(text: "1");

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Race number"),
        content: TextField(
          controller: raceNoController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: "Enter SailWave race number (e.g. 5)",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Export"),
          ),
        ],
      ),
    );

    if (ok != true) return;

    // Convert the user input into an integer
    final raceNo = int.tryParse(raceNoController.text.trim());
    if (raceNo == null || raceNo <= 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enter a valid race number (e.g. 1, 2, 3...).")),
        );
      }
      return;
    }

    // Step 3: Build the export URL
  
    // IMPORTANT:
    // - Using dio.options.baseUrl so it always matches the backend host.
    // - The backend endpoint should be:
    // GET /export/sailwave-race-csv?race_date=YYYY-MM-DD&class_name=...&race_no=...

    // That endpoint outputs a CSV in a SailWave-friendly structure (raceno, class, sailno, start, finish ...),
    // matching Sailwave's import guidance.
    // Reference: Uri.replace with queryParameters for building safe URLs [F17]


    final baseUrl = dio.options.baseUrl; // e.g. http://127.0.0.1:8000
    final uri = Uri.parse("$baseUrl/export/sailwave-race-csv").replace(
      queryParameters: {
        "race_date": todayDate,
        "class_name": selectedClass,
        "race_no": raceNo.toString(),
      },
    );
    //   Flutter showDialog function and dialog widgets (SimpleDialog, AlertDialog) [F18]

    // Step 4: Open the URL in the browser so the admin can download/share the CSV.
    // On desktop this usually downloads the file.
    // On phone it opens the CSV and allows Share/Save-to-Files.
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open export link.")),
      );
    }
  }

  /// Build the full UI scaffold
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // App bar title shows today's date for clarity
      appBar: AppBar(
        title: Text("Today's Results – $todayDate"),


        // admin only button to Export to Sailwave
        // Reference: AppBar actions with IconButton, conditional widget lists using `if (...)` in Dart [F14][F15]

        // If widget.isAdmin = true, show the export icon.
        // If false, hide it entirely.
        actions: [
          if (widget.isAdmin)
            IconButton(
              tooltip: "Export to Sailwave CSV",
              icon: const Icon(Icons.download),
              onPressed: _exportSailwaveCsv,
            ),
        ],
      ),

      // Main body of the screen with padding
      body: Padding(
        padding: const EdgeInsets.all(12),

        // Loading state
        child: loading
            ? const Center(child: CircularProgressIndicator())

            // Error state
            : error != null
                ? Center(child: Text(error!))

                // No results found
                : resultsByClass.isEmpty
                    ? const Center(child: Text("No results yet for today."))

                    // Results found - show the tables
                    : ListView(
                        children: [
                          // Loop through each class:
                          // entry.key = class name
                          // entry.value = list of results for that class
                          for (final entry in resultsByClass.entries)
                            _buildClassTable(entry.key, entry.value),
                        ],
                      ),
      ),
    );
  }


  // Builds a table card for a single class (e.g., White Sail 1)
  // Includes:
  // - Title (Class Name)
  // - DataTable with position, sail no, elapsed, corrected
  // Reference: DataTable for tabular race results [F6]
  // Reference: Card and ListView for grouping by class [F5]
  // Reference: DataTable dynamic columns and conditional columns for admin-only fields [F6][F15]

  Widget _buildClassTable(
    String className,
    List<Map<String, dynamic>> results,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16), // Spacing between class sections
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Class Name Table
            Text(
              className,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            // Wide horizontal scrolling to fit table columns
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                // Column definitions (headers)
                columns: const [
                  DataColumn(label: Text("Pos")),
                  DataColumn(label: Text("Sail No")),
                  DataColumn(label: Text("Boat")),
                  DataColumn(label: Text("Rating")),
                  DataColumn(label: Text("Elapsed")),
                  DataColumn(label: Text("Corrected")),
                  DataColumn(label: Text("Code")),
                  DataColumn(label: Text("Place")),
                ],

                // Create one DataRow per result entry
                rows: results.map((r) {
                  // Extract values
                  final pos = r["position"];
                  final elapsed = r["elapsed_seconds"] as int?;
                  final corrected = r["corrected_seconds"] as num?;

                  // Build a single table row
                  return DataRow(
                    cells: [
                      DataCell(Text(pos?.toString() ?? "-")),
                      DataCell(Text(r["sail_no"] as String)),
                      DataCell(Text(r["name"] as String)),
                      DataCell(Text((r["rating_value"] as num).toString())),
                      DataCell(Text(_formatDuration(elapsed))),
                      DataCell(Text(_formatDuration(corrected))),
                      DataCell(Text((r["code"] as String?) ?? "")),
                      DataCell(Text(r["position"]?.toString() ?? "-")),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// Summary
// Professional results display with:
// 1. Grouped by class in expandable cards
// 2. DataTable for clean tabular layout
// 3. Time formatting (HH:MM:SS)
// 4. Admin-only export to Sailwave CSV
// 5. Handles OCS codes and penalties correctly

// Reference: StatefulWidget for async results loading [F14]
// Reference: DataTable for results display [F6]
// Reference: SingleChildScrollView for horizontal scrolling [F5]
// Reference: Card for class grouping [F19]
// Reference: SimpleDialog for class selection [F16]
// Reference: AlertDialog for race number input [F18]
// Reference: TextField for input [F4]
// Reference: TextEditingController for form management [F4]
// Reference: Dio GET request [D1][D3]
// Reference: FastAPI results endpoint [B1]
// Reference: Query parameters for filtering [B11]
// Reference: url_launcher package for CSV download [F17]
// Reference: Uri.parse for URL construction [F17]
// Reference: Sailwave CSV format specification [S1][S2]
// Reference: CircularProgressIndicator for loading [F1]
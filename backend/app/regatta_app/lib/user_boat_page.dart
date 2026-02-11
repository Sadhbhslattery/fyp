// This screen is shown AFTER a successful user login (boat owner)
// It is personalised to a single boat and shows:

// Static boat information (name, sail number, class, rating, club)
// "Today's course" details (if the race officer has selected a course)
//  Today's results table for that boat's class (White Sail 1, etc.)
//  The user's own boat is highlighted in the table
// The page pulls data from the backend via FastAPI endpoints:
//  GET /current-course - what course (and start time) is selected today
//  GET /race-results   - per-class results (elapsed and corrected times)

// This allows sailors to quickly see:
//  What course they are sailing today
//  How they performed relative to other boats in their class

import 'package:flutter/material.dart'; // Flutter widgets and layout
import 'package:dio/dio.dart';
import 'package:regatta_app/theme/app_theme.dart'; // HTTP client for calling the backend

// Start sequence (5–4–1–Start) UI
// This reads the race officer "5-minute gun" broadcast and displays:
//  - the selected preparatory flag (P/I/Z/U/BLACK)
//  - a live countdown timer to the start
// It pulls data from the backend via FastAPI endpoints:
//  GET /start-sequence/status?class_name=...&race_date=...
import 'dart:async'; // Timer.periodic for live countdown updates
import 'services/start_sequence_api.dart';
import 'ui/flags/flag_chip.dart';

// UserBoatPage is a stateful widget because:
// it loads data asynchronously from the backend and the course/results can change over time
// Reference: Dio GET with queryParameters and mapping JSON to Dart Maps [D1][F8]

// It receives a `boat` object from the login page so we know which boat this screen is associated with
class UserBoatPage extends StatefulWidget {
  // Boat information passed in (includes id, sail_no, name, club, class_name, rating, etc.)
  final Map<String, dynamic> boat;

  const UserBoatPage({super.key, required this.boat});

  @override
  State<UserBoatPage> createState() => _UserBoatPageState();
}

class _UserBoatPageState extends State<UserBoatPage> {
  // HTTP client pointing at our local FastAPI backend (same as other pages)
  final dio = Dio(BaseOptions(baseUrl: "http://127.0.0.1:8000"));

  // API client used to fetch the start-sequence broadcast
  // (Uses the same FastAPI base URL)
  final StartSequenceApi startSeqApi = StartSequenceApi("http://127.0.0.1:8000");

  // Holds the currently selected course for today, as returned by GET /current-course.

  // Example structure:
  // {
  //   "course": { "id": 1, "name": "...", "wind": "...", "rounds": [...] },
  //   "start_time": "18:30"
  // }
  Map<String, dynamic>? currentCourse;

  // Error message if loading the current course fails
  String? courseError;

  // Flag to show loading spinner while course info is being fetched
  bool loadingCourse = true;

  // Holds all race results for this boat's class for today
  // Data from GET /race-results?race_date=...&class_name=...
  List<dynamic> classResults = [];

  // Error message if loading class results fails or no data exists
  String? resultsError;

  // Flag to show loading spinner while results are being fetched
  bool loadingResults = true;

  // Date string used in API calls ("YYYY-MM-DD")
  late String todayDate;

  // NEW: START SEQUENCE STATE (User view)

  // Holds the current start sequence status for this boat's class (if the RO has started it)
  //
  // Expected backend JSON shape (example):
  // {
  //   "class_name": "White Sail 1",
  //   "race_date": "2026-02-04",
  //   "prep_flag": "P",
  //   "sequence_start_utc": "2026-02-04T18:25:00Z",
  //   "server_time_utc": "2026-02-04T18:25:12Z"
  // }
  Map<String, dynamic>? startSequence;

  // Error message if there is no sequence yet or server error
  String? startSequenceError;

  // Flag to show loading spinner while sequence status is being fetched
  bool loadingStartSequence = true;

  // Timers:
  // - pollTimer keeps device synchronised with backend (in case RO restarts sequence)
  // - tickTimer updates countdown smoothly every second
  Timer? pollTimer;
  Timer? tickTimer;

  // We keep a local "serverNow" that we advance between polls.
  // This avoids relying on the phone's clock.
  DateTime? serverNowUtc;

  // initState runs once when the widget is created
  // Here it is:
  //   - building today's date string
  //   - loading the current course
  //   - loading today's class results for this boat's class
  @override
  void initState() {
    super.initState();

    // Build today's date in the format the backend expects
    final now = DateTime.now();
    todayDate =
        "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    // Kick off the asynchronous loads
    _loadCurrentCourse();
    _loadClassResults();

    // NEW: start listening for the live start sequence for this boat's class
    _startStartSequenceTimers();
  }

  @override
  void dispose() {
    // Always cancel timers to avoid memory leaks when leaving the page
    pollTimer?.cancel();
    tickTimer?.cancel();
    super.dispose();
  }

  // Start squence poll and tick 

  // Starts:
  //  - polling the backend every 2 seconds for the current sequence state
  //  - ticking locally every second to update the countdown smoothly
  void _startStartSequenceTimers() {
    // Poll backend for accuracy (e.g., RO restarts or changes prep flag)
    pollTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _loadStartSequence(),
    );

    // Local tick keeps countdown smooth between polls
    tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (serverNowUtc != null) {
        serverNowUtc = serverNowUtc!.add(const Duration(seconds: 1));
        if (mounted) setState(() {});
      }
    });

    // Initial fetch immediately
    _loadStartSequence();
  }

  // Load Current course from backend

  // Calls GET /current-course:
  // - If a race officer has selected a course today, the backend returns course and start_time.
  // - If not, we show "No race selected yet."
  Future<void> _loadCurrentCourse() async {
    setState(() {
      loadingCourse = true;
      courseError = null;
    });

    try {
      // Fetch the current course selection from backend
      final res = await dio.get("/current-course");

      // On success, store the result as a Map<String, dynamic>
      setState(() {
        currentCourse = res.data as Map<String, dynamic>;
      });
    } catch (e) {
      // If anything goes wrong (no selection, server not set, etc.),
      // we treat it as "no race selected yet"
      setState(() {
        courseError = "No race selected yet.";
        currentCourse = null;
      });
    } finally {
      // Stop showing the spinner regardless of success/failure
      setState(() {
        loadingCourse = false;
      });
    }
  }


  // Load Class reaults for this Boats's class

  // Loads race results for this boat's class (e.g. "White Sail 1")
  // for today's date from GET /race-results

  // The backend returns a list of objects, including fields like:
  //   - boat_id
  //   - sail_no
  //   - name
  //   - elapsed_seconds
  //   - corrected_seconds
  //   - position
  Future<void> _loadClassResults() async {
    setState(() {
      loadingResults = true;
      resultsError = null;
    });

    try {
      // Use widget.boat["class_name"] to request the right class
      final res = await dio.get(
        "/race-results",
        queryParameters: {
          "race_date": todayDate,
          "class_name": widget.boat["class_name"],
        },
      );

      setState(() {
        classResults = res.data as List<dynamic>;
      });
    } catch (e) {
      // If there is no data or an error occurred, we show a friendly message
      setState(() {
        classResults = [];
        resultsError = "No timing data yet for your class today.";
      });
    } finally {
      setState(() {
        loadingResults = false;
      });
    }
  }

  // load start sequence for this boat's class

  // Calls GET /start-sequence/status for the boat's class:
  // - If the RO has fired the 5-minute gun, we get sequence_start_utc and prep_flag and server_time_utc.
  // - If not, we show "Start sequence not started yet."
  Future<void> _loadStartSequence() async {
    setState(() {
      loadingStartSequence = true;
      startSequenceError = null;
    });

    try {
      // Use widget.boat["class_name"] so each boat only sees their class broadcast
      final res = await startSeqApi.getStatus(
        className: widget.boat["class_name"],
        raceDate: todayDate,
      );

      setState(() {
        startSequence = res;

        // Store server time to keep countdown accurate across devices
        final serverTimeStr = res["server_time_utc"] as String;
        serverNowUtc = DateTime.parse(serverTimeStr).toUtc();
      });
    } catch (e) {
      // If no sequence exists yet, users should see a friendly waiting message
      setState(() {
        startSequence = null;
        startSequenceError = "Start sequence not started yet for your class.";
        serverNowUtc = null;
      });
    } finally {
      setState(() {
        loadingStartSequence = false;
      });
    }
  }

  // format seconds - "HH:MM:SS" For Display

  // Converts a number of seconds to a readable duration string.

  // Example: 3672 seconds - "01:01:12"
  String _formatDuration(num? seconds) {
    // If null, we return em dash to indicate "not available"
    if (seconds == null) return "—";

    final d = Duration(seconds: seconds.toInt());

    String two(int n) => n.toString().padLeft(2, '0');

    final h = two(d.inHours);
    final m = two(d.inMinutes.remainder(60));
    final s = two(d.inSeconds.remainder(60));

    return "$h:$m:$s";
  }

  // Format Countdown- "MM:SS" For Start Sequence

  // Converts a Duration to MM:SS for the start countdown.
  // If negative, clamps to 00:00 after the start.
  String _formatCountdown(Duration d) {
    final totalSeconds = d.inSeconds < 0 ? 0 : d.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }

  // Determine which phase of the sequence we are in (5 / 4 / 1 / STARTED)
  String _sequencePhaseLabel(Duration timeToStart) {
    if (timeToStart <= Duration.zero) return "STARTED";
    if (timeToStart > const Duration(minutes: 4)) return "5 minute signal";
    if (timeToStart > const Duration(minutes: 1)) return "4 minute / running";
    return "1 minute signal";
  }

  // Build UI

  @override
  Widget build(BuildContext context) {
    // For convenience, pull the boat from the widget property
    final boat = widget.boat;

    // Identify this boat's ID to highlight it later in the results table
    final myBoatId = boat["id"];

    // Reference: Dart list iteration and Map usage [F8]

    Map<String, dynamic>? myRow;
    for (final r in classResults) {
      final m = Map<String, dynamic>.from(r as Map);
      if (m["boat_id"] == myBoatId) {
        myRow = m;
        break;
      }
    }

    // allFinished indicates whether every boat in the class has:
    // - a finish_time
    // - a corrected_seconds value

    // We keep this logic in case we want to change the UI if the race is fully finished, but we are no longer showing "Today's result: X of Y"
    final allFinished = classResults.isNotEmpty &&
        classResults.every(
          (r) =>
              (r as Map)["finish_time"] != null &&
              (r)["corrected_seconds"] != null,
        );

    // Scaffold = main page layout structure (app bar and body)
    return Scaffold(
      appBar: AppBar(
        // Title includes the boat’s sail number for clarity
        title: Text("Your Boat: ${boat['sail_no']}"),
      ),

      // Padding around entire page body
      body: Padding(
        padding: const EdgeInsets.all(20),

        // We use a ListView so content scrolls if it doesn’t fit on screen
        child: ListView(
          children: [
            // Boat info card

            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),

                // Layout the text top-to-bottom left aligned
                // Reference: Card layout for boat details and course description [F1][F3]

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Boat Name: ${boat['name']}",
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 4),
                    Text("Club: ${boat['club'] ?? ''}"),
                    Text("Class: ${boat['class_name']}"),
                    Text("Rating: ${boat['rating_value']}"),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Start Sequence Card(5–4–1–Start)

            // This section shows:
            //  Preparatory flag (P/I/Z/U/BLACK) chosen by the race officer
            //  Live countdown timer to the start
            //  Current phase (5 minute, 4 minute, 1 minute, STARTED)
            // It is shown per-class, so boats only see the sequence for their own class.
            loadingStartSequence
                ? const Center(child: CircularProgressIndicator())
                : _buildStartSequenceCard(),

            const SizedBox(height: 16),

            // Today's Course Card

            // This section shows:
            // Course name
            // Wind info
            // Start time
            // Detailed rounds

            loadingCourse
                // Show spinner while /current-course is loading
                ? const Center(child: CircularProgressIndicator())
                // If not loading and there is no course, show an info message
                : currentCourse == null
                    ? Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            courseError ?? "No race selected yet.",
                            style: const TextStyle(color: AppTheme.surface2),
                          ),
                        ),
                      )
                    // If course exists, build the full "Today's course" card
                    : _buildRaceCard(),

            const SizedBox(height: 16),

            // Class results table

            // Shows only results for this boat's class
            // The user’s own boat is highlighted in bold in the table
            loadingResults
                // Spinner while results are being loaded
                ? const Center(child: CircularProgressIndicator())
                // Once loading is complete, show the results card
                : _buildClassResultsCard(myBoatId),
          ],
        ),
      ),
    );
  }

  // build start sequence card
  // Builds the UI card that shows:
  // - flag selected by race officer
  // - countdown to the start for this boat's class
  // - current phase label (5 / 4 / 1 / STARTED)
  Widget _buildStartSequenceCard() {
    // If there is no active start sequence, show a friendly message
    if (startSequence == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            startSequenceError ?? "Start sequence not started yet for your class.",
            style: const TextStyle(color: AppTheme.surface2),
          ),
        ),
      );
    }

    final s = startSequence!;

    // Parse times returned by backend
    final seqStartUtc =
        DateTime.parse(s["sequence_start_utc"] as String).toUtc();

    // Use serverNowUtc (advanced locally) to avoid phone clock drift
    final nowUtc = serverNowUtc ??
        DateTime.parse(s["server_time_utc"] as String).toUtc();

    // The RO pressed "5-minute gun" at sequence_start_utc
    // The actual START happens 5 minutes after that moment.
    final startMomentUtc = seqStartUtc.add(const Duration(minutes: 5));
    final timeToStart = startMomentUtc.difference(nowUtc);

    final prepFlag = (s["prep_flag"] as String?) ?? "P";

    // The preparatory flag goes DOWN at 1 minute to start.
    final showPrepFlag = timeToStart > const Duration(minutes: 1);

    return Card(
      // Light background to differentiate from the other cards
      color: AppTheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title shows boat class so user knows this is their fleet countdown
            Text(
              "Start sequence — ${widget.boat["class_name"]}",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            // Show flag chip while it is "UP" (from 5 minutes until 1 minute)
            if (showPrepFlag)
              Center(
                child: FlagChip(
                  flagCode: prepFlag,
                  label: "Preparatory: $prepFlag (UP)",
                ),
              )
            else
              Center(
                child: Text(
                  "Preparatory flag DOWN (1 minute)",
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),

            const SizedBox(height: 16),

            // Large countdown MM:SS
            Center(
              child: Text(
                _formatCountdown(timeToStart),
                style: const TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 6),

            // Phase label (5 minute / 4 minute / 1 minute / STARTED)
            Center(
              child: Text(
                _sequencePhaseLabel(timeToStart),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build Today's Course Card

  // Builds the card describing today's selected course

  // Uses the structure returned by GET /current-course:
  // {
  //   "course": { ... },
  //   "start_time": "HH:MM"
  // }
  Widget _buildRaceCard() {
    // Using currentCourse! because this function is only called when it's non-null
    final cc = currentCourse!;

    // Extract inner course details
    final course = cc["course"] as Map<String, dynamic>;

    // Start time can be null if not set; we use "TBC" in that case
    final startTime = cc["start_time"] ?? "TBC";

    // Rounds is a List<String> from backend; join with newlines
    final rounds = (course["rounds"] as List<dynamic>).join("\n");

    return Card(
      // Light background to differentiate from the other cards
      color: AppTheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title is always "Today's course" based on your design choice
            const Text(
              "Today's course",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            // Basic course metadata
            Text("Course: ${course['name']}"),
            Text("Wind: ${course['wind']}"),
            Text("Start time: $startTime"),

            const SizedBox(height: 10),

            const Text(
              "Rounds:",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),

            const SizedBox(height: 4),

            // Detailed course rounds (e.g., "Start - Mark A - Mark B - Finish")
            Text(rounds),
          ],
        ),
      ),
    );
  }

  // Build Class results table

  // Builds a table of results (position, sail number, boat, times) for this boat's class for today.

  // The row for `myBoatId` is drawn in bold to stand out
  Widget _buildClassResultsCard(int myBoatId) {
    // If there are no results yet, show a grey info message
    if (classResults.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            resultsError ?? "No timing data yet for your class today.",
            style: const TextStyle(color: AppTheme.surface2),
          ),
        ),
      );
    }

    // If there is data, render it as a horizontal-scrollable DataTable
    // Reference: DataTable and styling with TextStyle [F6]
    return Card(
      color: AppTheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title includes class name so the user knows what they are viewing
            Text(
              "Today's ${widget.boat["class_name"]} results",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            // Allow the table to scroll horizontally in case of small screens
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                // Column headings for the results
                columns: const [
                  DataColumn(label: Text("Pos")),
                  DataColumn(label: Text("Sail No")),
                  DataColumn(label: Text("Boat")),
                  DataColumn(label: Text("Elapsed")),
                  DataColumn(label: Text("Corrected")),
                ], // Reference: Flutter DataTable Docs [F6]

                // Build one row per boat result
                rows: classResults.map((r) {
                  // Ensure we have a strongly-typed Map before reading fields
                  final row = Map<String, dynamic>.from(r as Map);

                  // Is this row the logged-in user's boat?
                  final isMe = row["boat_id"] == myBoatId;

                  // Extract timing and position fields
                  final elapsed = row["elapsed_seconds"] as int?;
                  final corrected = row["corrected_seconds"] as num?;
                  final pos = row["position"] as int?;

                  // If it's this user's boat we render the text in bold
                  final style = TextStyle(
                    fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                  );

                  // One DataRow per boat
                  return DataRow(
                    cells: [
                      DataCell(Text(pos?.toString() ?? "-", style: style)),
                      DataCell(Text(row["sail_no"] as String, style: style)),
                      DataCell(Text(row["name"] as String, style: style)),
                      DataCell(Text(_formatDuration(elapsed), style: style)),
                      DataCell(Text(_formatDuration(corrected), style: style)),
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

// Reference: StatefulWidget for async data loading [F14]
// Reference: Multiple async data sources with independent error handling [F8]
// Reference: Timer.periodic for live countdown synchronization [F23]
// Reference: DataTable for results display with conditional styling [F6]
// Reference: Card layout for modular content sections [F19]
// Reference: ListView for scrollable content [F5]
// Reference: Dio HTTP client with query parameters [D1][D3]
// Reference: UTC timezone handling for server sync [B10]
// Reference: FastAPI query parameters for filtering [B11]
// Reference: Scaffold structure for page layout [F3]
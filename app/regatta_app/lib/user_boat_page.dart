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

import 'package:flutter/material.dart'; // Flutter widgets & layout
import 'package:dio/dio.dart';  // HTTP client for calling the backend

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
  }


  // LOAD CURRENT COURSE FROM BACKEND
 

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


  // LOAD CLASS RESULTS FOR THIS BOAT'S CLASS

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

 
  // FORMAT SECONDS - "HH:MM:SS" For Display
 

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


  // BUILD UI


  @override
  Widget build(BuildContext context) {
    // For convenience, pull the boat from the widget property
    final boat = widget.boat;

    // Identify this boat's ID to highlight it later in the results table
    final myBoatId = boat["id"];

    // Optional: we can search classResults for this boat’s own row (e.g., to display special info). Currently we don’t use it in the UI
    // but it demonstrates how to find the current boat in result list
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

    // Scaffold = main page layout structure (app bar + body)
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
            
            // BOAT INFO CARD

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

            // TODAY'S COURSE CARD
            
            // This section shows:
            //  Course name
            //  Wind info
            //  Start time
            //  Detailed rounds
            
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
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    // If course exists, build the full "Today's course" card
                    : _buildRaceCard(),

            const SizedBox(height: 16),

            
            // CLASS RESULTS TABLE
            
            
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

  
  // BUILD "TODAY'S COURSE" CARD


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
      color: Colors.deepPurple.shade50,
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

  
  // BUILD CLASS RESULTS TABLE
  

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
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    // If there IS data, render it as a horizontal-scrollable DataTable
    // Reference: DataTable and styling with TextStyle [F6]
    return Card(
      color: Colors.blueGrey.shade50,
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

// This screen is shown AFTER a successful user login (boat owner)
// It is personalised to a single boat and shows:

// Static boat information (name, sail number, class, rating, club)
// Check-in status (whether the competitor has confirmed they are racing today)
// "Today's course" details (if the race officer has selected a course)
//  Today's results table for that boat's class (White Sail 1, etc.)
//  The user's own boat is highlighted in the table
// The page pulls data from the backend via FastAPI endpoints:
//  GET /current-course - what course (and start time) is selected today
//  GET /race-results   - per-class results (elapsed and corrected times)
//  GET /check-ins - whether this boat has already checked in today
//  POST /check-in - confirm this boat is racing today
//  GET /race-starts/boat - this boat's scheduled start time for today

// This allows sailors to quickly see:
//  What course they are sailing today
//  Their scheduled start time before the gun fires
//  The live countdown during the start sequence
//  How long they have been racing since the start
//  How they performed relative to other boats in their class

import 'package:flutter/material.dart'; // Flutter widgets and layout
import 'package:dio/dio.dart';
import 'package:regatta_app/theme/app_theme.dart'; // HTTP client for calling the backend

// Start sequence (5-4-1-Start) UI
// This reads the race officer "5-minute gun" broadcast and displays:
//  - the selected preparatory flag (P/I/Z/U/BLACK)
//  - a live countdown timer to the start
// It pulls data from the backend via FastAPI endpoints:
//  GET /start-sequence/status?class_name=...&race_date=...
import 'dart:async'; // Timer.periodic for live countdown updates
import 'services/start_sequence_api.dart';

// UserBoatPage is a stateful widget because:
// it loads data asynchronously from the backend and the course/results can change over time
// Reference: Dio GET with queryParameters and mapping JSON to Dart Maps [D1][F8]

// It receives a `boat` object from the login page so we know which boat this screen is associated with
class UserBoatPage extends StatefulWidget {
  // Boat information passed in (includes id, sail_no, name, club, class_name, rating, etc.)
  final Map<String, dynamic> boat;

  const UserBoatPage({super.key, required this.boat, required String sailNo});

  @override
  State<UserBoatPage> createState() => _UserBoatPageState();
}

class _UserBoatPageState extends State<UserBoatPage> {
  // HTTP client pointing at our local FastAPI backend (same as other pages)
  final dio = Dio(BaseOptions(baseUrl: "https://web-production-9fd2e3.up.railway.app"));

  // API client used to fetch the start-sequence broadcast
  // (Uses the same FastAPI base URL)
  final StartSequenceApi startSeqApi = StartSequenceApi("https://web-production-9fd2e3.up.railway.app");

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

  // START SEQUENCE STATE (User view)

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
  DateTime? sequenceStartUtc; // store once so countdown doesn't reset

  // Boat Start Record Sate
  // Holds this boat's race start record from GET /race-starts/boat.
  // Used to display the scheduled start time before the 5-minute gun fires,
  // and to detect when the admin has finished the boat (finish_time != null).
  // Polled every 10 seconds so updates appear without manual refresh. [F23][D1][D3]
  // Example structure:
  // {
  //   "id": 42,
  //   "boat_id": 7,
  //   "race_date": "2026-03-01",
  //   "start_time": "18:30:00",
  //   "finish_time": null,  // set when admin taps "Finish"
  //   "elapsed_seconds": null,  // computed by backend on finish
  //   ...
  // }
  // Reference: Dart nullable Map type for optional backend data [F8]
  Map<String, dynamic>? boatStart;

  // Chekc-in State
  // Tracks whether this competitor has confirmed they are racing today.
  // Set to true after a successful POST /check-in or if GET /check-ins
  // shows this boat already checked in. Displayed as a Chip in the boat info card.
  bool isCheckedIn = false;

  // initState runs once when the widget is created
  // Here it is:
  //   - building today's date string
  //   - loading the current course
  //   - loading today's class results for this boat's class
  //   - loading the boat's scheduled start time
  //   - prompting the check-in dialog (after the first frame renders)
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
    _loadBoatStart();

    // Start listening for the live start sequence for this boat's class
    _startStartSequenceTimers();

    // Prompt check-in dialog after the first frame has rendered.
    // We use addPostFrameCallback because showDialog requires the widget
    // tree to be fully built — calling it directly in initState would fail
    // silently since the BuildContext is not yet ready for overlays.
    // Reference: WidgetsBinding.instance.addPostFrameCallback [F14]
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _promptCheckIn();
    });
  }

  // Check in prompt
  // Called once after the first frame renders. Steps:
  //   1. Check GET /check-ins to see if this boat already checked in today.
  //   2. If already checked in, set isCheckedIn = true and skip the dialog.
  //   3. If not, show a confirmation dialog asking "Racing today?"
  //   4. If confirmed, POST /check-in to record it in the database.
  //   5. The race officer sees this on their page via GET /check-ins.
  Future<void> _promptCheckIn() async {
    // First check if already checked in today by querying the backend
    try {
      final res = await dio.get("/check-ins", queryParameters: {"race_date": todayDate});
      final List<dynamic> checkIns = res.data as List<dynamic>;
      // Look for this boat's id in the list of today's check-ins
      final alreadyIn = checkIns.any((c) => c["boat_id"] == widget.boat["id"]);
      if (alreadyIn) {
        setState(() => isCheckedIn = true);
        return; // Already checked in, no dialog needed
      }
    } catch (_) {
      // If the endpoint fails (e.g. not deployed yet), fall through to show the dialog
    }

    // Not checked in yet — show confirmation dialog
    // Check 'mounted' to avoid showing a dialog if the widget has been
    // disposed of while the async check-in query was running [F36]
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      // barrierDismissible: false forces the user to tap a button rather than
      // tapping outside to dismiss — ensures they make a deliberate choice
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Racing today?"),
        content: const Text(
          "Confirm you're racing today so the race officer knows you're on the water.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Not today"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Yes, I'm racing"),
          ),
        ],
      ),
    );

    // If user tapped "Yes, I'm racing", send the check-in to the backend
    if (confirmed == true) {
      try {
        await dio.post("/check-in", queryParameters: {
          "boat_id": widget.boat["id"],
          "race_date": todayDate,
        });
        setState(() => isCheckedIn = true);
      } catch (_) {
        // Silently fail — the check-in is a nice-to-have, not critical
      }
    }
  }

  @override
  void dispose() {
    // Always cancel timers to avoid memory leaks when leaving the page
    pollTimer?.cancel();
    tickTimer?.cancel();
    super.dispose();
  }

  // Start sequence poll and tick

  // Starts:
  //  - polling the backend every 10 seconds for the current sequence state
  //  - ticking locally every second to update the countdown and elapsed timer smoothly
  void _startStartSequenceTimers() {
    // Poll backend for accuracy (e.g., RO restarts or changes prep flag)
    // Also re-fetches the boat's start record so the scheduled time updates
    // when the admin sets per-class start times after the page is already open,
    // and so the finish_time is detected when the admin finishes the boat.
    // Reference: Timer.periodic for recurring HTTP polls [F23]
    // Reference: Dio GET requests with query parameters [D1][D3][B1]
    pollTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) {
        _loadStartSequence();
        _loadBoatStart();
      },
    );

    // Local tick keeps countdown and elapsed timer smooth between polls.
    // Runs every 1 second (not 10) so the elapsed timer updates smoothly.
    // Only triggers a setState rebuild — actual time is computed from DateTime.now().
    // Reference: Timer.periodic for 1-second UI ticks [F23]
    // Reference: setState triggers widget rebuild without re-fetching data [F36]
    tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (sequenceStartUtc != null) {
        if (mounted) setState(() {}); // UI rebuild only, timers run off DateTime.now()
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


  // Load Class results for this Boat's class

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

  // Load this boat's race start record
  
  // Calls GET /race-starts/boat?boat_id=X&race_date=Y [D1][D3][B1]
  // Returns the scheduled start time set by the race officer via class-start,
  // plus finish_time and elapsed_seconds if the boat has been finished.
  
  // Used for three purposes:
  //   1. Display scheduled start time before the 5-minute gun fires (STATE 1)
  //   2. Display "Your start: HH:MM" on the course card instead of generic course time [F15]
  //   3. Detect when admin has finished the boat (finish_time != null) to freeze elapsed timer
  
  // Polled every 10 seconds via pollTimer so updates appear automatically [F23]
  // A 404 response means no start time set yet — handled via catch block [F8]
  Future<void> _loadBoatStart() async {
    try {
      final res = await dio.get(
        "/race-starts/boat",
        queryParameters: {
          "boat_id": widget.boat["id"],
          "race_date": todayDate,
        },
      );
      setState(() {
        boatStart = res.data as Map<String, dynamic>;
      });
    } catch (_) {
      // 404 means no start time set yet — that is fine, we just don't show it
      setState(() {
        boatStart = null;
      });
    }
  }

  // Load start sequence for this boat's class

  // Calls GET /start-sequence/status for the boat's class:
  // - If the RO has fired the 5-minute gun, we get sequence_start_utc and prep_flag and server_time_utc.
  // - If not, we fall through to showing the scheduled start time.
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

      // Extract the UTC timestamp when the 5-minute gun was fired [F31]
      final startStr = res["sequence_start_utc"] as String;
      // Parse the ISO 8601 string into a DateTime object in UTC [F31]
      final seqStart = DateTime.parse(startStr).toUtc();

      setState(() {
        startSequence = res;

        // Only set sequenceStartUtc the first time (prevents resetting every poll)
        if (sequenceStartUtc == null) {
          sequenceStartUtc = seqStart;
        }
      });
    } catch (e) {
      // If no sequence exists yet, clear sequence state.
      // The UI will fall through to showing the scheduled start time
      // (if one exists) or nothing at all.
      setState(() {
        startSequence = null;
        startSequenceError = null;
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
    if (seconds == null) return "\u2014";

    // Convert the raw seconds into a Duration object for easy extraction [F32]
    final d = Duration(seconds: seconds.toInt());

    // Helper function to zero-pad a number to 2 digits (e.g. 5 → "05") [F8]
    String two(int n) => n.toString().padLeft(2, '0');

    // Extract hours, minutes, and seconds components from the Duration [F32]
    final h = two(d.inHours);
    final m = two(d.inMinutes.remainder(60));
    final s = two(d.inSeconds.remainder(60));

    // Return formatted string "HH:MM:SS"
    return "$h:$m:$s";
  }

  // Format Countdown - "MM:SS" For Start Sequence

  // Converts a Duration to MM:SS for the start countdown.
  // If negative, clamps to 00:00 after the start.
  String _formatCountdown(Duration d) {
    // Clamp negative durations to zero (race has started) [F32]
    final totalSeconds = d.inSeconds < 0 ? 0 : d.inSeconds;
    // Integer division to extract whole minutes from total seconds [F8]
    final minutes = totalSeconds ~/ 60;
    // Modulo to get the remaining seconds after extracting minutes [F8]
    final seconds = totalSeconds % 60;
    // Zero-pad both values to always show two digits (e.g. "05:09") [F8]
    return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }

  // Format Elapsed Racing Time - "HH:MM:SS"
  //
  // Converts a Duration to HH:MM:SS for the elapsed racing timer.
  // Used after the start to show how long the competitor has been racing.
  // Clamps negative values to 0 to handle any clock drift between client and server.
  // Reference: Dart Duration class for time arithmetic [F32]
  // Reference: Dart truncating division operator (~/) for integer division [F8]
  // Reference: String.padLeft for zero-padding single digits [F8]
  String _formatElapsed(Duration d) {
    // Clamp negative durations to zero (handles clock drift) [F32]
    final totalSeconds = d.inSeconds < 0 ? 0 : d.inSeconds;
    // Extract hours by dividing total seconds by 3600 (seconds per hour) [F8]
    final hours = totalSeconds ~/ 3600;
    // Extract minutes from the remainder after removing hours [F8]
    final minutes = (totalSeconds % 3600) ~/ 60;
    // Extract remaining seconds after removing hours and minutes [F8]
    final seconds = totalSeconds % 60;
    // Zero-pad each component to two digits and join with colons [F8]
    return "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }

  // Determine which phase of the sequence we are in (5 / 4 / 1 / STARTED)
  // Returns a human-readable label for the current countdown phase.
  // The phases follow the World Sailing 5-4-1-Go start sequence. [F32]
  String _sequencePhaseLabel(Duration timeToStart) {
    // If countdown has reached zero or gone negative, the race has started
    if (timeToStart <= Duration.zero) return "STARTED";
    // More than 4 minutes remaining = we are in the 5-minute signal phase
    if (timeToStart > const Duration(minutes: 4)) return "5 minute signal";
    // More than 1 minute remaining = we are in the 4-minute / running phase
    if (timeToStart > const Duration(minutes: 1)) return "4 minute / running";
    // Less than 1 minute remaining = final approach to the start line
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

    // Search through the class results to find this boat's own row [F29][F30]
    // Used to determine if the user's boat has a result to highlight
    Map<String, dynamic>? myRow;
    for (final r in classResults) {
      // Convert the dynamic map to a strongly-typed Map for field access [F8]
      final m = Map<String, dynamic>.from(r as Map);
      if (m["boat_id"] == myBoatId) {
        myRow = m;
        break; // Found our boat, no need to keep searching
      }
    }

    // allFinished indicates whether every boat in the class has:
    // - a finish_time
    // - a corrected_seconds value

    // We keep this logic in case we want to change the UI if the race is fully finished
    final allFinished = classResults.isNotEmpty &&
        classResults.every(
          (r) =>
              (r as Map)["finish_time"] != null &&
              (r)["corrected_seconds"] != null,
        );

    // Scaffold = main page layout structure (app bar and body)
    return Scaffold(
      appBar: AppBar(
        // Title includes the boat's sail number for clarity
        title: Text("Your Boat: ${boat['sail_no']}"),
      ),

      // Padding around entire page body
      body: Padding(
        padding: const EdgeInsets.all(20),

        // We use a ListView so content scrolls if it doesn't fit on screen
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
                    // Row with boat name and check-in status chip
                    // The Chip gives the competitor visual confirmation that
                    // their check-in was received by the backend.
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Boat Name: ${boat['name']}",
                          style: const TextStyle(fontSize: 18),
                        ),
                        if (isCheckedIn)
                          const Chip(
                            label: Text("Checked in"),
                            avatar: Icon(Icons.check_circle, size: 18, color: Colors.white),
                            backgroundColor: Colors.green,
                          ),
                      ],
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

            // Race Status Card
            
            // This section shows one of three states:
            //  1. BEFORE 5-min gun: Scheduled start time (e.g. "18:30")
            //  2. DURING countdown: Live countdown (05:00 - 00:00)
            //  3. AFTER start: Elapsed racing time ticking up (e.g. "00:12:34")
            
            // It is shown per-class, so boats only see the sequence for their own class.
            loadingStartSequence
                ? const Center(child: CircularProgressIndicator())
                : _buildRaceStatusCard(),

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
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      )
                    // If course exists, build the full "Today's course" card
                    : _buildRaceCard(),

            const SizedBox(height: 16),

            // Class results table

            // Shows only results for this boat's class
            // The user's own boat is highlighted in bold in the table
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

  // Build Race Status Card
  
  // Unified card that shows the appropriate state based on a three-state
  // finite state machine pattern. The state is determined by checking
  // conditions in priority order (STATE 3 first, then 2, then 1):
  
  //  STATE 1 — Before 5-minute gun: scheduled start time from race officer
  //            Shows per-class time if set, otherwise falls back to general course time [F15]
  //  STATE 2 — During countdown: live MM:SS countdown (5-4-1-Go) [F32][F31]
  //  STATE 3 — After start: elapsed racing time HH:MM:SS ticking up [F32][F31]
  //            Freezes to recorded elapsed_seconds when admin finishes the boat [F8]
  
  // Reference: Flutter Card widget for Material Design container [F19]
  // Reference: Conditional widget rendering in Column children [F15]
  // Reference: DateTime.difference for countdown and elapsed calculation [F31]
  Widget _buildRaceStatusCard() {

    // Check if we have an active start sequence 
    // Reference: DateTime.parse for ISO 8601 UTC string from backend [F31]
    // Reference: Duration addition to compute race start moment [F32]
    // Reference: DateTime.difference for countdown calculation [F31]
    if (startSequence != null) {
      // Parse when the 5-minute gun was fired (UTC timestamp from backend) [F31]
      final seqStartUtc =
          DateTime.parse(startSequence!["sequence_start_utc"] as String).toUtc();
      // The actual race start moment is 5 minutes after the gun was fired [F32]
      final startMomentUtc = seqStartUtc.add(const Duration(minutes: 5));
      // Get current time in UTC for consistent comparison with server times [F31]
      final nowUtc = DateTime.now().toUtc();
      // Calculate how much time remains until the race starts [F31]
      // Positive = countdown still running, negative or zero = race has started
      final timeToStart = startMomentUtc.difference(nowUtc);

      // STATE 3: Race has started — show elapsed timer
      if (timeToStart.inSeconds <= 0) {

        // Check if this boat has been finished by the admin.
        // boatStart is polled every 10 seconds via _loadBoatStart() [F23][D1][D3]
        // When the admin taps "Finish", the backend sets finish_time and
        // computes elapsed_seconds. We detect this by checking finish_time != null.
        // Reference: Dart null-aware operator for safe field access [F8]
        final bool boatFinished = boatStart != null && boatStart!["finish_time"] != null;
        // Will hold either the live elapsed time or the frozen finish time [F32]
        final Duration elapsed;
        // Card header text — changes between "Racing" and "Finished"
        final String title;
        // Card label text — changes between "Time racing" and "Your finish time"
        final String subtitle;

        if (boatFinished) {
          // Boat has been finished — show fixed elapsed time from the database.
          // Uses elapsed_seconds recorded by backend (official race time) so it
          // matches exactly what appears in the results table.
          // Reference: Duration constructor from integer seconds [F32]
          // Read elapsed_seconds from backend; default to 0 if null [F8]
          final recordedSeconds = boatStart!["elapsed_seconds"] as int? ?? 0;
          // Create a fixed Duration from the recorded seconds [F32]
          elapsed = Duration(seconds: recordedSeconds);
          // Update card header to show "Finished" instead of "Racing"
          title = "Finished \u2014 ${widget.boat["class_name"]}";
          // Update card label to show "Your finish time" instead of "Time racing"
          subtitle = "Your finish time";
        } else {
          // Boat still racing — show live ticking elapsed time.
          // Computed as: now (UTC) minus the moment the race started (5 min after sequence start).
          // Updates every second via tickTimer calling setState. [F23][F36]
          // Reference: DateTime.difference for elapsed calculation [F31]
          // Compute live elapsed time: current UTC time minus the race start moment [F31]
          elapsed = nowUtc.difference(startMomentUtc);
          // Show "Racing" as the card header while the boat is still on the water
          title = "Racing \u2014 ${widget.boat["class_name"]}";
          // Show "Time racing" as the card label
          subtitle = "Time racing";
        }

        return Card(
          color: AppTheme.primary,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // Large elapsed time HH:MM:SS
                // Ticks every second while racing; freezes when finished
                Center(
                  child: Text(
                    _formatElapsed(elapsed),
                    style: const TextStyle(
                      fontSize: 52,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 6),

                Center(
                  child: Text(
                    subtitle,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      // STATE 2: Countdown is active — show live countdown 
      // This card is shown when the 5-minute gun has been fired but
      // the countdown has not yet reached zero. [F19][F20]
      return Card(
        color: AppTheme.primary,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Start sequence \u2014 ${widget.boat["class_name"]}",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

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

              // Phase label (5 minute / 4 minute / 1 minute)
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

    // STATE 1: No active sequence — show scheduled start time 
    
    // Two-tier fallback logic:
    //  1. Per-class start time from race_starts table (set via "Set Start" on admin page)
    //     This is class-specific, e.g. White Sail 1 at 11:00, White Sail 2 at 11:10
    //  2. General course start time from race_day_settings (set via "Select Course")
    //     This is the same for all classes — used as a fallback before class times are set
    //  3. Nothing — no times set yet, return SizedBox.shrink [F33]
    
    // The subtitle changes to indicate which time source is being shown,
    // so the competitor knows whether this is their specific class time
    // or the general first-start time for the whole race.
    // Reference: Conditional widget rendering in Column children [F15]
    // Reference: Dart nullable types and null checks [F8]
    // Reference: String.substring to trim "HH:MM:SS" to "HH:MM" [F8]

    // Time to display — will be set from per-class or course-level start time [F8]
    String? displayTime;
    // Subtitle text shown below the time — changes based on which source is used
    String subtitle = "Scheduled start";

    if (boatStart != null && boatStart!["start_time"] != null) {
      // Per-class time exists — show that (most accurate)
      // start_time comes as "HH:MM:SS" from the backend
      final startTimeStr = boatStart!["start_time"] as String;
      // Strip seconds: "HH:MM:SS" - "HH:MM" for cleaner display
      displayTime = startTimeStr.length >= 5
          ? startTimeStr.substring(0, 5)
          : startTimeStr;
      subtitle = "Your class start";
    } else if (currentCourse != null && currentCourse!["start_time"] != null) {
      // No per-class time yet, but course has a general start time — show as fallback
      displayTime = currentCourse!["start_time"] as String;
      subtitle = "Scheduled start";
    }

    // If we have a time to display (from either source), render the card [F19]
    if (displayTime != null) {
      return Card(
        color: AppTheme.primary,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${widget.boat["class_name"]}",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // Large scheduled start time
              Center(
                child: Text(
                  displayTime,
                  style: const TextStyle(
                    fontSize: 52,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 6),

              Center(
                child: Text(
                  subtitle,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // No data at all — no start time set, no sequence fired 
    // Don't clutter the page; return empty space.
    return const SizedBox.shrink();
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
            // Show the per-class start time if the admin has set one,
            // otherwise show the general course start time labelled as "First start"
            // so the competitor isn't confused by two different times on the page.
            // This uses Dart's inline if/else inside a Column children list.
            // Reference: Conditional widget rendering (collection if) [F15]
            // Reference: String.substring to trim "HH:MM:SS" to "HH:MM" for display [F8]
            // Reference: Dart null-aware checks on nullable Map fields [F8]
            if (boatStart != null && boatStart!["start_time"] != null)
              Text("Your start: ${(boatStart!["start_time"] as String).substring(0, 5)}")
            else
              Text("First start: $startTime"),

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
            style: const TextStyle(color: Colors.white),
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
                // Styled white and bold so they stand out against the blue card background [A1]
                columns: const [
                  DataColumn(label: Text("Pos", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("Sail No", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("Boat", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("Elapsed", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("Corrected", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text("Code", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
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
                      DataCell(Text((row["result_code"] as String?) ?? (row["code"] as String?) ?? "", style: style)),
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


// References — This file uses the following sources (full details in
// the Iteration Documentation reference list)

// Flutter / Dart:
// [F1] Google LLC, 2025. Flutter: Introduction to widgets.
// [F3] Google LLC, 2025. Scaffold class.
// [F5] Google LLC, 2025. ListView & ListTile.
// [F6] Google LLC, 2025. DataTable class.
// [F7] Google LLC, 2025. Dialogs & SnackBar.npx vercel 
// [F8] Google LLC, 2025. Dart language tour: async, futures & Duration.
// [F15] Google LLC, 2025. Dart language: collection if / list literals.
// [F19] Google LLC, 2025. Card class.
// [F20] Google LLC, 2025. Column class.
// [F23] Dart Team, 2025. Timer class and Timer.periodic.
// [F31] Dart Team, 2025. DateTime class - parse, toUtc, difference, isAfter.
// [F32] Dart Team, 2025. Duration class - arithmetic, comparison, inSeconds.
// [F33] Google LLC, 2025. SizedBox.shrink constructor.
// [F34] Google LLC, 2025. debugPrint property.
// [F35] Dart Team, 2025. Set class, unordered collection of unique values.
// [F36] Google LLC, 2025. StatefulWidget lifecycle, initState, dispose, mounted.
// [F37] Google LLC, 2025. Chip class.
// [F38] Google LLC, 2025. WidgetsBinding.addPostFrameCallback.

// Dio HTTP:
// [D1] Flutter Community, 2025. Dio package for Dart/Flutter.
// [D3] Flutter Community, 2025. Dio request methods (GET, POST, DELETE).

// Backend:
// [B1] Tiangolo, S., 2024. FastAPI – Query Parameters.
// [B12] SQLAlchemy, 2026. ORM-Enabled INSERT, UPDATE, DELETE statements.


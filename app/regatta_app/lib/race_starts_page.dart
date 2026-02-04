// This screen is used by the Race Officer (admin) to:
//  Set class start times (e.g., all White Sail 1 boats start at 18:30:00)
//  Record a finish time for each individual boat
//  View start, finish, and elapsed times for every boat
//  Reset the day’s timings if something goes wrong

// This page interacts with the backend via FastAPI endpoints such as:
//   /boats
//   /race-starts
//   /race-starts/class-start
//   /race-finish
//   /race-day

// The UI automatically groups boats by class and allows fast race-day operation

import 'package:flutter/material.dart'; // Flutter widgets and layout tools
import 'package:dio/dio.dart'; // HTTP client for backend communication

// Stateful widget because the page updates dynamically:
// - loading boats
// - updating class start times
// - recording individual finishes
// - refreshing after POST requests
class RaceStartsPage extends StatefulWidget {
  const RaceStartsPage({super.key});

  @override
  State<RaceStartsPage> createState() => _RaceStartsPageState();
}

// The State class holds all mutable data used by this screen
class _RaceStartsPageState extends State<RaceStartsPage> {
  // HTTP client that automatically talks to FastAPI at localhost:8000
  final dio = Dio(BaseOptions(baseUrl: "http://127.0.0.1:8000"));

  // Full list of boats fetched from backend (/boats)
  List<dynamic> boats = [];

  // Mapping of boat_id - timing record (start_time, finish_time, elapsed_seconds)
  // Allows instant lookup of timing data for each boat
  Map<int, Map<String, dynamic>> startsByBoatId = {};

  // Controls spinner visibility while data loads
  bool loading = true;

  // Error text if something goes wrong with loading
  String? error;

  // Today's date ("YYYY-MM-DD") is used as API parameter for all race-related endpoints
  // Reference: Dart DateTime and string formatting (padLeft) [F8]
  late String todayDate;


  // BOAT STATE HELPERS (Started/Finished)

  // Returns true if this boat has a start record for today and has a start_time set.
  // Using startsByBoatId (boat_id - timing record) to check race-day status.
  bool _hasStarted(Map<String, dynamic> boat) {
    // boat["id"] is the database ID for this boat
    final boatId = boat["id"] as int;

    // Look up today's timing record for this boat
    final startRecord = startsByBoatId[boatId];

    // If there is a record and start_time is not null, the boat has started
    return startRecord != null && startRecord["start_time"] != null;
  }

  // Returns true if this boat has a finish_time set for today.
  bool _hasFinished(Map<String, dynamic> boat) {
    final boatId = boat["id"] as int;
    final startRecord = startsByBoatId[boatId];

    // If finish_time exists, the boat is finished
    return startRecord != null && startRecord["finish_time"] != null;
  }

  // List of boats that are currently "in progress":
  // - must have started
  // - must NOT have finished
  List<Map<String, dynamic>> get inProgressBoats {
    return boats
        // Convert each dynamic boat into a Map<String, dynamic>
        .map((b) => Map<String, dynamic>.from(b as Map))
        // Keep only boats that have started and not finished
        .where((boat) => _hasStarted(boat) && !_hasFinished(boat))
        .toList();
  }

  // List of boats that are finished:
  // - must have a finish_time
  List<Map<String, dynamic>> get finishedBoats {
    return boats
        .map((b) => Map<String, dynamic>.from(b as Map))
        .where((boat) => _hasFinished(boat))
        .toList();
  }

  /// initState runs once when the widget appears
  @override
  void initState() {
    super.initState();

    // Build today's date as a formatted string
    final now = DateTime.now();
    todayDate =
        "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    // Load boats + timing records
    // Reference: multiple Dio GET requests and mapping JSON to Dart Maps [D1][F8]
    _loadData();
  }

  // LOAD BOATS AND START/FINISH TIMES FOR TODAY

  // Loads:
  //   1) List of all boats (/boats)
  //   2) All start/finish records for today (/race-starts?race_date=...)
  Future<void> _loadData() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      // Step 1: Fetch all boats from backend
      final boatsRes = await dio.get("/boats");
      boats = boatsRes.data as List<dynamic>;

      // Step 2: Fetch timing data for the selected race date
      final startsRes = await dio.get(
        "/race-starts",
        queryParameters: {"race_date": todayDate},
      );

      final startsList = startsRes.data as List<dynamic>;

      // Convert list → Map keyed by boat_id for fast access
      startsByBoatId = {
        for (final s in startsList)
          s["boat_id"] as int: Map<String, dynamic>.from(s as Map)
      };

      setState(() {}); // Refresh UI
    } catch (e) {
      setState(() {
        error = "Failed to load data";
      });
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  // GET UNIQUE CLASS LIST (White Sail 1, White Sail 2, etc.)

  // Extracts a sorted list of unique boat class names
  // Reference: Dart Set, List, and collection operations [F8]
  List<String> get classNames {
    final set = <String>{};

    for (final b in boats) {
      final m = b as Map<String, dynamic>;
      set.add(m["class_name"] as String);
    }

    final list = set.toList()..sort(); // Sort alphabetically
    return list;
  }

  // SET CLASS START TIME (ALL BOATS IN THAT CLASS)

  // Lets race officer define start time for a class:
  // - Opens a time entry dialog
  // - Sends POST /race-starts/class-start
  Future<void> _setClassStart(String className) async {
    // Default start time = current time rounded to minute
    // Reference: showDialog for input + Dio POST [F7][D1]
    final now = DateTime.now();
    final defaultTime =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:00";

    final controller = TextEditingController(text: defaultTime);

    // Confirmation dialog
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Set start for $className"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: "Start time (HH:MM:SS)",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Set"),
          ),
        ],
      ),
    );

    // Cancelled dialog
    if (ok != true) return;

    try {
      // Convert HH:MM:SS into the ISO-style time format your FastAPI endpoint expects
      // Example: "18:30:00" -"18:30:00.000Z"
      final startTimeIso = "${controller.text.trim()}.000Z";

      // POST request to backend
      await dio.post("/race-starts/class-start", data: {
        "class_name": className,
        "race_date": todayDate,
        "start_time": startTimeIso,
      });

      // Reload data after modification
      await _loadData();

      // Success feedback (show what the user typed, not the ISO string)
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Start for $className set to ${controller.text.trim()}",
            ),
          ),
        );
      }
    } catch (e) {
      // Error feedback
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to set start for $className"),
          ),
        );
      }
    }
  }

  // RECORD INDIVIDUAL BOAT FINISH TIME

  // Records the exact moment a boat crosses the finish line
  // Reference: capturing current time, string formatting, HTTP POST [F8][D1]


  // FINISH A BOAT (with OCS and Penalty options)


  // This replaces the old _finishBoat() method.
  // When the race officer taps "Finish now", shows a bottom sheet that allows:
  //  - marking the boat as OCS
  //  - entering a penalty in seconds
  // Then we post to /race-finish with finish_time + options.
  Future<void> _finishBoatWithOptions(Map<String, dynamic> boat) async {
    final boatId = boat["id"] as int;

    // Look up this boat's timing record for today
    final startRecord = startsByBoatId[boatId];

    // Safety check: must have a start time before you can finish
    if (startRecord == null || startRecord["start_time"] == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("No start time recorded yet for ${boat['sail_no']}."),
          ),
        );
      }
      return;
    }

    // Local values controlled by the bottom sheet UI
    bool ocs = false;

    // Text controller for penalty seconds input
    final penaltyController = TextEditingController(text: "0");

    // Show a bottom sheet (clean UI) to capture finish options
    // Reference: showModalBottomSheet for collecting user input in a modal sheet [F9]
    // Reference: StatefulBuilder for local state inside modal widgets [F10]

    final confirmed = await showModalBottomSheet<bool>(
      context: context,

      // Allows the sheet to move up when keyboard opens
      isScrollControlled: true,

      // Rounded top corners for a nicer look
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),

      builder: (context) {
        return Padding(
          // Add padding and account for keyboard so fields aren’t hidden
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            // Shrinks to fit content
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sheet heading
              Text(
                "Finish options",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),

              // Uses StatefulBuilder so the switch can update inside the sheet
              // Reference: SwitchListTile widget for boolean toggles (OCS on/off) [F11]

              StatefulBuilder(
                builder: (context, setModalState) {
                  return SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Mark as OCS"),
                    value: ocs,
                    onChanged: (v) => setModalState(() => ocs = v),
                  );
                },
              ),

              // Penalty entry (seconds)
              // Reference: TextField numeric input and keyboardtype for number entry [F12]
              TextField(
                controller: penaltyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Penalty (seconds)",
                  hintText: "0",
                ),
              ),

              const SizedBox(height: 16),

              // Action buttons
              // Reference: OutlinedButton/ElevatedButton for actions (Cancel/Confirm) [F13]
              Row(
                children: [
                  // Cancel button
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text("Cancel"),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Confirm button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text("Record finish"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    // If they cancel the sheet, do nothing
    if (confirmed != true) return;

    // Convert penalty input to int safely
    final penaltySeconds = int.tryParse(penaltyController.text.trim()) ?? 0;

    // Capture the exact finish time "now"
    final now = DateTime.now();
    final finishTime =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";

    try {
      // POST finish and options to backend
      await dio.post("/race-finish", data: {
        "boat_id": boatId,
        "race_date": todayDate,
        "finish_time": finishTime,

        // Extra fields for penalties/OCS
        "ocs": ocs,
        "penalty_seconds": penaltySeconds,
      });

      // Reload the boats and timings so UI updates
      await _loadData();

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Finish recorded for ${boat['sail_no']} at $finishTime"),
          ),
        );
      }
    } catch (e) {
      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to record finish")),
        );
      }
    }
  }

  // RESET TODAY’S TIMINGS (ALL OR PER CLASS)

  // DELETE all timing data for a class OR all classes for today's race
  // Reference: RESTful DELETE with query parameters using Dio [D1]
  Future<void> _resetToday({String? className}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Reset today's timings"),
        content: Text(
          className == null
              ? "This will clear ALL start/finish times for today. Are you sure?"
              : "This will clear ALL start/finish times for $className today. Are you sure?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Reset"),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await dio.delete(
        "/race-day",
        queryParameters: {
          "race_date": todayDate,
          if (className != null) "class_name": className,
        },
      );

      await _loadData();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              className == null
                  ? "Cleared all timings for today"
                  : "Cleared all timings for $className today",
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to reset timings")),
        );
      }
    }
  }

  // FORMAT SECONDS - HH:MM:SS (used for elapsed time)

  String _formatDuration(int? seconds) {
    // Reference: Dart Duration to HH:MM:SS formatting [F8]
    if (seconds == null) return "—";

    final d = Duration(seconds: seconds);

    String two(int n) => n.toString().padLeft(2, '0');

    final h = two(d.inHours);
    final m = two(d.inMinutes.remainder(60));
    final s = two(d.inSeconds.remainder(60));

    return "$h:$m:$s";
  }

  // BUILD UI
  // Reference: Wrap layout widget & buttons for class controls [F1]
  // Reference: ListView.builder showing per-boat timing info [F5]
  // Reference: Flutter Card & Material layout widgets [F19]
  // Reference: Flutter Column & alignment for vertical layout [F20]


  // UI HELPER: Build a boat card in a consistent clean style

  Widget _buildBoatCard(
    Map<String, dynamic> boat, {
    required bool showFinishButton,
  }) {
    // Get the timing record for this boat for today (if any)
    final startRecord = startsByBoatId[boat["id"]];

    // Extract timing values safely
    final startTime =
        startRecord != null ? startRecord["start_time"] as String? : null;
    final finishTime =
        startRecord != null ? startRecord["finish_time"] as String? : null;
    final elapsedSeconds =
        startRecord != null ? startRecord["elapsed_seconds"] as int? : null;

    return Card(
      // Reference: Card widget for grouping related content visually [F19]
      // Rounded corners for a cleaner look
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        // Boat label
        // Reference: ListTile widget for standard list row layout [F5]

        title: Text("${boat['sail_no']} – ${boat['name']}"),

        // Timing details
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Class: ${boat['class_name']}"),
            Text("Start: ${startTime ?? '—'}"),
            Text("Finish: ${finishTime ?? '—'}"),
            Text("Elapsed: ${_formatDuration(elapsedSeconds)}"),
          ],
        ),

        // Right side of the tile:
        // - If boat is in progress - show Finish button
        // - If boat is finished - show a simple check icon
        trailing: showFinishButton
                // Reference: Conditional UI rendering using Dart collection-if [F15]
                // Reference: ElevatedButton for primary actions, Icon for status display [F13][F21]

            ? ElevatedButton(
                // Open the "Finish options" sheet so the RO can mark OCS / penalty
                onPressed: () => _finishBoatWithOptions(boat),
                child: const Text("Finish now"),
              )
            : const Icon(Icons.check_circle_outline),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Title includes today's date to avoid confusion
      appBar: AppBar(
        title: Text("Start & Finish – $todayDate"),
      ),

      // Page padding
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? Center(child: Text(error!))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Reset timings for entire day
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => _resetToday(),
                          icon: const Icon(Icons.refresh),
                          label: const Text("Reset today's timings"),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Section title
                      Text(
                        "Set class start times",
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),

                      // Buttons for each class
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final className in classNames)
                            ElevatedButton(
                              onPressed: () => _setClassStart(className),
                              child: Text(className),
                            ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Boat list split into two clean sections:
                      // 1) In progress (only boats that started and have NOT finished)
                      // 2) Finished (boats that have finished)
                      // Reference: ListView for scrollable lists of widgets [F5]

                      Expanded(
                        child: ListView(
                          children: [
                            Text(
                              "In progress",
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),

                            // If there are no boats in progress, show a helpful message
                            if (inProgressBoats.isEmpty)
                              const Text("No boats currently in progress.")
                            else
                              // Build a card for each boat that is in progress
                              ...inProgressBoats.map(
                                (boat) => _buildBoatCard(
                                  boat,
                                  showFinishButton: true,
                                ),
                              ),

                            const SizedBox(height: 16),

                            Text(
                              "Finished",
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),

                            // If no boats are finished, show a message
                            if (finishedBoats.isEmpty)
                              const Text("No boats finished yet.")
                            else
                              // Build a card for each finished boat (no finish button)
                              ...finishedBoats.map(
                                (boat) => _buildBoatCard(
                                  boat,
                                  showFinishButton: false,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

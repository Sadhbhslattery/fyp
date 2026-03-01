// Race Starts Page

// This screen allows the Race Officer to:
// Set class start times (stored in DB via POST /race-starts/class-start)
// Fire the 5-minute gun (stored in DB via POST /start-sequence/start)
// View a live countdown and preparatory flag (read from DB via GET /start-sequence/status)
// See boats currently racing and finished, grouped by class (boats and race-start rows joined in UI)
// Record finishes (writes finish_time and options to DB via POST /race-finish)
// See which competitors have checked in for today's race (read from DB via GET /check-ins)
// Reset all timing and check-in data for today (DELETE /race-day with confirmation)
// Refresh data manually (Refresh button) or by pull-to-refresh

// DATABASE IN PLAIN ENGLISH
// This page joins two tables in the UI:
// boats table: Permanent boat details (id, sail_no, name, class_name)
// race_starts table: Per-boat, per-day timing (race_date, start_time, finish_time, elapsed_seconds)
// check_ins table: Per-boat, per-day confirmation that the competitor is racing today
// The page:
// 1. GET /boats - loads all boats
// 2. GET /race-starts?race_date=... - loads today's timing rows
// 3. GET /check-ins?race_date=... - loads today's check-in confirmations
// 4. Creates map: startsByBoatId[boat_id] = timing_record
// 5. UI determines state by checking timing record:
// Not started: start_time is in future or null
// In progress: now >= start_time AND finish_time == null
// Finished: finish_time != null

// Two-Timer Countdown Architecture
// Similar to user start sequence page:
// Poll timer (2 seconds): Fetches latest sequence from backend
// Tick timer (1 second): Updates countdown locally
// Shows preparatory flag until 1-minute mark
// Displays MM:SS countdown

// _loadData(): GET /boats, GET /race-starts, and GET /check-ins, builds startsByBoatId map
// _parseStartDateTimeUtc(): Converts "HH:MM:SS" string to DateTime for comparisons
// _hasStarted(boat): Returns true if now >= scheduled start time
// _hasFinished(boat): Returns true if finish_time != null
// _inProgress(boat): Returns _hasStarted && !_hasFinished
// _setClassStart(className): Dialog for time input, POST /race-starts/class-start
// _fireFiveMinuteGun(className): Calls StartSequenceApi.start()
// _finishBoatWithOptions(boat): Bottom sheet with OCS toggle and penalty input, POST /race-finish
// _checkedInForClass(className): Returns list of check-in records for a given class
// _resetRaceDay(): Confirmation dialog then DELETE /race-day to wipe today's data


import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import 'services/start_sequence_api.dart';


final StartSequenceApi startSeqApi = StartSequenceApi("https://web-production-9fd2e3.up.railway.app");

class RaceStartsPage extends StatefulWidget {
  const RaceStartsPage({super.key});

  @override
  State<RaceStartsPage> createState() => _RaceStartsPageState();
}

class _RaceStartsPageState extends State<RaceStartsPage> {
  final dio = Dio(BaseOptions(baseUrl: "https://web-production-9fd2e3.up.railway.app"));

  List<dynamic> boats = [];
  Map<int, Map<String, dynamic>> startsByBoatId = {};

  // Holds today's check-in records fetched from GET /check-ins?race_date=...
  // Each entry contains: boat_id, sail_no, name, class_name, checked_in_at
  List<Map<String, dynamic>> checkIns = [];

  bool loading = true;
  String? error;

  late String todayDate;



  // Start Sequence 

  StartSequenceStatusDto? startSequence;
  String? selectedSequenceClass;
  String? startSequenceError;

  Timer? pollTimer;
  Timer? tickTimer;
  DateTime? serverNowUtc;

  // ── Auto-fire tracking ──
  // Keeps track of which classes have already had their 5-minute gun fired
  // (either manually by tapping "5-min" or automatically by the auto-fire timer).
  // Prevents the same class from being fired twice.
  final Set<String> _autoFiredClasses = {};

  // Timer that checks every second whether any class is 5 minutes away from
  // its scheduled start time. If so, it automatically fires the 5-minute gun.
  Timer? _autoFireTimer;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    todayDate =
        "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    _loadData();
  }

  @override
  void dispose() {
    pollTimer?.cancel();
    tickTimer?.cancel();
    _autoFireTimer?.cancel();
    super.dispose();
  }


  // Load Data (boats, race-start rows and check-ins)

  Future<void> _loadData() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final boatsRes = await dio.get("/boats");
      boats = boatsRes.data as List<dynamic>;

      final startsRes = await dio.get(
        "/race-starts",
        queryParameters: {"race_date": todayDate},
      );

      final list = startsRes.data as List<dynamic>;

      startsByBoatId = {
        for (final s in list) (s["boat_id"] as int): Map<String, dynamic>.from(s as Map)
      };

      // Load today's check-ins from the backend
      // Each check-in record contains boat_id, sail_no, name, class_name, checked_in_at
      final checkInsRes = await dio.get(
        "/check-ins",
        queryParameters: {"race_date": todayDate},
      );
      checkIns = (checkInsRes.data as List<dynamic>)
          .map((c) => Map<String, dynamic>.from(c as Map))
          .toList();

      // Start the auto-fire timer now that we know each class's start time.
      // Safe to call repeatedly — it cancels the previous timer first.
      _startAutoFireTimer();

      // If we don't already have a sequence selected (e.g. page was re-entered),
      // probe the backend for any active countdown so we can restore it.
      if (selectedSequenceClass == null) {
        await _restoreActiveSequence();
      }

      setState(() {});
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


  // Class List (derived from boats table)

  List<String> get classNames {
    final set = <String>{};
    for (final b in boats) {
      final m = Map<String, dynamic>.from(b as Map);
      set.add(m["class_name"] as String);
    }
    final list = set.toList()..sort();
    return list;
  }


  // Check-In Helpers

  // Returns the list of check-in records for a given class name
  // Used to display checked-in boats as chips in the race officer UI
  List<Map<String, dynamic>> _checkedInForClass(String className) {
    return checkIns.where((c) => c["class_name"] == className).toList();
  }


  // Start Time parsing (IMPORTANT)

  // Backend gives start_time as "HH:MM:SS"
  // We turn it into a DateTime for today and treat it as UTC for comparisons.

  DateTime? _parseStartDateTimeUtc(String? startTimeStr) {
    if (startTimeStr == null) return null;

    final t = startTimeStr.trim();
    final iso = "${todayDate}T$t";
    final dt = DateTime.tryParse(iso);
    return dt?.toUtc();
  }

  // Find the scheduled start time for a boat (from race_starts row)
  DateTime? _scheduledStartUtcForBoat(Map<String, dynamic> boat) {
    final boatId = boat["id"] as int;
    final record = startsByBoatId[boatId];
    final startStr = record?["start_time"] as String?;
    return _parseStartDateTimeUtc(startStr);
  }

  // For the UI header: show the scheduled start time per CLASS (all boats share it)
  String _classStartTimeLabel(String className) {
    for (final b in boats) {
      final boat = Map<String, dynamic>.from(b as Map);
      if (boat["class_name"] == className) {
        final dt = _scheduledStartUtcForBoat(boat);
        if (dt == null) return "Start: not set";
        // show as HH:MM:SS (local display)
        final local = dt.toLocal();
        final hh = local.hour.toString().padLeft(2, '0');
        final mm = local.minute.toString().padLeft(2, '0');
        final ss = local.second.toString().padLeft(2, '0');
        return "Start: $hh:$mm:$ss";
      }
    }
    return "Start: not set";
  }


  // Boat State Logic (filtered by time)


  // Boat is started only when now - scheduled start time
  bool _hasStarted(Map<String, dynamic> boat) {
    final scheduled = _scheduledStartUtcForBoat(boat);
    if (scheduled == null) return false;
    return DateTime.now().toUtc().isAfter(scheduled) ||
        DateTime.now().toUtc().isAtSameMomentAs(scheduled);
  }

  bool _hasFinished(Map<String, dynamic> boat) {
    final boatId = boat["id"] as int;
    final record = startsByBoatId[boatId];
    return record != null && record["finish_time"] != null;
  }

  bool _inProgress(Map<String, dynamic> boat) => _hasStarted(boat) && !_hasFinished(boat);

  // Boats grouped by class
  List<Map<String, dynamic>> _boatsForClass(String className) {
    return boats
        .map((b) => Map<String, dynamic>.from(b as Map))
        .where((b) => b["class_name"] == className)
        .toList();
  }

  List<Map<String, dynamic>> _inProgressForClass(String className) =>
      _boatsForClass(className).where(_inProgress).toList();

  List<Map<String, dynamic>> _finishedForClass(String className) =>
      _boatsForClass(className).where(_hasFinished).toList();


  // ── Restore Active Sequence on Page Load ──
  //
  // When the admin navigates away and comes back, the in-memory state
  // (selectedSequenceClass, startSequence, timers) is lost because
  // initState creates a fresh widget. This method probes the backend
  // for each class to see if a countdown is still active (time remaining > 0).
  // If found, it restores the countdown card so the admin doesn't lose
  // visibility of a running sequence.
  Future<void> _restoreActiveSequence() async {
    for (final className in classNames) {
      try {
        final res = await startSeqApi.getStatus(
          className: className,
          raceDate: todayDate,
        );

        // Check if this sequence still has time remaining
        final dto = StartSequenceStatusDto.fromMap(res);
        final startMoment = dto.sequenceStartUtc.add(const Duration(minutes: 5));
        final remaining = startMoment.difference(DateTime.now().toUtc());

        if (remaining.inSeconds > 0) {
          // Found an active sequence — restore it
          setState(() {
            selectedSequenceClass = className;
            _autoFiredClasses.add(className); // don't re-fire
          });
          _startSequenceTimers();
          debugPrint("Restored active sequence for $className (${remaining.inSeconds}s remaining)");
          return; // only restore the first active one
        }
      } catch (_) {
        // No sequence for this class — try next
      }
    }
  }


  // Start Sequence Timers

  void _startSequenceTimers() {
    pollTimer?.cancel();
    tickTimer?.cancel();

    pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (selectedSequenceClass != null) _loadStartSequence();
    });

    tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (serverNowUtc != null) {
        serverNowUtc = serverNowUtc!.add(const Duration(seconds: 1));
        if (mounted) setState(() {});
      }
    });

    _loadStartSequence();
  }

  Future<void> _loadStartSequence() async {
    final cls = selectedSequenceClass;
    if (cls == null) return;

    try {
      final res = await startSeqApi.getStatus(
        className: cls,
        raceDate: todayDate,
      );

      final dto = StartSequenceStatusDto.fromMap(res);

      setState(() {
        startSequence = dto;
        serverNowUtc = dto.serverTimeUtc;
        startSequenceError = null;
      });
    } catch (_) {
      setState(() {
        startSequence = null;
        serverNowUtc = null;
        startSequenceError = "No start sequence started yet for $cls";
      });
    }
  }

  // ── Auto-Fire Logic ──
  //
  // Called once after data loads. Starts a 1-second timer that checks
  // each class's scheduled start time. If the current time is within
  // 5 minutes of the start (i.e. now >= startTime - 5min), and the
  // class hasn't been fired yet, it automatically triggers the
  // 5-minute gun — exactly as if the admin tapped "5-min" manually.
  //
  // IMPORTANT: Only auto-fires within a 30-second window of the exact
  // 5-minute mark. This prevents misfiring when the admin sets a start
  // time that's already less than 5 minutes away — in that case the
  // admin should manually tap "5-min" instead.
  //
  // Example: If White Sail 1 is set to start at 18:30:
  //   - fiveMinBefore = 18:25:00
  //   - At 18:24:59 → not yet, skip
  //   - At 18:25:00 → 0 seconds past trigger, FIRE ✓
  //   - At 18:25:29 → 29 seconds past trigger, FIRE ✓ (catches slight delays)
  //   - At 18:25:31 → 31 seconds past trigger, too late, skip (admin must tap "5-min")
  //
  // The competitor page picks up the countdown automatically because
  // it polls GET /start-sequence/status every 10 seconds.

  void _startAutoFireTimer() {
    _autoFireTimer?.cancel();

    _autoFireTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final nowUtc = DateTime.now().toUtc();

      for (final className in classNames) {
        // Skip if already fired (manually or automatically)
        if (_autoFiredClasses.contains(className)) continue;

        // Find the scheduled start time for this class
        // (all boats in a class share the same start time)
        DateTime? classStartUtc;
        for (final b in boats) {
          final boat = Map<String, dynamic>.from(b as Map);
          if (boat["class_name"] == className) {
            classStartUtc = _scheduledStartUtcForBoat(boat);
            break;
          }
        }

        // No start time set yet — skip this class
        if (classStartUtc == null) continue;

        // Calculate when the 5-minute gun should fire
        // (exactly 5 minutes before the scheduled start)
        final fiveMinBefore = classStartUtc.subtract(const Duration(minutes: 5));

        // How many seconds past the 5-minute trigger point are we?
        // Only auto-fire within a 30-second window of the exact moment.
        // This prevents misfiring when the admin sets a start time that's
        // already less than 5 minutes away — in that case the admin
        // should manually tap "5-min" instead.
        //
        // Example: start = 18:30, fiveMinBefore = 18:25
        //   At 18:24:59 → not yet, skip
        //   At 18:25:00 → 0 seconds past, FIRE
        //   At 18:25:29 → 29 seconds past, FIRE (catches slight delays)
        //   At 18:25:31 → 31 seconds past, too late, skip (admin must manually fire)
        final secondsPastTrigger = nowUtc.difference(fiveMinBefore).inSeconds;
        if (secondsPastTrigger >= 0 && secondsPastTrigger <= 30) {
          // Mark as fired BEFORE the async call to prevent double-firing
          _autoFiredClasses.add(className);

          // Fire the 5-minute gun (same as tapping "5-min" button)
          _fireFiveMinuteGun(className);

          debugPrint("Auto-fired 5-min gun for $className at ${nowUtc.toIso8601String()}");
        }
      }
    });
  }


  // Admin Actions


  Future<void> _fireFiveMinuteGun(String className) async {
    // Mark this class as fired so the auto-fire timer skips it
    _autoFiredClasses.add(className);

    try {
      await startSeqApi.start(
        className: className,
        raceDate: todayDate,
        prepFlag: "P",
      );
      // countdown starts when the admin actually fires the gun
      setState(() => selectedSequenceClass = className);
      _startSequenceTimers();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("5-minute gun fired for $className")),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to fire 5-minute gun")),
        );
      }
    }
  }

  Future<void> _setClassStart(String className) async {
    final now = DateTime.now();
    final defaultTime =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:00";

    final controller = TextEditingController(text: defaultTime);

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Set start for $className"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: "Start time (HH:MM:SS)"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Set")),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await dio.post("/race-starts/class-start", data: {
        "class_name": className,
        "race_date": todayDate,
        "start_time": "${controller.text.trim()}.000Z",
      });

      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Start for $className set to ${controller.text.trim()}")),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to set start for $className")),
        );
      }
    }
  }

  Future<void> _finishBoat(Map<String, dynamic> boat) async {
    final now = DateTime.now();
    final finishTime =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";

    try {
      await dio.post("/race-finish", data: {
        "boat_id": boat["id"],
        "race_date": todayDate,
        "finish_time": finishTime,
      });

      await _loadData();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to record finish")),
        );
      }
    }
  }


  // Countdown UI helpers

  String _formatCountdown(Duration d) {
    final s = d.inSeconds < 0 ? 0 : d.inSeconds;
    final m = s ~/ 60;
    final ss = s % 60;
    return "${m.toString().padLeft(2, '0')}:${ss.toString().padLeft(2, '0')}";
  }

  Widget _buildStartSequenceCard() {
    if (selectedSequenceClass == null) return const SizedBox.shrink();

    if (startSequence == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(startSequenceError ?? "No start sequence running."),
        ),
      );
    }

    final s = startSequence!;
    final nowUtc = serverNowUtc ?? s.serverTimeUtc;

    final startMomentUtc = s.sequenceStartUtc.add(const Duration(minutes: 5));
    final timeToStart = startMomentUtc.difference(nowUtc);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              "Start Sequence — ${s.className}",
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _formatCountdown(timeToStart),
              style: const TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

// Finish a boat (with OCS and Penalty options)

// What this does:
// 1) Checks the boat has a start_time in today's race_starts row (startsByBoatId)
// 2) Pops up a bottom sheet where the Race Officer can:
//    - mark OCS (true/false)
//    - enter penalty seconds (number)
// 3) If confirmed, posts to FastAPI POST /race-finish with:
//    boat_id, race_date, finish_time, ocs, penalty_seconds
// 4) Reloads /boats and /race-starts so the UI updates instantly
  Future<void> _finishBoatWithOptions(Map<String, dynamic> boat) async {
    final boatId = boat["id"] as int;

    // Look up today's timing record for this boat (from /race-starts)
    final startRecord = startsByBoatId[boatId];

    // Safety check: must have a start time before you can finish
    if (startRecord == null || startRecord["start_time"] == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No start time recorded yet for ${boat['sail_no']}.")),
      );
      return;
    }

    // Local values controlled by the bottom sheet UI
    String? resultCode; // null = normal finish, or "OCS", "DNF", "DNS", etc.
    final penaltyController = TextEditingController(text: "0");

    // Bottom sheet to capture options
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Finish options", style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),

              // Result Code dropdown (Normal / OCS / DNF / DNS etc.)
              StatefulBuilder(
                builder: (context, setModalState) {
                  return DropdownButtonFormField<String>(
                    initialValue: resultCode,
                    decoration: const InputDecoration(
                      labelText: "Result Code",
                      helperText: "Leave blank for a normal finish",
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text("Normal Finish")),
                      DropdownMenuItem(value: "OCS", child: Text("OCS - On Course Side")),
                      DropdownMenuItem(value: "DNS", child: Text("DNS - Did Not Start")),
                      DropdownMenuItem(value: "DNF", child: Text("DNF - Did Not Finish")),
                      DropdownMenuItem(value: "RET", child: Text("RET - Retired")),
                      DropdownMenuItem(value: "DSQ", child: Text("DSQ - Disqualified")),
                      DropdownMenuItem(value: "BFD", child: Text("BFD - Black Flag")),
                    ],
                    onChanged: (v) => setModalState(() => resultCode = v),
                  );
                },
              ),

              // Penalty seconds input
              StatefulBuilder(
                builder: (context, setModalState) {
                  final isDns = resultCode == "DNS";
                  return TextField(
                    controller: penaltyController,
                    enabled: !isDns,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: "Penalty (seconds)",
                      hintText: "0",
                      helperText: isDns ? "DNS has no finish/penalty" : null,
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // Cancel / Confirm
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text("Cancel"),
                    ),
                  ),
                  const SizedBox(width: 12),
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

    if (confirmed != true) return;

    // Parse penalty safely
    final penaltySeconds = int.tryParse(penaltyController.text.trim()) ?? 0;

    // Capture finish time as "HH:MM:SS"
    final now = DateTime.now();
    final finishTime =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";

    try {
      // POST to backend: this updates the race_starts row in MySQL for this boat/date
      await dio.post("/race-finish", data: {
        "boat_id": boatId,
        "race_date": todayDate,
        "finish_time": finishTime,
        "result_code": resultCode,
        "penalty_seconds": penaltySeconds,
      });

      // Reload to refresh lists and times
      await _loadData();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Finish recorded for ${boat['sail_no']} at $finishTime")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to record finish")),
      );
    }
  }


  // Reset Race Day
  // Calls DELETE /race-day to clear all timing data and check-ins for today.
  // Shows a confirmation dialog first to prevent accidental data loss.
  // After reset, competitors will see the check-in dialog again on next login
  // since their check-in records have been cleared from the database.
  Future<void> _resetRaceDay() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Reset race day?"),
        content: const Text(
          "This will delete ALL start times, finish times, and check-ins for today. This cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Reset"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await dio.delete("/race-day", queryParameters: {"race_date": todayDate});
      await _loadData();

      // Clear auto-fire tracking so classes can be re-fired after a reset
      _autoFiredClasses.clear();

      // Clear the active countdown card — the sequence records may have
      // been deleted by the backend along with other race-day data.
      setState(() {
        selectedSequenceClass = null;
        startSequence = null;
        serverNowUtc = null;
        startSequenceError = null;
      });
      pollTimer?.cancel();
      tickTimer?.cancel();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Race day reset — all times and check-ins cleared.")),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to reset race day.")),
        );
      }
    }
  }


  // Boat Card

  Widget _boatTile(Map<String, dynamic> boat, {required bool showFinish}) {
    final boatId = boat["id"] as int;
    final record = startsByBoatId[boatId];

    final startStr = record?["start_time"] as String?;
    final finishStr = record?["finish_time"] as String?;

    return Card(
      child: ListTile(
        title: Text("${boat["sail_no"]} — ${boat["name"]}"),
        subtitle: Text("Start: ${startStr ?? "—"}   Finish: ${finishStr ?? "—"}"),
        trailing: showFinish
            ? ElevatedButton(
                onPressed: () => _finishBoatWithOptions(boat),
                child: const Text("Finish"),
              )
            : const Icon(Icons.check_circle_outline),
      ),
    );
  }


  // UI

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Race Officer — $todayDate"),
        actions: [
          // Refresh button — reloads data without deleting anything
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: "Refresh",
          ),
          // Reset button — clears all timing and check-in data for today
          // Uses a red warning icon to distinguish it from a simple refresh
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.red),
            onPressed: _resetRaceDay,
            tooltip: "Reset Race Day",
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text(error!))
              : RefreshIndicator(
                  // Pull-to-refresh too
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      // Class button (Set Start and 5-min)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final className in classNames)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ElevatedButton(
                                  onPressed: () => _setClassStart(className),
                                  child: Text(className),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: () => _fireFiveMinuteGun(className),
                                  child: const Text("5-min"),
                                ),
                              ],
                            )
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Start Sequence Countdown Card
                      _buildStartSequenceCard(),

                      const SizedBox(height: 14),

                      // Boats Grouped by class
                      for (final className in classNames) ...[
                        ExpansionTile(
                          title: Text(
                            className,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          // Subtitle now shows the check-in count alongside the start time
                          // so the race officer can see at a glance how many boats have confirmed
                          subtitle: Text(
                            "${_checkedInForClass(className).length} checked in  •  ${_classStartTimeLabel(className)}",
                          ),
                          childrenPadding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
                          children: [
                            // Checked-in boats section
                            // Displays compact Chip widgets for each competitor who has
                            // confirmed they are racing today via the check-in dialog.
                            // This lets the race officer see who is on the water before
                            // the start sequence begins.
                            const SizedBox(height: 8),
                            const Text("Checked in", style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),

                            if (_checkedInForClass(className).isEmpty)
                              const Text("No boats checked in yet.")
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: _checkedInForClass(className).map((c) {
                                  return Chip(
                                    avatar: const Icon(Icons.check_circle, size: 18),
                                    label: Text("${c["sail_no"]} — ${c["name"]}"),
                                  );
                                }).toList(),
                              ),

                            const SizedBox(height: 12),

                            const Text("In progress", style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),

                            if (_inProgressForClass(className).isEmpty)
                              const Text("No boats currently in progress.")
                            else
                              ..._inProgressForClass(className).map(
                                (b) => _boatTile(b, showFinish: true),
                              ),

                            const SizedBox(height: 12),
                            const Text("Finished", style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),

                            if (_finishedForClass(className).isEmpty)
                              const Text("No boats finished yet.")
                            else
                              ..._finishedForClass(className).map(
                                (b) => _boatTile(b, showFinish: false),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
    );
  }
}


// Dto Class(dot notation in UI)

class StartSequenceStatusDto {
  final String className;
  final String raceDate;
  final String prepFlag;
  final DateTime sequenceStartUtc;
  final DateTime serverTimeUtc;
  final String status;

  StartSequenceStatusDto({
    required this.className,
    required this.raceDate,
    required this.prepFlag,
    required this.sequenceStartUtc,
    required this.serverTimeUtc,
    required this.status,
  });

  factory StartSequenceStatusDto.fromMap(Map<String, dynamic> m) {
    return StartSequenceStatusDto(
      className: m["class_name"] as String,
      raceDate: m["race_date"] as String,
      prepFlag: m["prep_flag"] as String,
      sequenceStartUtc: DateTime.parse(m["sequence_start_utc"] as String),
      serverTimeUtc: DateTime.parse(m["server_time_utc"] as String),
      status: (m["status"] ?? "RUNNING") as String,
    );
  }
}

// Summary
// The race officer control panel that:
// 1. Manages start times at class level
// 2. Shows live countdown synchronized with backend
// 3. Groups boats by state (checked in / in progress / finished)
// 4. Records finishes with OCS/penalty options
// 5. Provides both manual refresh and pull-to-refresh
// 6. Displays check-in confirmations from competitors as compact chips
// 7. Reset Race Day button (red trash icon) clears all timing and check-in data with confirmation
// 8. Auto-fires the 5-minute gun when a class is exactly 5 minutes from its scheduled start
//    (within a 30-second window to prevent misfires from late-set start times)

// This is the heart of the race timing system.

// Reference: StatefulWidget for complex state management [F14]
// Reference: Timer.periodic for countdown synchronization [F23]
// Reference: Duration and DateTime calculations [F8]
// Reference: UTC timezone handling [B10]
// Reference: ExpansionTile for class grouping [F26]
// Reference: RefreshIndicator for pull-to-refresh [F27]
// Reference: showModalBottomSheet for finish options [F9]
// Reference: StatefulBuilder for bottom sheet state [F10]
// Reference: SwitchListTile for OCS toggle [F11]
// Reference: TextField for penalty input [F4]
// Reference: ElevatedButton and OutlinedButton [F1]
// Reference: Dio GET/POST/DELETE methods [D1][D3]
// Reference: FastAPI timing endpoints [B1]
// Reference: Query parameters for date filtering [B11]
// Reference: SnackBar for feedback [F7]
// Reference: Card for countdown display [F19]
// Reference: Chip widget for compact check-in display [F28]
// Reference: showDialog for destructive action confirmation [F9]
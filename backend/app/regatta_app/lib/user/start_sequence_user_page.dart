// What This File Does
// This is the competitor interface that displays a live countdown timer. It:
// Polls the backend every 2 seconds for sequence data
// Updates countdown display every second locally
// Shows preparatory flag (drops it at 1-minute mark)
// Displays phase labels (5-minute signal, running, 1-minute signal, STARTED)


import 'dart:async';  // Provides Timer class for periodic operations
import 'package:flutter/material.dart'; // Core Flutter widgets
import '../services/start_sequence_api.dart';  // HTTP service for backend communication
import '../ui/flags/flag_chip.dart';  // Custom flag display widget

class StartSequenceUserPage extends StatefulWidget {
  final String className;
  final String raceDate; // YYYY-MM-DD

  const StartSequenceUserPage({
    super.key,
    required this.className,
    required this.raceDate,
  });
  // Unlike the admin page, this widget accepts parameters:
  // className: Which class this competitor is in
  // raceDate: Which race day to show
  // These come from the login flow - after a competitor logs in with their sail number, the app looks up their boat record and navigates to this page with their className.


  @override
  State<StartSequenceUserPage> createState() => _StartSequenceUserPageState();
}

class _StartSequenceUserPageState extends State<StartSequenceUserPage> {
  // Use local FastAPI backend for simulator testing
  final api = StartSequenceApi("https://web-production-9fd2e3.up.railway.app");

  // Map returned by StartSequenceApi.getStatus()
  Map<String, dynamic>? status;  // Latest response from backend (null until first successful fetch)
  String? error;  // Error message if fetch fails

  Timer? pollTimer;  // Timer that fires every 2 seconds to fetch from backend
  Timer? tickTimer;  // Timer that fires every 1 second to update countdown locally
  DateTime? serverNowUtc;  // The "current" server time, updated locally between polls

  @override
  void initState() { 
    super.initState();
    _startTimers();
  }  //  Called once when widget is first created. Starts the timers.

  @override
  void dispose() { 
    pollTimer?.cancel();
    tickTimer?.cancel();
    super.dispose();
  } // Called when widget is removed. Cancels timers to prevent memory leaks.


  void _startTimers() {
    // Poll backend to stay accurate (e.g. admin restarts sequence).
    pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _fetch());  // Calls _fetch() every 2 seconds

    // Local tick: keeps countdown smooth without hammering the backend.
    tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {  // Every 1 second, adds 1 second to serverNowUtc and rebuilds UI

      if (serverNowUtc != null) {
        serverNowUtc = serverNowUtc!.add(const Duration(seconds: 1));
        if (mounted) setState(() {});
      }
    });

    // Initial fetch happens immediately
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final res = await api.getStatus(
        className: widget.className,
        raceDate: widget.raceDate,
      );

      // Save the whole response map
      status = res;

      // Parse server time (UTC) from ISO string
      final serverTimeStr = (res["server_time_utc"] ?? res["serverTimeUtc"]) as String;
      serverNowUtc = DateTime.parse(serverTimeStr);

      error = null;
      if (mounted) setState(() {});
    } catch (e) {
      status = null;
      serverNowUtc = null;
      error = "Start sequence not started yet for ${widget.className}.";
      if (mounted) setState(() {});
    }
  }
  // Calls api.getStatus() with className and raceDate from widget parameters.
  // On success:
  // Stores the response in status
  // Parses server_time_utc string into DateTime object
  // Clears any error
  // Rebuilds UI

// On error:
// Clears status and serverNowUtc
// Sets user-friendly error message
// Rebuilds UI

// The "if (mounted)" check prevents calling setState after widget is disposed.


  @override
  Widget build(BuildContext context) {
    final s = status;

    return Scaffold(
      appBar: AppBar(title: const Text('Start Sequence')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: (s == null)
              ? Center(child: Text(error ?? 'Loading…'))
              : _buildContent(context, s),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Map<String, dynamic> s) {
    // This method builds the actual countdown display.
    // Expect backend fields like:
    // class_name, race_date, prep_flag, sequence_start_utc, server_time_utc, status
    final className = (s["class_name"] ?? s["className"]) as String? ?? widget.className;
    final raceDate = (s["race_date"] ?? s["raceDate"]) as String? ?? widget.raceDate;
    final prepFlag = (s["prep_flag"] ?? s["prepFlag"]) as String? ?? "P";
    final statusText = (s["status"] ?? "ACTIVE").toString();

    // Sequence timeline:
    // Admin starts the sequence at "sequenceStartUtc" which represents the 5-minute signal moment.
    // The START happens 5 minutes later.
    // Critical logic: The backend records when the 5-minute gun fired (sequenceStartUtc). 
    // The actual START happens 5 minutes later. So we add 5 minutes to get startMomentUtc, 
    // then calculate the difference from current time.
    final seqStartStr = (s["sequence_start_utc"] ?? s["sequenceStartUtc"]) as String;
    final sequenceStartUtc = DateTime.parse(seqStartStr);


    final nowUtc = serverNowUtc ?? DateTime.now().toUtc();

    final startMomentUtc = sequenceStartUtc.add(const Duration(minutes: 5));
    final timeToStart = startMomentUtc.difference(nowUtc);

    final phase = _phaseLabel(timeToStart); // Text label like "5 minute signal" or "STARTED"
    final showPrepFlag = timeToStart > const Duration(minutes: 1); // drop at 1-minute
    final mmss = _formatDuration(timeToStart);  // Formatted countdown like "04:32"

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '$className — $raceDate',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 14),

        if (showPrepFlag)
          FlagChip(flagCode: prepFlag, label: 'Preparatory: $prepFlag (UP)')
        else
          const Text('Preparatory flag DOWN (1 minute)', textAlign: TextAlign.center),

        const SizedBox(height: 18),

        Center(
          child: Text(
            mmss,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 52),
          ),
        ),
        const SizedBox(height: 8),
        Center(child: Text(phase, style: Theme.of(context).textTheme.titleMedium)),

        const SizedBox(height: 18),
        Text('Status: $statusText'),
        Text('Server time (UTC): ${nowUtc.toIso8601String()}'),
      ],
    );
  }

  String _phaseLabel(Duration timeToStart) {
    if (timeToStart <= Duration.zero) return 'STARTED';
    if (timeToStart > const Duration(minutes: 4)) return '5 minute signal';
    if (timeToStart > const Duration(minutes: 1)) return '4 minute / running';
    return '1 minute signal';
  }

  String _formatDuration(Duration d) {
    // If negative, clamp to 0:00 after start.
    final secs = d.inSeconds;
    final clamped = secs < 0 ? 0 : secs;

    final minutes = clamped ~/ 60;
    final seconds = clamped % 60;

    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    return '$mm:$ss';
  }
}


// Summary 
// This page provides a synchronized countdown display:
// 1. Polls backend every 2 seconds for latest sequence data
// 2. Updates serverNowUtc every 1 second locally
// 3. Calculates remaining time using server time (not device clock)
// 4. Shows flag until 1-minute mark
// 5. Displays phase labels and formatted countdown

// The hybrid poll and tick approach ensures accuracy without excessive API calls.

// Reference: StatefulWidget for timer management [F14]
// Reference: Timer.periodic for countdown updates [F23]
// Reference: Duration and DateTime arithmetic [F8]
// Reference: Async/await patterns for API calls [F8]
// Reference: Server time synchronization to prevent clock drift [B10]
// Reference: UTC timezone handling for accurate timing [B10]
// Reference: Card layout for countdown display [F19]
// Reference: CircularProgressIndicator for loading states [F1]

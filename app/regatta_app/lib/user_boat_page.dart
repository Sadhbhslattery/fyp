import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

class UserBoatPage extends StatefulWidget {
  final Map<String, dynamic> boat;
  const UserBoatPage({super.key, required this.boat});

  @override
  State<UserBoatPage> createState() => _UserBoatPageState();
}

class _UserBoatPageState extends State<UserBoatPage> {
  final dio = Dio(BaseOptions(baseUrl: "http://127.0.0.1:8000"));

  Map<String, dynamic>? currentCourse;
  String? courseError;
  bool loadingCourse = true;

  List<dynamic> classResults = [];
  String? resultsError;
  bool loadingResults = true;

  late String todayDate; // "YYYY-MM-DD"

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    todayDate =
        "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    _loadCurrentCourse();
    _loadClassResults();
  }

  Future<void> _loadCurrentCourse() async {
    setState(() {
      loadingCourse = true;
      courseError = null;
    });

    try {
      final res = await dio.get("/current-course");
      setState(() {
        currentCourse = res.data as Map<String, dynamic>;
      });
    } catch (e) {
      setState(() {
        courseError = "No race selected yet.";
        currentCourse = null;
      });
    } finally {
      setState(() {
        loadingCourse = false;
      });
    }
  }

  Future<void> _loadClassResults() async {
    setState(() {
      loadingResults = true;
      resultsError = null;
    });

    try {
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
      setState(() {
        classResults = [];
        resultsError =
            "No timing data yet for your class today.";
      });
    } finally {
      setState(() {
        loadingResults = false;
      });
    }
  }

  String _formatDuration(num? seconds) {
    if (seconds == null) return "—";
    final d = Duration(seconds: seconds.toInt());
    String two(int n) => n.toString().padLeft(2, '0');
    final h = two(d.inHours);
    final m = two(d.inMinutes.remainder(60));
    final s = two(d.inSeconds.remainder(60));
    return "$h:$m:$s";
  }

  @override
  Widget build(BuildContext context) {
    final boat = widget.boat;

    final myBoatId = boat["id"];
    Map<String, dynamic>? myRow;
    for (final r in classResults) {
      final m = Map<String, dynamic>.from(r as Map);
      if (m["boat_id"] == myBoatId) {
        myRow = m;
        break;
      }
    }

    // We still compute this, but we’re no longer showing "Today's result: X of Y"
    final allFinished = classResults.isNotEmpty &&
        classResults.every(
          (r) =>
              (r as Map)["finish_time"] != null &&
              (r)["corrected_seconds"] != null,
        );

    return Scaffold(
      appBar: AppBar(
        title: Text("Your Boat: ${boat['sail_no']}"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            // Boat info (no more "Today's result: X of Y" line)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
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

            // Course card (now always "Today's course")
            loadingCourse
                ? const Center(child: CircularProgressIndicator())
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
                    : _buildRaceCard(),

            const SizedBox(height: 16),

            // Class results table
            loadingResults
                ? const Center(child: CircularProgressIndicator())
                : _buildClassResultsCard(myBoatId),
          ],
        ),
      ),
    );
  }

  // Title changed to always "Today's course"
  Widget _buildRaceCard() {
    final cc = currentCourse!;
    final course = cc["course"] as Map<String, dynamic>;
    final startTime = cc["start_time"] ?? "TBC";
    final rounds = (course["rounds"] as List<dynamic>).join("\n");

    return Card(
      color: Colors.deepPurple.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Today's course",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text("Course: ${course['name']}"),
            Text("Wind: ${course['wind']}"),
            Text("Start time: $startTime"),
            const SizedBox(height: 10),
            const Text(
              "Rounds:",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(rounds),
          ],
        ),
      ),
    );
  }

  Widget _buildClassResultsCard(int myBoatId) {
    if (classResults.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            resultsError ??
                "No timing data yet for your class today.",
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    // Table-style layout: Pos | Sail No | Boat | Elapsed | Corrected
    return Card(
      color: Colors.blueGrey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Today's ${widget.boat["class_name"]} results",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text("Pos")),
                  DataColumn(label: Text("Sail No")),
                  DataColumn(label: Text("Boat")),
                  DataColumn(label: Text("Elapsed")),
                  DataColumn(label: Text("Corrected")),
                ], // Reference: Flutter DataTable Docs
                rows: classResults.map((r) {
                  final row = Map<String, dynamic>.from(r as Map);
                  final isMe = row["boat_id"] == myBoatId;
                  final elapsed = row["elapsed_seconds"] as int?;
                  final corrected = row["corrected_seconds"] as num?;
                  final pos = row["position"] as int?;

                  final style = TextStyle(
                    fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                  );

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

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

class RaceStartsPage extends StatefulWidget {
  const RaceStartsPage({super.key});

  @override
  State<RaceStartsPage> createState() => _RaceStartsPageState();
}

class _RaceStartsPageState extends State<RaceStartsPage> {
  final dio = Dio(BaseOptions(baseUrl: "http://127.0.0.1:8000"));

  List<dynamic> boats = [];
  // boat_id -> race start record (start/finish/elapsed/etc.)
  Map<int, Map<String, dynamic>> startsByBoatId = {};
  bool loading = true;
  String? error;
  late String todayDate; // "YYYY-MM-DD"

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    todayDate =
        "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      // Get all boats
      final boatsRes = await dio.get("/boats");
      boats = boatsRes.data as List<dynamic>;

      // Get all race starts for today
      final startsRes = await dio.get(
        "/race-starts",
        queryParameters: {"race_date": todayDate},
      );
      final startsList = startsRes.data as List<dynamic>;
      startsByBoatId = {
        for (final s in startsList)
          s["boat_id"] as int: Map<String, dynamic>.from(s as Map)
      };

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

  List<String> get classNames {
    final set = <String>{};
    for (final b in boats) {
      final m = b as Map<String, dynamic>;
      set.add(m["class_name"] as String);
    }
    final list = set.toList()..sort();
    return list;
  }

  Future<void> _setClassStart(String className) async {
    final now = DateTime.now();
    final defaultTime =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:00";

    final controller = TextEditingController(text: defaultTime);

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

    if (ok != true) return;

    try {
      await dio.post("/race-starts/class-start", data: {
        "class_name": className,
        "race_date": todayDate,
        "start_time": controller.text.trim(),
      });

      await _loadData();

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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to set start for $className"),
          ),
        );
      }
    }
  }

  Future<void> _finishBoat(Map<String, dynamic> boat) async {
    final boatId = boat["id"] as int;
    final start = startsByBoatId[boatId];
    if (start == null || start["start_time"] == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                "No start time recorded yet for ${boat['sail_no']}."),
          ),
        );
      }
      return;
    }

    final now = DateTime.now();
    final finishTime =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";

    try {
      await dio.post("/race-finish", data: {
        "boat_id": boatId,
        "race_date": todayDate,
        "finish_time": finishTime,
      });

      await _loadData();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Finish recorded for ${boat['sail_no']} at $finishTime",
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to record finish")),
        );
      }
    }
  }

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

  String _formatDuration(int? seconds) {
    if (seconds == null) return "—";
    final d = Duration(seconds: seconds);
    String two(int n) => n.toString().padLeft(2, '0');
    final h = two(d.inHours);
    final m = two(d.inMinutes.remainder(60));
    final s = two(d.inSeconds.remainder(60));
    return "$h:$m:$s";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Start & Finish – $todayDate"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? Center(child: Text(error!))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Reset button
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => _resetToday(),
                          icon: const Icon(Icons.refresh),
                          label: const Text("Reset today's timings"),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Class start controls
                      Text(
                        "Set class start times",
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
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

                      // Boat list with start/finish and elapsed
                      Expanded(
                        child: ListView.builder(
                          itemCount: boats.length,
                          itemBuilder: (_, i) {
                            final b =
                                Map<String, dynamic>.from(boats[i] as Map);
                            final start = startsByBoatId[b["id"]];
                            final startTime =
                                start != null ? start["start_time"] as String? : null;
                            final finishTime =
                                start != null ? start["finish_time"] as String? : null;
                            final elapsed =
                                start != null ? start["elapsed_seconds"] as int? : null;

                            return Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text("${b['sail_no']} – ${b['name']}"),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Class: ${b['class_name']}"),
                                    Text("Start: ${startTime ?? '—'}"),
                                    Text("Finish: ${finishTime ?? '—'}"),
                                    Text("Elapsed: ${_formatDuration(elapsed)}"),
                                  ],
                                ),
                                trailing: ElevatedButton(
                                  onPressed: () => _finishBoat(b),
                                  child: const Text("Finish now"),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

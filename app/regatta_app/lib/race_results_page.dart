import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

class RaceResultsPage extends StatefulWidget {
  const RaceResultsPage({super.key});

  @override
  State<RaceResultsPage> createState() => _RaceResultsPageState();
}

class _RaceResultsPageState extends State<RaceResultsPage> {
  final dio = Dio(BaseOptions(baseUrl: "http://127.0.0.1:8000"));

  late String todayDate;
  bool loading = true;
  String? error;

  // class_name -> list of results
  final Map<String, List<Map<String, dynamic>>> resultsByClass = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    todayDate =
        "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    _loadResults();
  }

  Future<void> _loadResults() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      // First get all boats so we know what classes exist
      final boatsRes = await dio.get("/boats");
      final boats = boatsRes.data as List<dynamic>;
      final classes = <String>{};
      for (final b in boats) {
        classes.add((b as Map<String, dynamic>)["class_name"] as String);
      }

      resultsByClass.clear();

      // For each class, get that class's results
      for (final className in classes) {
        final res = await dio.get(
          "/race-results",
          queryParameters: {
            "race_date": todayDate,
            "class_name": className,
          },
        );
        final list = (res.data as List<dynamic>)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        resultsByClass[className] = list;
      }

      setState(() {});
    } catch (e) {
      setState(() {
        error = "Failed to load results";
      });
    } finally {
      setState(() {
        loading = false;
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
    return Scaffold(
      appBar: AppBar(
        title: Text("Today's Results – $todayDate"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? Center(child: Text(error!))
                : resultsByClass.isEmpty
                    ? const Center(child: Text("No results yet for today."))
                    : ListView(
                        children: [
                          for (final entry in resultsByClass.entries)
                            _buildClassTable(entry.key, entry.value),
                        ],
                      ),
      ),
    );
  }

  Widget _buildClassTable(
    String className,
    List<Map<String, dynamic>> results,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              className,
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
                  DataColumn(label: Text("Rating")),
                  DataColumn(label: Text("Elapsed")),
                  DataColumn(label: Text("Corrected")),
                ],
                rows: results.map((r) {
                  final pos = r["position"];
                  final elapsed = r["elapsed_seconds"] as int?;
                  final corrected = r["corrected_seconds"] as num?;

                  return DataRow(
                    cells: [
                      DataCell(Text(pos?.toString() ?? "-")),
                      DataCell(Text(r["sail_no"] as String)),
                      DataCell(Text(r["name"] as String)),
                      DataCell(Text((r["rating_value"] as num).toString())),
                      DataCell(Text(_formatDuration(elapsed))),
                      DataCell(Text(_formatDuration(corrected))),
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

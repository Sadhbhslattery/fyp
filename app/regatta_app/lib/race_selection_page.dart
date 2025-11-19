import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

class RaceSelectionPage extends StatefulWidget {
  const RaceSelectionPage({super.key});

  @override
  State<RaceSelectionPage> createState() => _RaceSelectionPageState();
}

class _RaceSelectionPageState extends State<RaceSelectionPage> {
  final dio = Dio(BaseOptions(baseUrl: "http://127.0.0.1:8000"));
  List<dynamic> courses = [];
  bool loading = true;
  String? error;
  String? infoMessage;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    setState(() {
      loading = true;
      error = null;
      infoMessage = null;
    });

    try {
      final res = await dio.get("/courses");
      setState(() {
        courses = res.data as List<dynamic>;
      });
    } catch (e) {
      setState(() {
        error = "Failed to load courses";
      });
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> _selectCourse(Map<String, dynamic> course) async {
    final timeController = TextEditingController(text: "18:30");

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Set ${course['name']} as today's race?"),
        content: TextField(
          controller: timeController,
          decoration: const InputDecoration(
            labelText: "Start time (e.g. 18:30)",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Confirm"),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await dio.post("/select-course", data: {
        "course_id": course["id"],
        "start_time": timeController.text.trim(),
      });

      setState(() {
        infoMessage =
            "${course['name']} set as today's race at ${timeController.text.trim()}";
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(infoMessage!)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to set today's race")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Select today's race")),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? Center(child: Text(error!))
                : ListView.builder(
                    itemCount: courses.length,
                    itemBuilder: (_, i) {
                      final c = courses[i] as Map<String, dynamic>;
                      final rounds = (c["rounds"] as List<dynamic>).join("\n");

                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c["name"],
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Wind: ${c['wind']}",
                                style: const TextStyle(
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                c["description"],
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              Text(rounds),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton.icon(
                                  onPressed: () =>
                                      _selectCourse(c),
                                  icon: const Icon(Icons.flag),
                                  label: const Text("Set for today"),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

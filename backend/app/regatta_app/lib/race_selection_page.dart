// Lets race officer select today's course and start time. The app:
// 1. Loads predefined courses from backend (Course 1, 2, 3)
// 2. Displays each course with description, wind, and rounds
//  3. Race officer taps "Set for today" on chosen course
// 4. Dialog prompts for start time (e.g., "18:30")
// 5. Sends POST /select-course with course_id and start_time
// 6. Shows success SnackBar

// _loadCourses(): GET /courses, stores in List<dynamic>
// _selectCourse(course): Shows confirmation dialog, POST /select-course
// build(): ListView of course cards


import 'package:flutter/material.dart'; // Flutter UI widgets & layout
import 'package:dio/dio.dart';  // HTTP client used to call FastAPI backend
// Reference: Dio GET request to load list data [D1]
// Reference: Stateful widget and async init pattern [F1][F8]

// Stateful widget because we:
// load data from the backend
// show loading and error states
// update the UI once the user selects a course
class RaceSelectionPage extends StatefulWidget {
  const RaceSelectionPage({super.key});

  @override
  State<RaceSelectionPage> createState() => _RaceSelectionPageState();
}

// The state class holds all mutable data:
// list of courses from backend
// loading and error flags
// info message after setting today's race
class _RaceSelectionPageState extends State<RaceSelectionPage> {
  // HTTP client with base URL pointing to your FastAPI backend
  // All calls like dio.get("/courses") -  http://127.0.0.1:8000/courses
  final dio = Dio(BaseOptions(baseUrl: "https://web-production-9fd2e3.up.railway.app"));

  // List of course objects returned from backend
  // Each element is a Map with fields like id, name, wind, description, rounds
  List<dynamic> courses = [];

  // Whether the screen is currently fetching data
  bool loading = true;

  // Stores error message if loading fails
  String? error;

  // Optional informational message after course selection (e.g. "Course 1 set...")
  String? infoMessage;

  // initState() runs once when this page is first created
  // We use it to immediately load the courses from the API
  @override
  void initState() {
    super.initState();
    _loadCourses(); // Trigger the API call to get the list of courses
    // Reference: asynchronous HTTP call and error handling [D1][F8]

  }

  // Load Courses from backend


  // Fetches courses from GET /courses and updates the UI
  Future<void> _loadCourses() async {
    // Before fetching, reset loading state and clear errors / info messages
    setState(() {
      loading = true;
      error = null;
      infoMessage = null;
    });

    try {
      // Call the backend endpoint that returns all available courses
      final res = await dio.get("/courses");

      // On success, store the list of courses
      setState(() {
        courses = res.data as List<dynamic>;
      });
    } catch (e) {
      // If something goes wrong (no server, bad network, etc.), store a generic error
      setState(() {
        error = "Failed to load courses";
      });
    } finally {
      // In all cases, stop the loading spinner
      setState(() {
        loading = false;
      });
    }
  }

 
  // Select Course for Today


  // Called when the Race Officer taps "Set for today" on a course card
  // Steps:
  //  1. Show a dialog asking for confirmation and start time
  //  2. If confirmed, send POST /select-course with:
  //        - course_id
  //        - start_time (e.g. "18:30")
  //  3. Show a SnackBar message on success or failure
  Future<void> _selectCourse(Map<String, dynamic> course) async {
    // Text field controller for the start time input inside the dialog
    // Defaults to 10:30 for convenience.
    // Reference: showDialog with AlertDialog and TextField [F7][F4]
    // Reference: Dio POST with JSON body [D1]

    final timeController = TextEditingController(text: "10:30");

    // Show a confirmation dialog to the user
    // Returns true if user confirms, false/null if cancelled
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        // Title of the confirmation dialog includes the course name
        title: Text("Set ${course['name']} as today's race?"),

        // Content: a text field for entering start time (e.g., 10:30)
        content: TextField(
          controller: timeController,
          decoration: const InputDecoration(
            labelText: "Start time (e.g. 10:30)",
          ),
        ),

        // Buttons at the bottom of the dialog
        actions: [
          // Cancel button just closes the dialog and returns false
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),

          // Confirm button closes the dialog and returns true
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Confirm"),
          ),
        ],
      ),
    );

    // If the user did not confirm (cancelled or closed dialog), stop here
    if (ok != true) return;

    try {
      // Send POST request to backend with selected course ID and chosen start time
      await dio.post("/select-course", data: {
        "course_id": course["id"],    // Which course was chosen
        "start_time": timeController.text.trim(),  // Starting time as text
      });

      // If POST is successful, update infoMessage with a success text
      setState(() {
        infoMessage =
            "${course['name']} set as today's race at ${timeController.text.trim()}";
      });

      // If the widget is still in the tree, show a SnackBar at the bottom
      // Reference: ScaffoldMessenger and SnackBar for feedback [F7]

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(infoMessage!)),
        );
      }
    } catch (e) {
      // If something went wrong when calling /select-course show an error SnackBar to the user
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to set today's race")),
        );
      }
    }
  }


  // Build UI

  /// The build method describes how this screen looks
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Top bar with page title
      appBar: AppBar(title: const Text("Select today's race")),

      // Body of the page with padding around the edges
      body: Padding(
        padding: const EdgeInsets.all(12),

        // Use different widgets based on loading/error/data state
        child: loading
            // 1) Show a spinner while courses are loading
            ? const Center(child: CircularProgressIndicator())

            // 2) Show error message if something went wrong
            : error != null
                ? Center(child: Text(error!))

                // 3) Otherwise, show the list of courses
                // Reference: ListView.builder and Card UI [F5]
                : ListView.builder(
                    itemCount: courses.length, // Number of course cards to render
                    itemBuilder: (_, i) {
                      // Each course is a Map<String, dynamic>
                      final c = courses[i] as Map<String, dynamic>;

                      // "rounds" field is a list of strings; join them with line breaks
                      final rounds = (c["rounds"] as List<dynamic>).join("\n");

                      // Each course is wrapped in a Card for nice Material design
                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12), // Rounded corners
                        ),
                        margin: const EdgeInsets.only(bottom: 12), // Space between cards

                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,

                            children: [
                              // Course name (e.g., "Course 1 – Inner Harbour")
                              Text(
                                c["name"],
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              const SizedBox(height: 4),

                              // Wind description (e.g., "Wind: SW 15–20 kts")
                              Text(
                                "Wind: ${c['wind']}",
                                style: const TextStyle(
                                  fontStyle: FontStyle.italic,
                                ),
                              ),

                              const SizedBox(height: 8),

                              // A short bold-ish course description line
                              Text(
                                c["description"],
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),

                              const SizedBox(height: 8),

                              // Full rounds text (each rounding on its own line)
                              Text(rounds),

                              const SizedBox(height: 12),

                              // Align the "Set for today" button to the right
                              Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton.icon(
                                  // When pressed, attempt to set this course as today's race
                                  onPressed: () => _selectCourse(c),

                                  // Flag icon to visually indicate race/course selection
                                  icon: const Icon(Icons.flag),

                                  // Button label text
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

// Summary
// Simple course picker with:
// Card-based UI showing course details
// Confirmation dialog with start time input
// Backend persistence via POST /select-course
// SnackBar feedback on success/failure

// Reference: StatefulWidget for async course loading [F14]
// Reference: ListView.builder for course cards [F5]
// Reference: Card for course display [F19]
// Reference: AlertDialog for start time input [F18]
// Reference: TextField for time input [F4]
// Reference: TextEditingController for form management [F4]
// Reference: Dio GET/POST methods [D1][D3]
// Reference: FastAPI course endpoints [B1]
// Reference: SnackBar for feedback [F7]
// Reference: CircularProgressIndicator for loading [F1]
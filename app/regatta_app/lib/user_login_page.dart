// This screen is used by sailors (boat owners) to log into the app.
// They login by entering:
//   Sail Number
//   Password

// When the login is successful, the backend returns the boat object associated with the given sail number. The app then navigates to
// UserBoatPage so the competitor can see:
//   Today's course
//   Today's results for their class
//   Their own boat highlighted in the results table

// This screen communicates with the backend using:
// POST /user-login

// Expected backend responses:
//   SUCCESS - { "success": true, "boat": {...} }
//   FAILURE -{ "success": false, "message": "Invalid password" }

// This page contains:
// - Two input fields (sail_no and password)
// - A login button
// - Error messages
// - A loading spinner


import 'package:flutter/material.dart'; // Flutter UI components
import 'package:dio/dio.dart';  // HTTP client for backend requests 
import 'package:regatta_app/theme/app_theme.dart';
// Reference: Dio for HTTP requests [D1], login form similar pattern as admin login [F4]
import 'user_boat_page.dart';   // Next screen after successful login

// A stateful widget because:
//  - it handles text input,
//  - performs HTTP requests,
//  - displays loading indicators and error messages
class UserLoginPage extends StatefulWidget {
  const UserLoginPage({super.key});

  @override
  State<UserLoginPage> createState() => _UserLoginPageState();
}

// The state class holds all dynamic data (text fields, loading state, errors)
class _UserLoginPageState extends State<UserLoginPage> {
  // HTTP client configured to communicate with your FastAPI backend
  final dio = Dio(BaseOptions(baseUrl: "http://127.0.0.1:8000"));

  // Text controllers to read input text from the two fields
  final sailController = TextEditingController(); // Sail Number input
  final passController = TextEditingController(); // Password input

  // Error message shown under the AppBar if login fails
  String? error;

  // Loading flag used to display a spinner instead of Login button
  bool loading = false;


  // ATTEMPT LOGIN


  // Handles user login logic

  // Steps:
  //   1. Clear errors and show loading spinner
  //   2. POST /user-login { sail_no, password } to backend
  //   3. If response["success"] == true:
  //        - Navigate to UserBoatPage
  //      Else:
  //        - Display server-provided error message
  //   4. If network exception occurs:
  //        - Show "Connection error"
  Future<void> _login() async {
    // Reference: async/await with Dio POST, JSON handling [D1][F8]
    // Reset UI state before making the request
    setState(() {
      error = null;
      loading = true;
    });

    try {
      // Send login request to backend
      final res = await dio.post("/user-login", data: {
        "sail_no": sailController.text.trim(),
        "password": passController.text.trim(),
      });

      // Backend signals success using success = true
      if (res.data["success"] == true) {
        // Only navigate if widget is still mounted
        if (context.mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              // Pass the boat object into the next screen
              builder: (_) => UserBoatPage(boat: res.data["boat"]),
            ),
          );
        }

      } else {
        // Server responded but login failed (wrong password, boat not found, etc.)
        setState(() => error = res.data["message"]);
      }

    } catch (e) {
      // Network or backend unreachable
      setState(() => error = "Connection error");
    }

    // Stop the spinner now that login attempt has finished
    setState(() => loading = false);
  }


  // BUILD UI


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The AppBar title indicates this is the competitor login path
      // Reference: Simple login form UI (TextField, obscureText for passwords) [F1][F4]
      appBar: AppBar(title: const Text("Competitor Login")),

      // Add padding inside the screen
      body: Padding(
        padding: const EdgeInsets.all(20),

        // Use a Column to stack content vertically
        child: Column(
          children: [

            // ERROR MESSAGE 
            if (error != null)
              Text(
                error!,
                style: const TextStyle(color: AppTheme.danger),
              ),

            //  SAIL NUMBER INPUT 
            TextField(
              controller: sailController,
              decoration: const InputDecoration(
                labelText: "Sail Number", // User sees this text label
                border: OutlineInputBorder(),  // Adds visible textfield border
              ),
            ),

            const SizedBox(height: 16),

            //  PASSWORD INPUT 
            TextField(
              controller: passController,
              obscureText: true,  // Hide password characters
              decoration: const InputDecoration(
                labelText: "Password",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            //  LOGIN BUTTON OR LOADING SPINNER 
            loading
                // Show spinner while login is in progress
                ? const CircularProgressIndicator()
                // Otherwise show the login button
                : ElevatedButton(
                    onPressed: _login,            // Run login function
                    child: const Text("Login"),   // Button label
                  ),
          ],
        ),
      ),
    );
  }
}

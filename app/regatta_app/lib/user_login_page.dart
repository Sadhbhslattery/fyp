// This page lets competitors (boat owners) log in using their sail number and password. 
// After successful login, the backend returns the boat object and the app navigates to UserBoatPage where they can view:
// Today's race course
// Their class results
// Their own boat highlighted

// Key Difference from Admin Login
// Admin login uses username/password and navigates to fleet management.
// User login uses sail_no/password and navigates to personal dashboard.

// Backend endpoint: POST /user-login
// Response: { "success": true, "boat": {...} } or { "success": false, "message": "..." }


import 'package:flutter/material.dart'; // Flutter UI components
import 'package:dio/dio.dart';  // HTTP client for backend requests 
import 'package:regatta_app/theme/app_theme.dart'; // Dark Theme
// Reference: Dio for HTTP requests [D1], login form similar pattern as admin login [F4]
import 'user_boat_page.dart';   // Next screen after successful login


class UserLoginPage extends StatefulWidget {
  // stateful because of text input and API calls
  const UserLoginPage({super.key});

  @override
  State<UserLoginPage> createState() => _UserLoginPageState();
}

class _UserLoginPageState extends State<UserLoginPage> {
  // The state class holds all dynamic data (text fields, loading state, errors)
  final dio = Dio(BaseOptions(baseUrl: "https://web-production-9fd2e3.up.railway.app"));
  // HTTP client configured to communicate with my FastAPI backend

  // Text controllers to read input text from the two fields
  final sailController = TextEditingController(); // Sail Number input
  final passController = TextEditingController(); // Password input

  String? error;// Error message shown under the AppBar if login fails

  bool loading = false; // Loading flag used to display a spinner instead of Login button
 

  // Attempt Login

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
      // Sends sail number and password to backend. 
      // Note the field is "sail_no" (snake_case) to match backend Pydantic model.

      // Backend signals success using success = true
      if (res.data["success"] == true) {
        // Only navigate if widget is still mounted
        if (context.mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              // Pass the boat object into the next screen
              builder: (_) => UserBoatPage(boat: res.data["boat"], sailNo: '',),
            ),
            // Key difference: Passes boat data to UserBoatPage constructor.
            // This is the boat object from backend containing sail_no, name, class_name, rating_value, etc.
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


  // Build Method (UI) 


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

            // Error Message
            if (error != null)
              Text(
                error!,
                style: const TextStyle(color: AppTheme.danger),
              ),

            // Sail Number Input 
            TextField(
              controller: sailController,
              decoration: const InputDecoration(
                labelText: "Sail Number",  // User sees this text label
                border: OutlineInputBorder(),  // Adds visible textfield border
              ),
            ),

            const SizedBox(height: 16),

            // Password input
            TextField(
              controller: passController,
              obscureText: true,  // Hide password characters
              decoration: const InputDecoration(
                labelText: "Password",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            //  Login button or leading spinner
            loading
                // Show spinner while login is in progress
                ? const CircularProgressIndicator()
                // Otherwise show the login button
                : ElevatedButton(
                    onPressed: _login,  // Run login function
                    child: const Text("Login"),  // Button label
                  ),
          ],
        ),
      ),
    );
  }
}

// Summary 
// Very similar to admin login, but:
// Uses sail_no instead of username
// Calls POST /user-login
// Receives boat object in response
// Navigates to UserBoatPage(boat: ...)
// No form validation (simplified)

// Reference: StatefulWidget for form state [F14]
// Reference: TextField for input fields [F4]
// Reference: Dio POST request for authentication [D1][D3]
// Reference: Navigator.pushReplacement with data passing [F28]
// Reference: CircularProgressIndicator for loading state [F1]
// Reference: SnackBar for error feedback [F7]
// Reference: FastAPI user authentication endpoint [B1]

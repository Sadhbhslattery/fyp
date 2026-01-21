// This file displays the Admin Login screen
// It allows the Race Officer to:
// - Enter username and password
// - Validate credentials via FastAPI backend (/login endpoint)
// - Navigate to the FleetAdminPage on success

import 'package:flutter/material.dart'; // Flutter UI framework
import 'package:dio/dio.dart';  // HTTP client for calling the backend
import 'fleet_admin_page.dart';  // Screen to open after successful login

// LoginPage is a StatefulWidget because:
// - The form fields (username & password) contain mutable text
// - The loading spinner appears/disappears
// - Error messages appear dynamically
class LoginPage extends StatefulWidget {
  const LoginPage({super.key}); // Constructor

  @override
  State<LoginPage> createState() => _LoginPageState();
}
// Reference: Dio HTTP client for Flutter [D1]

// Holds all the mutable login logic and UI state
class _LoginPageState extends State<LoginPage> {

  // BACKEND CLIENT SETUP


  // Create the Dio client with the backend base URL
  // Every request like dio.post("/login") → goes to http://127.0.0.1:8000/login
  final dio = Dio(BaseOptions(baseUrl: "http://127.0.0.1:8000"));


  // FORM & CONTROLLERS


  // Form key used to validate the username & password fields
  final _formKey = GlobalKey<FormState>();
  // Reference: Flutter form validation (Form, GlobalKey, TextFormField) [F4]

  // Text controllers for reading the text typed into the form fields
  final usernameController = TextEditingController(); // For admin username
  final passwordController = TextEditingController(); // For admin password

  // STATE VARIABLES
  

  bool loading = false; // True while login request is being sent
  String? errorMessage; // Stores error message to show in UI

  // LOGIN LOGIC (CALLS BACKEND)

  // Attempts to log in by sending POST /login to the backend with:
  // - username
  // - password
  //
  // If the backend returns success:true - navigate to FleetAdminPage
  // Otherwise - show "invalid credentials"
  // Reference: async/await futures in Dart [F8] and Dio POST request [D1]
  Future<void> _attemptLogin() async {
    // First validate the form:
    // Run validators on all TextFormFields (username/password)
    if (!_formKey.currentState!.validate()) return;

    // Update UI: show loading spinner and clear previous error
    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      // POST request to backend with login data
      final res = await dio.post("/login", data: {
        "username": usernameController.text.trim(),  // Trim removes spaces
        "password": passwordController.text.trim(),
      });

      // The backend returns success: true or false
      if (res.data["success"] == true) {
        // Backend accepted credentials
        // Navigate to the admin fleet page

        // context.mounted ensures the widget still exists in the tree
        if (context.mounted) {
          // pushReplacement removes login page so Admin cannot go "back" to login
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const FleetAdminPage()),
          );
        }

      } else {
        // Backend responded but credentials were wrong
        setState(() {
          errorMessage = "Invalid username or password";
        });
      }

    } catch (e) {
      // If connection fails entirely (backend not running), show generic message
      setState(() {
        errorMessage = "Error connecting to server";
      });

    } finally {
      // Stop the loading spinner in all cases
      setState(() {
        loading = false;
      });
    }
  }


  // UI BUILD METHOD
  

  @override
  Widget build(BuildContext context) {
    // Reference: Scaffold, TextFormField, ElevatedButton UI pattern [F1][F3][F4]
    return Scaffold(
      // AppBar at the top with title "Admin Login"
      appBar: AppBar(title: const Text("Admin Login")),

      // Padding adds space around the main content
      body: Padding(
        padding: const EdgeInsets.all(20),

        // Center widget centers the content on the screen
        child: Center(
          child: SingleChildScrollView(
            // SingleChildScrollView prevents overflow if keyboard appears
            child: Form(
              // Connect the form widget to the key for validation
              key: _formKey,

              child: Column(
                children: [
                  
                  // ERROR MESSAGE (IF ANY)
                  
                  // Reference: Flutter conditional rendering and progress indicators [F1]

                  if (errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        errorMessage!,               // Show the error text
                        style: const TextStyle(
                          color: Colors.red,         // Red to indicate a problem
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                  
                  // USERNAME FIELD
                  
                  TextFormField(
                    controller: usernameController, // Reads/writes username text
                    decoration: const InputDecoration(
                      labelText: "Username",        // Field label
                      border: OutlineInputBorder(), // Standard boxed style
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? "Enter username" : null,
                  ),

                  const SizedBox(height: 16),

                  
                  // PASSWORD FIELD
                  
                  TextFormField(
                    controller: passwordController,
                    obscureText: true,              // Hides password characters
                    decoration: const InputDecoration(
                      labelText: "Password",
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? "Enter password" : null,
                  ),

                  const SizedBox(height: 20),

                  
                  // LOGIN BUTTON OR LOADING SPINNER
                  
                  loading
                      ? const CircularProgressIndicator() // Show spinner when "loading == true"
                      : ElevatedButton(
                          onPressed: _attemptLogin,   // Try to log in
                          child: const Text("Login"), // Button text
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// This page provides a simple username/password login for race officers (admins). 
// After successful authentication, it navigates to FleetAdminPage where they can manage the fleet and race.
// Authentication Flow
// 1. Admin enters username and password
// 2. App sends POST /login to backend
// 3. Backend checks credentials (currently hardcoded: admin/password123)
// 4. If valid: navigate to FleetAdminPage
// 5. If invalid: show error message

import 'package:flutter/material.dart'; // Flutter UI framework
import 'package:dio/dio.dart';  // HTTP client for calling the backend
import 'package:regatta_app/theme/app_theme.dart';  // The dark theme
import 'fleet_admin_page.dart';  // Screen to open after successful login
import 'package:regatta_app/signup_page.dart'; // Sign Up page
import 'package:regatta_app/user_boat_page.dart'; // User Page



class LoginPage extends StatefulWidget {
  // StatefulWidget because the form has changing data (text input, loading state, errors)
  const LoginPage({super.key}); // Constructor

  @override
  State<LoginPage> createState() => _LoginPageState();
}
// Reference: Dio HTTP client for Flutter [D1]

class _LoginPageState extends State<LoginPage> {
// The state class that holds all mutable data

  // Backend Client Setup

  final dio = Dio(BaseOptions(baseUrl: "https://web-production-9fd2e3.up.railway.app"));
  // Creates HTTP client pointing to localhost:8000. All requests will be prefixed with this base URL.
  // Now with Railway it is: "https://web-production-9fd2e3.up.railway.app"


  // Form and Controllers

  final _formKey = GlobalKey<FormState>();
  // Line 41: final _formKey = GlobalKey<FormState>()
  // Form key used for validation. When I call _formKey.currentState!.validate(), 
  // Flutter runs all field validators and returns true if all pass.

  // Reference: Flutter form validation (Form, GlobalKey, TextFormField) [F4]

  final usernameController = TextEditingController(); // For admin username
  final passwordController = TextEditingController(); // For admin password
  // Text controllers for reading the text typed into the form fields


  // State Varibales
  

  bool loading = false; // Shows spinner during login attempt
  String? errorMessage; // Stores error message to display

  // Login Logic (Calls Backend)

  // Attempts to log in by sending POST /login to the backend with:
  // - username
  // - password
  
  // If the backend returns success:true - navigate to FleetAdminPage
  // Otherwise - show "invalid credentials"
  // Reference: async/await futures in Dart [F8] and Dio POST request [D1]
  Future<void> _attemptLogin() async {
    // Async function that handles login logic
    if (!_formKey.currentState!.validate()) return;
    // Triggers all validators in the form. If any fail, this returns early without making the API call.

    setState(() {
      loading = true;
      errorMessage = null;
    });
    // Shows loading spinner and clears any previous error

    try {
      // POST request to backend with login data
      final res = await dio.post("/login", data: {
        "sail_no": usernameController.text.trim(),  // Trim removes spaces
        "password": passwordController.text.trim(),
      });
      // Sends credentials to backend. await pauses until response arrives.

      // The backend returns success: true or false
      final role = res.data["role"];

      if (role == "admin") {
        if (context.mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const FleetAdminPage()),
          );
        }
      } else if (role == "competitor") {
        if (context.mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => UserBoatPage(
                sailNo: usernameController.text.trim(), boat: {},
              ),
            ),
          );
        }
      } else {
        setState(() {
          errorMessage = "Invalid login response";
        });
      }



    } catch (e) {
      // If connection fails entirely (backend not running), show generic message
      setState(() {
        errorMessage = "Error connecting to server";
      });

    } finally {
      // Always runs, even if exception occurs. Stops the loading spinner.
      setState(() {
        loading = false;
      });
    }
  }


  // UI Build Method
  

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

                  // Reference: Flutter conditional rendering and progress indicators [F1]
                  
                  // Error Message

                  if (errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        errorMessage!,  // Show the error text
                        style: const TextStyle(
                          color: AppTheme.danger,  // Red to indicate a problem
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                  
                  // Username field
                  
                  TextFormField(
                    controller: usernameController, // Reads/writes username text
                    decoration: const InputDecoration(
                      labelText: "Sail number",        // Field label
                      border: OutlineInputBorder(), // Standard boxed style
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? "Enter username" : null,
                  ),
                  // validator: Function that returns null if valid, error string if invalid. 
                  // This runs when form.validate() is called.

                  const SizedBox(height: 16),

                  
                  // Password Field
                  
                  TextFormField(
                    controller: passwordController,
                    obscureText: true,  // Replaces typed characters with dots/bullets for security
                    decoration: const InputDecoration(
                      labelText: "Password",
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? "Enter password" : null,
                  ),

                  const SizedBox(height: 20),

                  
                  // Login button or spinner
                  
                  loading
                      ? const CircularProgressIndicator()  // Show spinner when "loading == true"
                      : ElevatedButton(
                          onPressed: _attemptLogin,  // Ternary operator: if loading is true, show spinner; else show button. When button is pressed, calls _attemptLogin().
                          child: const Text("Login"),  // Button text
                        ),

                  // Create Account button (navigates to SignupPage)
                  // On success, SignupPage returns the sail_no so we can prefill the login field.
                  TextButton(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SignupPage(dio: dio),
                        ),
                      );

                      // result will be sail_no from SignupPage (we returned Navigator.pop(context, sailNo))
                      if (result is String && result.isNotEmpty) {
                        setState(() {
                          usernameController.text = result; // or sailNoController.text
                        });
                      }
                    },
                    child: const Text("Create account"),
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

// Summary 
// Simple form with:
// 1. Two text fields (username, password) with validation
// 2. Login button that calls backend
// 3. Error display in red
// 4. Loading spinner during API call
// 5. Navigation to FleetAdminPage on success

// Reference: StatefulWidget for form state [F14]
// Reference: Form validation with GlobalKey [F4]
// Reference: TextFormField with validators [F4]
// Reference: Dio POST request for authentication [D1][D3]
// Reference: Navigator.pushReplacement to prevent back navigation [F28]
// Reference: CircularProgressIndicator for loading state [F1]
// Reference: SnackBar for error messages [F7]
// Reference: FastAPI authentication endpoint [B1]


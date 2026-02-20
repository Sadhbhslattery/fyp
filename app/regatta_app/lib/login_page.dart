// This page provides a simple username/password login for race officers (admins). 
// After successful authentication, it navigates to FleetAdminPage where they can manage the fleet and race.
// Authentication Flow
// 1. Admin enters username and password
// 2. App sends POST /login to backend
// 3. Backend checks credentials (currently hardcoded: admin/password123)
// 4. If valid: navigate to FleetAdminPage
// 5. If invalid: show error message

import 'package:flutter/material.dart';
// Provides Scaffold, AppBar, Form, TextFormField, ElevatedButton, etc.
// Reference: Flutter Introduction to Widgets [F1]

import 'package:dio/dio.dart';
// HTTP client for calling the FastAPI /login endpoint.
// Reference: Dio package [D1]

import 'package:regatta_app/theme/app_theme.dart';
// Provides AppTheme.danger (red) for error text styling.
// Reference: Material Design Dark Theme [A2]

import 'fleet_admin_page.dart';
// The fleet management screen navigated to after a successful admin login.
// Reference: Flutter Navigator [F28]


class LoginPage extends StatefulWidget {
  // StatefulWidget because the form holds changing data:
  //   text input values, loading state, and error messages.
  // Reference: Flutter StatefulWidget lifecycle [F14]
  const LoginPage({super.key});
  // super.key passes the key to the Widget superclass.

  @override
  State<LoginPage> createState() => _LoginPageState();
  // Returns the private State class that manages LoginPage's mutable data.
}


class _LoginPageState extends State<LoginPage> {
  // State class for LoginPage – holds controllers, form key, and flags.

  // HTTP Client
  final dio = Dio(BaseOptions(baseUrl: "https://web-production-9fd2e3.up.railway.app"));
  // Dio instance with the Railway backend URL as the base.
  // Every dio.post("/login") call prepends this URL automatically.
  // Reference: Dio BaseOptions [D2]
  // Reference: Railway deployment [RD1]

  // Form Key
  final _formKey = GlobalKey<FormState>();
  // A GlobalKey that gives programmatic access to the Form widget's state.
  // Calling _formKey.currentState!.validate() triggers all field validators
  // and returns true only if all pass.
  // Reference: Flutter Form validation with GlobalKey [F4]

  // Text Controllers
  final usernameController = TextEditingController();
  // Controls the Username field. .text reads the typed value.
  // Reference: Flutter TextEditingController [F12]

  final passwordController = TextEditingController();
  // Controls the Password field.
  // Reference: Flutter TextEditingController [F12]

  // State Variables
  bool loading = false;
  // True while the POST /login request is in flight.
  // Switches the Login button to a spinner when true.

  String? errorMessage;
  // Null when there is no error to display; non-null shows the error above the form.

  // Login Logic

  Future<void> _attemptLogin() async {
    // Async function handling the full login cycle: validate - request - navigate.
    // Reference: Dart async/await [F8]

    if (!_formKey.currentState!.validate()) return;
    // Run all field validators. If any field is empty the validator returns
    // an error string and validate() returns false, so we return early without
    // making the network request.
    // Reference: Flutter Form.validate() [F4]

    setState(() {
      loading = true;  // Show spinner while awaiting the HTTP response.
      errorMessage = null;  // Clear any previously shown error.
    });
    // Reference: Flutter setState [F14]

    try {
      final res = await dio.post("/login", data: {
        // POST the credentials as a JSON body to /login.
        // await pauses execution until the server responds.
        // Reference: Dio POST [D3]
        "username": usernameController.text.trim(),
        // .trim() strips accidental leading/trailing whitespace.
        // Field name "username" matches AdminLoginRequest Pydantic model [B3].
        "password": passwordController.text.trim(),
        // Plain-text password sent over HTTPS to the backend.
      });

      if (res.data["success"] == true) {
        // Backend returned { "success": true, "message": "Login successful" }.
        if (context.mounted) {
          // Check mounted before using context after an await.
          // Reference: Flutter mounted check [F28]
          Navigator.pushReplacement(
            // pushReplacement removes LoginPage from the stack so back button
            // does not return the admin to the login screen.
            // Reference: Flutter Navigator.pushReplacement [F28]
            context,
            MaterialPageRoute(builder: (_) => const FleetAdminPage()),
            // MaterialPageRoute applies the default slide-in transition.
          );
        }
      } else {
        // Backend responded but credentials were wrong.
        setState(() {
          errorMessage = "Invalid username or password";
        });
      }

    } catch (e) {
      // Catches network errors (no connection, timeout, server down, etc.).
      setState(() {
        errorMessage = "Error connecting to server";
      });
      // A more detailed error handler (like DioException) could be added here;
      // this simple catch-all keeps the admin login minimal.

    } finally {
      // finally block always runs, even if an exception was thrown.
      // Stops the loading spinner after the request completes or fails.
      setState(() {
        loading = false;
      });
      // Reference: Dart try/catch/finally [F8]
    }
  }


  // UI Build Method

  @override
  Widget build(BuildContext context) {
    // Builds the full page widget tree.  Called on every setState().
    // Reference: Flutter build() [F1]
    return Scaffold(
      // Standard Material page structure.
      // Reference: Flutter Scaffold [F3]
      appBar: AppBar(title: const Text("Admin Login")),
      // AppBar with "Admin Login" title to distinguish this from the competitor login.
      // Reference: Flutter AppBar [F14]

      body: Padding(
        padding: const EdgeInsets.all(20),
        // 20px padding on all sides.
        child: Center(
          // Center the form content both vertically and horizontally.
          // Reference: Flutter Center widget [F1]
          child: SingleChildScrollView(
            // SingleChildScrollView prevents overflow when the keyboard is shown,
            // allowing the user to scroll to see all fields.
            // Reference: Flutter SingleChildScrollView [F1]
            child: Form(
              // Form groups the TextFormFields and provides collective validation
              // via _formKey.currentState!.validate().
              // Reference: Flutter Form validation [F4]
              key: _formKey,
              // Connects the Form to the GlobalKey so validate() can be called externally.
              child: Column(
                // Stacks children vertically.
                // Reference: Flutter Column [F20]
                children: [

                  // Error Banner 
                  if (errorMessage != null)
                  // Dart collection-if: adds the Text widget only when there is an error.
                  // Reference: Dart collection if [F15]
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      // 16px space below the error before the first field.
                      child: Text(
                        errorMessage!,
                        // errorMessage! is safe because of the null check above.
                        style: const TextStyle(
                          color: AppTheme.danger,
                          // Red to signal a problem to the user.
                          // Reference: Material colour guidelines [A2]
                          fontWeight: FontWeight.bold,
                          // Bold makes the error text stand out.
                        ),
                      ),
                    ),

                  // Username Field 
                  TextFormField(
                    // TextFormField integrates with Form for collective validation.
                    // Reference: Flutter TextFormField [F4]
                    controller: usernameController,
                    // Links the field to the controller so _attemptLogin() can read it.
                    decoration: const InputDecoration(
                      labelText: "Username",
                      border: OutlineInputBorder(),
                      // Rectangular outlined border style.
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? "Enter username" : null,
                    // validator runs when _formKey.currentState!.validate() is called.
                    // Returns an error string if invalid (shown under the field),
                    // or null if valid.
                    // Reference: Flutter form validation [F4]
                  ),

                  const SizedBox(height: 16),
                  // 16px vertical gap between username and password fields.

                  // Password Field 
                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    // Masks typed characters for security.
                    // Reference: Flutter TextField obscureText [F12]
                    decoration: const InputDecoration(
                      labelText: "Password",
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? "Enter password" : null,
                    // Returns an error if the password field is empty.
                  ),

                  const SizedBox(height: 20),
                  // 20px gap between the password field and the button.

                  // Login Button / Spinner 
                  loading
                      ? const CircularProgressIndicator()
                      // While loading is true, show an indeterminate spinner.
                      // Reference: Flutter CircularProgressIndicator [F1]
                      : ElevatedButton(
                          // When not loading, show the Login button.
                          // Reference: Flutter ElevatedButton [F13]
                          onPressed: _attemptLogin,
                          // Tapping calls _attemptLogin().
                          child: const Text("Login"),
                        ),

                ], // end Column children
              ),
            ),
          ),
        ),
      ),
    );
  }
}


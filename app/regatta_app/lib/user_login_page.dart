// This page lets competitors (boat owners) log in using their sail number and password.
// After successful login, the backend returns the boat object and the app navigates to UserBoatPage where they can view:
// Today's race course
// Their scheduled start time and live countdown
// Their class results
// Their own boat highlighted

// Key Difference from Admin Login
// Admin login uses username/password and navigates to fleet management.
// User login uses sail_no/password and navigates to personal dashboard.

// Backend endpoint: POST /user-login
// Request body: { "sail_no": "IRL5355", "password": "mypassword123" }
// Response: { "success": true, "boat": {...} } or { "success": false, "message": "..." }

import 'package:flutter/material.dart';
// Flutter's core Material Design UI toolkit.
// Provides Scaffold, AppBar, TextField, ElevatedButton, CircularProgressIndicator, etc.
// Reference: Flutter Introduction to Widgets [F1]

import 'package:dio/dio.dart';
// Dio is a powerful HTTP client for Dart/Flutter.
// Provides BaseOptions (base URL config), dio.post() and DioException for error handling.
// Reference: Dio package [D1]

import 'package:regatta_app/theme/app_theme.dart';
// Imports the app-wide dark nautical theme, including AppTheme.danger (red colour)
// used to style error messages. Theme colours follow WCAG contrast guidelines.
// Reference: Material Design Dark Theme [A2]
// Reference: WCAG Contrast Ratios [A1]

import 'user_boat_page.dart';
// The competitor dashboard page navigated to after a successful login.
// Receives the boat object from this page via its constructor.
// Shows scheduled start time, countdown, elapsed timer, course and results.
// Reference: Flutter Navigator [F28]

import 'package:regatta_app/signup_page.dart';
// The account-creation page, opened when the competitor taps "Create account".
// When signup completes, it returns the sail_no so this page can pre-fill the field.
// Reference: Flutter Navigator.push with result [F28]


// Widget Declaration 


class UserLoginPage extends StatefulWidget {
  // StatefulWidget because this page holds mutable state:
  //   text field values (sailController, passController)
  //   loading spinner flag (loading)
  //   error message string (error)
  // Reference: Flutter StatefulWidget lifecycle [F36]
  const UserLoginPage({super.key});
  // super.key passes the optional key argument up to the Widget base class.
  // Keys help Flutter identify widgets in the tree when rebuilding.
  // Reference: Flutter Introduction to Widgets [F1]

  @override
  State<UserLoginPage> createState() => _UserLoginPageState();
  // createState() returns the associated State object.
  // The leading underscore makes _UserLoginPageState private to this file.
  // This is a Dart naming convention for library-private identifiers.
}


// State Class 

class _UserLoginPageState extends State<UserLoginPage> {
  // Holds all mutable data (controllers, flags, error string) for UserLoginPage.
  // Extends State<UserLoginPage> which gives access to widget, context, mounted, setState.
  // Reference: Flutter State lifecycle [F36]

  // HTTP Client 
  final dio = Dio(
    BaseOptions(baseUrl: "https://web-production-9fd2e3.up.railway.app"),
  );
  // Creates a Dio HTTP client instance with the Railway-hosted backend URL.
  // BaseOptions.baseUrl prefixes every request, so dio.post("/user-login") sends
  // a request to https://web-production-9fd2e3.up.railway.app/user-login.
  // Reference: Dio BaseOptions [D2]
  // Reference: Railway deployment [RD1]

  // Text Input Controllers 
  final sailController = TextEditingController();
  // Controls the Sail Number TextField.
  // sailController.text gives the current typed value.
  // Must be disposed in dispose() to prevent memory leaks.
  // Reference: Flutter TextField & TextEditingController [F12]

  final passController = TextEditingController();
  // Controls the Password TextField.
  // passController.text gives the current typed value.
  // Must be disposed in dispose() to prevent memory leaks.
  // Reference: Flutter TextField & TextEditingController [F12]

  // State Variables 
  String? error;
  // Nullable string – null means no error to display, non-null means show the error
  // in red text above the form. Set by _login() on failure, cleared on retry.
  // Reference: Dart null safety and nullable types [F8]

  bool loading = false;
  // True while the login HTTP request is in flight.
  // When true, the Login button is replaced with a CircularProgressIndicator.
  // Set to true at the start of _login(), set to false when it completes.
  // Reference: Flutter CircularProgressIndicator [F1]


  // Lifecycle 

  @override
  void dispose() {
    // dispose() is called when Flutter removes this State from the widget tree.
    // Always dispose TextEditingControllers to release the underlying resources
    // and prevent memory leaks when the user navigates away.
    // Reference: Flutter widget lifecycle dispose [F36]
    sailController.dispose();
    // Releases the sail number controller's memory and detaches listeners.
    passController.dispose();
    // Releases the password controller's memory and detaches listeners.
    super.dispose();
    // Calls the parent State.dispose() to complete the teardown chain.
    // Must always be the last line in dispose() to avoid accessing
    // the widget after the parent has torn down.
  }


  // Login Logic 


  Future<void> _login() async {
    // async marks this as an asynchronous function – it can use await.
    // Future<void> means it returns no value when complete.
    // Reference: Dart async/await [F8]

    // 1. Reset UI: clear previous error and show loading spinner.
    setState(() {
      // setState() notifies Flutter that state has changed, triggering a rebuild.
      // Reference: Flutter setState [F36]
      error = null; // Clear any previously displayed error message.
      loading = true; // Switch the Login button to a spinner.
    });

    try {
      // 2. POST the credentials to the FastAPI backend.
      final res = await dio.post("/user-login", data: {
        // await suspends execution here until the HTTP response arrives.
        // The data map is automatically serialised to JSON by Dio.
        // Reference: Dart async/await and Future [F8]
        // Reference: Dio POST request [D3]
        "sail_no": sailController.text.trim(),
        // .trim() removes leading/trailing whitespace the user may have typed.
        // Reference: Dart String methods [B22]
        // Field name "sail_no" must match the UserLoginRequest Pydantic schema [B3].
        "password": passController.text.trim(),
        // Plain-text password sent over HTTPS; the backend hashes it with bcrypt
        // and compares against the stored hash — never stored in plain text.
        // Reference: passlib bcrypt [B15]
        // Reference: Provos & Mazières bcrypt paper [B16]
      });
      // dio.post() sends a POST request with the data dict serialised as JSON.
      // On success it returns a Response object whose .data field contains the
      // decoded JSON body (a Dart Map<String, dynamic>).
      // Reference: Dio POST request [D3]
      // Reference: FastAPI endpoint [B1]

      debugPrint("USER-LOGIN RES: ${res.data}");
      // Writes the raw backend response to the debug console.
      // Useful during development to confirm what shape of JSON was returned.
      // Reference: Flutter debugPrint [F34]

      // 3. Extract the response body.
      final data = res.data;
      // res.data is already parsed from JSON into a Dart Map<String, dynamic>
      // by Dio's default JSON transformer.

      // 4. Determine whether login was successful.
      final bool ok =
          (data is Map && data["success"] == true) ||
          (data is Map && data["boat"] != null);
      // Two success conditions are checked for robustness:
      //  a) Backend explicitly set "success": true in the response body.
      //  b) Backend returned a non-null "boat" object (older response shape).
      // Using `is Map` guards against the rare case where data is not a Map.
      // Reference: Dart type checking with `is` [F8]

      if (ok) {
        // 5a. Login succeeded – extract the boat object and navigate forward 

        final boat = (data is Map) ? (data["boat"] ?? data) : data;
        // Extract the nested "boat" dict from the response.
        // Falls back to the entire data map if "boat" key is null
        // (handles older backend response shapes).
        // Reference: Dart null-aware operator ?? [F8]

        if (context.mounted) {
          // context.mounted guards against using the BuildContext after the
          // widget has been removed from the tree (e.g. if the user navigated
          // away before the async call completed). Prevents a Flutter error.
          // Reference: Flutter mounted property [F36]
          Navigator.pushReplacement(
            // pushReplacement removes UserLoginPage from the navigation stack
            // so the back button does not return to the login screen.
            // This is standard practice for login flows.
            // Reference: Flutter Navigator.pushReplacement [F28]
            context,
            MaterialPageRoute(
              // MaterialPageRoute builds the destination widget with a
              // platform-appropriate slide transition animation.
              // Reference: Flutter Navigator [F28]
              builder: (_) => UserBoatPage(
                boat: boat,
                // Passes the full boat object to UserBoatPage so it can display
                // the competitor's name, class, results, and scheduled start time
                // without an extra API call.
                sailNo: (boat is Map && boat["sail_no"] != null)
                    ? boat["sail_no"].toString()
                    : sailController.text.trim(),
                // Passes the sail number as a separate convenience parameter.
                // Prefers the value from the server response; falls back to the
                // text field value if the server did not echo it back.
                // Reference: Dart type check and null-aware access [F8]
              ),
            ),
          );
        }

      } else {
        // 5b. Login failed – display the server's error message 
        setState(() {
          // Update error to trigger a rebuild showing the error banner [F36]
          if (data is Map) {
            error = (data["message"] ?? data["detail"] ?? "Login failed").toString();
            // Tries "message" first (app convention), then "detail" (FastAPI default),
            // then falls back to a generic string.
            // Reference: FastAPI HTTPException detail field [B1]
            // Reference: Dart null-aware chaining [F8]
          } else {
            error = "Login failed";
            // Safety fallback if the response body is not a Map.
          }
        });
      }

    } on DioException catch (e) {
      // Catches HTTP-level errors (4xx / 5xx status codes, network timeouts, etc.).
      // DioException wraps the failed response so the status code and body are accessible.
      // Reference: Dio DioException [D1]
      debugPrint("USER-LOGIN ERROR: ${e.response?.data}");
      // Logs the error response body to the debug console to aid debugging.
      // Reference: Flutter debugPrint [F34]
      setState(() {
        error = e.response?.data.toString() ?? "Connection error";
        // Shows the server's error body if available, otherwise a generic message.
        // ?. is the null-safe member access operator — avoids a crash if
        // e.response is null (e.g. when the server is completely unreachable).
        // Reference: Dart null safety [F8]
      });

    } catch (e) {
      // Catches any other unexpected errors (e.g. JSON parsing errors,
      // type cast failures, or unhandled exceptions).
      setState(() => error = e.toString());
      // Converts the exception to a string and displays it to the user.
    }

    // 6. Stop the loading spinner regardless of outcome (success, failure, or error).
    if (mounted) {
      // mounted check again because await may have taken time and the widget
      // could have been disposed while waiting for the network response.
      // Reference: Flutter mounted property [F36]
      setState(() => loading = false);
      // Set loading to false so the next rebuild shows the Login button
      // instead of the CircularProgressIndicator.
    }
  }


  // UI Build Method 

  @override
  Widget build(BuildContext context) {
    // build() is called every time setState() is called or Flutter needs to
    // repaint this widget. It returns the widget tree for this page.
    // Reference: Flutter widget build method [F1]
    return Scaffold(
      // Scaffold provides the standard Material page structure:
      // AppBar, body, FAB slot, bottom sheet slot, etc.
      // Reference: Flutter Scaffold [F3]
      appBar: AppBar(title: const Text("Competitor Login")),
      // AppBar displays a title bar at the top of the page.
      // "Competitor Login" tells the user which login path they are on
      // (as opposed to the separate Admin Login page).
      // Reference: Flutter AppBar [F14]

      body: Padding(
        // Padding adds 20 logical pixels of space on all four sides of the body.
        // This prevents content from touching the screen edges.
        padding: const EdgeInsets.all(20),
        // EdgeInsets.all(20) creates uniform insets of 20px on top, right, bottom, left.
        // Reference: Flutter layout padding [F1]

        child: Column(
          // Column stacks its children vertically from top to bottom.
          // By default it aligns children to the start (top) of the vertical axis.
          // Reference: Flutter Column [F20]
          children: [

            // Error Banner 
            if (error != null)
            // Dart collection-if: this widget is only added to the Column's
            // children list if `error` is non-null. When error is null, this
            // entire Padding widget is excluded from the widget tree.
            // Reference: Dart collection if [F15]
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                // Adds 12px of space below the error text to separate it from
                // the form fields below.
                child: Text(
                  error!,
                  // error! asserts that error is non-null here (safe because of the
                  // `if (error != null)` guard above). The ! operator tells the Dart
                  // compiler we guarantee this is not null. [F8]
                  style: const TextStyle(color: AppTheme.danger),
                  // AppTheme.danger is a red colour defined in the app theme,
                  // chosen to visually signal an error following accessibility guidelines.
                  // Reference: app_theme.dart, Material dark theme [A2]
                  // Reference: WCAG contrast guidelines [A1]
                ),
              ),

            // Sail Number Field 
            TextField(
              // TextField is a Material Design text input widget.
              // Reference: Flutter TextField [F12]
              controller: sailController,
              // Links this field to sailController so _login() can read the
              // typed value via sailController.text.
              decoration: const InputDecoration(
                // InputDecoration configures the visual appearance of the field.
                labelText: "Sail Number",
                // Label floats above the field when it has focus or contains text.
                border: OutlineInputBorder(),
                // Adds a visible rectangular border around the field for clarity.
              ),
            ),

            const SizedBox(height: 16),
            // Adds 16px of vertical space between the two text fields.
            // SizedBox is a lightweight way to add fixed spacing in a Column.
            // Reference: Flutter SizedBox spacer [F1]

            // Password Field 
            TextField(
              // Reference: Flutter TextField [F12]
              controller: passController,
              // Links this field to passController so _login() can read the value.
              obscureText: true,
              // Replaces typed characters with bullet points (•) so the password
              // is not visible on screen. Standard practice for password fields.
              // Reference: Flutter TextField obscureText [F12]
              decoration: const InputDecoration(
                labelText: "Password",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),
            // 20px gap between the password field and the login button.

            // Login Button / Spinner 
            loading
                ? const CircularProgressIndicator()
                // If `loading` is true, show a spinning progress indicator
                // while the HTTP request is in flight. This gives the user
                // visual feedback that something is happening.
                // Reference: Flutter CircularProgressIndicator [F1]
                : ElevatedButton(
                    // Otherwise show the Login button.
                    // ElevatedButton is a filled button with elevation (shadow).
                    // Reference: Flutter ElevatedButton [F13]
                    onPressed: _login,
                    // Calls _login() when the button is tapped.
                    // onPressed accepts a VoidCallback (a function with no arguments).
                    child: const Text("Login"),
                    // Button label text.
                  ),

            // Create Account Link 
            TextButton(
              // TextButton is a flat button with no background or elevation.
              // Used here for a secondary action (account creation).
              // Reference: Flutter TextButton [F13]
              onPressed: () async {
                // async lambda because Navigator.push returns a Future<T?>.
                // We need await to get the result when SignupPage pops.
                // Reference: Dart async/await [F8]
                final result = await Navigator.push(
                  // Navigator.push adds SignupPage on top of the navigation stack.
                  // When SignupPage calls Navigator.pop(context, sailNo) it
                  // returns that value here as `result`.
                  // Reference: Flutter Navigator.push [F28]
                  context,
                  MaterialPageRoute(
                    builder: (_) => SignupPage(dio: dio),
                    // Passes the existing Dio instance to SignupPage so both
                    // pages share the same base URL configuration and connection.
                    // Reference: Dio BaseOptions [D2]
                  ),
                );

                // Check if SignupPage returned a sail number string
                if (result is String && result.isNotEmpty) {
                  // If SignupPage returned a non-empty sail number string,
                  // pre-fill the sail number field so the competitor does not
                  // have to retype it after creating their account.
                  // Reference: Dart type checking with `is` [F8]
                  setState(() {
                    sailController.text = result;
                    // Sets the text field value programmatically.
                    // The user can still edit it before tapping Login.
                    // Reference: Flutter TextEditingController [F12]
                  });
                }
              },
              child: const Text("Create account"),
              // Label for the account creation link.
            ),

          ], // end Column children
        ),
      ),
    );
  }
}


// REFERENCES — This file uses the following sources (full details in
// the Iteration Report reference list)


// Flutter / Dart:
// [F1]  Google LLC, 2025. Flutter: Introduction to widgets.
// [F3]  Google LLC, 2025. Scaffold class.
// [F8]  Google LLC, 2025. Dart language tour: async, futures & Duration.
// [F12] Google LLC, 2025. TextField class.
// [F13] Google LLC, 2025. OutlinedButton & ElevatedButton classes.
// [F14] Google LLC, 2025. AppBar class.
// [F15] Google LLC, 2025. Dart language: collection if / list literals.
// [F20] Google LLC, 2025. Column class.
// [F28] Google LLC, 2025. Navigator class.
// [F34] Google LLC, 2025. debugPrint property.
// [F36] Google LLC, 2025. StatefulWidget lifecycle, initState, dispose, mounted.

// Dio HTTP:
// [D1]  Flutter Community, 2025. Dio package for Dart/Flutter.
// [D2]  Flutter Community, 2025. Dio BaseOptions configuration.
// [D3]  Flutter Community, 2025. Dio request methods (GET, POST, DELETE).

// Backend:
// [B1]  Tiangolo, S., 2024. FastAPI – First Steps, Path Parameters, Query Parameters.
// [B3]  Pydantic, 2024. Pydantic v2: Models and field validators.
// [B15] Python-passlib Contributors, 2024. passlib CryptContext, hash(), verify().
// [B16] Provos, N. and Mazières, D., 1999. A Future-Adaptable Password Scheme.
// [B22] Python Software Foundation, 2025. String Methods.

// Accessibility:
// [A1]  W3C, 2018. Web Content Accessibility Guidelines (WCAG) 2.1.
// [A2]  Material Design, 2024. Dark theme design guidelines.


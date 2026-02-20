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

import 'package:flutter/material.dart';
// Flutter's core Material Design UI toolkit.
// Provides Scaffold, AppBar, TextField, ElevatedButton, CircularProgressIndicator, etc.
// Reference: Flutter Introduction to Widgets [F1]

import 'package:dio/dio.dart';
// Dio is a powerful HTTP client for Dart/Flutter.
// Provides BaseOptions (base URL config), dio.post(), and DioException for error handling.
// Reference: Dio package [D1]

import 'package:regatta_app/theme/app_theme.dart';
// Imports the app-wide dark theme, including AppTheme.danger (red colour)
// used to style error messages.
// Reference: Material Design Dark Theme [A2]

import 'user_boat_page.dart';
// The competitor dashboard page navigated to after a successful login.
// Receives the boat object from this page via its constructor.
// Reference: Flutter Navigator [F28]

import 'package:regatta_app/signup_page.dart';
// The account-creation page, opened when the competitor taps "Create account".
// When signup completes, it returns the sail_no so this page can pre-fill the field.
// Reference: Flutter Navigator.push with result [F28]


// Widget Declaration


class UserLoginPage extends StatefulWidget {
  // StatefulWidget because this page holds mutable state:
  //   text field values
  //   loading spinner flag
  //   error message string
  // Reference: Flutter StatefulWidget [F14]
  const UserLoginPage({super.key});
  // super.key passes the optional key argument up to the Widget base class.
  // Keys help Flutter identify widgets in the tree when rebuilding.

  @override
  State<UserLoginPage> createState() => _UserLoginPageState();
  // createState() returns the associated State object.
  // The leading underscore makes _UserLoginPageState private to this file.
}


// State Class


class _UserLoginPageState extends State<UserLoginPage> {
  // Holds all mutable data (controllers, flags, error string) for UserLoginPage.
  // Reference: Flutter State lifecycle [F14]

  // HTTP Client
  final dio = Dio(
    BaseOptions(baseUrl: "https://web-production-9fd2e3.up.railway.app"),
  );
  // Creates a Dio HTTP client instance.
  // BaseOptions.baseUrl prefixes every request, so dio.post("/user-login") sends
  // a request to https://web-production-9fd2e3.up.railway.app/user-login.
  // Reference: Dio BaseOptions [D2]
  // Reference: Railway deployment [RD1]

  // Text Input Controllers
  final sailController = TextEditingController();
  // Controls the Sail Number TextField.
  // sailController.text gives the current typed value.
  // Reference: Flutter TextField & TextEditingController [F12]

  final passController = TextEditingController();
  // Controls the Password TextField.
  // passController.text gives the current typed value.
  // Reference: Flutter TextField & TextEditingController [F12]

  // State Variables
  String? error;
  // Nullable string – null means no error to display, non-null means show the error
  // in red text above the form.
  // Reference: Dart null safety and nullable types [F8]

  bool loading = false;
  // True while the login HTTP request is in flight.
  // When true, the Login button is replaced with a CircularProgressIndicator.
  // Reference: Flutter CircularProgressIndicator [F1]


  // Lifecycle

  @override
  void dispose() {
    // dispose() is called when Flutter removes this State from the widget tree.
    // Always dispose TextEditingControllers to release the underlying resources
    // and prevent memory leaks when the user navigates away.
    // Reference: Flutter widget lifecycle dispose [F14]
    sailController.dispose();
    // Releases the sail number controller's memory.
    passController.dispose();
    // Releases the password controller's memory.
    super.dispose();
    // Calls the parent State.dispose() to complete the teardown chain.
  }


  // Login Logic


  Future<void> _login() async {
    // async marks this as an asynchronous function – it can use await.
    // Future<void> means it returns no value when complete.
    // Reference: Dart async/await [F8]

    // 1. Reset UI: clear previous error and show loading spinner.
    setState(() {
      // setState() notifies Flutter that state has changed, triggering a rebuild.
      // Reference: Flutter setState [F14]
      error = null;    // Clear any previously displayed error message.
      loading = true;  // Switch the Login button to a spinner.
    });

    try {
      // 2. POST the credentials to the FastAPI backend.
      final res = await dio.post("/user-login", data: {
        // await suspends execution here until the HTTP response arrives.
        // Reference: Dart async/await and Future [F8]
        "sail_no": sailController.text.trim(),
        // .trim() removes leading/trailing whitespace the user may have typed.
        // Field name "sail_no" must match the UserLoginRequest Pydantic schema [B3].
        "password": passController.text.trim(),
        // Plain-text password sent over HTTPS: never stored in plain text on the backend.
        // Reference: passlib bcrypt [B15]
      });
      // dio.post() sends a POST request with the data dict serialised as JSON.
      // On success it returns a Response object whose .data field contains the
      // decoded JSON body.
      // Reference: Dio POST request [D3]

      debugPrint("USER-LOGIN RES: ${res.data}");
      // Writes the raw backend response to the debug console.
      // Useful during development to confirm what shape of JSON was returned.
      // Reference: Flutter debugPrint [F1]

      // 3. Extract the response body.
      final data = res.data;
      // res.data is already parsed from JSON into a Dart Map<String, dynamic>.

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
        // 5a. Login succeeded – extract the boat object and navigate forward.

        final boat = (data is Map) ? (data["boat"] ?? data) : data;
        // Extract the nested "boat" dict.  Falls back to the entire data map
        // if "boat" is null (handles older backend response shapes).
        // Reference: Dart null-aware operator [F8]

        if (context.mounted) {
          // context.mounted guards against using the BuildContext after the
          // widget has been removed from the tree (e.g. if the user navigated
          // away before the async call completed).
          // Reference: Flutter BuildContext and mounted check [F28]
          Navigator.pushReplacement(
            // pushReplacement removes UserLoginPage from the navigation stack
            // so the back button does not return to the login screen.
            context,
            MaterialPageRoute(
              // MaterialPageRoute builds the destination widget with a slide transition.
              builder: (_) => UserBoatPage(
                boat: boat,
                // Passes the full boat object to UserBoatPage so it can display
                // the competitor's name, class, and results without an extra API call.
                sailNo: (boat is Map && boat["sail_no"] != null)
                    ? boat["sail_no"].toString()
                    : sailController.text.trim(),
                // Passes the sail number as a separate convenience parameter.
                // Prefers the value from the server response: falls back to the
                // text field value if the server did not echo it back.
              ),
            ),
          );
          // Reference: Flutter Navigator.pushReplacement [F28]
        }

      } else {
        // 5b. Login failed – display the server's error message.
        setState(() {
          if (data is Map) {
            error = (data["message"] ?? data["detail"] ?? "Login failed").toString();
            // Tries "message" first (app convention), then "detail" (FastAPI default),
            // then falls back to a generic string.
            // Reference: FastAPI HTTPException detail field [B1]
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
      // Logs the error response body to aid debugging.
      setState(() {
        error = e.response?.data.toString() ?? "Connection error";
        // Shows the server's error body if available, otherwise a generic message.
        // ?. is the null-safe member access operator in Dart.
        // Reference: Dart null safety [F8]
      });

    } catch (e) {
      // Catches any other unexpected errors (e.g. JSON parsing errors).
      setState(() => error = e.toString());
      // Converts the exception to a string and displays it.
    }

    // 6. Stop the loading spinner regardless of outcome.
    if (mounted) {
      // mounted check again because await may have taken time and the widget
      // could have been disposed.
      setState(() => loading = false);
    }
  }


  // UI Build Method

  @override
  Widget build(BuildContext context) {
    // build() is called every time setState() is called or Flutter needs to
    // repaint this widget.  It returns the widget tree for this page.
    // Reference: Flutter widget build method [F1]
    return Scaffold(
      // Scaffold provides the standard Material page structure:
      // AppBar, body, FAB slot, etc.
      // Reference: Flutter Scaffold [F3]
      appBar: AppBar(title: const Text("Competitor Login")),
      // AppBar displays a title bar at the top of the page.
      // "Competitor Login" tells the user which login path they are on.
      // Reference: Flutter AppBar [F14]

      body: Padding(
        // Padding adds 20 logical pixels of space on all four sides of the body.
        padding: const EdgeInsets.all(20),
        // EdgeInsets.all(20) creates uniform insets.
        // Reference: Flutter layout padding [F1]

        child: Column(
          // Column stacks its children vertically.
          // Reference: Flutter Column [F20]
          children: [

            // Error Banner 
            if (error != null)
            // Dart collection-if: this widget is only added to the list if
            // `error` is non-null. Reference: Dart collection if [F15]
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                // Adds 12px of space below the error text.
                child: Text(
                  error!,
                  // error! asserts that error is non-null here (safe because of the
                  // `if (error != null)` guard above).
                  style: const TextStyle(color: AppTheme.danger),
                  // AppTheme.danger is a red colour defined in the app theme,
                  // chosen to visually signal an error.
                  // Reference: app_theme.dart, Material dark theme [A2]
                ),
              ),

            // Sail Number Field 
            TextField(
              // TextField is an unvalidated text input widget.
              // Reference: Flutter TextField [F12]
              controller: sailController,
              // Links this field to sailController so _login() can read the value.
              decoration: const InputDecoration(
                labelText: "Sail Number",
                // Label floats above the field when it has focus.
                border: OutlineInputBorder(),
                // Adds a visible rectangular border around the field.
              ),
            ),

            const SizedBox(height: 16),
            // Adds 16px of vertical space between the two text fields.
            // Reference: Flutter SizedBox spacer [F1]

            // Password Field 
            TextField(
              controller: passController,
              // Links this field to passController.
              obscureText: true,
              // Replaces typed characters with bullet points (•) so the password
              // is not visible on screen.
              // Reference: Flutter TextField obscureText [F12]
              decoration: const InputDecoration(
                labelText: "Password",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),
            // 20px gap between the password field and the button.

            // Login Button / Spinner 
            loading
                ? const CircularProgressIndicator()
                // If `loading` is true, show a spinning progress indicator
                // while the HTTP request is in flight.
                // Reference: Flutter CircularProgressIndicator [F1]
                : ElevatedButton(
                    // Otherwise show the Login button.
                    // Reference: Flutter ElevatedButton [F13]
                    onPressed: _login,
                    // Calls _login() when the button is tapped.
                    child: const Text("Login"),
                  ),

            // Create Account Link 
            TextButton(
              // TextButton navigates to SignupPage.
              // Reference: Flutter TextButton [F13]
              onPressed: () async {
                // async lambda because Navigator.push returns a Future<T?>.
                final result = await Navigator.push(
                  // Navigator.push adds SignupPage on top of the stack.
                  // When SignupPage calls Navigator.pop(context, sailNo) it
                  // returns that value here as `result`.
                  // Reference: Flutter Navigator [F28]
                  context,
                  MaterialPageRoute(
                    builder: (_) => SignupPage(dio: dio),
                    // Passes the existing Dio instance to SignupPage so both
                    // pages share the same base URL configuration.
                  ),
                );

                if (result is String && result.isNotEmpty) {
                  // If SignupPage returned a sail number string, pre-fill the
                  // sail number field so the competitor does not have to retype it.
                  setState(() {
                    sailController.text = result;
                    // Sets the text field value programmatically.
                  });
                }
              },
              child: const Text("Create account"),
            ),

          ], // end Column children
        ),
      ),
    );
  }
}
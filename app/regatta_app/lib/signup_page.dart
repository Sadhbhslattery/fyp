// Account creation page for competitors.
// The race officer must have already added the boat's sail number to the
// fleet before signup is possible.

// Backend endpoint: POST /signup
// Expected request body: { sail_no, password, owner_name? }
// Expected response: { "message": "Account created" } or error detail.

// On success the page calls Navigator.pop(context, sailNo) to return the
// sail number to UserLoginPage, which pre-fills the sail number field.


import 'package:flutter/material.dart';
// Core Flutter UI toolkit.
// Reference: Flutter Introduction to Widgets [F1]

import 'package:dio/dio.dart';
// HTTP client; the Dio instance is passed in from UserLoginPage so both pages
// share the same base URL.
// Reference: Dio package [D1]


class SignupPage extends StatefulWidget {
  // StatefulWidget because the form has mutable state (controllers, loading flag).
  // Reference: Flutter StatefulWidget [F14]

  final Dio dio;
  // The Dio HTTP client is injected via the constructor rather than being created
  // here. This is a form of dependency injection: UserLoginPage owns the Dio
  // instance and passes it in, ensuring both pages use the same base URL.
  // Reference: Dio dependency injection pattern [D1]

  const SignupPage({super.key, required this.dio});
  // required this.dio – the caller must supply a Dio instance: it cannot be null.
  // super.key passes the key to the StatefulWidget superclass.

  @override
  State<SignupPage> createState() => _SignupPageState();
}


class _SignupPageState extends State<SignupPage> {
  // State class for SignupPage.

  // Form Key
  final _formKey = GlobalKey<FormState>();
  // Enables collective validation of all TextFormFields in the Form.
  // Reference: Flutter Form & GlobalKey [F4]

  // Text Controllers
  final _sailNoCtrl = TextEditingController();
  // Controls the Sail Number field.
  // Reference: Flutter TextEditingController [F12]

  final _passwordCtrl = TextEditingController();
  // Controls the Password field.
  // Also read by the Confirm Password validator to check the two values match.

  final _confirmCtrl = TextEditingController();
  // Controls the Confirm Password field.

  final _ownerNameCtrl = TextEditingController();
  // Controls the optional Owner Name field.

  bool _loading = false;
  // True while the POST /signup request is in flight; disables the button.


  // Lifecycle


  @override
  void dispose() {
    // Release all four controllers when the page is removed from the tree.
    // Reference: Flutter widget lifecycle dispose [F14]
    _sailNoCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _ownerNameCtrl.dispose();
    super.dispose();
    // Calls State.dispose() to complete the teardown chain.
  }


  // Signup Logic


  Future<void> _signup() async {
    // Handles the full signup cycle: validate - POST - show result - navigate back.
    // Reference: Dart async/await [F8]

    if (!_formKey.currentState!.validate()) return;
    // Run all field validators. If any return an error string, stop here.
    // Reference: Flutter Form.validate() [F4]

    setState(() => _loading = true);
    // Show loading spinner: disable the Create Account button.

    try {
      final res = await widget.dio.post(
        // widget.dio accesses the Dio instance passed in via the constructor.
        // Reference: Flutter accessing widget properties from State [F14]
        "/signup",
        // POST to the FastAPI /signup endpoint.
        data: {
          "sail_no": _sailNoCtrl.text.trim(),
          // Trimmed sail number: must match a Boat row in the database.
          // Field name matches SignupRequest Pydantic schema [B3].
          "password": _passwordCtrl.text,
          // Plain-text password; bcrypt-hashed on the backend before storage.
          // Reference: passlib bcrypt [B15]
          "owner_name": _ownerNameCtrl.text.trim().isEmpty
              ? null
              : _ownerNameCtrl.text.trim(),
          // Owner name is optional: send null if the field is blank so the
          // backend Pydantic model receives None (Optional[str] = None) [B3].
        },
      );
      // Reference: Dio POST request [D3]

      // Parse the response body.
      final data = res.data;
      // res.data is the decoded JSON body as a Dart Map<String, dynamic>.

      final success = (data is Map && data["success"] == true);
      // Check the "success" flag in the response.
      // The /signup endpoint in app.py returns { "message": "Account created" };
      // the boat-signup endpoint returns { "success": true/false, ... }.

      if (!success) {
        // Server responded with HTTP 200 but reported a logical failure.
        final msg = (data is Map && data["message"] != null)
            ? data["message"].toString()
            : "Signup failed.";
        if (!mounted) return;
        // Guard against using context after widget disposal.
        ScaffoldMessenger.of(context).showSnackBar(
          // Display the error message as a SnackBar at the bottom of the screen.
          // Reference: Flutter SnackBar [F7]
          SnackBar(content: Text(msg)),
        );
        return;
        // Stop further execution; do not navigate back.
      }

      // Signup succeeded – show a success SnackBar.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data["message"]?.toString() ?? "Account created.")),
        // Shows the server's success message, e.g. "Account created".
        // ?. is the null-safe member access operator; ?? provides a fallback.
        // Reference: Dart null safety operators [F8]
      );

      // Navigate back to UserLoginPage, returning the sail number.
      Navigator.pop(context, _sailNoCtrl.text.trim());
      // Navigator.pop removes SignupPage from the stack.
      // The second argument is the return value; UserLoginPage receives this
      // as the result of `await Navigator.push(...)` and pre-fills the field.
      // Reference: Flutter Navigator.pop with result [F28]

    } on DioException catch (e) {
      // Handles HTTP errors (4xx / 5xx).
      // Reference: Dio DioException [D1]
      final status = e.response?.statusCode;
      // HTTP status code, e.g. 404, 409, 500.

      final backendMsg = (e.response?.data is Map)
          ? (e.response?.data["detail"] ?? e.response?.data["message"])
          : null;
      // Extract the backend's detail or message from the error body.
      // FastAPI raises HTTPException with "detail" as the error field [B1].

      final msg = backendMsg?.toString() ??
          // Use the backend message if available, otherwise use a user-friendly
          // status-code-specific message.
          (status == 404
              ? "Boat not found. Ask the race officer to add your sail number first."
              // The backend returned 404 – the sail number is not in the database.
              : status == 409
                  ? "This boat is already signed up. Please log in."
                  // The backend returned 409 Conflict – an account already exists.
                  : "Signup error. Please try again.");
          // Generic fallback for other error codes.

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
        // Show the user-friendly error message.
        // Reference: Flutter SnackBar [F7]
      );

    } catch (_) {
      // Catch-all for unexpected errors (JSON parsing, etc.).
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Unexpected error. Please try again.")),
      );

    } finally {
      // Always stop the loading spinner when the request finishes or fails.
      if (mounted) setState(() => _loading = false);
      // Reference: Dart finally [F8]
    }
  }


  // UI Build Method


  @override
  Widget build(BuildContext context) {
    // Returns the full widget tree for the signup form.
    return Scaffold(
      // Standard Material page scaffold.
      // Reference: Flutter Scaffold [F3]
      appBar: AppBar(title: const Text("Create account")),
      // AppBar with a back arrow (automatically provided by Navigator) and title.
      // Reference: Flutter AppBar [F14]

      body: Padding(
        padding: const EdgeInsets.all(16),
        // 16px uniform padding inside the page.
        child: Form(
          // Groups all TextFormFields and provides collective validation.
          // Reference: Flutter Form [F4]
          key: _formKey,
          // Links the Form to _formKey for programmatic validation.
          child: ListView(
            // ListView is used instead of Column here so the form automatically
            // scrolls when the keyboard is shown and all fields are visible.
            // Reference: Flutter ListView [F5]
            children: [

              // Sail Number Field
              TextFormField(
                controller: _sailNoCtrl,
                // Reads the sail number value in _signup().
                decoration: const InputDecoration(
                  labelText: "Sail number",
                  hintText: "e.g. IRL15455",
                  // Hint text shows placeholder text before the user types.
                ),
                textInputAction: TextInputAction.next,
                // Configures the keyboard's action button to move to the next field.
                // Reference: Flutter TextInputAction [F12]
                validator: (v) {
                  final val = (v ?? "").trim();
                  // ?? "" handles the null case (field not yet touched).
                  if (val.isEmpty) return "Please enter your sail number";
                  // Returns an error string if empty; Form.validate() shows this below the field.
                  return null;
                  // null means the field is valid.
                },
              ),

              const SizedBox(height: 12),
              // 12px vertical gap.

              // Owner Name Field (Optional) 
              TextFormField(
                controller: _ownerNameCtrl,
                // Optional field – no validator, so it always passes.
                decoration: const InputDecoration(
                  labelText: "Owner name (optional)",
                ),
                textInputAction: TextInputAction.next,
              ),

              const SizedBox(height: 12),

              // Password Field 
              TextFormField(
                controller: _passwordCtrl,
                // _confirmCtrl's validator reads this controller to compare values.
                decoration: const InputDecoration(labelText: "Password"),
                obscureText: true,
                // Masks typed characters.
                textInputAction: TextInputAction.next,
                validator: (v) {
                  final val = v ?? "";
                  if (val.length < 6) return "Password must be at least 6 characters";
                  // Minimum length of 6 characters is a basic security measure.
                  return null;
                },
              ),

              const SizedBox(height: 12),

              // Confirm Password Field 
              TextFormField(
                controller: _confirmCtrl,
                decoration: const InputDecoration(labelText: "Confirm password"),
                obscureText: true,
                // Also masked so the confirmation is private.
                textInputAction: TextInputAction.done,
                // "done" button on the keyboard signals the last field.
                validator: (v) {
                  if ((v ?? "") != _passwordCtrl.text) return "Passwords do not match";
                  // Cross-field validation: compares this field's value to _passwordCtrl.
                  // Reference: Flutter cross-field form validation [F4]
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // Create Account Button 
              ElevatedButton(
                // Reference: Flutter ElevatedButton [F13]
                onPressed: _loading ? null : _signup,
                // null disables the button while loading, preventing double-submissions.
                // When not loading, tapping calls _signup().
                child: _loading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                        // Small spinner inside the button while the request is in flight.
                        // Reference: Flutter CircularProgressIndicator [F1]
                      )
                    : const Text("Create account"),
                // Shows "Create account" text when not loading.
              ),

            ], // end ListView children
          ),
        ),
      ),
    );
  }
}

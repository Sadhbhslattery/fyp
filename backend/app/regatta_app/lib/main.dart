// main.dart is the first file that runs when this Flutter app starts. It's like the main() function in any program - the entry point. This file:
// Displays the initial login selector screen
// Sets up the global app theme (dark mode)
// Configures navigation between screens
// Lets users choose between Admin or Competitor login


import 'package:flutter/material.dart'; // Imports Flutter's Material Design widgets - all the basic UI components like Scaffold, AppBar, ElevatedButton, Text, etc.
import 'login_page.dart'; // Imports the admin login screen so we can navigate to it
import 'user_login_page.dart'; // Imports the competitor login screen
import 'theme/app_theme.dart'; // Imports custom dark theme



void main() => runApp(const MyApp());
// This is the very first line of code that executes when the app launches. The main() function is required in every Dart program.
// void main(): The function signature (returns nothing)
// => : Arrow syntax for single-expression functions (shorthand)
// runApp(...): Flutter function that inflates the given widget and displays it on screen
// const MyApp(): Creates an instance of the MyApp widget (defined below)

// Reference: Flutter app entrypoint & runApp [F1][F2]


class MyApp extends StatelessWidget {
  // MyApp is a StatelessWidget because the root app configuration never changes - theme and initial route are constant.
  // StatelessWidget vs StatefulWidget:
  // StatelessWidget: For widgets that don't change over time
  // StatefulWidget: For widgets that need to update (login forms, lists that load data, etc.)
  const MyApp({super.key}); // Constructor
  // The {super.key} passes the key parameter up to the parent StatelessWidget class.

  @override
  Widget build(BuildContext context) {
    // Every widget must implement build(), which returns the widget tree to display.
    return MaterialApp(
      // MaterialApp is the root widget for Material Design apps. It provides:
      // Navigation system (Navigator)
      // Theme configuration
      // Title for OS task switcher
      // Debug banner control
      // Reference: MaterialApp, theming, navigation [F2][F3]
      title: 'Regatta Login',
      // App title shown in Android task switcher
      theme: AppTheme.darkTheme,
      // Sets the global theme. AppTheme.darkTheme is the ThemeData object I defined in app_theme.dart. 
      // Every widget in the app automatically uses this theme.
      debugShowCheckedModeBanner: false,
      // Hides the "DEBUG" banner in the top-right corner (shown by default in debug builds)
      home: const LoginSelector(),
      // The first screen shown when the app launches. This displays the choice between Admin and User login.
    );
  }
}

// LoginSelector is a simple screen with two buttons:
// 1. Admin Login
// 2. Boat Owner Login

// This screen appears when the app starts and lets the user choose which login path they need to enter.
class LoginSelector extends StatelessWidget {
  // Another StatelessWidget - just shows two buttons, no changing state.
  const LoginSelector({super.key});

  @override
  Widget build(BuildContext context) {
    // Reference: Scaffold, layout & basic widgets [F1][F3]
    return Scaffold(
      // Scaffold is Flutter's basic screen structure with AppBar and body.
      appBar: AppBar(title: const Text("Select Login Type")),
      // Creates the top bar with "Select Login Type" title

      // body is the main content of the screen

      body: SafeArea(
        // SafeArea: Ensures content doesn't overlap with system UI (notch, status bar)
        child: Center(
          //  Centers content horizontally and vertically
          child: SingleChildScrollView(
            // Allows scrolling if content is too tall (prevents RenderFlex overflow)
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                // Column stacks widgets vertically (the two buttons)
                mainAxisAlignment: MainAxisAlignment.center, // Vertically centers the buttons
                crossAxisAlignment: CrossAxisAlignment.stretch, // Makes buttons full-width

                children: [
                  // Reference: Flutter navigation with Navigator.push [F1]

                  // Admin Login Button
                  ElevatedButton(
                    // The text shown on the button
                    child: const Text("Admin Login"),

                    // onPressed runs when the user taps the button
                    onPressed: () {
                      Navigator.push(
                        // Pushes a new screen onto the navigation stack
                        context,
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                       // MaterialPageRoute: Creates a transition animation (slide from right)
                       // builder: (_) => const LoginPage(): Builder function that creates the LoginPage widget. 
                       // The _ is convention for "unused parameter" (BuildContext)
                      );
                    },
                  ),

                  // Add spacing between the two buttons
                  const SizedBox(height: 16),

                  // User Login Button
                  ElevatedButton(
                    child: const Text("User Login (Boat Owner)"),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const UserLoginPage()),
                      );
                      // Same pattern, but navigates to UserLoginPage instead
                    },
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
// This file:
// 1. Is the entry point (main() function)
// 2. Sets up MaterialApp with dark theme
// 3. Shows LoginSelector as first screen
// 4. LoginSelector has two buttons that navigate to respective login pages

// Flow: App starts - main() - runApp(MyApp()) -  MyApp builds MaterialApp -  
// MaterialApp shows LoginSelector - User taps button - Navigator pushes login page

// Reference: MaterialApp configuration [F2]
// Reference: ThemeData from app_theme.dart [F11]
// Reference: Navigator.push for screen transitions [F28]
// Reference: StatelessWidget for static screens [F1]
// Reference: Scaffold structure [F3]
// Reference: ElevatedButton for primary actions [F1]
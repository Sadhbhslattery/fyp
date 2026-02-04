// main.dart is the entry point of your Flutter application
// It is the first file that runs when the app starts
// It displays the login selector screen where the user chooses:
// - Admin Login
// - User Login (Boat Owner)

import 'package:flutter/material.dart'; // Core Flutter UI package
import 'login_page.dart'; // Screen for Admin login
import 'user_login_page.dart'; // Screen for Boat Owner login.
import 'theme/app_theme.dart'; // Colour themes

// The main() function is the very first thing that executes
// runApp() tells Flutter to display the given widget on screen
// MyApp() becomes the root widget of the entire app

// Reference: Flutter app entrypoint & runApp [F1][F2]
void main() => runApp(const MyApp());

/// MyApp is the root of the widget tree
/// It wraps the whole application inside a MaterialApp, which provides navigation, themes, styling, routing, etc.
class MyApp extends StatelessWidget {
  const MyApp({super.key}); // Constructor

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Title used by Android task switcher and older OS systems
      // Reference: MaterialApp, theming, navigation [F2][F3]
      title: 'Regatta Login',

      // Global theme settings for the app
      // useMaterial3: enables the latest Material UI design system
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,

      // home: is the first screen shown when the app launches
      // Here we show LoginSelector(), a simple screen that lets the user
      // choose between Admin Login and Boat Owner Login
      home: const LoginSelector(),
    );
  }
}

// LoginSelector is a simple screen with two buttons:
// 1. Admin Login
// 2. Boat Owner Login
//
// This screen appears when the app starts and lets the user choose which login path they need to enter.
class LoginSelector extends StatelessWidget {
  const LoginSelector({super.key});

  @override
  Widget build(BuildContext context) {
    // Reference: Scaffold, layout & basic widgets [F1][F3]
    return Scaffold(
      // AppBar displays a bar at the top with a title
      appBar: AppBar(title: const Text("Select Login Type")),

      // body is the main content of the screen
      //
      // FIX for RenderFlex overflow:
      // - Replace Center + Column with SafeArea + SingleChildScrollView
      // - This prevents vertical overflow on smaller screens / when text scales
      body: SafeArea(
        child: Center(
          // Center positions its child widget in the middle of the screen
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                // Column stacks widgets vertically
                mainAxisAlignment: MainAxisAlignment.center, // Vertically centers the buttons
                crossAxisAlignment: CrossAxisAlignment.stretch, // Makes buttons full-width

                children: [
                  // Reference: Flutter navigation with Navigator.push [F1]
                  // ADMIN LOGIN BUTTON
                  ElevatedButton(
                    // The text shown on the button
                    child: const Text("Admin Login"),

                    // onPressed runs when the user taps the button
                    onPressed: () {
                      // Navigator.push() moves to a new screen
                      // MaterialPageRoute creates a transition animation
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      );
                    },
                  ),

                  // Add spacing between the two buttons
                  const SizedBox(height: 16),

                  // USER LOGIN BUTTON
                  ElevatedButton(
                    child: const Text("User Login (Boat Owner)"),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const UserLoginPage()),
                      );
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

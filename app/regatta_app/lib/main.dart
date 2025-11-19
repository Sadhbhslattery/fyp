import 'package:flutter/material.dart';
import 'login_page.dart';
import 'user_login_page.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Regatta Login',
      theme: ThemeData(useMaterial3: true),
      home: const LoginSelector(),
    );
  }
}

class LoginSelector extends StatelessWidget {
  const LoginSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Select Login Type")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              child: const Text("Admin Login"),
              onPressed: () {
                Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const LoginPage()));
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              child: const Text("User Login (Boat Owner)"),
              onPressed: () {
                Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const UserLoginPage()));
              },
            ),
          ],
        ),
      ),
    );
  }
}

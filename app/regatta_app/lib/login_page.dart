import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'fleet_admin_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final dio = Dio(BaseOptions(baseUrl: "http://127.0.0.1:8000"));
  final _formKey = GlobalKey<FormState>();

  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;
  String? errorMessage;

  Future<void> _attemptLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final res = await dio.post("/login", data: {
        "username": usernameController.text.trim(),
        "password": passwordController.text.trim(),
      });

      if (res.data["success"] == true) {
        // Navigate to Fleet Admin Page on success
        if (context.mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const FleetAdminPage()),
          );
        }
      } else {
        setState(() {
          errorMessage = "Invalid username or password";
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "Error connecting to server";
      });
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Admin Login")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  if (errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),

                  TextFormField(
                    controller: usernameController,
                    decoration: const InputDecoration(
                      labelText: "Username",
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? "Enter username" : null,
                  ),

                  const SizedBox(height: 16),

                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: "Password",
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? "Enter password" : null,
                  ),

                  const SizedBox(height: 20),

                  loading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: _attemptLogin,
                          child: const Text("Login"),
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

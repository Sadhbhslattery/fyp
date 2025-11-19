import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'user_boat_page.dart';

class UserLoginPage extends StatefulWidget {
  const UserLoginPage({super.key});

  @override
  State<UserLoginPage> createState() => _UserLoginPageState();
}

class _UserLoginPageState extends State<UserLoginPage> {
  final dio = Dio(BaseOptions(baseUrl: "http://127.0.0.1:8000"));
  final sailController = TextEditingController();
  final passController = TextEditingController();

  String? error;
  bool loading = false;

  Future<void> _login() async {
    setState(() {
      error = null;
      loading = true;
    });

    try {
      final res = await dio.post("/user-login", data: {
        "sail_no": sailController.text.trim(),
        "password": passController.text.trim(),
      });

      if (res.data["success"] == true) {
        if (context.mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => UserBoatPage(boat: res.data["boat"]),
            ),
          );
        }
      } else {
        setState(() => error = res.data["message"]);
      }
    } catch (e) {
      setState(() => error = "Connection error");
    }

    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Competitor Login")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),

            TextField(
              controller: sailController,
              decoration: const InputDecoration(
                labelText: "Sail Number",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passController,
              decoration: const InputDecoration(
                labelText: "Password",
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),

            const SizedBox(height: 20),
            loading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _login,
                    child: const Text("Login"),
                  ),
          ],
        ),
      ),
    );
  }
}

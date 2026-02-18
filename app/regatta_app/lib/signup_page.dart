// REFERENCE
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

class SignupPage extends StatefulWidget {
  final Dio dio;

  const SignupPage({super.key, required this.dio});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();

  final _sailNoCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _ownerNameCtrl = TextEditingController();

  bool _loading = false;

  @override
  void dispose() {
    _sailNoCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _ownerNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final res = await widget.dio.post(
        "/signup",
        data: {
          "sail_no": _sailNoCtrl.text.trim(),
          "password": _passwordCtrl.text,
          "owner_name": _ownerNameCtrl.text.trim().isEmpty
              ? null
              : _ownerNameCtrl.text.trim(),
        },
      );

      // Expecting: { success: true, message: "..." }
      final data = res.data;
      final success = (data is Map && data["success"] == true);

      if (!success) {
        final msg = (data is Map && data["message"] != null)
            ? data["message"].toString()
            : "Signup failed.";
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data["message"]?.toString() ?? "Account created.")),
      );

      // Go back to login, passing sail_no so it can prefill
      Navigator.pop(context, _sailNoCtrl.text.trim());
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final backendMsg = (e.response?.data is Map)
          ? (e.response?.data["detail"] ?? e.response?.data["message"])
          : null;

      final msg = backendMsg?.toString() ??
          (status == 404
              ? "Boat not found. Ask the race officer to add your sail number first."
              : status == 409
                  ? "This boat is already signed up. Please log in."
                  : "Signup error. Please try again.");

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Unexpected error. Please try again.")),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create account")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _sailNoCtrl,
                decoration: const InputDecoration(
                  labelText: "Sail number",
                  hintText: "e.g. IRL15455",
                ),
                textInputAction: TextInputAction.next,
                validator: (v) {
                  final val = (v ?? "").trim();
                  if (val.isEmpty) return "Please enter your sail number";
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ownerNameCtrl,
                decoration: const InputDecoration(
                  labelText: "Owner name (optional)",
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordCtrl,
                decoration: const InputDecoration(labelText: "Password"),
                obscureText: true,
                textInputAction: TextInputAction.next,
                validator: (v) {
                  final val = v ?? "";
                  if (val.length < 6) return "Password must be at least 6 characters";
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmCtrl,
                decoration: const InputDecoration(labelText: "Confirm password"),
                obscureText: true,
                textInputAction: TextInputAction.done,
                validator: (v) {
                  if ((v ?? "") != _passwordCtrl.text) return "Passwords do not match";
                  return null;
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _signup,
                child: _loading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text("Create account"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

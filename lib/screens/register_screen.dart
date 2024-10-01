// lib/screens/register_screen.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key); // Added const and key

  @override
  State<RegisterScreen> createState() => RegisterScreenState(); // Renamed _RegisterScreenState
}

class RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _signUp() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final AuthResponse response = await Supabase.instance.client.auth.signUp(
        email: _emailController.text,
        password: _passwordController.text,
      );
      setState(() {
        _isLoading = false;
      });
      if (response.user != null) {
        if (!mounted) return;
        _showMessage('Registration successful! Please check your email to confirm your account.');
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        _showMessage('Registration failed');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showMessage('An error occurred: $e');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')), // Added const
      body: Padding(
        padding: const EdgeInsets.all(16.0), // Added const
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'), // Added const
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'), // Added const
              obscureText: true,
            ),
            const SizedBox(height: 20), // Added const
            _isLoading
                ? const CircularProgressIndicator() // Added const
                : ElevatedButton(
                    onPressed: _signUp,
                    child: const Text('Register'), // Added const
                  ),
          ],
        ),
      ),
    );
  }
}

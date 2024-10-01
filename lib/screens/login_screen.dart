// lib/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key); // Added const and key

  @override
  State<LoginScreen> createState() => LoginScreenState(); // Renamed _LoginScreenState
}

class LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _signIn() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final AuthResponse response = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
      setState(() {
        _isLoading = false;
      });
      if (response.user != null) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        _showMessage('Login failed');
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
      appBar: AppBar(title: const Text('Login')), // Added const
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
                    onPressed: _signIn,
                    child: const Text('Login'), // Added const
                  ),
            TextButton(
              onPressed: () {
                if (!mounted) return;
                Navigator.pushNamed(context, '/register');
              },
              child: const Text('Register'), // Added const
            ),
          ],
        ),
      ),
    );
  }
}

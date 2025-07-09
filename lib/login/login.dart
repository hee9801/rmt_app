import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../admin/admin_dashboard.dart';
import '../staff/canteen_dashboard.dart';
import '../register/register.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isEmailValid = false;
  bool _isPasswordValid = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_validateInputs);
    _passwordController.addListener(_validateInputs);
  }

  void _validateInputs() {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    setState(() {
      _isEmailValid = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w]{2,4}$').hasMatch(email);
      _isPasswordValid = password.length >= 6;
    });
  }

  void _showForgotPasswordDialog() {
    final TextEditingController emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reset Password'),
          content: TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              hintText: 'Enter your email',
              prefixIcon: Icon(Icons.email),
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('Send Reset Link'),
              onPressed: () async {
                final email = emailController.text.trim();
                if (email.isNotEmpty) {
                  try {
                    await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Password reset email sent!')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${e.toString()}')),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            double screenWidth = constraints.maxWidth;
            bool isTablet = screenWidth > 600;

            return Center(
              child: SingleChildScrollView(
                child: Container(
                  width: isTablet ? 500 : double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'Welcome Back!',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const SizedBox(height: 32),

                      TextField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          hintText: 'Enter your Email',
                          labelStyle: const TextStyle(fontSize: 16),
                          hintStyle: const TextStyle(fontSize: 15),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(35),
                          ),
                          prefixIcon: const Icon(Icons.email_outlined, size: 24),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(35),
                            borderSide: BorderSide(
                              color: _isEmailValid ? Colors.green : Colors.grey,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(35),
                            borderSide: BorderSide(
                              color: _isEmailValid ? Colors.green : Colors.red,
                            ),
                          ),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 20),

                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          hintText: 'Enter your Password',
                          labelStyle: const TextStyle(fontSize: 16),
                          hintStyle: const TextStyle(fontSize: 15),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(35),
                          ),
                          prefixIcon: const Icon(Icons.lock_outline, size: 24),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(35),
                            borderSide: BorderSide(
                              color: _isPasswordValid ? Colors.green : Colors.grey,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(35),
                            borderSide: BorderSide(
                              color: _isPasswordValid ? Colors.green : Colors.red,
                            ),
                          ),
                        ),
                        style: const TextStyle(fontSize: 16),
                      ),

                      const SizedBox(height: 10),

                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _showForgotPasswordDialog,
                          child: const Text(
                            'Forgot Password?',
                            style: TextStyle(fontSize: 14, color: Colors.blue),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: (_isEmailValid && _isPasswordValid)
                            ? () async {
                                String email = _emailController.text.trim();
                                String password = _passwordController.text.trim();

                                try {
                                  final credential = await FirebaseAuth.instance
                                      .signInWithEmailAndPassword(email: email, password: password);

                                  final uid = credential.user!.uid;

                                  // Fetch role from Firestore
                                  final userDoc = await FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(uid)
                                      .get();

                                  final role = userDoc['role'];

                                  Widget nextScreen;

                                  if (role == 'admin') {
                                    nextScreen = const AdminDashboard();
                                  } 
                                  else {
                                    nextScreen = const CanteenDashboard();
                                  }

                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(builder: (context) => nextScreen),
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("Login failed: ${e.toString()}")),
                                  );
                                }
                              }
                            : null,

                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(35),
                            ),
                            backgroundColor: Colors.blue[700],
                          ),
                          child: const Text(
                            'Login',
                            style: TextStyle(fontSize: 17, color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Don't have an account?",
                            style: TextStyle(fontSize: 15),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const RegistrationPage(),
                                ),
                              );
                            },
                            child: const Text(
                              'Register',
                              style: TextStyle(fontSize: 15, color: Colors.blue), 
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final List<String> _roles = ['admin', 'canteen'];
String? _selectedRole;


  String? _nameError, _emailError, _passwordError, _confirmPasswordError;

  bool _nameValid = false,
      _emailValid = false,
      _passwordValid = false,
      _confirmPasswordValid = false;

  // Show/hide password toggle
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  InputDecoration _buildDecoration({
    required String label,
    required String hint,
    required IconData icon,
    String? errorText,
    bool isValid = false,
    VoidCallback? toggleVisibility,
    bool isPasswordField = false,
    bool isObscured = true,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      errorText: errorText,
      prefixIcon: Icon(icon),
      suffixIcon: isPasswordField
          ? IconButton(
              icon: Icon(isObscured ? Icons.visibility_off : Icons.visibility),
              onPressed: toggleVisibility,
            )
          : isValid
              ? const Icon(Icons.check_circle, color: Colors.green)
              : null,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(35)),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: isValid ? Colors.green : Colors.grey),
        borderRadius: BorderRadius.circular(35),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: isValid ? Colors.green : Colors.blue),
        borderRadius: BorderRadius.circular(35),
      ),
    );
  }

  void _validateName(String value) {
    setState(() {
      if (value.isEmpty) {
        _nameError = 'Name is required';
        _nameValid = false;
      } else if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value)) {
        _nameError = 'Only letters allowed';
        _nameValid = false;
      } else {
        _nameError = null;
        _nameValid = true;
      }
    });
  }

  void _validateEmail(String value) {
    setState(() {
      if (value.isEmpty) {
        _emailError = 'Email is required';
        _emailValid = false;
      } else if (!RegExp(r"^[\w\.-]+@[\w\.-]+\.\w+$").hasMatch(value)) {
        _emailError = 'Enter a valid email';
        _emailValid = false;
      } else {
        _emailError = null;
        _emailValid = true;
      }
    });
  }

  void _validatePassword(String value) {
    setState(() {
      if (value.isEmpty) {
        _passwordError = 'Password is required';
        _passwordValid = false;
      } else if (!RegExp(r'^(?=.*[A-Z])(?=.*[a-z])(?=.*\d)(?=.*[!@#$%^&*()_+{}\[\]:;<>,.?~\\/-]).{8,}$')
          .hasMatch(value)) {
        _passwordError = 'Min 8 chars, upper, lower, number, symbol';
        _passwordValid = false;
      } else {
        _passwordError = null;
        _passwordValid = true;
      }
    });

    _validateConfirmPassword(_confirmPasswordController.text);
  }

  void _validateConfirmPassword(String value) {
    setState(() {
      if (value != _passwordController.text) {
        _confirmPasswordError = 'Passwords do not match';
        _confirmPasswordValid = false;
      } else {
        _confirmPasswordError = null;
        _confirmPasswordValid = true;
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
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
                      'Create Account',
                      style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 32),

                    TextField(
                      controller: _nameController,
                      onChanged: _validateName,
                      decoration: _buildDecoration(
                        label: 'Full Name',
                        hint: 'Enter your full name',
                        icon: Icons.person_outline,
                        errorText: _nameError,
                        isValid: _nameValid,
                      ),
                    ),
                    const SizedBox(height: 20),

                    TextField(
                      controller: _emailController,
                      onChanged: _validateEmail,
                      decoration: _buildDecoration(
                        label: 'Email',
                        hint: 'Enter your email',
                        icon: Icons.email_outlined,
                        errorText: _emailError,
                        isValid: _emailValid,
                      ),
                    ),
                    const SizedBox(height: 20),

                    DropdownButtonFormField<String>(
                      value: _selectedRole,
                      onChanged: (value) => setState(() => _selectedRole = value),
                      decoration: InputDecoration(
                        labelText: 'Select Role',
                        prefixIcon: const Icon(Icons.account_circle_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(35)),
                      ),
                      items: _roles.map((role) {
                        return DropdownMenuItem<String>(
                          value: role,
                          child: Text(role),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 30),

                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      onChanged: _validatePassword,
                      decoration: _buildDecoration(
                        label: 'Password',
                        hint: 'Enter your password',
                        icon: Icons.lock_outline,
                        errorText: _passwordError,
                        isValid: _passwordValid,
                        toggleVisibility: () => setState(() => _obscurePassword = !_obscurePassword),
                        isPasswordField: true,
                        isObscured: _obscurePassword,
                      ),
                    ),
                    const SizedBox(height: 20),

                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      onChanged: _validateConfirmPassword,
                      decoration: _buildDecoration(
                        label: 'Confirm Password',
                        hint: 'Re-enter your password',
                        icon: Icons.lock_reset_outlined,
                        errorText: _confirmPasswordError,
                        isValid: _confirmPasswordValid,
                        toggleVisibility: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                        isPasswordField: true,
                        isObscured: _obscureConfirmPassword,
                      ),
                    ),
                    const SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (_nameValid &&
                                _emailValid &&
                                _passwordValid &&
                                _confirmPasswordValid &&
                                _selectedRole != null)
                            ? () async {
                                try {
                                  final email = _emailController.text.trim();
                                  final password = _passwordController.text.trim();
                                  final name = _nameController.text.trim();

                                  final methods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);
                                  if (methods.isNotEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Email is already in use')),
                                    );
                                    return;
                                  }

                                  final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
                                    email: email,
                                    password: password,
                                  );

                                  await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
                                    'uid': userCredential.user!.uid,
                                    'name': name,
                                    'email': email,
                                    'role': _selectedRole,
                                    'created_at': FieldValue.serverTimestamp(),
                                  });

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Registration successful!')),
                                  );

                                  Navigator.pop(context);
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e')),
                                  );
                                }
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.blue[700],
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(35)),
                        ),
                        child: const Text('Register', style: TextStyle(fontSize: 18, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    const Text("Already have an account?", style: TextStyle(fontSize: 15)),
    TextButton(
      onPressed: () => Navigator.pop(context),
      child: Text(
        "Login",
        style: TextStyle(
          fontSize: 15,
          color: Colors.blue.shade600,
        ),
      ),
    )
  ],
),

                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

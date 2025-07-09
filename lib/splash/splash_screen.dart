import 'dart:async';
import 'package:flutter/material.dart';
import '../login/login.dart'; // Change to home.dart if needed

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    Timer(const Duration(seconds: 5), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // Responsive screen size
    double screenHeight = MediaQuery.of(context).size.height;
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.blue[700],
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Replace with your logo if needed
              // Image.asset('assets/images/rmt_logo.png', height: screenHeight * 0.2),

              Icon(
                Icons.school,
                size: screenHeight * 0.15, // Responsive size
                color: Colors.white,
              ),
              const SizedBox(height: 15),

              Text(
                'e-RMT',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: screenWidth * 0.12, // Responsive font size
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

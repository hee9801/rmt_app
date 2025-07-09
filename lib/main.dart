import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
//import 'package:rmt_system/admin/admin_dashboard.dart';
//import 'package:rmt_system/admin/dashboard.dart';
//import 'package:rmt_system/admin/reporting_page.dart';
import 'package:rmt_system/splash/splash_screen.dart';
//import 'package:rmt_system/staff/canteen_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RMT App',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Poppins', // Just set this globally
      ),
      home: const SplashScreen(),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
//import 'package:rmt_system/admin/add_student.dart';
import 'package:rmt_system/admin/daily_meal_log_page.dart';
import 'package:rmt_system/admin/dashboard.dart';
//import 'package:rmt_system/admin/edit_student.dart';
import 'package:rmt_system/admin/reporting_page.dart';
//import 'package:rmt_system/staff/scan_fingerprint.dart';
import 'package:rmt_system/admin/student_management.dart';
import 'package:rmt_system/login/login.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;


  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _logout() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Row(
        children: [
          const Icon(Icons.logout, color: Colors.red),
          const SizedBox(width: 10),
          const Text(
            "Confirm Logout",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: const Text(
        "Are you sure you want to log out from the admin panel?",
        style: TextStyle(fontSize: 16),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.grey.shade500,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton.icon(
          
          label: const Text("Logout"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
            if (!mounted) return;
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginPage()),
              (route) => false,
            );
          },
        ),
      ],
    ),
  );
}


  @override
  Widget build(BuildContext context) {
    final pages = [
      const AdminDashboardPage(),
      const StudentManagementPage(),
      const ReportingPage(),
       DailyMealLogPage(),
       //const AddStudentPage(),
       //const EditStudentPage(student: student),
    ];

    final primaryColor = Colors.blue.shade400;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Panel"),
        backgroundColor: primaryColor,
        elevation: 6,
        actions: [
  Padding(
    padding: const EdgeInsets.only(right: 12),
    child: TextButton.icon(
      onPressed: _logout,
      
      label: const Text(
        "Logout",
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      style: TextButton.styleFrom(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    ),
  ),
],

        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(16),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: pages[_selectedIndex],
      ),
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          selectedItemColor: Colors.black,
          
          backgroundColor: primaryColor,
          onTap: _onItemTapped,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: "Dashboard"),
            BottomNavigationBarItem(icon: Icon(Icons.school), label: "Students"),
            BottomNavigationBarItem(icon: Icon(Icons.assessment), label: "Reports"),
            BottomNavigationBarItem(icon: Icon(Icons.food_bank), label: "Meal Log"),
          ],
          type: BottomNavigationBarType.fixed,
          showUnselectedLabels: true,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rmt_system/admin/daily_meal_log_page.dart';
import 'package:rmt_system/staff/scan_fingerprint.dart';
import 'package:rmt_system/login/login.dart';

class CanteenDashboard extends StatefulWidget {
  const CanteenDashboard({super.key});

  @override
  State<CanteenDashboard> createState() => _CanteenDashboardState();
}

class _CanteenDashboardState extends State<CanteenDashboard> {
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.logout, color: Colors.red),
            SizedBox(width: 10),
            Text("Confirm Logout", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          "Are you sure you want to log out from the canteen panel?",
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: Colors.grey[400],
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.exit_to_app),
            label: const Text("Logout"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
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
      FingerprintMatchPage(),       // Only shows when scanned
      const DailyMealLogPage(),     // Meal log list
    ];

    final primaryColor = Colors.blue.shade600;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Canteen Panel"),
        backgroundColor: primaryColor,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout, color: Colors.white),
              label: const Text("Logout", style: TextStyle(color: Colors.white)),
              style: TextButton.styleFrom(
                backgroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
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
            BottomNavigationBarItem(icon: Icon(Icons.fingerprint), label: "Scan"),
            BottomNavigationBarItem(icon: Icon(Icons.food_bank), label: "Meal Log"),
          ],
          type: BottomNavigationBarType.fixed,
          showUnselectedLabels: true,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int studentsNotCollected = 0;
  String todayMenu = '';

  @override
  void initState() {
    super.initState();
    todayMenu = _getTodayMenu();
    _getStudentsNotCollectedToday();
  }

  String _getTodayMenu() {
    String day = DateFormat('EEEE').format(DateTime.now());

    switch (day) {
      case 'Monday':
        return 'Nasi Ayam\nTeh Ais';
      case 'Tuesday':
        return 'Bubur Ayam\nKangkung\nSirap Ais';
      case 'Wednesday':
        return 'Nasi Goreng\nTelur Mata\nAis Kosong';
      case 'Thursday':
        return 'Mi Goreng\nSirap Ais';
      case 'Friday':
        return 'Nasi Impit\nRendang Daging\nAis Kosong';
      default:
        return 'No Menu (Weekend)';
    }
  }

  Future<void> _getStudentsNotCollectedToday() async {
  final today = DateFormat("dd/MM/yyyy").format(DateTime.now());

  try {
    final studentSnapshot = await FirebaseFirestore.instance.collection('students').get();

    final mealSnapshot = await FirebaseFirestore.instance
        .collection('meal_distributions')
        .where('date', isEqualTo: today)
        .get();

    final takenIds = mealSnapshot.docs
        .map((doc) => doc['fingerprintId'].toString())
        .toSet();

    int notTakenCount = 0;

    for (var student in studentSnapshot.docs) {
      final fingerprintId = student['fingerprintId'].toString();
      if (!takenIds.contains(fingerprintId)) {
        notTakenCount++;
      }
    }

    setState(() {
      studentsNotCollected = notTakenCount;
    });
  } catch (e) {
    print('Error getting not collected data: $e');
    setState(() {
      studentsNotCollected = 0;
    });
  }
}


  @override
  Widget build(BuildContext context) {
    final primaryColor = Colors.blue.shade200;
    final cardColor = Colors.blue.shade50;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: primaryColor,
        elevation: 4,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('students').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final count = snapshot.data?.docs.length ?? 0;
                return DashboardCard(
                  icon: Icons.people,
                  title: 'Total Students',
                  value: count.toString(),
                  color: primaryColor,
                  backgroundColor: cardColor,
                );
              },
            ),
            const SizedBox(height: 16),
            DashboardCard(
              icon: Icons.warning_amber_rounded,
              title: 'Did Not Take Food Today',
              value: studentsNotCollected.toString(),
              color: Colors.red.shade700,
              backgroundColor: Colors.red.shade50,
            ),
            const SizedBox(height: 16),
            DashboardCard(
              icon: Icons.restaurant_menu,
              title: 'Today\'s Menu',
              value: todayMenu,
              color: Colors.green.shade700,
              backgroundColor: Colors.green.shade50,
              multiline: true,
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color? color;
  final Color? backgroundColor;
  final bool multiline;

  const DashboardCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    this.color,
    this.backgroundColor,
    this.multiline = false,
  });

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: color ?? Colors.black87,
        );
    final valueStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: color ?? Colors.black87,
          height: multiline ? 1.3 : 1.0,
        );

    return Card(
      color: backgroundColor ?? Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        child: Row(
          crossAxisAlignment: multiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 44, color: color ?? Colors.black54),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: titleStyle),
                  const SizedBox(height: 8),
                  Text(
                    value,
                    style: valueStyle,
                    softWrap: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

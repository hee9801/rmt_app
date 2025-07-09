import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DailyMealLogPage extends StatefulWidget {
  const DailyMealLogPage({Key? key}) : super(key: key);

  @override
  State<DailyMealLogPage> createState() => _DailyMealLogPageState();
}

class _DailyMealLogPageState extends State<DailyMealLogPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late Future<Map<String, List<StudentMealStatus>>> _groupedStudentMealStatus;
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String? _selectedClass;

  @override
  void initState() {
    super.initState();
    _groupedStudentMealStatus = _loadAndGroupStudentMealStatus();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<Map<String, List<StudentMealStatus>>> _loadAndGroupStudentMealStatus() async {
    final today = DateFormat("dd/MM/yyyy").format(DateTime.now());

    final studentSnapshot = await _firestore.collection('students').get();
    final mealSnapshot = await _firestore
        .collection('meal_distributions')
        .where('date', isEqualTo: today)
        .get();

    final takenIds = mealSnapshot.docs
        .map((doc) => doc['fingerprintId'].toString())
        .toSet();

    Map<String, List<StudentMealStatus>> groupedStudents = {};

    for (var doc in studentSnapshot.docs) {
      final data = doc.data();
      final name = data['name'] ?? 'No Name';
      final fingerprintId = data['fingerprintId'].toString();
      final hasTakenMeal = takenIds.contains(fingerprintId);
      final studentClass = data['studentClass'] ?? 'Unknown';

      final studentStatus = StudentMealStatus(
        name: name,
        fingerprintId: fingerprintId,
        hasTakenMeal: hasTakenMeal,
      );

      groupedStudents.putIfAbsent(studentClass, () => []);
      groupedStudents[studentClass]!.add(studentStatus);
    }

    return groupedStudents;
  }

  void _refreshData() {
    setState(() {
      _groupedStudentMealStatus = _loadAndGroupStudentMealStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Colors.blue.shade200;
    final accentColor = Colors.blue.shade400;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text('Daily Meal Distribution Log'),
        elevation: 6,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search by name',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.toLowerCase();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: DropdownButtonFormField<String>(
                    value: _selectedClass,
                    dropdownColor: Colors.white,
                    decoration: InputDecoration(
                      labelText: 'Class',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: <String?>[null, '1', '2', '3', '4', '5', '6']
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value == null ? 'All' : 'Year $value'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedClass = value;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<Map<String, List<StudentMealStatus>>>(
              future: _groupedStudentMealStatus,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final groupedStudents = snapshot.data!;
                final sortedKeys = groupedStudents.keys.toList()..sort();

                List<Widget> cards = [];

                for (var className in sortedKeys) {
                  // Filter class
                  if (_selectedClass != null && _selectedClass != className) continue;

                  final students = groupedStudents[className]!
                      .where((student) =>
                          student.name.toLowerCase().contains(_searchQuery))
                      .toList();

                  if (students.isEmpty) continue;

                  cards.add(
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 3,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Year $className',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: accentColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Column(
                                children: List.generate(students.length, (index) {
                                  final student = students[index];
                                  return Container(
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: student.hasTakenMeal ? Colors.green : Colors.red,
                                        width: 1.2,
                                      ),
                                    ),
                                    child: ListTile(
                                      leading: Text(
                                        '${index + 1}.',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      title: Text(student.name),
                                      subtitle: Text(
                                        student.hasTakenMeal ? 'Meal Taken' : 'Not Taken',
                                        style: TextStyle(
                                          color: student.hasTakenMeal ? Colors.green : Colors.red,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }

                if (cards.isEmpty) {
                  return const Center(
                    child: Text(
                      'Student not found',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                return ListView(children: cards);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class StudentMealStatus {
  final String name;
  final String fingerprintId;
  final bool hasTakenMeal;

  StudentMealStatus({
    required this.name,
    required this.fingerprintId,
    required this.hasTakenMeal,
  });
}

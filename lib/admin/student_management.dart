import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'models/student_model.dart';
import 'edit_student.dart';
import 'add_student.dart';

class StudentManagementPage extends StatefulWidget {
  const StudentManagementPage({super.key});

  @override
  State<StudentManagementPage> createState() => _StudentManagementPageState();
}

class _StudentManagementPageState extends State<StudentManagementPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedClass;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Colors.blue.shade200;
    final accentColor = Colors.blue.shade400;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Management'),
        backgroundColor: primaryColor,
        elevation: 6,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
        actions: [
  Padding(
    padding: const EdgeInsets.only(right: 12),
    child: TextButton(
  onPressed: () => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const AddStudentPage()),
  ),
  style: TextButton.styleFrom(
    backgroundColor: Colors.blue.shade600,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    ),
    padding: const EdgeInsets.all(8), // tight padding for icon only
  ),
  child: const Icon(Icons.add, color: Colors.white),
),

  ),
],

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
                      labelText: 'Search by name or IC',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
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
                    style: const TextStyle(color: Colors.black), // <-- selected item color
                    decoration: InputDecoration(
                      labelText: 'Class',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    ),
                    items: <String?>[null, '1', '2', '3', '4', '5', '6']
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(
                            value == null ? 'All' : 'Year $value',
                            style: const TextStyle(
                              fontWeight: FontWeight.normal,
                              color: Colors.black,
                            ),
                          ),
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
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('students').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading students',
                      style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final students = snapshot.data!.docs
                    .map((doc) => Student.fromSnapshot(doc))
                    .where((student) {
                      final matchesSearch = student.name.toLowerCase().contains(_searchQuery) ||
                          student.icNumber.toLowerCase().contains(_searchQuery);
                      final matchesClass = _selectedClass == null || student.studentClass == _selectedClass;
                      return matchesSearch && matchesClass;
                    })
                    .toList();

                if (students.isEmpty) {
                  return Center(
                    child: Text(
                      'No students found.',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  );
                }

                final groupedStudents = <String, List<Student>>{};
                for (var student in students) {
                  groupedStudents.putIfAbsent(student.studentClass, () => []).add(student);
                }

                final sortedYears = groupedStudents.keys.toList()..sort();

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: sortedYears.length,
                  itemBuilder: (context, yearIndex) {
                    final year = sortedYears[yearIndex];
                    final yearStudents = groupedStudents[year]!..sort((a, b) => a.name.compareTo(b.name));

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: accentColor.withOpacity(0.1),
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Text(
                                'Year $year',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: accentColor,
                                ),
                              ),
                            ),
                            const Divider(height: 1),
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: yearStudents.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, studentIndex) {
                                final student = yearStudents[studentIndex];
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                  leading: Text(
                                    '${studentIndex + 1}.',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                  title: Text(
                                    student.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.normal,
                                      color: Colors.black,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'IC: ${student.icNumber}',
                                    style: const TextStyle(color: Colors.black),
                                  ),
                                  trailing: IconButton(
                                    tooltip: "Edit Student",
                                    icon: Icon(Icons.edit, color: accentColor),
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => EditStudentPage(student: student),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

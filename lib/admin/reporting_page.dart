import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:csv/csv.dart';
import 'dart:convert';

class ReportingPage extends StatefulWidget {
  const ReportingPage({super.key});

  @override
  State<ReportingPage> createState() => _ReportingPageState();
}

class _ReportingPageState extends State<ReportingPage> {
  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;
  DateTimeRange? dateRange;
  bool isUsingDateRange = false;
  String selectedStatusFilter = 'All';
  String selectedClassFilter = 'All';
  String nameQuery = '';

  List<Map<String, dynamic>> allLogs = [];
  List<Map<String, dynamic>> filteredLogs = [];
  List<String> classes = [];

  int currentPage = 0;
  static const int logsPerPage = 20;

  List<Map<String, dynamic>> get paginatedLogs {
    int start = currentPage * logsPerPage;
    int end = start + logsPerPage;
    return filteredLogs.sublist(start, end > filteredLogs.length ? filteredLogs.length : end);
  }

  @override
  void initState() {
    super.initState();
    fetchLogs();
  }

  Future<void> fetchLogs() async {
    final mealSnapshot = await FirebaseFirestore.instance.collection('meal_distributions').get();
    final studentSnapshot = await FirebaseFirestore.instance.collection('students').get();

    final takenMeals = mealSnapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'fingerprintId': data['fingerprintId'].toString(),
        'date': data['date'] ?? '',
      };
    }).toList();

    final allStudents = studentSnapshot.docs.map((doc) => doc.data()).toList();
    final Set<String> uniqueDates = takenMeals.map((m) => m['date'] as String).toSet();

    Set<String> classSet = {};
    List<Map<String, dynamic>> combinedLogs = [];

    for (var student in allStudents) {
      final fingerprintId = student['fingerprintId'].toString();
      final name = student['name'] ?? 'Unknown';
      final ic = student['icNumber'] ?? '-';
      final studentClass = student['studentClass']?.toString().trim() ?? 'Unknown';

      classSet.add(studentClass);

      for (var date in uniqueDates) {
        DateTime? logDate;
        try {
          logDate = DateFormat('dd/MM/yyyy').parse(date);
        } catch (_) {
          continue;
        }

        final hasTaken = takenMeals.any((log) => log['fingerprintId'] == fingerprintId && log['date'] == date);

        combinedLogs.add({
          'name': name,
          'icNumber': ic,
          'studentClass': studentClass,
          'status': hasTaken ? 'Taken' : 'Missed',
          'date': date,
          'parsedDate': logDate,
        });
      }
    }

    setState(() {
      allLogs = combinedLogs;
      classes = classSet.toList()..sort();
      applyFilter();
    });
  }

  void applyFilter() {
    final now = DateTime.now();
    List<Map<String, dynamic>> tempLogs = allLogs.where((log) {
      final date = log['parsedDate'] as DateTime;

      if (isUsingDateRange && dateRange != null) {
        return date.isAfter(dateRange!.start.subtract(const Duration(days: 1))) &&
            date.isBefore(dateRange!.end.add(const Duration(days: 1)));
      } else {
        final isSameMonth = date.month == selectedMonth && date.year == selectedYear;
        final isWeekday = date.weekday >= 1 && date.weekday <= 5;
        final isBeforeToday = date.isBefore(now.add(const Duration(days: 1)));
        return isSameMonth && isWeekday && isBeforeToday;
      }
    }).toList();

    if (selectedStatusFilter != 'All') {
      tempLogs = tempLogs.where((log) => log['status'] == selectedStatusFilter).toList();
    }

    if (selectedClassFilter != 'All') {
      tempLogs = tempLogs.where((log) => log['studentClass'] == selectedClassFilter).toList();
    }

    if (nameQuery.isNotEmpty) {
      tempLogs = tempLogs.where((log) {
        final name = log['name']?.toLowerCase() ?? '';
        return name.contains(nameQuery.toLowerCase());
      }).toList();
    }

    tempLogs.sort((a, b) {
      int classCompare = a['studentClass'].compareTo(b['studentClass']);
      return classCompare != 0 ? classCompare : a['name'].compareTo(b['name']);
    });

    setState(() {
      filteredLogs = tempLogs;
      currentPage = 0;
    });
  }

  Future<void> exportAsPDF() async {
    final pdf = pw.Document();
    final groupedLogs = <String, List<Map<String, dynamic>>>{};

    for (var log in filteredLogs) {
      groupedLogs.putIfAbsent(log['studentClass'], () => []).add(log);
    }

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text('Meal Distribution Report', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.Text('Generated on: ${DateFormat('dd/MM/yyyy hh:mm a').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 20),
          ...groupedLogs.entries.map((entry) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Class: ${entry.key}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 5),
                pw.Table.fromTextArray(
                  headers: ['No.', 'Name', 'IC Number', 'Status', 'Date'],
                  data: List.generate(entry.value.length, (index) {
                    final log = entry.value[index];
                    return [
                      '${index + 1}',
                      log['name'],
                      log['icNumber'],
                      log['status'],
                      log['date'],
                    ];
                  }),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  cellStyle: const pw.TextStyle(fontSize: 9),
                ),
                pw.SizedBox(height: 15),
              ],
            );
          }).toList(),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  Future<void> exportAsCSV() async {
    List<List<String>> rows = [
      ['No.', 'Name', 'IC Number', 'Class', 'Status', 'Date'],
      ...filteredLogs.asMap().entries.map((entry) {
        int index = entry.key;
        final log = entry.value;
        return [
          '${index + 1}',
          log['name'] ?? '',
          log['icNumber'] ?? '',
          log['studentClass'] ?? '',
          log['status'] ?? '',
          log['date'] ?? '',
        ];
      }),
    ];

    String csv = const ListToCsvConverter().convert(rows);
    final bytes = utf8.encode(csv);
    await Printing.sharePdf(bytes: bytes, filename: 'meal_report.csv');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue.shade200,
        title: const Text("Monthly Meal Report"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Filters
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text("Filter Options", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SwitchListTile(
                      title: const Text("Use Date Range Filter"),
                      value: isUsingDateRange,
                      onChanged: (val) {
                        setState(() {
                          isUsingDateRange = val;
                          applyFilter();
                        });
                      },
                    ),
                    if (isUsingDateRange)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade400,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.date_range),
                        label: Text(
                          dateRange == null
                              ? "Select Date Range"
                              : "${DateFormat('dd/MM/yyyy').format(dateRange!.start)} - ${DateFormat('dd/MM/yyyy').format(dateRange!.end)}",
                        ),
                        onPressed: () async {
                          final picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setState(() {
                              dateRange = picked;
                              applyFilter();
                            });
                          }
                        },
                      )
                    else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          DropdownButton<int>(
                            value: selectedMonth,
                            items: List.generate(12, (i) {
                              int m = i + 1;
                              return DropdownMenuItem(
                                value: m,
                                child: Text(DateFormat.MMMM().format(DateTime(0, m))),
                              );
                            }),
                            onChanged: (val) {
                              setState(() {
                                selectedMonth = val!;
                                applyFilter();
                              });
                            },
                          ),
                          const SizedBox(width: 16),
                          DropdownButton<int>(
                            value: selectedYear,
                            items: List.generate(5, (i) {
                              int y = DateTime.now().year - i;
                              return DropdownMenuItem(value: y, child: Text('$y'));
                            }),
                            onChanged: (val) {
                              setState(() {
                                selectedYear = val!;
                                applyFilter();
                              });
                            },
                          ),
                        ],
                      ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      children: [
                        DropdownButton<String>(
                          value: selectedStatusFilter,
                          items: ['All', 'Taken', 'Missed']
                              .map((val) => DropdownMenuItem(value: val, child: Text('Status: $val')))
                              .toList(),
                          onChanged: (val) {
                            setState(() {
                              selectedStatusFilter = val!;
                              applyFilter();
                            });
                          },
                        ),
                        DropdownButton<String>(
                          value: selectedClassFilter,
                          items: ['All', ...classes]
                              .map((val) => DropdownMenuItem(value: val, child: Text('Class: $val')))
                              .toList(),
                          onChanged: (val) {
                            setState(() {
                              selectedClassFilter = val!;
                              applyFilter();
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      decoration: InputDecoration(
                        labelText: "Search by Student Name",
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (val) {
                        setState(() {
                          nameQuery = val;
                          applyFilter();
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade400,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: exportAsPDF,
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text("Export PDF"),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade400,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: exportAsCSV,
                          icon: const Icon(Icons.file_download),
                          label: const Text("Export CSV"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text("Results (${filteredLogs.length} entries)", style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Expanded(
              child: filteredLogs.isEmpty
                  ? const Center(child: Text("Student not found."))
                  : Column(
                      children: [
                        Expanded(
                          child: ListView.separated(
                            itemCount: paginatedLogs.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 6),
                            itemBuilder: (context, i) {
                              final log = paginatedLogs[i];
                              return Card(
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        log['status'] == 'Taken' ? Colors.green : Colors.red,
                                    child: Icon(
                                        log['status'] == 'Taken' ? Icons.check : Icons.close,
                                        color: Colors.white),
                                  ),
                                  title: Text("${log['name']} (${log['studentClass']})"),
                                  subtitle: Text("IC: ${log['icNumber']} • Status: ${log['status']}"),
                                  trailing: Text(log['date'],
                                      style: const TextStyle(fontWeight: FontWeight.w500)),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (filteredLogs.length > logsPerPage)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton(
                                onPressed: currentPage > 0
                                    ? () => setState(() => currentPage--)
                                    : null,
                                child: const Text('Previous'),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Page ${currentPage + 1} of ${((filteredLogs.length - 1) / logsPerPage).ceil()}',
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: (currentPage + 1) * logsPerPage < filteredLogs.length
                                    ? () => setState(() => currentPage++)
                                    : null,
                                child: const Text('Next'),
                              ),
                            ],
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

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'models/student_model.dart';

class AddStudentPage extends StatefulWidget {
  const AddStudentPage({super.key});

  @override
  State<AddStudentPage> createState() => _AddStudentPageState();
}

class _AddStudentPageState extends State<AddStudentPage> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;

  final _nameController = TextEditingController();
  final _icController = TextEditingController();
  final _addressController = TextEditingController();
  final _incomeController = TextEditingController();
  final _dependentsController = TextEditingController();

  String _gender = 'L';
  String _religion = 'Islam';
  String _ethnicity = 'M';
  String _class = '1';

  final Map<String, bool> _category = {
    'Miskin Tegar': false,
    'OKU': false,
    'Sekolah Asli': false,
    'Lain-lain': false,
  };

  final Map<String, bool> _bantuan = {
    'RMT': false,
    'PSS': false,
  };

  int? _fingerprintId;
  bool _isScanning = false;
  String _statusMessage = '';

  final String esp32EnrollUrl = "http://192.168.43.46/enroll";
  final String esp32DeleteUrl = "http://192.168.43.46/delete";

  @override
  void dispose() {
    _nameController.dispose();
    _icController.dispose();
    _addressController.dispose();
    _incomeController.dispose();
    _dependentsController.dispose();
    super.dispose();
  }

  Future<int> _getNextFingerprintId() async {
    final snapshot = await _firestore.collection('students').get();
    final usedIds = <int>{};
    for (var doc in snapshot.docs) {
      final rawId = doc.data()['fingerprintId'];
      final id = rawId is int ? rawId : int.tryParse(rawId.toString()) ?? 0;
      if (id > 0) usedIds.add(id);
    }

    for (int i = 1; i <= 127; i++) {
      if (!usedIds.contains(i)) return i;
    }
    throw Exception('Maximum fingerprint ID reached (1–127)');
  }

  Future<void> _startFingerprintEnrollment() async {
    if (_isScanning) return;

    setState(() {
      _isScanning = true;
      _fingerprintId = null;
      _statusMessage = "Place your finger on the sensor...";
    });

    try {
      final id = await _getNextFingerprintId();

      await Future.delayed(const Duration(seconds: 3));
      setState(() => _statusMessage = "Remove your finger...");

      await Future.delayed(const Duration(seconds: 2));
      setState(() => _statusMessage = "Place the same finger again...");

      await Future.delayed(const Duration(seconds: 3));
      setState(() => _statusMessage = "Processing...");

      final response = await http
          .get(Uri.parse("$esp32EnrollUrl?id=$id"))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['fingerprintId'] != null) {
          final parsedId = int.tryParse(data['fingerprintId'].toString());
          if (parsedId != null) {
            setState(() {
              _fingerprintId = parsedId;
              _statusMessage = "Fingerprint enrolled with ID: $_fingerprintId";
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Fingerprint enrolled with ID: $_fingerprintId')),
            );
          } else {
            _showError('Invalid fingerprint ID format');
          }
        } else {
          _showError(data['message'] ?? 'Unknown error');
        }
      } else {
        _showError("HTTP ${response.statusCode}");
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _isScanning = false);
    }
  }

  Future<void> _clearFingerprint() async {
    if (_fingerprintId == null) return;

    try {
      final deleteUrl = "$esp32DeleteUrl?id=$_fingerprintId";
      final response = await http.get(Uri.parse(deleteUrl)).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            _fingerprintId = null;
            _statusMessage = '';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fingerprint ID cleared from sensor')),
          );
        } else {
          _showError(data['message'] ?? 'Failed to delete fingerprint on ESP32');
        }
      } else {
        _showError('HTTP ${response.statusCode} during deletion');
      }
    } catch (e) {
      _showError('Error clearing fingerprint: $e');
    }
  }

  Future<void> _saveStudent() async {
    if (!_formKey.currentState!.validate()) return;

    if (_fingerprintId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please scan fingerprint before saving')),
      );
      return;
    }

    try {
      final duplicate = await _firestore
          .collection('students')
          .where('fingerprintId', isEqualTo: _fingerprintId)
          .get();

      if (duplicate.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Duplicate fingerprint detected!')),
        );
        return;
      }

      final income = double.tryParse(_incomeController.text) ?? 0.0;
      final dependents = int.tryParse(_dependentsController.text) ?? 1;
      final perCapita = dependents > 0 ? income / dependents : income;

      final student = Student(
        id: '',
        name: _nameController.text.trim(),
        icNumber: _icController.text.trim(),
        address: _addressController.text.trim(),
        studentClass: _class,
        gender: _gender,
        religion: _religion,
        ethnicity: _ethnicity,
        income: income,
        dependents: dependents,
        perCapita: perCapita,
        category: Map<String, bool>.from(_category),
        bantuan: Map<String, bool>.from(_bantuan),
        fingerprintId: _fingerprintId!,
      );

      await _firestore.collection('students').add(student.toMap());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Student added successfully')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving student: $e')),
      );
    }
  }

  void _showError(String message) {
    setState(() => _statusMessage = "Error: $message");
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $message')));
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double formWidth = screenWidth < 600 ? screenWidth * 0.9 : 500;
    const double fontSize = 16;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Student'),
        backgroundColor: Colors.blue.shade400,
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Center(
          child: Container(
            width: formWidth,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTextField(_nameController, 'Nama', fontSize: fontSize),
                  _buildICField(fontSize: fontSize),
                  _buildTextField(_addressController, 'Alamat Murid', fontSize: fontSize),
                  _buildDropdown('Kelas', _class, ['1', '2', '3', '4', '5', '6'], (val) => _class = val, fontSize: fontSize),
                  _buildDropdown('Jantina', _gender, ['L', 'P'], (val) => _gender = val, fontSize: fontSize),
                  _buildDropdown('Agama', _religion, ['Islam', 'Bukan Islam'], (val) => _religion = val, fontSize: fontSize),
                  _buildDropdown('Keturunan', _ethnicity, ['M', 'C', 'I', 'Lain-lain'], (val) => _ethnicity = val, fontSize: fontSize),
                  _buildTextField(
                    _incomeController,
                    'Pendapatan Keluarga',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    fontSize: fontSize,
                  ),
                  _buildTextField(
                    _dependentsController,
                    'Jumlah Tanggungan (termasuk ibu bapa)',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    fontSize: fontSize,
                  ),
                  const SizedBox(height: 20),
                  _buildCheckboxGroup('Kategori Penerima', _category, fontSize: fontSize),
                  const SizedBox(height: 20),
                  _buildCheckboxGroup('Jenis Bantuan', _bantuan, fontSize: fontSize),
                  const SizedBox(height: 20),
                  _buildFingerprintStatus(fontSize: fontSize),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _isScanning || _fingerprintId != null ? null : _startFingerprintEnrollment,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Scan Fingerprint'),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text(
                        'Add Student',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      onPressed: _saveStudent,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade400,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 5,
                        shadowColor: Colors.deepPurpleAccent.withOpacity(0.4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {TextInputType? keyboardType, List<TextInputFormatter>? inputFormatters, double fontSize = 14}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(labelText: label),
        validator: (val) => val == null || val.isEmpty ? 'Required' : null,
        style: TextStyle(fontSize: fontSize),
      ),
    );
  }

  Widget _buildICField({double fontSize = 14}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: _icController,
        decoration: const InputDecoration(labelText: 'No. IC'),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        maxLength: 12,
        validator: (val) {
          if (val == null || val.isEmpty) return 'Required';
          if (val.length != 12) return 'IC must be 12 digits';
          return null;
        },
        keyboardType: TextInputType.number,
        style: TextStyle(fontSize: fontSize),
      ),
    );
  }

  Widget _buildDropdown(String label, String currentValue, List<String> options, ValueChanged<String> onChanged,
      {double fontSize = 14}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        value: currentValue,
        decoration: InputDecoration(labelText: label),
        items: options
            .map((opt) => DropdownMenuItem(value: opt, child: Text(opt, style: TextStyle(fontSize: fontSize))))
            .toList(),
        onChanged: (val) => onChanged(val!),
        style: TextStyle(fontSize: fontSize, color: Colors.black),
      ),
    );
  }

  Widget _buildCheckboxGroup(String title, Map<String, bool> items, {required double fontSize}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize)),
        ...items.keys.map((key) {
          return InkWell(
            onTap: () {
              setState(() {
                items[key] = !(items[key] ?? false);
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Checkbox(
                    value: items[key],
                    onChanged: (val) {
                      setState(() {
                        items[key] = val ?? false;
                      });
                    },
                  ),
                  Expanded(child: Text(key, style: TextStyle(fontSize: fontSize))),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildFingerprintStatus({double fontSize = 14}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Fingerprint Status:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize)),
        const SizedBox(height: 4),
        Text(
          _fingerprintId != null ? 'Enrolled with ID: $_fingerprintId' : 'Not enrolled yet',
          style: TextStyle(color: _fingerprintId != null ? Colors.green : Colors.red, fontSize: fontSize),
        ),
        if (_statusMessage.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(_statusMessage, style: TextStyle(color: Colors.blueGrey, fontSize: fontSize)),
          ),
        if (_fingerprintId != null)
          TextButton.icon(
            onPressed: _clearFingerprint,
            icon: const Icon(Icons.delete_forever, color: Colors.blue),
            label: const Text('Clear Fingerprint', style: TextStyle(color: Colors.red)),
          ),
      ],
    );
  }
}

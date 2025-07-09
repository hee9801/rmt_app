// Imports remain unchanged
//import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'models/student_model.dart';

class EditStudentPage extends StatefulWidget {
  final Student student;
  const EditStudentPage({super.key, required this.student});

  @override
  State<EditStudentPage> createState() => _EditStudentPageState();
}

class _EditStudentPageState extends State<EditStudentPage> {
  late TextEditingController _nameController;
  late TextEditingController _icController;
  late TextEditingController _addressController;
  late TextEditingController _classController;
  late TextEditingController _incomeController;
  late TextEditingController _dependentsController;

  late String _gender;
  late String _religion;
  late String _ethnicity;
  late String _studentClass;
  late Map<String, bool> _category;
  late Map<String, bool> _bantuan;

  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.student;
    _nameController = TextEditingController(text: s.name);
    _icController = TextEditingController(text: s.icNumber);
    _addressController = TextEditingController(text: s.address);
    _classController = TextEditingController(text: s.studentClass);
    _incomeController = TextEditingController(text: s.income.toString());
    _dependentsController = TextEditingController(text: s.dependents.toString());
    _gender = s.gender;
    _religion = s.religion;
    _ethnicity = s.ethnicity;
    _studentClass = s.studentClass;
    _category = Map.from(s.category);
    _bantuan = Map.from(s.bantuan);
  }

  bool _hasChanges() {
    final s = widget.student;
    return _nameController.text != s.name ||
        _icController.text != s.icNumber ||
        _addressController.text != s.address ||
        _studentClass != s.studentClass ||
        _gender != s.gender ||
        _religion != s.religion ||
        _ethnicity != s.ethnicity ||
        _incomeController.text != s.income.toString() ||
        _dependentsController.text != s.dependents.toString() ||
        !_mapsEqual(_category, s.category) ||
        !_mapsEqual(_bantuan, s.bantuan);
  }

  bool _mapsEqual(Map<String, bool> a, Map<String, bool> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }

  void _updateStudent() async {
    if (!_formKey.currentState!.validate()) return;

    final income = double.tryParse(_incomeController.text.replaceAll(',', '')) ?? 0.0;
    final dependents = int.tryParse(_dependentsController.text) ?? 1;
    final perCapita = dependents > 0 ? income / dependents : 0.0;

    final updatedStudent = Student(
      id: widget.student.id,
      name: _nameController.text,
      icNumber: _icController.text,
      address: _addressController.text,
      studentClass: _studentClass,
      gender: _gender,
      religion: _religion,
      ethnicity: _ethnicity,
      income: income,
      dependents: dependents,
      perCapita: perCapita,
      category: _category,
      bantuan: _bantuan,
      fingerprintId: widget.student.fingerprintId, // keeping it unchanged
    );

    setState(() => _isSaving = true);
    await FirebaseFirestore.instance
        .collection('students')
        .doc(widget.student.id)
        .update(updatedStudent.toMap());
    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Student updated')),
      );
      Navigator.pop(context, true);
    }
  }

  void _deleteStudent() async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Confirm Delete', style: TextStyle(fontWeight: FontWeight.bold)),
      content: const Text('Are you sure you want to delete this student?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  if (confirm != true) return;

  setState(() => _isSaving = true);

  try {
    // Step 1: Delete from Firebase
    await FirebaseFirestore.instance
        .collection('students')
        .doc(widget.student.id)
        .delete();

    // Step 2: Delete from ESP32
    final fingerprintId = widget.student.fingerprintId;
    if (fingerprintId != null) {
      final uri = Uri.parse('http://192.168.43.46/delete?id=$fingerprintId'); // Replace with your ESP32 IP
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        print('Fingerprint deleted from ESP32');
      } else {
        print('Failed to delete fingerprint on ESP32: ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Deleted from Firebase, but failed to delete from fingerprint sensor.')),
        );
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Student successfully deleted')),
      );
      Navigator.pop(context);
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }

  setState(() => _isSaving = false);
}


  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_hasChanges()) {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Unsaved Changes',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
              ),
              content: const Text('You have unsaved changes. Do you want to discard them?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Discard'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                  onPressed: () => Navigator.pop(context, true),
                ),
              ],
            ),
          );
          return confirm == true;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.blue.shade400,
          title: const Text('Edit Student'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton.icon(
                onPressed: _isSaving ? null : _deleteStudent,
                icon: const Icon(Icons.delete, color: Colors.white),
                label: const Text('Delete', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
        body: AbsorbPointer(
          absorbing: _isSaving,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Nama'),
                  validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                ),
                TextFormField(
                  controller: _icController,
                  decoration: const InputDecoration(labelText: 'No Kad Pengenalan'),
                  keyboardType: TextInputType.number,
                  maxLength: 12,
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Required';
                    if (val.length != 12 || !RegExp(r'^\d{12}$').hasMatch(val)) {
                      return 'IC must be 12 digits and numeric';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(labelText: 'Alamat Murid'),
                  validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField(
                  value: _studentClass,
                  isExpanded: true,
                  items: ['1', '2', '3', '4', '5', '6']
                      .map((c) => DropdownMenuItem(value: c, child: Text(' $c')))
                      .toList(),
                  onChanged: (val) => setState(() => _studentClass = val!),
                  decoration: const InputDecoration(labelText: 'Kelas'),
                ),
                DropdownButtonFormField(
                  value: _gender,
                  isExpanded: true,
                  items: ['L', 'P'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                  onChanged: (val) => setState(() => _gender = val!),
                  decoration: const InputDecoration(labelText: 'Jantina'),
                ),
                DropdownButtonFormField(
                  value: _religion,
                  isExpanded: true,
                  items: ['Islam', 'Bukan Islam'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (val) => setState(() => _religion = val!),
                  decoration: const InputDecoration(labelText: 'Agama'),
                ),
                DropdownButtonFormField(
                  value: _ethnicity,
                  isExpanded: true,
                  items: ['M', 'C', 'I', 'Lain-lain']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (val) => setState(() => _ethnicity = val!),
                  decoration: const InputDecoration(labelText: 'Keturunan'),
                ),
                TextFormField(
                  controller: _incomeController,
                  decoration: const InputDecoration(labelText: 'Pendapatan Keluarga'),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                ),
                TextFormField(
                  controller: _dependentsController,
                  decoration: const InputDecoration(labelText: 'Jumlah Tanggungan'),
                  keyboardType: TextInputType.number,
                  validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 10),
                const Text('Kategori Penerima', style: TextStyle(fontWeight: FontWeight.bold)),
                ..._category.keys.map((key) => CheckboxListTile(
                      title: Text(key),
                      value: _category[key],
                      onChanged: (val) => setState(() => _category[key] = val!),
                    )),
                const Text('Jenis Bantuan', style: TextStyle(fontWeight: FontWeight.bold)),
                ..._bantuan.keys.map((key) => CheckboxListTile(
                      title: Text(key),
                      value: _bantuan[key],
                      onChanged: (val) => setState(() => _bantuan[key] = val!),
                    )),
                const SizedBox(height: 10),
                TextFormField(
                  initialValue: widget.student.fingerprintId?.toString() ?? '-',
                  readOnly: true,
                  enabled: false,
                  decoration: const InputDecoration(
                    labelText: 'Fingerprint ID',
                    border: OutlineInputBorder(),
                    disabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _updateStudent,
                  icon: const Icon(Icons.save),
                  label: const Text('Update Student'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade400,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

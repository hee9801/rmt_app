import 'package:cloud_firestore/cloud_firestore.dart';

class Student {
  final String id;
  final String name;
  final String icNumber;
  final String address;
  final String gender;
  final String religion;
  final String ethnicity;
  final int dependents;
  final double income;
  final double perCapita;
  final String studentClass;
  final Map<String, bool> category;
  final Map<String, bool> bantuan;
  final int fingerprintId; // Changed from String to int

  Student({
    required this.id,
    required this.name,
    required this.icNumber,
    required this.address,
    required this.gender,
    required this.religion,
    required this.ethnicity,
    required this.dependents,
    required this.income,
    required this.perCapita,
    required this.studentClass,
    required this.category,
    required this.bantuan,
    required this.fingerprintId,
  });

  factory Student.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data()!;

    return Student(
      id: snapshot.id,
      name: data['name'] ?? '',
      icNumber: data['icNumber'] ?? '',
      address: data['address'] ?? '',
      gender: data['gender'] ?? '',
      religion: data['religion'] ?? '',
      ethnicity: data['ethnicity'] ?? '',
      dependents: (data['dependents'] ?? 1) is int
          ? data['dependents']
          : int.tryParse(data['dependents'].toString()) ?? 1,
      income: (data['income'] ?? 0) is double
          ? data['income']
          : double.tryParse(data['income'].toString()) ?? 0,
      perCapita: (data['perCapita'] ?? 0) is double
          ? data['perCapita']
          : double.tryParse(data['perCapita'].toString()) ?? 0,
      studentClass: data['studentClass'] ?? '',
      category: Map<String, bool>.from(data['category'] ?? {}),
      bantuan: Map<String, bool>.from(data['bantuan'] ?? {}),
      fingerprintId: (data['fingerprintId'] ?? 0) is int
          ? data['fingerprintId']
          : int.tryParse(data['fingerprintId'].toString()) ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'icNumber': icNumber,
      'address': address,
      'gender': gender,
      'religion': religion,
      'ethnicity': ethnicity,
      'dependents': dependents,
      'income': income,
      'perCapita': perCapita,
      'studentClass': studentClass,
      'category': category,
      'bantuan': bantuan,
      'fingerprintId': fingerprintId, // stored as int in Firestore
    };
  }
}

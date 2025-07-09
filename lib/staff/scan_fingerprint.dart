import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class FingerprintMatchPage extends StatefulWidget {
  @override
  _FingerprintMatchPageState createState() => _FingerprintMatchPageState();
}

class _FingerprintMatchPageState extends State<FingerprintMatchPage> {
  String status = "Scan the fingerprint";
  Map<String, dynamic>? studentData;
  bool _isScanning = false;

  Future<void> scanFingerprintAndFetchStudent() async {
    if (_isScanning) return;

    if (!mounted) return;
    setState(() {
      _isScanning = true;
      studentData = null;
    });

    await Future.delayed(const Duration(seconds: 1));

    try {
      final response = await http
          .get(Uri.parse("http://192.168.43.46/match"))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['status'] == 'success') {
          if (!mounted) return;
          setState(() {
            status = "Verifying fingerprint...";
          });

          final int id = result['fingerprintId'];

          final snapshot = await FirebaseFirestore.instance
              .collection("students")
              .where("fingerprintId", isEqualTo: id)
              .limit(1)
              .get();

          if (snapshot.docs.isNotEmpty) {
            final studentDoc = snapshot.docs.first.data();
            final icNumber = studentDoc['icNumber'];

            final nowUtc = DateTime.now().toUtc();
            final formattedDate = DateFormat('dd/MM/yyyy').format(nowUtc.toLocal());

            final alreadyTaken = await FirebaseFirestore.instance
                .collection("meal_distributions")
                .where("fingerprintId", isEqualTo: id)
                .where("date", isEqualTo: formattedDate)
                .get();

            if (!mounted) return;
            if (alreadyTaken.docs.isEmpty) {
              await FirebaseFirestore.instance.collection("meal_distributions").add({
                'icNumber': icNumber,
                'fingerprintId': id,
                'timestamp': nowUtc,
                'date': formattedDate,
              });

              if (!mounted) return;
              setState(() {
                studentData = studentDoc;
                status = "✅ Verified - Meal Given";
              });
            } else {
              if (!mounted) return;
              setState(() {
                studentData = studentDoc;
                status = "⚠️ Already Received Meal Today";
              });
            }

            WidgetsBinding.instance.addPostFrameCallback((_) {
              Future.delayed(const Duration(seconds: 5), () {
                if (!mounted) return;
                setState(() {
                  studentData = null;
                  status = "Scan the fingerprint";
                });
                scanFingerprintAndFetchStudent();
              });
            });
          } else {
            if (!mounted) return;
            setState(() {
              status = "❌ No student found for this ID.";
            });
            Future.delayed(const Duration(seconds: 3), () {
              if (!mounted) return;
              setState(() => status = "Scan the fingerprint");
              scanFingerprintAndFetchStudent();
            });
          }
        } else {
          Future.delayed(const Duration(seconds: 2), () {
            if (!mounted) return;
            scanFingerprintAndFetchStudent();
          });
        }
      } else {
        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted) return;
          scanFingerprintAndFetchStudent();
        });
      }
    } catch (e) {
      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        scanFingerprintAndFetchStudent();
      });
    }

    if (!mounted) return;
    setState(() => _isScanning = false);
  }

  @override
  void initState() {
    super.initState();
    scanFingerprintAndFetchStudent();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: studentData == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.fingerprint, size: 100, color: Colors.grey),
                  const SizedBox(height: 20),
                  Text(
                    status,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.verified, size: 100, color: Colors.green),
                  const SizedBox(height: 20),
                  Text(
                    status,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Divider(height: 30),
                  Text("👤 Name: ${studentData!['name']}"),
                  Text("🎓 Class: ${studentData!['studentClass']}"),
                  Text("🆔 IC: ${studentData!['icNumber']}"),
                ],
              ),
      ),
    );
  }
}

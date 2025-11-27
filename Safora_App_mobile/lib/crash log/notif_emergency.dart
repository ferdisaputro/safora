import 'dart:async';
import 'package:flutter/material.dart';
import 'package:safora_app/dashboard/dashboard_page.dart';

class AccidentAlertPage extends StatefulWidget {
  const AccidentAlertPage({super.key});

  @override
  State<AccidentAlertPage> createState() => _AccidentAlertPageState();
}

class _AccidentAlertPageState extends State<AccidentAlertPage> {
  int countdown = 10;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    startCountdown();
  }

  void startCountdown() {
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (countdown > 0) {
        setState(() {
          countdown--;
        });
      } else {
        t.cancel();
        // Aksi kalau waktu habis → kembali ke Dashboard
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const dashboardPage()),
        );
      }
    });
  }


  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.white,
                size: 120,
              ),
              const SizedBox(height: 20),
              const Text(
                "Kecelakaan Terdeteksi",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Text(
                "Tingkat: Parah",
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                "Konfirmasi Dalam",
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "$countdown s",
                style: const TextStyle(
                  fontSize: 60,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  // Aksi jika user menekan "Konfirmasi Aman"
                  timer?.cancel();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Telah konfirmasi kondisi dalam keadaan aman")),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.yellow,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 40, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  "Konfirmasi Aman",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Pencet tombol ini jika anda tidak mengalami kecelakaan",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

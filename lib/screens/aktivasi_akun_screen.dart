import 'package:flutter/material.dart';

import 'syarat_dan_ketentuan.dart';
// HAPUS: import 'package:get/get.dart';

class AktivasiAkunScreen extends StatelessWidget {
  final Map<String, dynamic> user;

  const AktivasiAkunScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green[50],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo KSMI
              Image.asset(
                'assets/images/KSMI_LOGO.png',
                width: 120,
                height: 120,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.people_alt,
                      size: 60,
                      color: Colors.green,
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
              
              // Judul
              Text(
                'Selamat Datang di KSMI',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[800],
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
              
              // Deskripsi
              Text(
                'Selamat! Anda telah bergabung menjadi anggota Koperasi Syirkah Muslim Indonesia.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.green[700],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 8),
              
              Text(
                'Tinggal satu langkah lagi untuk mengaktifkan keanggotaan Anda.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.green[700],
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 40),
              
              // Tombol Mulai
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    // GANTI: Get.to(() => SyaratKetentuanScreen(user: user));
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SyaratKetentuanScreen(user: user),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: const Text(
                    'Mulai Aktivasi',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
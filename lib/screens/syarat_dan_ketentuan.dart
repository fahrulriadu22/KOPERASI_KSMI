import 'package:flutter/material.dart';

import 'upload_dokumen_screen.dart';
// HAPUS: import 'package:get/get.dart';

class SyaratKetentuanScreen extends StatelessWidget {
  final Map<String, dynamic> user;

  const SyaratKetentuanScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green[50],
      appBar: AppBar(
        title: const Text('Syarat & Ketentuan'),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Center(
                child: Text(
                  'Persyaratan Keanggotaan',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800],
                  ),
                ),
              ),
              
              const SizedBox(height: 8),
              
              Center(
                child: Text(
                  'Pastikan Anda memenuhi semua persyaratan berikut:',
                  style: TextStyle(
                    color: Colors.green[600],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Daftar Persyaratan
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildRequirementItem('1. Berusia minimal 17 tahun'),
                      _buildRequirementItem('2. Memiliki KTP domisili Jawa Timur'),
                      _buildRequirementItem('3. Mengisi formulir keanggotaan'),
                      _buildRequirementItem('4. Menyerahkan foto kopi KTP dan KK'),
                      _buildRequirementItem('5. Menyerahkan pas foto berwarna ukuran 3x4 sebanyak 4 lembar'),
                      
                      const SizedBox(height: 24),
                      
                      // Biaya
                      Text(
                        'Biaya Keanggotaan:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[800],
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      _buildCostItem('Simpanan Pokok (SIMPOK)', 'Rp 100.000', 'Dibayar 1 kali ketika pendaftaran'),
                      _buildCostItem('Simpanan Wajib (SIMWA)', 'Rp 25.000/bulan', 'Dibayar perbulan selama menjadi anggota'),
                      _buildCostItem('Biaya Administrasi', 'Rp 5.000', 'Dibayar saat pendaftaran'),
                      
                      const SizedBox(height: 24),
                      
                      // Peraturan
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Kewajiban Anggota:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[800],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '• Menyetujui dan menaati segala peraturan yang berlaku di KSMI\n'
                              '• Membayar simpanan wajib tepat waktu setiap bulannya\n'
                              '• Mengikuti AD/ART KSMI',
                              style: TextStyle(
                                color: Colors.orange[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
              
              // Tombol Setuju
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    // GANTI: Get.to(() => UploadDokumenScreen(user: user));
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UploadDokumenScreen(user: user),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Saya Setuju & Lanjutkan',
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

  Widget _buildRequirementItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, color: Colors.green[700], size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.green[700],
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostItem(String title, String amount, String description) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.green[800],
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.green[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.green[700],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
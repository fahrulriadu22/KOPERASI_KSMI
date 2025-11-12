import 'package:flutter/material.dart';
import '../services/api_service.dart';

// ✅ CUSTOM SHAPE UNTUK APPBAR - DIPERBAIKI
class NotchedAppBarShape extends ContinuousRectangleBorder {
  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final double centerWidth = 180.0;
    final double centerDepth = 25.0;
    final double sideCurveDepth = 25.0;
    
    return Path()
      ..moveTo(rect.left, rect.top)
      ..lineTo(rect.right, rect.top)
      ..lineTo(rect.right, rect.bottom)
      ..quadraticBezierTo(
        rect.right - 40, 
        rect.bottom - sideCurveDepth,
        rect.right - 80, 
        rect.bottom - centerDepth,
      )
      ..lineTo(rect.left + 80, rect.bottom - centerDepth)
      ..quadraticBezierTo(
        rect.left + 40, 
        rect.bottom - sideCurveDepth,
        rect.left, 
        rect.bottom,
      )
      ..lineTo(rect.left, rect.top)
      ..close();
  }
}

class RiwayatAngsuranScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final String? initialAngsuranType;
  
  const RiwayatAngsuranScreen({
    super.key, 
    required this.user,
    this.initialAngsuranType,
  });
  
  @override
  State<RiwayatAngsuranScreen> createState() => _RiwayatAngsuranScreenState();
}

class _RiwayatAngsuranScreenState extends State<RiwayatAngsuranScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _riwayatAngsuran = [];
  List<Map<String, dynamic>> _dataMaster = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  late String _selectedAngsuranType;
  List<Map<String, dynamic>> _angsuranTypes = [];

  @override
  void initState() {
    super.initState();
    
    // ✅ SET INITIAL VALUE BERDASARKAN PARAMETER
    _selectedAngsuranType = 'semua';
    
    _loadRiwayatAngsuran();
  }

  // ✅ LOAD DATA DARI API
  Future<void> _loadRiwayatAngsuran() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = '';
      });
    }

    try {
      print('🚀 Memulai load data dari getAlltaqsith API...');
      
      // ✅ PANGGIL API GETALLTAQSITH
      final result = await _apiService.getAlltaqsith();
      
      print('📊 Response getAlltaqsith: ${result['success']}');
      print('📊 Message: ${result['message']}');
      
      if (mounted) {
        setState(() {
          if (result['success'] == true) {
            final data = result['data'];
            final dataMaster = result['data_master'];
            
            // ✅ SIMPAN DATA MASTER
            if (dataMaster is List && dataMaster.isNotEmpty) {
              _dataMaster = List<Map<String, dynamic>>.from(dataMaster);
              print('✅ Berhasil load ${_dataMaster.length} data master');
            } else {
              _dataMaster = [];
              print('⚠️ Data master kosong');
            }
            
            // ✅ KONVERSI DATA DARI API
            if (data is List && data.isNotEmpty) {
              _riwayatAngsuran = _parseTaqsithData(data);
              print('✅ Berhasil load ${_riwayatAngsuran.length} data pembiayaan');
              
              // ✅ GENERATE JENIS ANGSURAN DARI DATA YANG ADA
              _generateAngsuranTypes();
            } else {
              _riwayatAngsuran = [];
              print('⚠️ Data pembiayaan kosong atau bukan list');
            }
          } else {
            _riwayatAngsuran = [];
            _dataMaster = [];
            _hasError = true;
            _errorMessage = result['message'] ?? 'Gagal memuat data pembiayaan';
            print('❌ API Error: $_errorMessage');
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Gagal memuat data: $e';
          _riwayatAngsuran = [];
          _dataMaster = [];
        });
      }
    }
  }

 // ✅ GENERATE JENIS ANGSURAN DARI DATA YANG ADA
void _generateAngsuranTypes() {
  final types = <Map<String, dynamic>>[];
  
  // ✅ TAMBAHKAN "SEMUA" SEBAGAI DEFAULT
  types.add({
    'id': 'semua', 
    'name': 'Semua', 
    'icon': Icons.all_inclusive, 
    'color': Colors.green, 
    'is_active': true,
    'total': _getTotalAngsuran('semua')
  });
  
  // ✅ EKSTRAK JENIS UNIK DARI DATA
  final uniqueTypes = <String, Map<String, dynamic>>{};
  
  for (var angsuran in _riwayatAngsuran) {
    final jenis = angsuran['jenis']?.toString() ?? 'taqsith';
    final namaBarang = angsuran['nama_barang']?.toString() ?? 'Produk';
    // ✅ HAPUS ID KREDIT DARI NAMA FILTER
    // final idKredit = angsuran['id_kredit']?.toString() ?? '';
    
    if (!uniqueTypes.containsKey(jenis)) {
      uniqueTypes[jenis] = {
        'id': jenis,
        'name': namaBarang, // ✅ HANYA NAMA BARANG, TANPA ID
        'icon': Icons.payments, // ✅ ICON STANDAR
        'color': Colors.green, // ✅ WARNA STANDAR HIJAU
        'is_active': true,
        'total': _getTotalAngsuran(jenis)
      };
    }
  }
  
  // ✅ TAMBAHKAN KE LIST
  types.addAll(uniqueTypes.values.toList());
  
  setState(() {
    _angsuranTypes = types;
  });
  
  print('✅ Generated ${_angsuranTypes.length} angsuran types');
}

  // ✅ PARSING DATA DARI API - SESUAI STRUCTURE POSTMAN
  List<Map<String, dynamic>> _parseTaqsithData(List<dynamic> apiData) {
    final List<Map<String, dynamic>> parsedData = [];
    
    for (var kreditItem in apiData) {
      try {
        if (kreditItem is Map<String, dynamic>) {
          final idKredit = kreditItem['id_kredit']?.toString();
          final namaBarang = kreditItem['nama_barang']?.toString() ?? 'Produk';
          final angsuranList = kreditItem['angsuran'];
          
          // ✅ CARI DATA MASTER UNTUK INFORMASI TAMBAHAN
          final masterData = _findMasterData(idKredit);
          final jangkaWaktu = masterData?['jangka_waktu']?.toString() ?? '18 Bulan';
          final statusMaster = masterData?['status']?.toString() ?? 'TEPAT WAKTU';
          final angsuranMaster = double.tryParse(masterData?['angsuran']?.toString() ?? '0') ?? 0;
          
          // ✅ GUNAKAN ID_KREDIT + NAMA_BARANG SEBAGAI JENIS
          final jenisPembiayaan = '$idKredit-$namaBarang';
          
          if (angsuranList is List && angsuranList.isNotEmpty) {
            for (var angsuranItem in angsuranList) {
              if (angsuranItem is Map<String, dynamic>) {
                // ✅ PARSE DATA DARI RESPONSE API
                final harga = double.tryParse(angsuranItem['harga']?.toString() ?? '0') ?? 0;
                final sisa = double.tryParse(angsuranItem['sisa']?.toString() ?? '0') ?? 0;
                final ke = int.tryParse(angsuranItem['ke']?.toString() ?? '0') ?? 0;
                final hargaBagiHasil = double.tryParse(angsuranItem['harga_bagi_hasil']?.toString() ?? '0') ?? 0;
                final sisaBagiHasil = double.tryParse(angsuranItem['sisa_bagi_hasil']?.toString() ?? '0') ?? 0;
                final tanggalBuat = angsuranItem['tanggal_buat']?.toString() ?? '';
                final invNo = angsuranItem['inv_no']?.toString() ?? '';
                final idRujukan = angsuranItem['id_rujukan']?.toString() ?? '';
                
                // ✅ TENTUKAN STATUS BERDASARKAN SISA
                String statusAngsuran = 'aktif';
                if (sisa <= 0) {
                  statusAngsuran = 'lunas';
                } else if (ke > 1) {
                  statusAngsuran = 'berjalan';
                }
                
                // ✅ HITUNG TOTAL ANGSURAN (18 BULAN)
                final totalAngsuran = angsuranMaster > 0 ? angsuranMaster * 18 : harga * 18;
                
                parsedData.add({
                  'id': '${idRujukan}_$ke',
                  'tanggal': tanggalBuat,
                  'no_invoice': invNo,
                  'jumlah': harga,
                  'sisa_angsuran': sisa,
                  'ke': ke,
                  'id_kredit': idKredit,
                  'nama_barang': namaBarang,
                  'jenis': jenisPembiayaan,
                  'keterangan': 'Angsuran $namaBarang - Cicilan ke-$ke',
                  'status': statusAngsuran,
                  'harga_bagi_hasil': hargaBagiHasil,
                  'sisa_bagi_hasil': sisaBagiHasil,
                  'total_angsuran': totalAngsuran,
                  'tenor': _extractTenor(jangkaWaktu),
                  'jangka_waktu': jangkaWaktu,
                  'status_master': statusMaster,
                  'angsuran_master': angsuranMaster,
                });
              }
            }
          } else {
            // ✅ JIKA TIDAK ADA ANGSURAN, TAMPILKAN DATA KREDIT SAJA
            print('⚠️ Tidak ada data angsuran untuk kredit $idKredit - $namaBarang');
            
            parsedData.add({
              'id': 'kredit_$idKredit',
              'tanggal': '',
              'no_invoice': '',
              'jumlah': 0,
              'sisa_angsuran': 0,
              'ke': 0,
              'id_kredit': idKredit,
              'nama_barang': namaBarang,
              'jenis': jenisPembiayaan,
              'keterangan': 'Pembiayaan $namaBarang (Belum ada angsuran)',
              'status': 'belum mulai',
              'harga_bagi_hasil': 0,
              'sisa_bagi_hasil': 0,
              'total_angsuran': angsuranMaster * 18,
              'tenor': _extractTenor(jangkaWaktu),
              'jangka_waktu': jangkaWaktu,
              'status_master': statusMaster,
              'angsuran_master': angsuranMaster,
            });
          }
        }
      } catch (e) {
        print('❌ Error parsing item: $e');
      }
    }
    
    // ✅ URUTKAN BERDASARKAN TANGGAL (TERBARU DIATAS) DAN STATUS
    parsedData.sort((a, b) {
      final dateA = DateTime.tryParse(a['tanggal'] ?? '') ?? DateTime(2000);
      final dateB = DateTime.tryParse(b['tanggal'] ?? '') ?? DateTime(2000);
      
      if (dateA != DateTime(2000) && dateB != DateTime(2000)) {
        return dateB.compareTo(dateA);
      } else if (dateA != DateTime(2000)) {
        return -1;
      } else if (dateB != DateTime(2000)) {
        return 1;
      } else {
        return (b['nama_barang'] ?? '').compareTo(a['nama_barang'] ?? '');
      }
    });
    
    return parsedData;
  }

  // ✅ CARI DATA MASTER BERDASARKAN ID_KREDIT
  Map<String, dynamic>? _findMasterData(String? idKredit) {
    if (idKredit == null) return null;
    
    try {
      return _dataMaster.firstWhere(
        (master) => master['id_kredit']?.toString() == idKredit,
        orElse: () => {},
      );
    } catch (e) {
      return null;
    }
  }

  // ✅ EKSTRAK TENOR DARI JANGKA_WAKTU
  String _extractTenor(String jangkaWaktu) {
    try {
      final regex = RegExp(r'(\d+)');
      final match = regex.firstMatch(jangkaWaktu);
      return match?.group(1) ?? '18';
    } catch (e) {
      return '18';
    }
  }

  // ✅ FILTER RIWAYAT BERDASARKAN JENIS YANG DIPILIH
  List<Map<String, dynamic>> get _filteredRiwayat {
    try {
      if (_selectedAngsuranType == 'semua') {
        return _riwayatAngsuran;
      }
      
      return _riwayatAngsuran.where((angsuran) {
        final jenis = angsuran['jenis']?.toString() ?? '';
        return jenis == _selectedAngsuranType;
      }).toList();
    } catch (e) {
      print('❌ Error filtering: $e');
      return [];
    }
  }

  // ✅ GET TOTAL ANGSURAN
  double _getTotalAngsuran(String jenisId) {
    try {
      if (jenisId == 'semua') {
        return _riwayatAngsuran.fold(0.0, (sum, angsuran) {
          try {
            final jumlah = (angsuran['jumlah'] as num?)?.toDouble() ?? 0.0;
            return sum + jumlah;
          } catch (e) {
            return sum;
          }
        });
      }
      
      return _riwayatAngsuran.where((angsuran) {
        final jenis = angsuran['jenis']?.toString() ?? '';
        return jenis == jenisId;
      }).fold(0.0, (sum, angsuran) {
        try {
          final jumlah = (angsuran['jumlah'] as num?)?.toDouble() ?? 0.0;
          return sum + jumlah;
        } catch (e) {
          return sum;
        }
      });
    } catch (e) {
      print('❌ Error calculating total: $e');
      return 0.0;
    }
  }

  // ✅ FORMAT CURRENCY
  String _formatCurrency(double amount) {
    try {
      if (amount == 0) return 'Rp 0';
      
      return 'Rp ${amount.toInt().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]}.',
      )}';
    } catch (e) {
      return 'Rp 0';
    }
  }

  // ✅ GET STATUS COLOR
  Color _getStatusColor(String status) {
    try {
      final statusStr = status.toString().toLowerCase();
      switch (statusStr) {
        case 'lunas': 
        case 'tepat waktu':
        case 'completed':
        case 'paid':
        case 'selesai':
          return Colors.green;
        case 'aktif':
        case 'berjalan':
        case 'diproses':
        case 'pending':
          return Colors.blue;
        case 'tertunggak':
        case 'belum terbayar':
        case 'unpaid':
        case 'ditolak':
          return Colors.red;
        case 'belum mulai':
          return Colors.orange;
        default: return Colors.grey;
      }
    } catch (e) {
      return Colors.grey;
    }
  }

  // ✅ GET ANGSURAN COLOR
  Color _getAngsuranColor(String jenis) {
    try {
      final jenisLower = jenis.toLowerCase();
      if (jenisLower.contains('handphone') || jenisLower.contains('hp')) {
        return Colors.blue;
      } else if (jenisLower.contains('motor') || jenisLower.contains('vario')) {
        return Colors.orange;
      } else if (jenisLower.contains('mobil')) {
        return Colors.red;
      } else if (jenisLower.contains('rumah')) {
        return Colors.green;
      } else {
        return Colors.purple;
      }
    } catch (e) {
      return Colors.grey;
    }
  }

  // ✅ GET ANGSURAN NAME
  String _getAngsuranName(String jenis) {
    try {
      // ✅ EKSTRAK NAMA BARANG DARI JENIS (format: id-nama)
      final parts = jenis.split('-');
      if (parts.length > 1) {
        return parts.sublist(1).join('-'); // Ambil bagian nama setelah id
      }
      return jenis;
    } catch (e) {
      return 'Angsuran';
    }
  }

  // ✅ FORMAT TANGGAL
  String _formatTanggal(String? tanggal) {
    if (tanggal == null || tanggal.isEmpty) return '-';
    
    try {
      final dateTime = DateTime.parse(tanggal);
      return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
    } catch (e) {
      return tanggal.length > 10 ? tanggal.substring(0, 10) : tanggal;
    }
  }

  // ✅ TAMPILKAN DIALOG DETAIL
  void _showDetailAngsuran(Map<String, dynamic> angsuran) {
    try {
      final jumlah = (angsuran['jumlah'] as num?)?.toDouble() ?? 0;
      final jenis = angsuran['jenis']?.toString() ?? '';
      final sisaAngsuran = (angsuran['sisa_angsuran'] as num?)?.toDouble() ?? 0;
      final totalAngsuran = (angsuran['total_angsuran'] as num?)?.toDouble() ?? (jumlah * 18);
      final tanggal = _formatTanggal(angsuran['tanggal']?.toString());
      final status = angsuran['status']?.toString() ?? 'aktif';
      final keterangan = angsuran['keterangan']?.toString() ?? 'Angsuran ${_getAngsuranName(jenis)}';
      final noInvoice = angsuran['no_invoice']?.toString() ?? '-';
      final tenor = angsuran['tenor']?.toString() ?? '18';
      final ke = angsuran['ke']?.toString() ?? '0';
      final namaBarang = angsuran['nama_barang']?.toString() ?? 'Produk';
      final hargaBagiHasil = (angsuran['harga_bagi_hasil'] as num?)?.toDouble() ?? 0;
      final sisaBagiHasil = (angsuran['sisa_bagi_hasil'] as num?)?.toDouble() ?? 0;
      final jangkaWaktu = angsuran['jangka_waktu']?.toString() ?? '18 Bulan';
      final statusMaster = angsuran['status_master']?.toString() ?? 'TEPAT WAKTU';
      final idKredit = angsuran['id_kredit']?.toString() ?? '';

      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // HEADER
// ✅ PERBAIKAN DI _showDetailAngsuran() - HEADER
Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Colors.green.withOpacity(0.1), // ✅ WARNA STANDAR
    borderRadius: const BorderRadius.only(
      topLeft: Radius.circular(16),
      topRight: Radius.circular(16),
    ),
  ),
  child: Row(
    children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.green, // ✅ WARNA STANDAR
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.payments, // ✅ ICON STANDAR
          color: Colors.white,
          size: 24,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              namaBarang,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green, // ✅ WARNA STANDAR
              ),
            ),
            // ❌ HAPUS ID KREDIT DARI HEADER
            // Text(
            //   'ID Kredit: $idKredit',
            //   style: const TextStyle(
            //     fontSize: 14,
            //     color: Colors.grey,
            //   ),
            // ),
          ],
        ),
      ),
    ],
  ),
),

                // DETAIL ANGSURAN
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // INFO UTAMA
                        const Text(
                          'Detail Pembiayaan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        _buildDetailItem('ID Kredit', idKredit),
                        _buildDetailItem('Produk', namaBarang),
                        _buildDetailItem('No. Invoice', noInvoice),
                        _buildDetailItem('Keterangan', keterangan),
                        _buildDetailItem('Tanggal', tanggal),
                        _buildDetailItem('Angsuran Ke', '$ke dari $tenor'),
                        _buildDetailItem('Jangka Waktu', jangkaWaktu),
                        _buildDetailItem('Jumlah Angsuran', _formatCurrency(jumlah)),
                        _buildDetailItem('Bagi Hasil', _formatCurrency(hargaBagiHasil)),
                        _buildDetailItem('Total Pembiayaan', _formatCurrency(totalAngsuran)),
                        _buildDetailItem('Sisa Angsuran', _formatCurrency(sisaAngsuran)),
                        _buildDetailItem('Sisa Bagi Hasil', _formatCurrency(sisaBagiHasil)),
                        
                        const SizedBox(height: 16),
                        
                        // PROGRESS BAR
                        if (totalAngsuran > 0 && sisaAngsuran >= 0 && status != 'belum mulai')
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Progress Pelunasan',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: totalAngsuran > 0 ? (totalAngsuran - sisaAngsuran) / totalAngsuran : 0,
                                backgroundColor: Colors.grey[300],
                                color: Colors.green,
                                minHeight: 8,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                totalAngsuran > 0 
                                  ? '${((totalAngsuran - sisaAngsuran) / totalAngsuran * 100).toStringAsFixed(1)}% Terbayar'
                                  : '0% Terbayar',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        
                        const SizedBox(height: 16),
                        
                        // STATUS
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: _getStatusColor(status).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: _getStatusColor(status)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.circle,
                                    color: _getStatusColor(status),
                                    size: 12,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Status Angsuran: ${status.toUpperCase()}',
                                    style: TextStyle(
                                      color: _getStatusColor(status),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: _getStatusColor(statusMaster).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: _getStatusColor(statusMaster)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.circle,
                                    color: _getStatusColor(statusMaster),
                                    size: 12,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Status Kredit: $statusMaster',
                                    style: TextStyle(
                                      color: _getStatusColor(statusMaster),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // TOMBOL TUTUP
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Tutup'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      print('❌ Error showing detail: $e');
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Detail Angsuran'),
          content: const Text('Terjadi kesalahan saat menampilkan detail.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ BUILD ERROR WIDGET
  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            'Gagal Memuat Data',
            style: TextStyle(
              fontSize: 18,
              color: Colors.red[700],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loadRiwayatAngsuran,
            icon: const Icon(Icons.refresh),
            label: const Text('Coba Lagi'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ BUILD EMPTY STATE WIDGET
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.payments_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'Belum ada riwayat pembiayaan',
            style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Data riwayat pembiayaan akan muncul setelah Anda melakukan transaksi',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loadRiwayatAngsuran,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh Data'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

@override
Widget build(BuildContext context) {
  final totalSemuaAngsuran = _getTotalAngsuran('semua');
  final filteredCount = _filteredRiwayat.length;

  return Scaffold(
    backgroundColor: Colors.green[50], // ✅ BACKGROUND UTAMA SAMA DENGAN HEADER
    appBar: PreferredSize(
      preferredSize: const Size.fromHeight(70.0),
      child: AppBar(
        title: const Padding(
          padding: EdgeInsets.only(bottom: 10.0),
          child: Text(
            'Riwayat Angsuran',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        elevation: 8,
        shadowColor: Colors.green.withOpacity(0.5),
        shape: NotchedAppBarShape(),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10.0, right: 8.0),
            child: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadRiwayatAngsuran,
              tooltip: 'Refresh Data',
            ),
          ),
        ],
      ),
    ),
    body: Container(
      color: Colors.green[50], // ✅ BACKGROUND UTAMA
      child: Column(
        children: [
          // ✅ HEADER INFO - FIXED NO GAP
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            margin: EdgeInsets.zero, // ✅ HILANGKAN MARGIN
            decoration: BoxDecoration(
              color: Colors.green[50],
              // ✅ HAPUS SEMUA BORDER & BOX SHADOW YANG MEMBUAT CELAH
            ),
            child: Column(
              children: [
                const Text(
                  'Total Semua Angsuran',
                  style: TextStyle(fontSize: 16, color: Colors.green, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatCurrency(totalSemuaAngsuran),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$filteredCount transaksi',
                  style: TextStyle(color: Colors.green[600], fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),

          // ✅ JENIS ANGSURAN FILTER - DYNAMIC DARI DATA
          if (_angsuranTypes.isNotEmpty)
            Container(
              height: 100,
              margin: EdgeInsets.zero, // ✅ HILANGKAN MARGIN
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(12),
                itemCount: _angsuranTypes.length,
                itemBuilder: (context, index) {
                  final type = _angsuranTypes[index];
                  final isSelected = _selectedAngsuranType == type['id'];
                  final isActive = type['is_active'] == true;
                  final totalAngsuran = _getTotalAngsuran(type['id'] as String);

                  return GestureDetector(
                    onTap: isActive ? () {
                      setState(() {
                        _selectedAngsuranType = type['id'] as String;
                      });
                    } : null,
                    child: Container(
                      width: 120,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? (type['color'] as Color).withOpacity(0.15)
                            : (isActive ? Colors.white : Colors.grey[100]),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected 
                              ? type['color'] as Color 
                              : (isActive ? Colors.grey[300]! : Colors.grey[400]!),
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isSelected ? 0.1 : 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            type['icon'] as IconData,
                            color: isActive ? type['color'] as Color : Colors.grey[400],
                            size: 24,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            type['name'] as String,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isActive ? type['color'] as Color : Colors.grey[500],
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatCurrency(totalAngsuran),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isActive 
                                  ? (isSelected ? Colors.black87 : Colors.black54)
                                  : Colors.grey[500],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          // ✅ LOADING INDICATOR
          if (_isLoading) 
            const LinearProgressIndicator(
              backgroundColor: Colors.green,
              color: Colors.green,
            ),

        // ✅ RIWAYAT LIST - BACKGROUND PUTIH
          Expanded(
            child: Container(
              color: Colors.white, // ✅ BACKGROUND PUTIH UNTUK KONTEN UTAMA
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Colors.green),
                          SizedBox(height: 16),
                          Text(
                            'Memuat data pembiayaan...',
                            style: TextStyle(color: Colors.green),
                          ),
                        ],
                      ),
                    )
                  : _hasError
                      ? _buildErrorWidget()
                      : _filteredRiwayat.isEmpty
                          ? _buildEmptyState()
                          : RefreshIndicator(
                              onRefresh: _loadRiwayatAngsuran,
                              color: Colors.green,
                              backgroundColor: Colors.white,
                              child: ListView.separated(
                                padding: EdgeInsets.zero, // ✅ HILANGKAN PADDING
                                itemCount: _filteredRiwayat.length,
                                separatorBuilder: (context, index) => const SizedBox(height: 4),
                                itemBuilder: (context, index) {
                                  final angsuran = _filteredRiwayat[index];
                                  final jumlah = (angsuran['jumlah'] as num?)?.toDouble() ?? 0;
                                  final jenis = angsuran['jenis']?.toString() ?? '';
                                  final sisaAngsuran = (angsuran['sisa_angsuran'] as num?)?.toDouble() ?? 0;
                                  final status = angsuran['status']?.toString() ?? 'aktif';
                                  final tanggal = _formatTanggal(angsuran['tanggal']?.toString());
                                  final ke = angsuran['ke']?.toString() ?? '0';
                                  final tenor = angsuran['tenor']?.toString() ?? '18';
                                  final namaBarang = angsuran['nama_barang']?.toString() ?? 'Produk';
                                  final hargaBagiHasil = (angsuran['harga_bagi_hasil'] as num?)?.toDouble() ?? 0;
                                  
                                  return Container(
                                    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                    child: Card(
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        side: BorderSide(color: Colors.green[100]!),
                                      ),
                                      child: ListTile(
                                        leading: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withOpacity(0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.payments,
                                            color: Colors.green,
                                            size: 20,
                                          ),
                                        ),
                                        title: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Angsuran ke-$ke',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '$namaBarang',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(tanggal),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: _getStatusColor(status).withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: _getStatusColor(status)),
                                                  ),
                                                  child: Text(
                                                    status.toUpperCase(),
                                                    style: TextStyle(
                                                      color: _getStatusColor(status),
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  '$ke/$tenor',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (hargaBagiHasil > 0)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 4),
                                                child: Text(
                                                  'Bagi Hasil: ${_formatCurrency(hargaBagiHasil)}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.orange[700],
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        trailing: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              _formatCurrency(jumlah),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green,
                                                fontSize: 16,
                                              ),
                                            ),
                                            if (sisaAngsuran > 0)
                                              Text(
                                                'Sisa: ${_formatCurrency(sisaAngsuran)}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.red[600],
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            if (sisaAngsuran == 0 && status != 'belum mulai')
                                              Text(
                                                'LUNAS',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.green[600],
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                          ],
                                        ),
                                        onTap: () {
                                          _showDetailAngsuran(angsuran);
                                        },
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
            ),
          ),
        ],
      ),
    ),
  );
}
}
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/temporary_storage_service.dart';
import '../services/file_validator.dart';
import '../services/transaction_service.dart';
import '../services/bukti_storage_service.dart'; // ✅ TAMBAH INI

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

class RiwayatTabunganScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final String? initialTabunganType;

  const RiwayatTabunganScreen({
    super.key, 
    required this.user,
    this.initialTabunganType,
  });

  @override
  State<RiwayatTabunganScreen> createState() => _RiwayatTabunganScreenState();
}

class _RiwayatTabunganScreenState extends State<RiwayatTabunganScreen> {
  final ApiService _apiService = ApiService();
  final TemporaryStorageService _storageService = TemporaryStorageService();
  final TransactionService _transactionService = TransactionService();
  final ImagePicker _imagePicker = ImagePicker();
  final Set<String> _uploadedBuktiIds = {};
  
  List<Map<String, dynamic>> _riwayatTabungan = [];
  Map<String, dynamic> _saldoData = {};
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  late String _selectedTabunganType;
  
  // ✅ STATE UNTUK UPLOAD BUKTI
  bool _isUploadingBukti = false;
  String? _uploadErrorBukti;
  Map<String, dynamic>? _selectedTransaksiForUpload;

  // ✅ Daftar jenis tabungan sesuai dengan API response
  final List<Map<String, dynamic>> _tabunganTypes = [
    {'id': 'semua', 'name': 'Semua', 'icon': Icons.all_inclusive, 'color': Colors.blue},
    {'id': 'pokok', 'name': 'Pokok', 'icon': Icons.account_balance, 'color': Colors.green},
    {'id': 'wajib', 'name': 'Wajib', 'icon': Icons.savings, 'color': Colors.orange},
    {'id': 'sukarela', 'name': 'Sukarela', 'icon': Icons.volunteer_activism, 'color': Colors.red},
    {'id': 'sitabung', 'name': 'SiTabung', 'icon': Icons.account_balance_wallet, 'color': Colors.blue},
    {'id': 'siumna', 'name': 'Siumna', 'icon': Icons.money, 'color': Colors.teal},
    {'id': 'siquna', 'name': 'Siquna', 'icon': Icons.handshake, 'color': Colors.purple},
  ];

@override
void initState() {
  super.initState();
  _selectedTabunganType = widget.initialTabunganType ?? 'semua';
  
  // ✅ LOAD DATA DENGAN APPROACH BARU
  _initializeApp();
}

  // ✅ INITIALIZE TEMPORARY STORAGE
  Future<void> _initializeStorage() async {
    try {
      await _storageService.loadFilesFromStorage();
      print('✅ TemporaryStorageService initialized for RiwayatTabungan');
    } catch (e) {
      print('❌ Error initializing storage: $e');
    }
  }

  // ✅ BUAT METHOD INITIALIZE BARU
Future<void> _initializeApp() async {
  await _loadBuktiStatus(); // ✅ LOAD STATUS BUKTI DULUAN
  _loadRiwayatTabungan();   // ✅ BARU LOAD DATA RIWAYAT
  _initializeStorage();
}

    // ✅ TAMBAHKAN METHOD INI DI DALAM CLASS
  String _getJenisTransaksiFromApi(String? transaksiApi, bool isSetoran) {
    if (transaksiApi == null || transaksiApi.isEmpty) {
      return isSetoran ? 'Setoran' : 'Penarikan';
    }
    
    switch (transaksiApi.toUpperCase()) {
      case 'POKOK':
        return 'Setoran Pokok';
      case 'WAJIB':
        return 'Setoran Wajib';
      case 'SITABUNG':
        return 'Setoran SiTabung';
      case 'PENARIKAN_SITABUNG':
        return 'Penarikan SiTabung';
      case 'SUKARELA':
        return 'Setoran Sukarela';
      case 'SIUMNA':
        return 'Setoran Siumna';
      case 'SIQUNA':
        return 'Setoran Siquna';
      default:
        return transaksiApi;
    }
  }

  // ✅ LOAD STATUS BUKTI DARI LOCAL STORAGE
Future<void> _loadBuktiStatus() async {
  try {
    final ids = await BuktiStorageService.getUploadedBuktiIds();
    setState(() {
      _uploadedBuktiIds.addAll(ids);
    });
    print('✅ Loaded ${ids.length} bukti IDs from storage');
  } catch (e) {
    print('❌ Error loading bukti status: $e');
  }
}

// ✅ SIMPAN STATUS BUKTI KE LOCAL STORAGE
Future<void> _saveBuktiStatus(String transactionId) async {
  try {
    await BuktiStorageService.saveBuktiId(transactionId);
    setState(() {
      _uploadedBuktiIds.add(transactionId);
    });
    print('✅ Bukti status saved for: $transactionId');
  } catch (e) {
    print('❌ Error saving bukti status: $e');
  }
}

Future<void> _loadRiwayatTabungan() async {
  if (mounted) {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });
  }

  try {
    print('🚀 === LOAD DATA RIWAYAT - APPROACH BARU ===');
    
    final result = await _apiService.getAllSaldo();
    
    print('📊 Response getAllSaldo success: ${result['success']}');
    
    if (result['success'] == true) {
      // ✅ AMBIL RAW DATA DARI RESPONSE
      final rawData = result['raw_data'] ?? {};
      
      print('🔍 RAW DATA KEYS: ${rawData.keys}');
      
      // ✅ EKSTRAK RIWAYAT DENGAN METHOD YANG SIMPLE
      final riwayatList = _extractRiwayatSimple(rawData);
      
      // ✅ NORMALIZE SALDO DATA
      final saldoData = _normalizeSaldoDataSimple(rawData);
      
      print('🎉 HASIL: ${riwayatList.length} riwayat, ${saldoData.length} saldo');
      
      if (mounted) {
        setState(() {
          _riwayatTabungan = riwayatList;
          _saldoData = saldoData;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = result['message'] ?? 'Gagal memuat data';
        });
      }
    }
  } catch (e) {
    print('❌ Error loading riwayat: $e');
    if (mounted) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Gagal memuat data: $e';
      });
    }
  }
}

Map<String, dynamic> _normalizeSaldoDataSimple(Map<String, dynamic> rawData) {
  final Map<String, dynamic> saldoData = {};
  int total = 0;
  
  print('💰 === NORMALIZE SALDO - SIMPLE ===');
  
  try {
    // ✅ POKOK
    if (rawData['pokok'] is List && (rawData['pokok'] as List).isNotEmpty) {
      final pokok = (rawData['pokok'] as List)[0];
      if (pokok is Map) {
        final saldo = int.tryParse(pokok['saldo']?.toString().replaceAll(RegExp(r'[^\d]'), '') ?? '0') ?? 0;
        saldoData['pokok'] = saldo;
        total += saldo;
        print('✅ Pokok: $saldo');
      }
    }
    
    // ✅ WAJIB
    if (rawData['wajib'] is List && (rawData['wajib'] as List).isNotEmpty) {
      final wajib = (rawData['wajib'] as List)[0];
      if (wajib is Map) {
        final saldo = int.tryParse(wajib['saldo']?.toString().replaceAll(RegExp(r'[^\d]'), '') ?? '0') ?? 0;
        saldoData['wajib'] = saldo;
        total += saldo;
        print('✅ Wajib: $saldo');
      }
    }
    
    // ✅ SITABUNG
    if (rawData['sitabung'] is List && (rawData['sitabung'] as List).isNotEmpty) {
      final sitabung = (rawData['sitabung'] as List)[0];
      if (sitabung is Map) {
        final saldo = int.tryParse(sitabung['saldo']?.toString().replaceAll(RegExp(r'[^\d]'), '') ?? '0') ?? 0;
        saldoData['sitabung'] = saldo;
        total += saldo;
        print('✅ Sitabung: $saldo');
      }
    }
    
    // ✅ LAINNYA
    final otherTypes = ['sukarela', 'siumna', 'siquna'];
    for (var type in otherTypes) {
      if (rawData[type] != null && rawData[type] is List && (rawData[type] as List).isNotEmpty) {
        final data = (rawData[type] as List)[0];
        if (data is Map) {
          final saldo = int.tryParse(data['saldo']?.toString().replaceAll(RegExp(r'[^\d]'), '') ?? '0') ?? 0;
          saldoData[type] = saldo;
          total += saldo;
          print('✅ $type: $saldo');
        }
      } else {
        saldoData[type] = 0;
      }
    }
    
    saldoData['saldo'] = total;
    print('💰 TOTAL SALDO: $total');
    
  } catch (e) {
    print('❌ Error normalizing saldo: $e');
  }
  
  return saldoData;
}

// ✅ BUAT SALDO DATA MANUAL DARI DATA MENTAH
Map<String, dynamic> _createSaldoDataFromRaw(dynamic rawData) {
  final Map<String, dynamic> saldoData = {};
  int total = 0;
  
  try {
    final safeData = _convertToStringDynamicMap(rawData);
    
    // ✅ POKOK
    if (safeData.containsKey('pokok') && safeData['pokok'] is List) {
      final pokokList = safeData['pokok'] as List;
      if (pokokList.isNotEmpty) {
        final first = pokokList[0];
        final safeFirst = _convertToSafeMap(first);
        if (safeFirst != null) {
          final saldo = _parseValue(safeFirst['saldo']);
          saldoData['pokok'] = saldo;
          total += saldo;
        }
      }
    }
    
    // ✅ WAJIB
    if (safeData.containsKey('wajib') && safeData['wajib'] is List) {
      final wajibList = safeData['wajib'] as List;
      if (wajibList.isNotEmpty) {
        final first = wajibList[0];
        final safeFirst = _convertToSafeMap(first);
        if (safeFirst != null) {
          final saldo = _parseValue(safeFirst['saldo']);
          saldoData['wajib'] = saldo;
          total += saldo;
        }
      }
    }
    
    // ✅ SITABUNG
    if (safeData.containsKey('sitabung') && safeData['sitabung'] is List) {
      final sitabungList = safeData['sitabung'] as List;
      if (sitabungList.isNotEmpty) {
        final first = sitabungList[0];
        final safeFirst = _convertToSafeMap(first);
        if (safeFirst != null) {
          final saldo = _parseValue(safeFirst['saldo']);
          saldoData['sitabung'] = saldo;
          total += saldo;
        }
      }
    }
    
    // ✅ LAINNYA
    final otherTypes = ['sukarela', 'siumna', 'siquna'];
    for (var type in otherTypes) {
      if (safeData.containsKey(type)) {
        final typeData = safeData[type];
        if (typeData is List && typeData.isNotEmpty) {
          final first = typeData[0];
          final safeFirst = _convertToSafeMap(first);
          if (safeFirst != null) {
            final saldo = _parseValue(safeFirst['saldo']);
            saldoData[type] = saldo;
            total += saldo;
          }
        } else {
          saldoData[type] = 0;
        }
      } else {
        saldoData[type] = 0;
      }
    }
    
    saldoData['saldo'] = total;
    
  } catch (e) {
    print('❌ Error creating saldo data: $e');
  }
  
  return saldoData;
}

// ✅ DEBUG EXTREME: CEK DATA SEBELUM MASUK KE METHOD MANAPUN
void _debugBeforeAnyProcessing(dynamic data) {
  print('🛑 === DEBUG BEFORE ANY PROCESSING ===');
  print('🛑 Data type: ${data.runtimeType}');
  
  if (data is Map) {
    print('🛑 Data keys: ${data.keys}');
    
    // ✅ CEK POKOK
    if (data.containsKey('pokok')) {
      final pokok = data['pokok'];
      print('🛑 Pokok type: ${pokok.runtimeType}');
      if (pokok is List) {
        print('🛑 Pokok List length: ${pokok.length}');
        if (pokok.isNotEmpty) {
          final first = pokok[0];
          print('🛑 First pokok: $first');
        }
      }
    }
    
    // ✅ CEK SITABUNG
    if (data.containsKey('sitabung')) {
      final sitabung = data['sitabung'];
      print('🛑 Sitabung type: ${sitabung.runtimeType}');
      if (sitabung is List) {
        print('🛑 Sitabung List length: ${sitabung.length}');
        if (sitabung.isNotEmpty) {
          final first = sitabung[0];
          print('🛑 First sitabung: $first');
          if (first is Map && first.containsKey('history_debet')) {
            final history = first['history_debet'];
            print('🛑 History type: ${history.runtimeType}');
            if (history is List) {
              print('🛑 History length: ${history.length}');
            }
          }
        }
      }
    }
  }
  
  print('🛑 === DEBUG END ===');
}

void getAllSaldo() async {
  print('🚀 === MEMULAI LOAD DATA DARI getAllSaldo ===');
  
  try {
    var response = await _apiService.getAllSaldo();
    
    if (response['success'] == true) {
      print('📡 Data diterima, processing...');
      
      // 1. Ambil data normalisasi untuk saldo
      var normalizedData = response['data'];
      print('💰 Normalized saldo: $normalizedData');
      
      // 2. Ambil raw data untuk ekstrak riwayat
      var rawData = response['raw_data'];
      print('📊 Raw data keys: ${rawData.keys}');
      
      // 3. Ekstrak riwayat dari raw data
      var riwayatResult = extractRiwayatFromSaldo(rawData);
      print('📋 Riwayat ditemukan: ${riwayatResult['riwayat'].length} data');
      
      setState(() {
        _saldoData = normalizedData;
        _riwayatTabungan = riwayatResult['riwayat'];
      });
      
      print('✅ LOAD DATA SELESAI: ${_riwayatTabungan.length} riwayat');
    } else {
      print('❌ API response failed: ${response['message']}');
    }
  } catch (e) {
    print('❌ ERROR getAllSaldo: $e');
  }
}

// ✅ METHOD UNTUK DEBUG STRUKTUR DATA
void _debugDataStructure() async {
  try {
    print('🔍 === DEBUG DATA STRUCTURE ===');
    
    final result = await _apiService.getAllSaldo();
    
    if (result['success'] == true) {
      final data = result['data'];
      final safeData = _convertToStringDynamicMap(data);
      
      print('📊 Semua keys: ${safeData.keys}');
      
      // ✅ CEK POKOK
      if (safeData.containsKey('pokok')) {
        final pokok = safeData['pokok'];
        print('💰 Pokok type: ${pokok.runtimeType}');
        
        if (pokok is List && pokok.isNotEmpty) {
          final firstPokok = pokok[0];
          final safeFirst = _convertToSafeMap(firstPokok);
          print('💰 First pokok item keys: ${safeFirst?.keys}');
          
          if (safeFirst != null && safeFirst.containsKey('history_debet')) {
            final history = safeFirst['history_debet'];
            print('💰 history_debet type: ${history.runtimeType}');
            
            if (history is List && history.isNotEmpty) {
              print('💰 Jumlah history_debet: ${history.length}');
              final firstHistory = history[0];
              print('💰 First history item: $firstHistory');
            }
          }
        }
      }
      
      // ✅ CEK SITABUNG
      if (safeData.containsKey('sitabung')) {
        final sitabung = safeData['sitabung'];
        print('💰 Sitabung type: ${sitabung.runtimeType}');
        
        if (sitabung is List && sitabung.isNotEmpty) {
          final firstSitabung = sitabung[0];
          final safeFirst = _convertToSafeMap(firstSitabung);
          print('💰 First sitabung item keys: ${safeFirst?.keys}');
          
          if (safeFirst != null && safeFirst.containsKey('history_debet')) {
            final history = safeFirst['history_debet'];
            print('💰 history_debet type: ${history.runtimeType}');
            
            if (history is List) {
              print('💰 Jumlah history_debet: ${history.length}');
              if (history.isNotEmpty) {
                final firstHistory = history[0];
                print('💰 First history item: $firstHistory');
              }
            }
          }
        }
      }
    }
    
    print('🔍 === DEBUG SELESAI ===');
  } catch (e) {
    print('❌ Debug error: $e');
  }
}

// ✅ HELPER: CONVERT MAP<DYNAMIC, DYNAMIC> KE MAP<STRING, DYNAMIC>
Map<String, dynamic> _convertToStringDynamicMap(dynamic data) {
  if (data is Map<String, dynamic>) {
    return data;
  } else if (data is Map<dynamic, dynamic>) {
    // ✅ CONVERT DARI Map<dynamic, dynamic> KE Map<String, dynamic>
    return Map<String, dynamic>.from(data);
  } else {
    print('⚠️ Unknown data type: ${data.runtimeType}');
    return {};
  }
}

List<Map<String, dynamic>> _extractRiwayatSimple(Map<String, dynamic> rawData) {
  final List<Map<String, dynamic>> allRiwayat = [];
  
  print('🔧 === EKSTRAK RIWAYAT - METHOD SIMPLE ===');
  
  try {
    // ✅ 1. EKSTRAK DARI POKOK
    if (rawData['pokok'] is List && (rawData['pokok'] as List).isNotEmpty) {
      final pokokData = (rawData['pokok'] as List)[0];
      if (pokokData is Map && pokokData['history_debet'] is List) {
        final history = pokokData['history_debet'] as List;
        print('💰 Found ${history.length} history in POKOK');
        
        for (var item in history) {
          if (item is Map) {
            final parsed = _parseHistoryItemSimple(item, 'pokok');
            if (parsed != null) allRiwayat.add(parsed);
          }
        }
      }
    }
    
    // ✅ 2. EKSTRAK DARI WAJIB
    if (rawData['wajib'] is List && (rawData['wajib'] as List).isNotEmpty) {
      final wajibData = (rawData['wajib'] as List)[0];
      if (wajibData is Map && wajibData['history_debet'] is List) {
        final history = wajibData['history_debet'] as List;
        print('💰 Found ${history.length} history in WAJIB');
        
        for (var item in history) {
          if (item is Map) {
            final parsed = _parseHistoryItemSimple(item, 'wajib');
            if (parsed != null) allRiwayat.add(parsed);
          }
        }
      }
    }
    
    // ✅ 3. EKSTRAK DARI SITABUNG
    if (rawData['sitabung'] is List && (rawData['sitabung'] as List).isNotEmpty) {
      final sitabungData = (rawData['sitabung'] as List)[0];
      if (sitabungData is Map && sitabungData['history_debet'] is List) {
        final history = sitabungData['history_debet'] as List;
        print('💰 Found ${history.length} history in SITABUNG');
        
        for (var item in history) {
          if (item is Map) {
            final parsed = _parseHistoryItemSimple(item, 'sitabung');
            if (parsed != null) allRiwayat.add(parsed);
          }
        }
      }
    }
    
    // ✅ SORT BY TANGGAL DESC
    allRiwayat.sort((a, b) {
      final dateA = a['tanggal'] ?? '';
      final dateB = b['tanggal'] ?? '';
      return dateB.compareTo(dateA);
    });
    
    print('🎉 TOTAL RIWAYAT DIEKSTRAK: ${allRiwayat.length}');
    
  } catch (e) {
    print('❌ Error in simple extraction: $e');
  }
  
  return allRiwayat;
}

Map<String, dynamic>? _parseHistoryItemSimple(Map<dynamic, dynamic> item, String jenisTabungan) {
  try {
    // ✅ CONVERT KE MAP YANG AMAN
    final safeItem = Map<String, dynamic>.from(item);
    
    // ✅ EXTRACT DATA DASAR
    final id = safeItem['id']?.toString() ?? 'unknown';
    final tanggal = safeItem['tanggal']?.toString() ?? '';
    final keterangan = safeItem['keterangan']?.toString() ?? 'Transaksi $jenisTabungan';
    final transaksiApi = safeItem['transaksi']?.toString() ?? '';
    final idCustomer = safeItem['id_customer']?.toString() ?? '';
    final idCabang = safeItem['id_m_cabang']?.toString() ?? '';
    final ketData = safeItem['ket_data']?.toString();
    final idTrans = safeItem['id_trans']?.toString() ?? '';
    final created = safeItem['created']?.toString() ?? '';
    final createdId = safeItem['created_id']?.toString() ?? '';
    final updated = safeItem['updated']?.toString() ?? '';
    final updatedId = safeItem['updated_id']?.toString() ?? '';
    
    // ✅ PARSE JUMLAH - PAKAI CARA SIMPLE
    final debetStr = safeItem['debet']?.toString() ?? '0';
    final creditStr = safeItem['credit']?.toString() ?? '0';
    final saldoStr = safeItem['saldo']?.toString() ?? '0';
    
    final debet = int.tryParse(debetStr.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
    final credit = int.tryParse(creditStr.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
    final saldo = int.tryParse(saldoStr.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
    
    // ✅ TENTUKAN JENIS TRANSAKSI
    final isSetoran = debet > 0;
    final jumlah = isSetoran ? debet : credit;
    
    // ✅ SKIP JIKA JUMLAH 0
    if (jumlah == 0) {
      print('⚠️ Skip transaksi dengan jumlah 0: $id');
      return null;
    }
    
    // ✅ TENTUKAN APAKAH BISA UPLOAD BUKTI
    final canUploadBukti = isSetoran && 
        jenisTabungan != 'pokok' && 
        !_uploadedBuktiIds.contains(id);
    
    // ✅ TENTUKAN STATUS BUKTI
    final hasBukti = _uploadedBuktiIds.contains(id);
    
    // ✅ TENTUKAN STATUS VERIFIKASI
    String statusVerifikasi = 'completed';
    if (hasBukti) {
      statusVerifikasi = 'menunggu_verifikasi';
    }
    
    // ✅ FORMAT TANGGAL UNTUK DISPLAY
    final tanggalDisplay = _formatTanggal(tanggal);
    
    // ✅ BUAT DATA TRANSAKSI LENGKAP
    final parsedData = {
      // ✅ IDENTITAS DASAR
      'id': id,
      'id_customer': idCustomer,
      'id_cabang': idCabang,
      'id_trans': idTrans,
      
      // ✅ INFORMASI TRANSAKSI
      'tanggal': tanggal,
      'tanggal_display': tanggalDisplay,
      'jenis_tabungan': jenisTabungan,
      'keterangan': keterangan,
      'ket_data': ketData,
      'transaksi_api': transaksiApi,
      
      // ✅ DATA KEUANGAN
      'debet': debet,
      'credit': credit,
      'jumlah': isSetoran ? jumlah : -jumlah,
      'saldo': saldo,
      'is_setoran': isSetoran,
      'tipe': isSetoran ? 'debet' : 'credit',
      
      // ✅ JENIS TRANSAKSI
      'jenis_transaksi': _getJenisTransaksiFromApi(transaksiApi, isSetoran),
      
      // ✅ STATUS BUKTI & UPLOAD
      'can_upload_bukti': canUploadBukti,
      'has_bukti': hasBukti,
      'status_verifikasi': statusVerifikasi,
      'bukti_uploaded_at': hasBukti ? DateTime.now().toString() : null,
      
      // ✅ STATUS LAINNYA
      'is_saldo': false,
      'status': 'completed',
      
      // ✅ TIMESTAMP
      'created': created,
      'created_id': createdId,
      'updated': updated,
      'updated_id': updatedId,
      
      // ✅ DATA ASLI DARI API
      'api_data': safeItem,
      
      // ✅ DEBUG INFO
      'parsed_at': DateTime.now().toString(),
      'parsed_by': 'RiwayatTabunganScreen',
    };
    
    print('✅ BERHASIL PARSED: $jenisTabungan - ${parsedData['jenis_transaksi']} - ${_formatCurrency(jumlah)} - Bukti: $hasBukti');
    
    return parsedData;
    
  } catch (e) {
    print('❌ Error parsing simple item: $e');
    print('   Item data: $item');
    return null;
  }
}

// ✅ METHOD BARU: EKSTRAK LANGSUNG TANPA PERDULI NORMALIZATION
List<Map<String, dynamic>> _extractRiwayatFromRawData(dynamic rawData) {
  final List<Map<String, dynamic>> riwayatList = [];
  
  print('🔧 === EKSTRAK RIWAYAT - METHOD BARU ===');
  
  // ✅ DEBUG SEBELUM PROSES
  _debugBeforeAnyProcessing(rawData);
  
  try {
    final safeData = _convertToStringDynamicMap(rawData);
    
    // ✅ PAKSA EKSTRAK DARI SETIAP JENIS
    final types = ['pokok', 'wajib', 'sitabung', 'sukarela', 'siumna', 'siquna'];
    
    for (var jenis in types) {
      if (safeData.containsKey(jenis)) {
        final data = safeData[jenis];
        print('💰 Processing $jenis: ${data.runtimeType}');
        
        if (data is List) {
          print('✅ $jenis is List with ${data.length} items');
          
          for (var item in data) {
            final safeItem = _convertToSafeMap(item);
            if (safeItem != null && safeItem.containsKey('history_debet')) {
              final history = safeItem['history_debet'];
              
              if (history is List) {
                print('🎯 Found ${history.length} history items in $jenis');
                
                for (var historyItem in history) {
                  final transaksi = _parseHistoryItem(historyItem, jenis);
                  if (transaksi != null) {
                    riwayatList.add(transaksi);
                  }
                }
              }
            }
          }
        }
      }
    }
    
  } catch (e) {
    print('❌ Extraction error: $e');
  }
  
  print('🎉 TOTAL EXTRACTED: ${riwayatList.length}');
  return riwayatList;
}

// ✅ METHOD NORMALIZE TERPISAH
Map<String, dynamic> _normalizeSaldoData(dynamic rawData) {
  final Map<String, dynamic> normalized = {};
  
  try {
    final safeData = _convertToStringDynamicMap(rawData);
    
    // ✅ NORMALIZE POKOK
    if (safeData.containsKey('pokok')) {
      final pokok = safeData['pokok'];
      if (pokok is List && pokok.isNotEmpty) {
        final first = pokok[0];
        final safeFirst = _convertToSafeMap(first);
        if (safeFirst != null) {
          normalized['pokok'] = _parseValue(safeFirst['saldo']);
        }
      }
    }
    
    // ✅ NORMALIZE WAJIB
    if (safeData.containsKey('wajib')) {
      final wajib = safeData['wajib'];
      if (wajib is List && wajib.isNotEmpty) {
        final first = wajib[0];
        final safeFirst = _convertToSafeMap(first);
        if (safeFirst != null) {
          normalized['wajib'] = _parseValue(safeFirst['saldo']);
        }
      }
    }
    
    // ✅ NORMALIZE SITABUNG
    if (safeData.containsKey('sitabung')) {
      final sitabung = safeData['sitabung'];
      if (sitabung is List && sitabung.isNotEmpty) {
        final first = sitabung[0];
        final safeFirst = _convertToSafeMap(first);
        if (safeFirst != null) {
          normalized['sitabung'] = _parseValue(safeFirst['saldo']);
        }
      }
    }
    
    // ✅ NORMALIZE LAINNYA
    final otherTypes = ['sukarela', 'siumna', 'siquna'];
    for (var type in otherTypes) {
      if (safeData.containsKey(type)) {
        final typeData = safeData[type];
        if (typeData is List && typeData.isNotEmpty) {
          final first = typeData[0];
          final safeFirst = _convertToSafeMap(first);
          if (safeFirst != null) {
            normalized[type] = _parseValue(safeFirst['saldo']);
          }
        } else if (typeData == null) {
          normalized[type] = 0;
        }
      } else {
        normalized[type] = 0;
      }
    }
    
    // ✅ HITUNG TOTAL
    int total = 0;
    for (var key in normalized.keys) {
      if (key != 'saldo') {
        total += (normalized[key] as int? ?? 0);
      }
    }
    normalized['saldo'] = total;
    
  } catch (e) {
    print('❌ Error normalizing saldo data: $e');
  }
  
  return normalized;
}

// ✅ HELPER: CONVERT DYNAMIC KE MAP<String, dynamic> YANG AMAN
Map<String, dynamic>? _convertToSafeMap(dynamic data) {
  try {
    if (data is Map<String, dynamic>) {
      return data;
    } else if (data is Map<dynamic, dynamic>) {
      return Map<String, dynamic>.from(data);
    } else {
      print('⚠️ Cannot convert to safe map: ${data.runtimeType}');
      return null;
    }
  } catch (e) {
    print('❌ Error converting to safe map: $e');
    return null;
  }
}

// ✅ HELPER: CONVERT LIST ITEM KE MAP YANG AMAN
List<Map<String, dynamic>> _convertListToSafeMaps(List<dynamic> list) {
  final List<Map<String, dynamic>> safeList = [];
  
  for (var item in list) {
    final safeItem = _convertToSafeMap(item);
    if (safeItem != null) {
      safeList.add(safeItem);
    }
  }
  
  return safeList;
}

Map<String, dynamic> extractRiwayatFromSaldo(Map<String, dynamic> rawData) {
  List<Map<String, dynamic>> allRiwayat = [];
  
  print('🔍 === EKSTRAK RIWAYAT DARI RAW DATA ===');
  print('📁 Raw data keys: ${rawData.keys}');
  
  // Process pokok
  if (rawData['pokok'] != null && rawData['pokok'] is List) {
    print('💰 Processing pokok...');
    var pokokList = rawData['pokok'] as List;
    if (pokokList.isNotEmpty) {
      var pokokData = pokokList[0];
      if (pokokData['history_debet'] is List) {
        var history = pokokData['history_debet'] as List;
        for (var item in history) {
          var riwayat = Map<String, dynamic>.from(item);
          riwayat['jenis_tabungan'] = 'POKOK';
          allRiwayat.add(riwayat);
        }
        print('✅ Pokok: ${history.length} riwayat');
      }
    }
  }
  
  // Process wajib
  if (rawData['wajib'] != null && rawData['wajib'] is List) {
    print('💰 Processing wajib...');
    var wajibList = rawData['wajib'] as List;
    if (wajibList.isNotEmpty) {
      var wajibData = wajibList[0];
      if (wajibData['history_debet'] is List) {
        var history = wajibData['history_debet'] as List;
        for (var item in history) {
          var riwayat = Map<String, dynamic>.from(item);
          riwayat['jenis_tabungan'] = 'WAJIB';
          allRiwayat.add(riwayat);
        }
        print('✅ Wajib: ${history.length} riwayat');
      }
    }
  }
  
  // Process sitabung
  if (rawData['sitabung'] != null && rawData['sitabung'] is List) {
    print('💰 Processing sitabung...');
    var sitabungList = rawData['sitabung'] as List;
    if (sitabungList.isNotEmpty) {
      var sitabungData = sitabungList[0];
      if (sitabungData['history_debet'] is List) {
        var history = sitabungData['history_debet'] as List;
        for (var item in history) {
          var riwayat = Map<String, dynamic>.from(item);
          riwayat['jenis_tabungan'] = 'SITABUNG';
          allRiwayat.add(riwayat);
        }
        print('✅ Sitabung: ${history.length} riwayat');
      }
    }
  }
  
  // Sort by tanggal descending
  allRiwayat.sort((a, b) {
    String dateA = a['tanggal'] ?? '';
    String dateB = b['tanggal'] ?? '';
    return dateB.compareTo(dateA);
  });
  
  print('🎉 TOTAL RIWAYAT: ${allRiwayat.length}');
  
  return {
    'riwayat': allRiwayat,
    'total': allRiwayat.length,
  };
}

// ✅ PERBAIKAN: PARSE HISTORY ITEM - HANDLE DATA REAL DARI API
Map<String, dynamic>? _parseHistoryItem(dynamic item, String jenisTabungan) {
  try {
    // ✅ CONVERT ITEM KE MAP YANG AMAN
    final safeItem = _convertToSafeMap(item);
    if (safeItem == null) {
      print('❌ Tidak bisa parse item: ${item.runtimeType}');
      return null;
    }
    
    // ✅ DEBUG: CEK DATA ASLI
    print('🔍 Data asli dari API:');
    print('   - id: ${safeItem['id']}');
    print('   - tanggal: ${safeItem['tanggal']}');
    print('   - transaksi: ${safeItem['transaksi']}');
    print('   - debet: ${safeItem['debet']}');
    print('   - credit: ${safeItem['credit']}');
    print('   - saldo: ${safeItem['saldo']}');
    
    final id = safeItem['id']?.toString() ?? 'unknown';
    final tanggal = safeItem['tanggal']?.toString();
    final keterangan = safeItem['keterangan']?.toString() ?? 'Transaksi $jenisTabungan';
    final jenisTransaksiApi = safeItem['transaksi']?.toString() ?? jenisTabungan.toUpperCase();
    
    // ✅ PERBAIKAN PENTING: HANDLE STRING NUMBER DARI API
    final debetStr = safeItem['debet']?.toString() ?? '0';
    final creditStr = safeItem['credit']?.toString() ?? '0';
    final saldoStr = safeItem['saldo']?.toString() ?? '0';
    
    // ✅ CLEAN STRING - HAPUS KARAKTER NON-NUMERIC
    final cleanDebet = debetStr.replaceAll(RegExp(r'[^\d]'), '');
    final cleanCredit = creditStr.replaceAll(RegExp(r'[^\d]'), '');
    final cleanSaldo = saldoStr.replaceAll(RegExp(r'[^\d]'), '');
    
    final debet = int.tryParse(cleanDebet) ?? 0;
    final credit = int.tryParse(cleanCredit) ?? 0;
    final saldo = int.tryParse(cleanSaldo) ?? 0;
    
    print('💰 Jumlah yang diparsed - Debet: $debet, Credit: $credit, Saldo: $saldo');
    
    // ✅ TENTUKAN JENIS TRANSAKSI
    final isSetoran = debet > 0;
    final jumlah = isSetoran ? debet : credit;
    
    // ✅ SKIP JIKA JUMLAH 0
    if (jumlah == 0) {
      print('⚠️ Skip transaksi dengan jumlah 0: $id');
      return null;
    }
    
    final parsedData = {
      'id': id,
      'tanggal': tanggal ?? DateTime.now().toString(),
      'jenis': jenisTabungan,
      'keterangan': keterangan,
      'jumlah': isSetoran ? jumlah : -jumlah, // Negative untuk penarikan
      'saldo': saldo,
      'tipe': isSetoran ? 'debet' : 'credit',
      'status': 'completed',
      'jenis_tabungan': jenisTabungan,
      'is_saldo': false,
      'can_upload_bukti': isSetoran && jenisTabungan != 'pokok', // Pokok biasanya tidak perlu bukti
      'jenis_transaksi': _getJenisTransaksiFromApi(jenisTransaksiApi, isSetoran),
      'is_setoran': isSetoran,
      'has_bukti': false,
      'api_data': safeItem,
    };
    
    print('✅ BERHASIL PARSED: $jenisTabungan - ${parsedData['jenis_transaksi']} - ${_formatCurrency(jumlah)}');
    
    return parsedData;
  } catch (e) {
    print('❌ Error parsing history item: $e');
    print('   Item data: $item');
    return null;
  }
}


// ✅ DEBUG: CEK DATA MENTAH DARI API
void _debugRawApiData() async {
  try {
    print('🔍 === DEBUG RAW API DATA ===');
    
    final result = await _apiService.getAllSaldo();
    
    if (result['success'] == true) {
      final data = result['data'];
      final safeData = _convertToStringDynamicMap(data);
      
      print('📊 All keys: ${safeData.keys}');
      
      // ✅ CEK STRUKTUR POKOK
      if (safeData.containsKey('pokok')) {
        final pokok = safeData['pokok'];
        print('💰 Pokok structure: ${pokok.runtimeType}');
        
        if (pokok is List) {
          print('💰 Pokok List length: ${pokok.length}');
          if (pokok.isNotEmpty) {
            final first = pokok[0];
            print('💰 First pokok item: $first');
            if (first is Map) {
              print('💰 First pokok keys: ${first.keys}');
              if (first.containsKey('history_debet')) {
                final history = first['history_debet'];
                print('💰 history_debet type: ${history.runtimeType}');
                if (history is List) {
                  print('💰 history_debet length: ${history.length}');
                  if (history.isNotEmpty) {
                    print('💰 First history item: ${history[0]}');
                  }
                }
              }
            }
          }
        }
      }
    }
    
    print('🔍 === DEBUG END ===');
  } catch (e) {
    print('❌ Debug error: $e');
  }
}

// ✅ METHOD BARU: PARSE DATA DARI API getRiwayatTabungan
List<Map<String, dynamic>> _parseRiwayatTabunganData(List<dynamic> apiData) {
  final List<Map<String, dynamic>> parsedData = [];
  
  print('🔧 Processing RIWAYAT TABUNGAN API data structure...');
  print('📊 API Data length: ${apiData.length}');
  
  try {
    for (var item in apiData) {
      if (item is Map<String, dynamic>) {
        final transaksi = item;
        
        // ✅ EXTRACT DATA DARI RESPONSE
        final id = transaksi['id']?.toString() ?? 'unknown';
        final tanggal = transaksi['tanggal']?.toString() ?? DateTime.now().toString();
        final keterangan = transaksi['keterangan']?.toString() ?? 'Transaksi Tabungan';
        final jenisTransaksi = transaksi['transaksi']?.toString() ?? 'TABUNGAN';
        final debet = _parseValue(transaksi['debet']);
        final credit = _parseValue(transaksi['credit']);
        final saldo = _parseValue(transaksi['saldo']);
        
        // ✅ TENTUKAN JENIS TRANSAKSI (SETORAN/PENARIKAN)
        final isSetoran = debet > 0;
        final jumlah = isSetoran ? debet : credit;
        
        // ✅ TENTUKAN JENIS TABUNGAN DARI KETERANGAN/TRANSAKSI
        final jenisTabungan = _detectJenisTabungan(jenisTransaksi, keterangan);
        
        if (jumlah > 0) {
          parsedData.add({
            'id': id,
            'tanggal': tanggal,
            'jenis': jenisTabungan,
            'keterangan': keterangan,
            'jumlah': isSetoran ? jumlah : -jumlah, // Negative untuk penarikan
            'saldo': saldo,
            'tipe': isSetoran ? 'debet' : 'credit',
            'status': 'completed',
            'jenis_tabungan': jenisTabungan,
            'is_saldo': false,
            'can_upload_bukti': isSetoran, // ✅ Hanya setoran yang bisa upload bukti
            'jenis_transaksi': _getJenisTransaksiFromApi(jenisTransaksi, isSetoran),
            'is_setoran': isSetoran,
            'has_bukti': false,
            'api_data': transaksi,
          });
          
          print('✅ Parsed: $jenisTabungan - ${isSetoran ? 'Setoran' : 'Penarikan'} - ${_formatCurrency(jumlah)}');
        }
      }
    }
    
  } catch (e) {
    print('❌ Error parsing riwayat tabungan data: $e');
  }
  
  // ✅ URUTKAN BERDASARKAN TANGGAL (TERBARU DIATAS)
  parsedData.sort((a, b) {
    final dateA = DateTime.tryParse(a['tanggal'] ?? '') ?? DateTime(2000);
    final dateB = DateTime.tryParse(b['tanggal'] ?? '') ?? DateTime(2000);
    return dateB.compareTo(dateA);
  });
  
  print('✅ Total riwayat transactions processed: ${parsedData.length}');
  
  return parsedData;
}

// ✅ DETEKSI JENIS TABUNGAN DARI DATA TRANSAKSI
String _detectJenisTabungan(String jenisTransaksi, String keterangan) {
  final transaksiUpper = jenisTransaksi.toUpperCase();
  final keteranganUpper = keterangan.toUpperCase();
  
  if (transaksiUpper.contains('POKOK') || keteranganUpper.contains('PK/') || keteranganUpper.contains('POKOK')) {
    return 'pokok';
  }
  else if (transaksiUpper.contains('WAJIB') || keteranganUpper.contains('WJ/') || keteranganUpper.contains('WAJIB')) {
    return 'wajib';
  }
  else if (transaksiUpper.contains('SITABUNG') || keteranganUpper.contains('STB/') || keteranganUpper.contains('SITABUNG')) {
    return 'sitabung';
  }
  else if (transaksiUpper.contains('SUKARELA') || keteranganUpper.contains('SUKARELA')) {
    return 'sukarela';
  }
  else if (transaksiUpper.contains('SIUMNA') || keteranganUpper.contains('SIUMNA')) {
    return 'siumna';
  }
  else if (transaksiUpper.contains('SIQUNA') || keteranganUpper.contains('SIQUNA')) {
    return 'siquna';
  }
  else if (transaksiUpper.contains('PENARIKAN')) {
    return 'penarikan';
  }
  else {
    return 'sukarela'; // Default
  }
}

// ✅ LOAD SALDO UNTUK HEADER (TERPISAH DARI RIWAYAT)
Future<void> _loadSaldoData() async {
  try {
    print('💰 Loading saldo data for header...');
    
    final result = await _apiService.getAllSaldo();
    
    if (result['success'] == true) {
      setState(() {
        _saldoData = result['data'] ?? {};
      });
      print('✅ Saldo data loaded: $_saldoData');
    }
  } catch (e) {
    print('❌ Error loading saldo: $e');
  }
}

// ✅ PERBAIKAN: PARSING DATA REAL DARI API getAllSaldo
List<Map<String, dynamic>> _parseTabunganData(Map<String, dynamic> apiData) {
  final List<Map<String, dynamic>> parsedData = [];
  
  print('🔧 Processing REAL API data structure...');
  print('📊 API Data keys: ${apiData.keys}');
  
  try {
    // ✅ PROCESS POKOK TABUNGAN - DATA REAL
    if (apiData.containsKey('pokok') && apiData['pokok'] is List) {
      final pokokList = apiData['pokok'] as List;
      if (pokokList.isNotEmpty) {
        final pokokData = pokokList[0] as Map<String, dynamic>;
        final saldoPokok = _parseValue(pokokData['saldo']);
        final historyDebet = pokokData['history_debet'] as List? ?? [];
        
        print('✅ Processing Pokok - Saldo: $saldoPokok, History: ${historyDebet.length} items');
        
        // ✅ SALDO CURRENT
        parsedData.add({
          'id': 'pokok_current',
          'tanggal': DateTime.now().toString(),
          'jenis': 'pokok',
          'keterangan': 'Saldo Simpanan Pokok',
          'jumlah': saldoPokok,
          'saldo': saldoPokok,
          'tipe': 'saldo',
          'status': 'active',
          'jenis_tabungan': 'pokok',
          'is_saldo': true,
          'can_upload_bukti': false,
          'jenis_transaksi': 'Saldo Pokok',
          'is_setoran': true,
        });
        
        // ✅ HISTORY TRANSAKSI REAL
        for (var history in historyDebet) {
          final transaksi = history as Map<String, dynamic>;
          final isSetoran = (transaksi['debet']?.toString() != '0');
          final jumlah = isSetoran ? 
              _parseValue(transaksi['debet']) : 
              _parseValue(transaksi['credit']);
          
          if (jumlah > 0) {
            parsedData.add({
              'id': transaksi['id']?.toString() ?? 'pokok_${DateTime.now().millisecondsSinceEpoch}',
              'tanggal': transaksi['tanggal']?.toString() ?? DateTime.now().toString(),
              'jenis': 'pokok',
              'keterangan': transaksi['keterangan']?.toString() ?? 'Transaksi Pokok',
              'jumlah': jumlah,
              'saldo': _parseValue(transaksi['saldo']),
              'tipe': isSetoran ? 'debet' : 'credit',
              'status': 'completed',
              'jenis_tabungan': 'pokok',
              'is_saldo': false,
              'can_upload_bukti': isSetoran, // ✅ Hanya setoran yang bisa upload bukti
              'jenis_transaksi': _getJenisTransaksiFromApi(transaksi['transaksi']?.toString(), isSetoran),
              'is_setoran': isSetoran,
              'has_bukti': false, // Default belum ada bukti
              'api_data': transaksi, // Simpan data original untuk referensi
            });
          }
        }
      }
    }
    
    // ✅ PROCESS WAJIB TABUNGAN - DATA REAL
    if (apiData.containsKey('wajib') && apiData['wajib'] is List) {
      final wajibList = apiData['wajib'] as List;
      if (wajibList.isNotEmpty) {
        final wajibData = wajibList[0] as Map<String, dynamic>;
        final saldoWajib = _parseValue(wajibData['saldo']);
        final historyDebet = wajibData['history_debet'] as List? ?? [];
        
        print('✅ Processing Wajib - Saldo: $saldoWajib, History: ${historyDebet.length} items');
        
        // ✅ SALDO CURRENT
        parsedData.add({
          'id': 'wajib_current',
          'tanggal': DateTime.now().toString(),
          'jenis': 'wajib',
          'keterangan': 'Saldo Simpanan Wajib',
          'jumlah': saldoWajib,
          'saldo': saldoWajib,
          'tipe': 'saldo',
          'status': 'active',
          'jenis_tabungan': 'wajib',
          'is_saldo': true,
          'can_upload_bukti': false,
          'jenis_transaksi': 'Saldo Wajib',
          'is_setoran': true,
        });
        
        // ✅ HISTORY TRANSAKSI REAL
        for (var history in historyDebet) {
          final transaksi = history as Map<String, dynamic>;
          final isSetoran = (transaksi['debet']?.toString() != '0');
          final jumlah = isSetoran ? 
              _parseValue(transaksi['debet']) : 
              _parseValue(transaksi['credit']);
          
          if (jumlah > 0) {
            parsedData.add({
              'id': transaksi['id']?.toString() ?? 'wajib_${DateTime.now().millisecondsSinceEpoch}',
              'tanggal': transaksi['tanggal']?.toString() ?? DateTime.now().toString(),
              'jenis': 'wajib',
              'keterangan': transaksi['keterangan']?.toString() ?? 'Transaksi Wajib',
              'jumlah': jumlah,
              'saldo': _parseValue(transaksi['saldo']),
              'tipe': isSetoran ? 'debet' : 'credit',
              'status': 'completed',
              'jenis_tabungan': 'wajib',
              'is_saldo': false,
              'can_upload_bukti': isSetoran, // ✅ Hanya setoran yang bisa upload bukti
              'jenis_transaksi': _getJenisTransaksiFromApi(transaksi['transaksi']?.toString(), isSetoran),
              'is_setoran': isSetoran,
              'has_bukti': false,
              'api_data': transaksi,
            });
          }
        }
      }
    }
    
    // ✅ PROCESS SITABUNG - DATA REAL
    if (apiData.containsKey('sitabung') && apiData['sitabung'] is List) {
      final sitabungList = apiData['sitabung'] as List;
      if (sitabungList.isNotEmpty) {
        final sitabungData = sitabungList[0] as Map<String, dynamic>;
        final saldoSitabung = _parseValue(sitabungData['saldo']);
        final historyDebet = sitabungData['history_debet'] as List? ?? [];
        
        print('✅ Processing SiTabung - Saldo: $saldoSitabung, History: ${historyDebet.length} items');
        
        // ✅ SALDO CURRENT
        parsedData.add({
          'id': 'sitabung_current',
          'tanggal': DateTime.now().toString(),
          'jenis': 'sitabung',
          'keterangan': 'Saldo SiTabung',
          'jumlah': saldoSitabung,
          'saldo': saldoSitabung,
          'tipe': 'saldo',
          'status': 'active',
          'jenis_tabungan': 'sitabung',
          'is_saldo': true,
          'can_upload_bukti': false,
          'jenis_transaksi': 'Saldo SiTabung',
          'is_setoran': true,
        });
        
        // ✅ HISTORY TRANSAKSI REAL
        for (var history in historyDebet) {
          final transaksi = history as Map<String, dynamic>;
          final isSetoran = (transaksi['transaksi']?.toString() == 'SITABUNG');
          final isPenarikan = (transaksi['transaksi']?.toString() == 'PENARIKAN_SITABUNG');
          final jumlah = isSetoran ? 
              _parseValue(transaksi['debet']) : 
              -_parseValue(transaksi['credit']); // Negative untuk penarikan
          
          if (jumlah != 0) {
            parsedData.add({
              'id': transaksi['id']?.toString() ?? 'sitabung_${DateTime.now().millisecondsSinceEpoch}',
              'tanggal': transaksi['tanggal']?.toString() ?? DateTime.now().toString(),
              'jenis': 'sitabung',
              'keterangan': transaksi['keterangan']?.toString() ?? 'Transaksi SiTabung',
              'jumlah': jumlah,
              'saldo': _parseValue(transaksi['saldo']),
              'tipe': isSetoran ? 'debet' : 'credit',
              'status': 'completed',
              'jenis_tabungan': 'sitabung',
              'is_saldo': false,
              'can_upload_bukti': isSetoran, // ✅ Hanya setoran yang bisa upload bukti
              'jenis_transaksi': _getJenisTransaksiFromApi(transaksi['transaksi']?.toString(), isSetoran),
              'is_setoran': isSetoran,
              'has_bukti': false,
              'api_data': transaksi,
            });
          }
        }
      }
    }
    
    // ✅ PROCESS JENIS TABUNGAN LAINNYA (sukarela, siumna, siquna)
    final otherTypes = ['sukarela', 'siumna', 'siquna'];
    for (var type in otherTypes) {
      if (apiData.containsKey(type) && apiData[type] != null) {
        if (apiData[type] is List) {
          final typeList = apiData[type] as List;
          if (typeList.isNotEmpty) {
            final typeData = typeList[0] as Map<String, dynamic>;
            final saldo = _parseValue(typeData['saldo']);
            final historyDebet = typeData['history_debet'] as List? ?? [];
            
            print('✅ Processing $type - Saldo: $saldo, History: ${historyDebet.length} items');
            
            // ✅ SALDO CURRENT
            if (saldo > 0) {
              parsedData.add({
                'id': '${type}_current',
                'tanggal': DateTime.now().toString(),
                'jenis': type,
                'keterangan': 'Saldo ${_getTabunganName(type)}',
                'jumlah': saldo,
                'saldo': saldo,
                'tipe': 'saldo',
                'status': 'active',
                'jenis_tabungan': type,
                'is_saldo': true,
                'can_upload_bukti': false,
                'jenis_transaksi': 'Saldo ${_getTabunganName(type)}',
                'is_setoran': true,
              });
            }
            
            // ✅ HISTORY TRANSAKSI REAL
            for (var history in historyDebet) {
              final transaksi = history as Map<String, dynamic>;
              final isSetoran = (transaksi['debet']?.toString() != '0');
              final jumlah = isSetoran ? 
                  _parseValue(transaksi['debet']) : 
                  _parseValue(transaksi['credit']);
              
              if (jumlah > 0) {
                parsedData.add({
                  'id': transaksi['id']?.toString() ?? '${type}_${DateTime.now().millisecondsSinceEpoch}',
                  'tanggal': transaksi['tanggal']?.toString() ?? DateTime.now().toString(),
                  'jenis': type,
                  'keterangan': transaksi['keterangan']?.toString() ?? 'Transaksi ${_getTabunganName(type)}',
                  'jumlah': jumlah,
                  'saldo': _parseValue(transaksi['saldo']),
                  'tipe': isSetoran ? 'debet' : 'credit',
                  'status': 'completed',
                  'jenis_tabungan': type,
                  'is_saldo': false,
                  'can_upload_bukti': isSetoran,
                  'jenis_transaksi': _getJenisTransaksiFromApi(transaksi['transaksi']?.toString(), isSetoran),
                  'is_setoran': isSetoran,
                  'has_bukti': false,
                  'api_data': transaksi,
                });
              }
            }
          }
        }
      }
    }
    
  } catch (e) {
    print('❌ Error parsing real tabungan data: $e');
  }
  
  // ✅ URUTKAN BERDASARKAN TANGGAL (TERBARU DIATAS)
  parsedData.sort((a, b) {
    final dateA = DateTime.tryParse(a['tanggal'] ?? '') ?? DateTime(2000);
    final dateB = DateTime.tryParse(b['tanggal'] ?? '') ?? DateTime(2000);
    return dateB.compareTo(dateA);
  });
  
  print('✅ Total transactions processed: ${parsedData.length}');
  print('📊 Processed data summary:');
  for (var item in parsedData) {
    final jenis = item['jenis_tabungan'] ?? 'unknown';
    final transaksi = item['jenis_transaksi'] ?? 'unknown';
    final jumlah = item['jumlah'] ?? 0;
    final canUpload = item['can_upload_bukti'] ?? false;
    final isSaldo = item['is_saldo'] ?? false;
    
    if (isSaldo) {
      print('   - 💰 $jenis: $transaksi (${_formatCurrency(jumlah)})');
    } else {
      print('   - 📄 $jenis: $transaksi (${_formatCurrency(jumlah)}) - Upload: $canUpload');
    }
  }
  
  return parsedData;
}

Future<void> _uploadBuktiPembayaran(Map<String, dynamic> transaksi) async {
  print('🟡 === UPLOAD BUKTI PEMBAYARAN START ===');
  print('🟡 Transaksi ID: ${transaksi['id']}');
  print('🟡 Jenis: ${transaksi['jenis_transaksi']}');
  print('🟡 Jumlah: ${_formatCurrency(transaksi['jumlah'])}');
  print('🟡 Tanggal: ${transaksi['tanggal_display']}');
  print('🟡 Can Upload: ${transaksi['can_upload_bukti']}');
  print('🟡 Has Bukti: ${transaksi['has_bukti']}');
  print('🟡 API Data: ${transaksi.containsKey('api_data') ? 'EXISTS' : 'MISSING'}');
  
  // ✅ VALIDASI SEBELUM UPLOAD
  if (_isUploadingBukti) {
    print('❌ Sedang proses upload lainnya');
    _showErrorSnackBar('Sedang mengupload bukti lainnya');
    return;
  }
  
  if (!transaksi['can_upload_bukti']) {
    print('❌ Transaksi ini tidak bisa upload bukti');
    _showErrorSnackBar('Transaksi ini tidak memerlukan bukti pembayaran');
    return;
  }
  
  if (transaksi['has_bukti']) {
    print('❌ Bukti sudah pernah diupload');
    _showErrorSnackBar('Bukti pembayaran sudah diupload sebelumnya');
    return;
  }
  
  try {
    // ✅ SET STATE UPLOADING
    setState(() {
      _selectedTransaksiForUpload = transaksi;
      _isUploadingBukti = true;
      _uploadErrorBukti = null;
    });

    // ✅ PILIH SUMBER GAMBAR
    print('📸 Memilih sumber gambar...');
    final imageSource = await _showImageSourceDialog();
    if (imageSource == null) {
      print('❌ User membatalkan pemilihan sumber');
      setState(() => _isUploadingBukti = false);
      return;
    }

    // ✅ PICK IMAGE
    print('🖼️ Memilih gambar dari ${imageSource == ImageSource.camera ? 'KAMERA' : 'GALERI'}...');
    final XFile? pickedFile = await _imagePicker.pickImage(
      source: imageSource,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );

    if (pickedFile == null) {
      print('❌ User tidak memilih gambar');
      setState(() => _isUploadingBukti = false);
      return;
    }

    final file = File(pickedFile.path);
    print('✅ Gambar dipilih: ${file.path}');
    
    // ✅ VALIDASI FILE
    print('🔍 Validasi file...');
    final validation = await FileValidator.validateBuktiTransfer(file.path);
    if (!validation['valid']) {
      print('❌ Validasi file gagal: ${validation['message']}');
      await _showValidationErrorDialog();
      setState(() => _isUploadingBukti = false);
      return;
    }
    print('✅ Validasi file berhasil');

    // ✅ KONFIRMASI UPLOAD
    print('❓ Menampilkan dialog konfirmasi...');
    final shouldUpload = await _showUploadConfirmationDialog(file);
    if (!shouldUpload) {
      print('❌ User membatalkan upload');
      setState(() => _isUploadingBukti = false);
      return;
    }
    print('✅ User menyetujui upload');

    // ✅ UPLOAD KE SERVER
    _showUploadingDialog('Mengupload Bukti Pembayaran...');
    print('🚀 Memulai upload ke server...');

    final result = await _apiService.setBuktiPhoto(
      filePath: file.path,
    );

    if (!mounted) {
      print('❌ Screen tidak mounted, cancel proses');
      return;
    }
    
    // ✅ TUTUP DIALOG LOADING
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    setState(() => _isUploadingBukti = false);

    // ✅ HANDLE RESPONSE
    if (result['success'] == true) {
      print('🎉 UPLOAD BUKTI SUKSES UNTUK TRANSAKSI REAL');
      print('📊 Response: ${result['message']}');
      
      // ✅ SIMPAN STATUS KE LOCAL STORAGE
      await _saveBuktiStatus(transaksi['id']);
      
      // ✅ UPDATE STATE UNTUK REFRESH UI
      setState(() {
        // Update transaksi yang sedang dilihat
        transaksi['has_bukti'] = true;
        transaksi['status_verifikasi'] = 'menunggu_verifikasi';
        transaksi['bukti_uploaded_at'] = DateTime.now().toString();
        transaksi['can_upload_bukti'] = false;
        
        // Update di list riwayat
        final index = _riwayatTabungan.indexWhere((t) => t['id'] == transaksi['id']);
        if (index != -1) {
          _riwayatTabungan[index] = {
            ..._riwayatTabungan[index],
            'has_bukti': true,
            'status_verifikasi': 'menunggu_verifikasi',
            'bukti_uploaded_at': DateTime.now().toString(),
            'can_upload_bukti': false,
          };
        }
      });
      
      // ✅ TAMPILKAN SUKSES
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('✅ ${result['message'] ?? 'Bukti pembayaran berhasil diupload!'}'),
              const SizedBox(height: 4),
              Text(
                'Transaksi: ${transaksi['jenis_transaksi']}',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
              Text(
                'Status: Menunggu verifikasi',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
      
      // ✅ LOG SUKSES
      print('''
      🎉 UPLOAD BUKTI BERHASIL:
      - Transaksi: ${transaksi['id']}
      - Jenis: ${transaksi['jenis_transaksi']} 
      - Jumlah: ${_formatCurrency(transaksi['jumlah'])}
      - Status: Menunggu verifikasi
      - Waktu: ${DateTime.now()}
      ''');
      
    } else {
      // ✅ HANDLE ERROR RESPONSE
      print('❌ UPLOAD BUKTI GAGAL: ${result['message']}');
      
      if (result['token_expired'] == true) {
        print('🔑 Token expired, redirect ke login');
        _showTokenExpiredDialog();
        return;
      }
      
      _showErrorSnackBar(result['message'] ?? 'Gagal upload bukti pembayaran');
    }

  } catch (e) {
    // ✅ HANDLE EXCEPTION
    print('❌ Upload error: $e');
    print('🔄 Membersihkan state...');
    
    if (mounted) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      setState(() => _isUploadingBukti = false);
    }
    
    _showErrorSnackBar('Terjadi kesalahan saat upload: $e');
    
    // ✅ LOG ERROR DETAIL
    print('''
    ❌ UPLOAD BUKTI ERROR:
    - Transaksi: ${transaksi['id']}
    - Error: $e
    - StackTrace: ${StackTrace.current}
    ''');
  } finally {
    // ✅ RESET STATE UPLOADING
    if (mounted) {
      setState(() {
        _isUploadingBukti = false;
        _selectedTransaksiForUpload = null;
      });
    }
    print('🔚 === UPLOAD BUKTI PROCESS END ===');
  }
}

// ✅ FORMAT TANGGAL UNTUK DISPLAY
String _formatTanggal(String? tanggal) {
  if (tanggal == null || tanggal.isEmpty) return '-';
  
  try {
    final dateTime = DateTime.parse(tanggal);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final transactionDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    if (transactionDate == today) {
      return 'Hari ini';
    } else if (transactionDate == yesterday) {
      return 'Kemarin';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  } catch (e) {
    return tanggal.length > 10 ? tanggal.substring(0, 10) : tanggal;
  }
}

// ✅ SHOW UPLOADING DIALOG (DIPERBAIKI)
void _showUploadingDialog(String message) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: SizedBox(
          height: 140,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.green[700]),
              const SizedBox(height: 20),
              Text(
                message,
                style: TextStyle(
                  color: Colors.green[800],
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Harap tunggu sebentar...',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Transaksi: ${_selectedTransaksiForUpload?['jenis_transaksi'] ?? '-'}',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ✅ BENAR - tanpa parameter tambahan
Future<void> _showValidationErrorDialog() async {
  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('File Tidak Valid'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('File yang dipilih tidak memenuhi persyaratan.'),
          const SizedBox(height: 16),
          
          const Text(
            'Persyaratan File:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('• Format: ${FileValidator.getAllowedExtensions().join(', ')}'),
          Text('• Ukuran min: ${(FileValidator.getMinFileSize() / 1024).toStringAsFixed(0)} KB'),
          Text('• Ukuran max: ${(FileValidator.getMaxFileSize() / 1024 / 1024).toStringAsFixed(0)} MB'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            // Coba lagi dengan transaksi yang sama
            if (_selectedTransaksiForUpload != null) {
              _uploadBuktiPembayaran(_selectedTransaksiForUpload!);
            }
          },
          child: const Text('Coba File Lain'),
        ),
      ],
    ),
  );
}

// ✅ UPDATE: DIALOG KONFIRMASI UPLOAD (1 PARAMETER)
Future<bool> _showUploadConfirmationDialog(File file) async {
  final fileInfo = await FileValidator.getFileInfo(file.path);
  
  return await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Upload Bukti Pembayaran?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Preview image
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: DecorationImage(
                image: FileImage(file),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Apakah Anda yakin ingin mengupload bukti pembayaran ini?'),
          const SizedBox(height: 8),
          
          // File info
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('File: ${fileInfo['filename']}'),
                Text('Size: ${fileInfo['size_kb']} KB'),
                Text('Type: ${fileInfo['mime_type']}'),
                Text('Format: ${fileInfo['extension']}'),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              '📁 Sistem akan mengupload file ini ke server sebagai bukti pembayaran.',
              style: TextStyle(fontSize: 11, color: Colors.blue),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
          ),
          child: const Text('Upload Sekarang'),
        ),
      ],
    ),
  ) ?? false;
}

  // ✅ DIALOG PILIHAN SUMBER GAMBAR
  Future<ImageSource?> _showImageSourceDialog() async {
    return await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pilih Sumber Gambar'),
        content: const Text('Pilih sumber untuk mengambil bukti pembayaran'),
        actions: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context, ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Kamera'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context, ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Galeri'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ✅ TOKEN EXPIRED DIALOG
  void _showTokenExpiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Sesi Berakhir'),
        content: const Text('Sesi login Anda telah berakhir. Silakan login kembali untuk melanjutkan.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
              Navigator.pushNamedAndRemoveUntil(
                context, 
                '/login', 
                (route) => false
              );
            },
            child: const Text('Login Kembali'),
          ),
        ],
      ),
    );
  }

// ✅ UPDATE ERROR HANDLING
void _showErrorSnackBar(String message) {
  if (!mounted) return;
  
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: Colors.red,
      duration: const Duration(seconds: 4),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

  // ✅ HELPER METHODS
  int _parseValue(dynamic value) {
    try {
      if (value == null) return 0;
      
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) {
        final cleanAmount = value.replaceAll(RegExp(r'[^\d]'), '');
        return int.tryParse(cleanAmount) ?? 0;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  String _getJenisTransaksi(String transaksi, bool isSetoran) {
    if (transaksi.isEmpty) {
      return isSetoran ? 'Setoran' : 'Penarikan';
    }
    
    switch (transaksi.toLowerCase()) {
      case 'pokok': return 'Setoran Pokok';
      case 'wajib': return 'Setoran Wajib';
      case 'sitabung': return 'Setoran SiTabung';
      case 'penarikan_sitabung': return 'Penarikan SiTabung';
      case 'sukarela': return 'Setoran Sukarela';
      default: return transaksi;
    }
  }

  // ✅ GETTERS
  List<Map<String, dynamic>> get _filteredRiwayat {
    if (_selectedTabunganType == 'semua') {
      return _riwayatTabungan;
    }
    return _riwayatTabungan.where((transaksi) {
      final jenis = transaksi['jenis_tabungan']?.toString() ?? '';
      return jenis == _selectedTabunganType;
    }).toList();
  }

// ✅ GET CURRENT SALDO DARI DATA YANG SUDAH DIPARSE
int _getCurrentSaldo(String jenisTabungan) {
  try {
    if (jenisTabungan == 'semua') {
      int total = 0;
      for (var type in _tabunganTypes) {
        final typeId = type['id'] as String;
        if (typeId != 'semua') {
          final saldo = _getSaldoFromApiData(typeId);
          total += saldo;
        }
      }
      return total;
    }
    
    return _getSaldoFromApiData(jenisTabungan);
  } catch (e) {
    return 0;
  }
}

// ✅ GET SALDO DARI _saldoData - DIPERBAIKI
int _getSaldoFromApiData(String jenisTabungan) {
  try {
    if (_saldoData.containsKey(jenisTabungan)) {
      final data = _saldoData[jenisTabungan];
      
      if (data is int) {
        return data;
      } else if (data is List && data.isNotEmpty) {
        // ✅ HANDLE LIST DATA DENGAN AMAN
        final firstItem = data[0];
        final safeItem = _convertToSafeMap(firstItem);
        if (safeItem != null) {
          final saldo = safeItem['saldo'];
          return _parseValue(saldo);
        }
      } else if (data is String) {
        return _parseValue(data);
      }
    }
    return 0;
  } catch (e) {
    print('❌ Error getting saldo for $jenisTabungan: $e');
    return 0;
  }
}

  String _formatCurrency(int amount) {
    try {
      if (amount == 0) return 'Rp 0';
      
      final isNegative = amount < 0;
      final absoluteAmount = amount.abs();
      
      final formatted = 'Rp ${absoluteAmount.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]}.',
      )}';
      
      return isNegative ? '-$formatted' : formatted;
    } catch (e) {
      return 'Rp 0';
    }
  }

  Color _getAmountColor(int amount) {
    return amount >= 0 ? Colors.green : Colors.red;
  }

  Color _getTabunganColor(String jenis) {
    final jenisStr = jenis.toString().toLowerCase();
    switch (jenisStr) {
      case 'pokok': return Colors.green;
      case 'wajib': return Colors.orange;
      case 'sitabung': return Colors.blue;
      case 'sukarela': return Colors.red;
      case 'siumna': return Colors.teal;
      case 'siquna': return Colors.purple;
      default: return Colors.grey;
    }
  }

  String _getTabunganName(String jenis) {
    final jenisStr = jenis.toString().toLowerCase();
    switch (jenisStr) {
      case 'pokok': return 'Pokok';
      case 'wajib': return 'Wajib';
      case 'sitabung': return 'SiTabung';
      case 'sukarela': return 'Sukarela';
      case 'siumna': return 'Siumna';
      case 'siquna': return 'Siquna';
      default: return jenisStr.isNotEmpty ? jenisStr : 'Tabungan';
    }
  }

// ✅ STATUS VERIFIKASI UNTUK DATA REAL
Widget _getStatusVerifikasi(Map<String, dynamic> transaksi) {
  final isSaldo = transaksi['is_saldo'] == true;
  final hasBukti = transaksi['has_bukti'] == true;
  final statusVerifikasi = transaksi['status_verifikasi']?.toString() ?? 'completed';

  if (isSaldo) {
    return _buildStatusChip('Saldo Aktif', Colors.green, Icons.verified);
  }

  // ✅ JIKA SUDAH UPLOAD BUKTI
  if (hasBukti) {
    switch (statusVerifikasi) {
      case 'menunggu_verifikasi':
        return _buildStatusChip('Menunggu Verifikasi', Colors.orange, Icons.schedule);
      case 'terverifikasi':
        return _buildStatusChip('Terverifikasi', Colors.green, Icons.verified);
      case 'ditolak':
        return _buildStatusChip('Ditolak', Colors.red, Icons.cancel);
      default:
        return _buildStatusChip('Bukti Terupload', Colors.blue, Icons.photo_library);
    }
  }

  // ✅ DEFAULT STATUS TRANSAKSI
  return _buildStatusChip('Selesai', Colors.green, Icons.verified);
}

// ✅ HELPER: BUILD STATUS CHIP
Widget _buildStatusChip(String text, Color color, IconData icon) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

// ✅ TEST UPLOAD BUKTI
void _testUploadBukti() async {
  try {
    print('🧪 TEST: Upload bukti dengan API setBuktiPhoto');
    
    // Test dengan file dummy
    final testResult = await _apiService.setBuktiPhoto(
      filePath: '/path/to/test/image.jpg',
    );
    
    print('🧪 TEST Result: ${testResult['success']}');
    print('🧪 TEST Message: ${testResult['message']}');
    
  } catch (e) {
    print('🧪 TEST Error: $e');
  }
}

  // ✅ ERROR WIDGET
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
            onPressed: _loadRiwayatTabungan,
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

  // ✅ EMPTY STATE WIDGET
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.savings_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Belum ada riwayat ${_selectedTabunganType == 'semua' ? 'tabungan' : _getTabunganName(_selectedTabunganType)}',
            style: const TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Data riwayat tabungan akan muncul setelah Anda melakukan transaksi setoran atau penarikan',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loadRiwayatTabungan,
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
  // ✅ DEBUG: Check data sebelum build
  print('🔄 BUILD - _saldoData: $_saldoData');
  print('🔄 BUILD - _riwayatTabungan length: ${_riwayatTabungan.length}');
  
  final totalSemuaTabungan = _getCurrentSaldo('semua');
  final filteredCount = _filteredRiwayat.length;
  
  print('🔄 BUILD - Total calculated: $totalSemuaTabungan');

  return Scaffold(
    backgroundColor: Colors.green[50], // ✅ BACKGROUND UTAMA SAMA DENGAN HEADER
    appBar: PreferredSize(
      preferredSize: const Size.fromHeight(70.0),
      child: AppBar(
        title: const Padding(
          padding: EdgeInsets.only(bottom: 10.0),
          child: Text(
            'Riwayat Tabungan',
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
              onPressed: _loadRiwayatTabungan,
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
                  'Total Semua Tabungan',
                  style: TextStyle(fontSize: 16, color: Colors.green, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatCurrency(totalSemuaTabungan),
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

          // ✅ ERROR MESSAGE UPLOAD
          if (_uploadErrorBukti != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: EdgeInsets.zero, // ✅ HILANGKAN MARGIN
              decoration: BoxDecoration(
                color: Colors.red[50],
                border: Border(bottom: BorderSide(color: Colors.red[100]!)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _uploadErrorBukti!,
                      style: TextStyle(
                        color: Colors.red[700],
                        fontSize: 12,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.red[700], size: 16),
                    onPressed: () => setState(() => _uploadErrorBukti = null),
                  ),
                ],
              ),
            ),
          ],

          // ✅ JENIS TABUNGAN FILTER - BACKGROUND PUTIH
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
              itemCount: _tabunganTypes.length,
              itemBuilder: (context, index) {
                final type = _tabunganTypes[index];
                final isSelected = _selectedTabunganType == type['id'];
                final saldo = _getCurrentSaldo(type['id'] as String);

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedTabunganType = type['id'] as String;
                    });
                  },
                  child: Container(
                    width: 120,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? (type['color'] as Color).withOpacity(0.15)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected 
                            ? type['color'] as Color 
                            : Colors.grey[300]!,
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
                          color: type['color'] as Color,
                          size: 24,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          type['name'] as String,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: type['color'] as Color,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatCurrency(saldo),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.black87 : Colors.black54,
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

          // ✅ MAIN CONTENT AREA - BACKGROUND PUTIH
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
                            'Memuat data tabungan...',
                            style: TextStyle(color: Colors.green),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Harap tunggu sebentar',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  : _hasError
                      ? _buildErrorWidget()
                      : _filteredRiwayat.isEmpty
                          ? _buildEmptyState()
                          : RefreshIndicator(
                              onRefresh: _loadRiwayatTabungan,
                              color: Colors.green,
                              backgroundColor: Colors.white,
                              child: ListView.separated(
                                padding: EdgeInsets.zero, // ✅ HILANGKAN PADDING
                                itemCount: _filteredRiwayat.length,
                                separatorBuilder: (context, index) => const SizedBox(height: 4),
                                itemBuilder: (context, index) {
                                  final transaksi = _filteredRiwayat[index];
                                  final jumlah = (transaksi['jumlah'] as num?)?.toInt() ?? 0;
                                  final isSetoran = transaksi['is_setoran'] == true;
                                  final jenisTabungan = transaksi['jenis_tabungan']?.toString() ?? 'sukarela';
                                  final keterangan = transaksi['keterangan']?.toString() ?? 'Transaksi tabungan';
                                  final tanggal = _formatTanggal(transaksi['tanggal']?.toString());
                                  final jenisTransaksi = transaksi['jenis_transaksi']?.toString() ?? 'Transaksi';
                                  final isSaldo = transaksi['is_saldo'] == true;
                                  final canUploadBukti = transaksi['can_upload_bukti'] == true;

                                  return Container(
                                    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                    child: Card(
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        side: BorderSide(color: Colors.green[100]!),
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        child: Row(
                                          children: [
                                            // ✅ LEADING ICON
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: _getTabunganColor(jenisTabungan).withOpacity(0.1),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                isSaldo ? Icons.account_balance : 
                                                         (isSetoran ? Icons.arrow_downward : Icons.arrow_upward),
                                                color: _getTabunganColor(jenisTabungan),
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            
                                            // ✅ CONTENT
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          jenisTransaksi,
                                                          style: const TextStyle(
                                                            fontWeight: FontWeight.w600,
                                                            fontSize: 14,
                                                          ),
                                                          maxLines: 2,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: _getTabunganColor(jenisTabungan).withOpacity(0.1),
                                                          borderRadius: BorderRadius.circular(4),
                                                          border: Border.all(color: _getTabunganColor(jenisTabungan)),
                                                        ),
                                                        child: Text(
                                                          _getTabunganName(jenisTabungan),
                                                          style: TextStyle(
                                                            color: _getTabunganColor(jenisTabungan),
                                                            fontSize: 9,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    tanggal,
                                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                                  ),
                                                  Text(
                                                    keterangan,
                                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 4),
                                                ],
                                              ),
                                            ),
                                            
                                            // ✅ TRAILING - NOMINAL
                                            SizedBox(
                                              width: 100,
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    _formatCurrency(jumlah),
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      color: _getAmountColor(jumlah),
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    isSetoran ? 'Setoran' : 'Penarikan',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: isSetoran ? Colors.green : Colors.red,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
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
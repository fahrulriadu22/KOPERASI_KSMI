import 'package:flutter/material.dart';
import 'riwayat_tabungan_screen.dart';
import 'riwayat_angsuran_screen.dart';
import '../services/api_service.dart';
import '../services/firebase_service.dart';
import '../services/system_notifier.dart';

// ✅ CUSTOM SHAPE UNTUK APPBAR
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

class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback? onRefresh;

  const DashboardScreen({
    super.key, 
    required this.user,
    this.onRefresh,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // ✅ List menu yang bisa ditampilkan dengan navigation target
  final List<MenuIcon> _allMenuItems = [
    MenuIcon('Pokok', Icons.account_balance, Colors.green, 'pokok', MenuType.tabungan),
    MenuIcon('Wajib', Icons.savings, Colors.orange, 'wajib', MenuType.tabungan),
    MenuIcon('Sukarela', Icons.volunteer_activism, Colors.red, 'sukarela', MenuType.tabungan),
    MenuIcon('SiTabung', Icons.account_balance_wallet, Colors.blue, 'sitabung', MenuType.tabungan),
    MenuIcon('Siumna', Icons.money, Colors.teal, 'siumna', MenuType.tabungan),
    MenuIcon('Siquna', Icons.handshake, Colors.purple, 'siquna', MenuType.tabungan),
    MenuIcon('Angsuran', Icons.payments, Colors.amber, 'angsuran', MenuType.angsuran),
    MenuIcon('Saldo', Icons.wallet, Colors.green[700]!, 'saldo', MenuType.saldo),
  ];

  // ✅ Menu yang aktif ditampilkan (default semua aktif)
  List<MenuIcon> _activeMenuItems = [];

  // ✅ Controller untuk scroll horizontal
  final ScrollController _scrollController = ScrollController();

  // ✅ Current user data dari session
  Map<String, dynamic>? _currentUser;

  // ✅ BUAT INSTANCE API SERVICE
  final ApiService _apiService = ApiService();

  // ✅ STATE UNTUK NOTIFICATION POPUP
OverlayEntry? _notificationOverlayEntry;
bool _isNotificationPopupOpen = false;

  // ✅ STATE UNTUK DATA SALDO DAN ANGSURAN DARI API
  Map<String, dynamic> _saldoData = {};
  Map<String, dynamic> _angsuranData = {};
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  int _unreadNotifications = 0;

// DI INITSTATE() DASHBOARDSCREEN - TAMBAHKAN:
@override
void initState() {
  super.initState();
  _activeMenuItems = List.from(_allMenuItems);
  _loadCurrentUser();
  _loadDataFromApi();
  _loadUnreadNotifications();
  
  // ✅ SETUP NOTIFICATION LISTENER
  _setupNotificationListener();
  
  // ✅ SETUP REAL-TIME STREAMS (TAMBAH INI)
  _setupRealTimeStreams();
}

// ✅ UPDATE DISPOSE() - TAMBAHKAN:
@override
void dispose() {
  _scrollController.dispose();
  _closeNotificationPopup();
  
  // ✅ STOP PERIODIC SYNC JIKA PERLU
  // firebaseService.stopPeriodicSync(); // Opsional
  
  super.dispose();
}

  // ✅ Load current user dari session management
  Future<void> _loadCurrentUser() async {
    try {
      final user = await _apiService.getCurrentUser();
      if (mounted) {
        setState(() {
          _currentUser = user ?? widget.user;
        });
      }
    } catch (e) {
      print('❌ Error loading current user: $e');
      if (mounted) {
        setState(() {
          _currentUser = widget.user;
        });
      }
    }
  }

  // ✅ TAMBAHKAN METHOD INI:
void _setupRealTimeStreams() {
  // Listen untuk real-time unread count updates
  firebaseService.unreadCountStream.listen((unreadCount) {
    print('📱 Real-time unread count: $unreadCount');
    if (mounted) {
      setState(() {
        _unreadNotifications = unreadCount;
      });
    }
  });

  // Listen untuk real-time notifications
  firebaseService.notificationStream.listen((notification) {
    print('📱 Real-time notification received: ${notification['title']}');
    _showRealTimeNotificationSnackbar(notification);
  });

  // Listen untuk real-time inbox data
  firebaseService.inboxDataStream.listen((inboxData) {
    print('📱 Real-time inbox data updated: ${inboxData.length} items');
    // Bisa refresh popup notifikasi jika sedang terbuka
    if (_isNotificationPopupOpen) {
      setState(() {});
    }
  });
}

// ✅ TAMBAHKAN METHOD INI:
void _showRealTimeNotificationSnackbar(Map<String, dynamic> notification) {
  final title = notification['title'] ?? 'KSMI Koperasi';
  final body = notification['body'] ?? 'Pesan baru';
  
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            body,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
      backgroundColor: Colors.green[700],
      duration: const Duration(seconds: 4),
      behavior: SnackBarBehavior.floating,
      action: SnackBarAction(
        label: 'Buka',
        textColor: Colors.white,
        onPressed: () {
          _showNotificationPopup();
        },
      ),
    ),
  );
  
  // Auto increment unread count
  if (mounted) {
    setState(() {
      _unreadNotifications++;
    });
  }
}

  // ✅ PERBAIKAN: LOAD UNREAD NOTIFICATIONS
  Future<void> _loadUnreadNotifications() async {
    try {
      print('📥 Loading unread notifications...');
      
      // Gunakan FirebaseService untuk get unread count
      final unreadCount = await firebaseService.getUnreadNotificationsCount();
      print('📊 Unread count from FirebaseService: $unreadCount');
      
      if (mounted) {
        setState(() {
          _unreadNotifications = unreadCount;
        });
      }
      
      // Juga refresh dari API untuk data terbaru
      final refreshResult = await firebaseService.refreshInboxData();
      if (refreshResult['success'] == true && mounted) {
        final newUnreadCount = refreshResult['unread_count'] ?? 0;
        print('🔄 Refreshed unread count: $newUnreadCount');
        
        setState(() {
          _unreadNotifications = newUnreadCount;
        });
      }
    } catch (e) {
      print('❌ Error loading notifications: $e');
    }
  }

  // ✅ SETUP NOTIFICATION LISTENER YANG LEBIH BAIK
  void _setupNotificationListener() {
    // Listen for unread count updates
    FirebaseService.onUnreadCountUpdated = (int unreadCount) {
      print('📱 Unread count updated: $unreadCount');
      if (mounted) {
        setState(() {
          _unreadNotifications = unreadCount;
        });
      }
    };

    // Listen for notification taps
    FirebaseService.onNotificationTap = (Map<String, dynamic> data) {
      _handleNotificationNavigation(data);
    };

    // Listen for incoming notifications
    FirebaseService.onNotificationReceived = (Map<String, dynamic> data) {
      _handleIncomingNotification(data);
    };
  }

  // ✅ HANDLE NOTIFICATION NAVIGATION
  void _handleNotificationNavigation(Map<String, dynamic> data) {
    try {
      final type = data['type']?.toString() ?? '';
      final id = data['id']?.toString() ?? '';
      final screen = data['screen']?.toString() ?? '';
      
      print('📱 Notification tapped - Type: $type, ID: $id, Screen: $screen');
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          switch (screen) {
            case 'inbox':
            case 'notifikasi':
              _showNotificationPopup();
              break;
            case 'transaction':
            case 'transaksi':
              // Navigate to transaction detail
              break;
            case 'tabungan':
              _navigateToRiwayatTabungan(context, _allMenuItems[0], _currentUser ?? widget.user);
              break;
            case 'angsuran':
            case 'taqsith':
              _navigateToRiwayatAngsuran(context, _currentUser ?? widget.user);
              break;
            case 'profile':
            case 'profil':
              // Navigate to profile
              break;
            default:
              // Refresh data untuk dashboard
              _refreshData();
              break;
          }
        }
      });
      
    } catch (e) {
      print('❌ Error handling notification navigation: $e');
    }
  }

  // ✅ HANDLE INCOMING NOTIFICATION
  void _handleIncomingNotification(Map<String, dynamic> data) {
    try {
      final title = data['title']?.toString() ?? 'KSMI Koperasi';
      final body = data['body']?.toString() ?? 'Pesan baru';
      final type = data['type']?.toString() ?? '';
      
      print('📱 Notification received - Title: $title, Body: $body, Type: $type');
      
      // Auto refresh unread count
      _loadUnreadNotifications();
      
    } catch (e) {
      print('❌ Error handling incoming notification: $e');
    }
  }

  // ✅ TEST ANDROID SYSTEM NOTIFICATIONS YANG LEBIH BAIK
  void _testAndroidSystemNotifications() async {
    try {
      print('🧪 Testing ANDROID SYSTEM Notifications...');
      
      // ✅ TAMPILKAN LOADING
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Testing SYSTEM Android...'),
            ],
          ),
          content: const Text('Mengirim notifikasi SYSTEM ke Android Notification Panel...'),
        ),
      );

      // ✅ GUNAKAN SYSTEMNOTIFIER
      print('🔄 Using SystemNotifier...');
      final systemNotifier = SystemNotifier();
      
      // ✅ INIT DULU SEBELUM TEST
      print('🔄 Initializing SystemNotifier...');
      await systemNotifier.initialize();
      await Future.delayed(const Duration(seconds: 1));

      // Test 1: BASIC SYSTEM NOTIFICATION
      print('1. Testing basic SYSTEM notification...');
      await systemNotifier.testBasicNotification();
      await Future.delayed(const Duration(seconds: 2));

      // Test 2: INBOX SYSTEM NOTIFICATION
      print('2. Testing inbox SYSTEM notification...');
      await systemNotifier.testInboxNotification();
      await Future.delayed(const Duration(seconds: 2));

      // Test 3: MULTIPLE SYSTEM NOTIFICATIONS
      print('3. Testing multiple SYSTEM notifications...');
      await systemNotifier.testMultipleNotifications();
      await Future.delayed(const Duration(seconds: 2));

      // ✅ TUTUP LOADING
      if (mounted) Navigator.of(context).pop();
      
      // ✅ TAMPILKAN INSTRUKSI
      _showAndroidNotificationInstructions();
      
      print('🎉 ANDROID SYSTEM NOTIFICATION Test Completed!');
      
    } catch (e) {
      print('❌ SYSTEM notification test failed: $e');
      
      // ✅ TUTUP LOADING JIKA ERROR
      if (mounted) Navigator.of(context).pop();
      
      // ✅ TAMPILKAN ERROR DETAIL
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('SYSTEM Test gagal: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // ✅ TAMPILKAN INSTRUKSI ANDROID
  void _showAndroidNotificationInstructions() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.android, color: Colors.green),
            SizedBox(width: 8),
            Text('Cek Sistem Android'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '✅ 3 Notifikasi telah dikirim ke sistem Android!',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Langkah cek:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildInstructionStep('1. MINIMALKAN aplikasi ini (tekan tombol home)'),
            _buildInstructionStep('2. Buka panel notifikasi Android'),
            _buildInstructionStep('3. Scroll ke bawah cari notifikasi "KSMI"'),
            _buildInstructionStep('4. Tap notifikasi untuk kembali ke app'),
            _buildInstructionStep('5. Clear notifikasi jika sudah dicek'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '💡 PENTING:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Notifikasi akan muncul di SYSTEM Android (panel notifikasi), bukan di dalam app!',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Test lagi
              _testAndroidSystemNotifications();
            },
            child: const Text('Test Lagi'),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.arrow_right, size: 16, color: Colors.green),
          const SizedBox(width: 4),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

// ✅ PERBAIKAN: LOAD DATA DENGAN STRUCTURE YANG SESUAI RIWAYAT_ANGSURAN_SCREEN
Future<void> _loadDataFromApi() async {
  // ✅ CEK MOUNTED SEBELUM SET STATE
  if (!mounted) return;
  
  setState(() {
    _isLoading = true;
    _hasError = false;
    _errorMessage = '';
  });

  try {
    print('🚀 Memulai load data dashboard dengan struktur taqsith...');

    // ✅ LOAD DATA SALDO DAN TAQSITH SECARA PARALEL
    final results = await Future.wait([
      _apiService.getAllSaldo(), // ✅ GET SALDO YANG SUDAH FIX
      _apiService.getAlltaqsith(),
    ]);

    final saldoResult = results[0];
    final taqsithResult = results[1];

    // ✅ CEK MOUNTED LAGI SEBELUM SET STATE
    if (!mounted) return;

    setState(() {
      // ✅ PROSES DATA SALDO
      if (saldoResult['success'] == true) {
        _saldoData = saldoResult['data'] ?? {};
        print('✅ Berhasil load data saldo');
      } else {
        _saldoData = {};
        print('❌ Gagal load data saldo');
      }

      // ✅ PROSES DATA TAQSITH - SESUAI STRUCTURE DARI RIWAYAT_ANGSURAN_SCREEN
      if (taqsithResult['success'] == true) {
        _angsuranData = _processTaqsithDataForDashboard(taqsithResult);
        print('✅ Berhasil load data taqsith untuk dashboard');
      } else {
        _angsuranData = {};
        print('❌ Gagal load data taqsith');
      }
      
      _isLoading = false;
    });
  } catch (e) {
    print('❌ Error loading dashboard data: $e');
    
    // ✅ CEK MOUNTED SEBELUM SET STATE ERROR
    if (!mounted) return;
    
    setState(() {
      _isLoading = false;
      _hasError = true;
      _errorMessage = 'Gagal memuat data: $e';
      _saldoData = {};
      _angsuranData = {};
    });
  }
}

  // ✅ PROSES DATA TAQSITH UNTUK DASHBOARD
  Map<String, dynamic> _processTaqsithDataForDashboard(Map<String, dynamic> taqsithResult) {
    final data = taqsithResult['data'] ?? [];
    final dataMaster = taqsithResult['data_master'] ?? [];
    
    print('🔧 Processing taqsith data for dashboard...');
    
    double totalAngsuran = 0;
    int jumlahProdukAktif = 0;
    List<Map<String, dynamic>> produkList = [];

    for (var master in dataMaster) {
      if (master is Map<String, dynamic>) {
        final idKredit = master['id_kredit']?.toString();
        final namaBarang = master['nama_barang']?.toString() ?? 'Produk';
        final angsuran = double.tryParse(master['angsuran']?.toString() ?? '0') ?? 0;
        final status = master['status']?.toString() ?? 'BELUM TERBAYAR';
        final jangkaWaktu = master['jangka_waktu']?.toString() ?? '18 Bulan';
        
        print('✅ Angsuran for $namaBarang: $angsuran');
        
        totalAngsuran += angsuran;
        
        if (angsuran > 0) {
          jumlahProdukAktif++;
        }
        
        final angsuranList = _findAngsuranForKredit(data, idKredit);
        final jumlahAngsuran = angsuranList.length;
        final angsuranTerbayar = angsuranList.where((a) => a['status'] == 'lunas').length;
        
        produkList.add({
          'id_kredit': idKredit,
          'nama_barang': namaBarang,
          'angsuran': angsuran,
          'status': status,
          'jangka_waktu': jangkaWaktu,
          'jumlah_angsuran': jumlahAngsuran,
          'angsuran_terbayar': angsuranTerbayar,
          'progress': jumlahAngsuran > 0 ? (angsuranTerbayar / jumlahAngsuran) * 100 : 0,
        });
      }
    }
    
    print('📊 Total angsuran calculated: $totalAngsuran');
    print('📊 Jumlah produk aktif: $jumlahProdukAktif');
    
    return {
      'total_angsuran': totalAngsuran,
      'jumlah_produk_aktif': jumlahProdukAktif,
      'produk_list': produkList,
      'data_master': dataMaster,
      'raw_data': data,
    };
  }

  // ✅ CARI DATA ANGSURAN UNTUK KREDIT TERTENTU
  List<Map<String, dynamic>> _findAngsuranForKredit(List<dynamic> data, String? idKredit) {
    if (idKredit == null) return [];
    
    try {
      for (var kreditItem in data) {
        if (kreditItem is Map<String, dynamic> && kreditItem['id_kredit'] == idKredit) {
          final angsuranList = kreditItem['angsuran'];
          if (angsuranList is List) {
            return List<Map<String, dynamic>>.from(angsuranList);
          }
        }
      }
    } catch (e) {
      print('❌ Error finding angsuran for kredit $idKredit: $e');
    }
    
    return [];
  }

  // ✅ GET ANGSURAN VALUE DARI STRUCTURE YANG BENAR
  int _getAngsuranValue() {
    try {
      print('🔍 Getting angsuran value from structure...');
      
      if (_angsuranData.containsKey('total_angsuran')) {
        final value = _angsuranData['total_angsuran'];
        print('✅ Found angsuran as total_angsuran: $value');
        return _parseValue(value);
      }
      
      print('⚠️ No angsuran value found in structure');
      return 0;
      
    } catch (e) {
      print('❌ Error getting angsuran value: $e');
      return 0;
    }
  }

  // ✅ FUNGSI UNTUK MENDAPATKAN NILAI DARI API DATA YANG BARU
  int _getApiValue(String key, Map<String, dynamic> data) {
    try {
      if (data.isEmpty) return 0;
      
      print('🔍 Searching for key: $key in data structure');
      
      if (data.containsKey(key)) {
        final value = data[key];
        print('✅ Found $key in root: $value');
        return _parseValue(value);
      }
      
      if (key == 'angsuran') {
        return _getAngsuranValue();
      }
      
      final possibleKeys = _getPossibleKeys(key);
      for (final possibleKey in possibleKeys) {
        if (data.containsKey(possibleKey)) {
          final value = data[possibleKey];
          print('✅ Found $key as $possibleKey: $value');
          return _parseValue(value);
        }
      }
      
      print('❌ Key $key not found in data structure');
      return 0;
      
    } catch (e) {
      print('❌ Error getApiValue for $key: $e');
      return 0;
    }
  }

  // ✅ UPDATE: FUNGSI UNTUK MENDAPATKAN BERBAGAI KEMUNGKINAN KEY NAMING
  List<String> _getPossibleKeys(String baseKey) {
    switch (baseKey) {
      case 'pokok':
        return ['pokok', 'simpananPokok', 'pokok_simpanan', 'simpanan_pokok', 'saldo_pokok'];
      case 'wajib':
        return ['wajib', 'simpananWajib', 'wajib_simpanan', 'simpanan_wajib', 'saldo_wajib'];
      case 'sukarela':
        return ['sukarela', 'simpananSukarela', 'sukarela_simpanan', 'simpanan_sukarela', 'saldo_sukarela'];
      case 'sitabung':
        return ['sitabung', 'sita', 'siTabung', 'sita_bung', 'saldo_sitabung', 'tabungan_sita'];
      case 'siumna':
        return ['siumna', 'simuna', 'simpananMuna', 'simuna_simpanan', 'saldo_siumna'];
      case 'siquna':
        return ['siquna', 'taqsith', 'taqshith', 'taqsiith', 'pembiayaan', 'saldo_siquna'];
      case 'saldo':
        return ['saldo', 'balance', 'total_saldo', 'total', 'jumlah_saldo', 'saldo_total'];
      case 'angsuran':
        return ['angsuran', 'installment', 'total_angsuran', 'taqsith_total', 'pembiayaan', 'cicilan'];
      default:
        return [baseKey];
    }
  }

  // ✅ FUNGSI UNTUK PARSE VALUE DARI BERBAGAI TIPE DATA
  int _parseValue(dynamic value) {
    if (value == null) return 0;
    
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      final cleaned = value.replaceAll(RegExp(r'[^\d.]'), '');
      return double.tryParse(cleaned)?.toInt() ?? 0;
    }
    
    return 0;
  }

  // ✅ PERBAIKAN: CALCULATE TOTAL TABUNGAN DARI DATA YANG SUDAH DINORMALISASI
  int _calculateTotalTabungan() {
    try {
      final pokok = _getApiValue('pokok', _saldoData);
      final wajib = _getApiValue('wajib', _saldoData);
      final sukarela = _getApiValue('sukarela', _saldoData);
      final sitabung = _getApiValue('sitabung', _saldoData);
      final siumna = _getApiValue('siumna', _saldoData);
      final siquna = _getApiValue('siquna', _saldoData);

      final total = pokok + wajib + sukarela + sitabung + siumna + siquna;

      print('''
    📊 Total Tabungan Calculation:
    - Pokok: $pokok
    - Wajib: $wajib  
    - Sukarela: $sukarela
    - SiTabung: $sitabung
    - Siumna: $siumna
    - Siquna: $siquna
    TOTAL: $total
    ''');

      return total;
    } catch (e) {
      print('❌ Error calculating total tabungan: $e');
      return 0;
    }
  }

  // ✅ PERBAIKAN: GET SALDO VALUE DENGAN LOGIC YANG LEBIH ROBUST
  int _getSaldoValue() {
    try {
      final directSaldo = _getApiValue('saldo', _saldoData);
      if (directSaldo > 0) {
        print('✅ Using direct saldo value: $directSaldo');
        return directSaldo;
      }
      
      final calculatedTotal = _calculateTotalTabungan();
      if (calculatedTotal > 0) {
        print('✅ Using calculated total: $calculatedTotal');
        return calculatedTotal;
      }
      
      final possibleKeys = ['total_saldo', 'balance', 'total', 'jumlah_saldo'];
      for (final key in possibleKeys) {
        final value = _getApiValue(key, _saldoData);
        if (value > 0) {
          print('✅ Found saldo as $key: $value');
          return value;
        }
      }
      
      print('⚠️ No saldo value found, returning 0');
      return 0;
      
    } catch (e) {
      print('❌ Error getting saldo value: $e');
      return 0;
    }
  }

// ✅ SHOW NOTIFICATION POPUP SEPERTI FACEBOOK
void _showNotificationPopup() {
  if (_isNotificationPopupOpen) {
    _closeNotificationPopup();
    return;
  }

  _closeNotificationPopup(); // Close existing if any

  final overlay = Overlay.of(context);
  final renderBox = context.findRenderObject() as RenderBox;
  final position = renderBox.localToGlobal(Offset.zero);

  _notificationOverlayEntry = OverlayEntry(
    builder: (context) => Stack(
      children: [
        // Background overlay
        GestureDetector(
          onTap: _closeNotificationPopup,
          child: Container(
            color: Colors.transparent,
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
          ),
        ),
        // Notification popup
        Positioned(
          top: position.dy + kToolbarHeight - 10,
          right: 16,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 320,
              height: 400,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green[700],
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.notifications, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Notifikasi',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        if (_unreadNotifications > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _unreadNotifications.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Content
                  Expanded(
                    child: _buildNotificationContent(),
                  ),
                  // Footer
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () {
                            _markAllAsRead();
                            _closeNotificationPopup();
                          },
                          child: const Text(
                            'Tandai semua dibaca',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            _closeNotificationPopup();
                            _showAllNotifications();
                          },
                          child: const Text(
                            'Lihat semua',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );

  overlay.insert(_notificationOverlayEntry!);
  setState(() {
    _isNotificationPopupOpen = true;
  });
}

  // ✅ PERBAIKAN: LOGOUT FUNCTION YANG BENAR
  Future<void> _logout() async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Logout'),
        content: const Text('Apakah Anda yakin ingin logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final result = await _apiService.logout();
      
      // Tutup loading dialog
      if (mounted) Navigator.of(context).pop();
      
      if (mounted) {
        if (result['success'] == true) {
          Navigator.pushNamedAndRemoveUntil(
            context, 
            '/login', 
            (route) => false
          );
        } else {
          // Jika logout API gagal, tetap redirect ke login
          Navigator.pushNamedAndRemoveUntil(
            context, 
            '/login', 
            (route) => false
          );
        }
      }
    }
  }

// ✅ REFRESH DATA FUNCTION
Future<void> _refreshData() async {
  // ✅ CEK MOUNTED
  if (!mounted) return;
  
  setState(() {
    _isLoading = true;
    _hasError = false;
    _errorMessage = '';
  });

  try {
    // Refresh user data dari session
    await _loadCurrentUser();
    // Refresh data dari API
    await _loadDataFromApi();
    // Refresh notifications
    await _loadUnreadNotifications();
    
    // ✅ Panggil callback jika ada
    widget.onRefresh?.call();
    
    // ✅ CEK MOUNTED SEBELUM SHOW SNACKBAR
    if (mounted && !_hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data berhasil diperbarui'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  } catch (e) {
    print('❌ Error refreshing data: $e');
    
    // ✅ CEK MOUNTED SEBELUM SET STATE ERROR
    if (!mounted) return;
    
    setState(() {
      _isLoading = false;
      _hasError = true;
      _errorMessage = 'Gagal refresh data: $e';
    });
  }
}

  // ✅ PERBAIKAN: HANDLE MENU TAP DENGAN DATA YANG BENAR
  void _handleMenuTap(MenuIcon menu, BuildContext context) {
    final userData = _currentUser ?? widget.user;
    
    print('🎯 Menu tapped: ${menu.title} - Type: ${menu.type}');
    
    switch (menu.type) {
      case MenuType.tabungan:
        _navigateToRiwayatTabungan(context, menu, userData);
        break;
      case MenuType.angsuran:
        _navigateToRiwayatAngsuran(context, userData);
        break;
      case MenuType.saldo:
        _showSaldoDetail(context);
        break;
    }
  }

// ✅ NAVIGASI NORMAL - USER PENCET BACK UNTUK KEMBALI
void _navigateToRiwayatTabungan(BuildContext context, MenuIcon menu, Map<String, dynamic> userData) {
  print('🚀 Navigating to RiwayatTabungan with type: ${menu.key}');
  
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => RiwayatTabunganScreen(
        user: userData,
        initialTabunganType: menu.key,
      ),
    ),
  );
}

// ✅ NAVIGASI KE RIWAYAT ANGSURAN
void _navigateToRiwayatAngsuran(BuildContext context, Map<String, dynamic> userData) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => RiwayatAngsuranScreen(user: userData),
    ),
  );
}

  // ✅ PERBAIKAN: SHOW SALDO DETAIL DENGAN DATA YANG AKURAT
  void _showSaldoDetail(BuildContext context) {
    final saldo = _getSaldoValue();
    final totalTabungan = _calculateTotalTabungan();
    final pokok = _getApiValue('pokok', _saldoData);
    final wajib = _getApiValue('wajib', _saldoData);
    final sukarela = _getApiValue('sukarela', _saldoData);
    final sitabung = _getApiValue('sitabung', _saldoData);
    final siumna = _getApiValue('siumna', _saldoData);
    final siquna = _getApiValue('siquna', _saldoData);
    final angsuran = _getAngsuranValue();

    print('''
  📋 Saldo Detail Dialog:
  - Saldo: $saldo
  - Total Tabungan: $totalTabungan
  - Pokok: $pokok
  - Wajib: $wajib
  - Sukarela: $sukarela
  - Sitabung: $sitabung
  - Siumna: $siumna
  - Siquna: $siquna
  - Angsuran: $angsuran
  ''');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.account_balance_wallet, color: Colors.green[700]),
            const SizedBox(width: 8),
            const Text(
              'Detail Saldo & Tabungan',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSaldoDetailItem('Saldo Tersedia', saldo, Colors.green),
            const SizedBox(height: 8),
            _buildSaldoDetailItem('Total Tabungan', totalTabungan, Colors.blue),
            _buildSaldoDetailItem('Total Angsuran', angsuran, Colors.amber),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Rincian Tabungan:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  _buildTabunganDetailRow('Pokok', pokok),
                  _buildTabunganDetailRow('Wajib', wajib),
                  _buildTabunganDetailRow('Sukarela', sukarela),
                  _buildTabunganDetailRow('SiTabung', sitabung),
                  _buildTabunganDetailRow('Siumna', siumna),
                  _buildTabunganDetailRow('Siquna', siquna),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Data diperbarui: ${DateTime.now().toString().substring(0, 16)}',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
            if (_hasError)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '⚠️ $_errorMessage',
                  style: const TextStyle(fontSize: 10, color: Colors.orange),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _refreshData();
            },
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildSaldoDetailItem(String label, int value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        Text(
          _formatCurrency(value),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildTabunganDetailRow(String label, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          Text(
            _formatCurrency(value),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // ✅ PERBAIKAN: FORMAT CURRENCY UNTUK NILAI BESAR
  String _formatCurrency(int value) {
    try {
      if (value == 0) return 'Rp 0';
      
      if (value < 1000) {
        return 'Rp $value';
      } else if (value < 1000000) {
        final thousands = (value / 1000).toStringAsFixed(0);
        return 'Rp ${thousands}K';
      } else if (value < 1000000000) {
        final millions = (value / 1000000).toStringAsFixed(1);
        return 'Rp ${millions}Jt';
      } else {
        final billions = (value / 1000000000).toStringAsFixed(1);
        return 'Rp ${billions}M';
      }
    } catch (e) {
      return 'Rp 0';
    }
  }

// ✅ BUILD NOTIFICATION CONTENT WITH REAL DATA
Widget _buildNotificationContent() {
  return FutureBuilder<List<Map<String, dynamic>>>(
    future: firebaseService.getRealInboxData(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      }
      
      if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.notifications_none, size: 48, color: Colors.grey),
              SizedBox(height: 8),
              Text(
                'Tidak ada notifikasi',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        );
      }
      
      final inboxData = snapshot.data!;
      
      return ListView.builder(
        padding: const EdgeInsets.all(0),
        itemCount: inboxData.length,
        itemBuilder: (context, index) {
          final item = inboxData[index];
          return _buildRealNotificationItem(item);
        },
      );
    },
  );
}

// ✅ BUILD REAL NOTIFICATION ITEM
Widget _buildRealNotificationItem(Map<String, dynamic> item) {
  final icon = _getNotificationIcon(item['subject']?.toString() ?? '');
  final isUnread = item['isUnread'] == true;
  
  return Container(
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      color: isUnread ? Colors.blue[50] : Colors.transparent,
    ),
    child: ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.green[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.green[700], size: 20),
      ),
      title: Text(
        item['subject']?.toString() ?? 'Notifikasi',
        style: TextStyle(
          fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
          fontSize: 14,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item['message']?.toString() ?? '',
            style: const TextStyle(fontSize: 12),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            item['time']?.toString() ?? '',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
      trailing: isUnread
          ? Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            )
          : null,
      onTap: () {
        _markNotificationAsRead(item['id']?.toString() ?? '');
        _closeNotificationPopup();
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
  );
}

// ✅ GET NOTIFICATION ICON BASED ON SUBJECT
IconData _getNotificationIcon(String subject) {
  final lowerSubject = subject.toLowerCase();
  
  if (lowerSubject.contains('pembayaran') || lowerSubject.contains('setoran')) {
    return Icons.account_balance_wallet;
  } else if (lowerSubject.contains('penarikan')) {
    return Icons.money_off;
  } else if (lowerSubject.contains('siquana') || lowerSubject.contains('taqsith')) {
    return Icons.handshake;
  } else if (lowerSubject.contains('test')) {
    return Icons.notifications;
  } else {
    return Icons.notifications;
  }
}

// ✅ MARK SPECIFIC NOTIFICATION AS READ
void _markNotificationAsRead(String notificationId) async {
  try {
    if (notificationId.isNotEmpty) {
      // Update local state
      if (_unreadNotifications > 0) {
        setState(() {
          _unreadNotifications--;
        });
      }
      
      // Call API to mark as read
      await _apiService.markNotificationAsRead(notificationId);
      
      // Refresh data
      _loadUnreadNotifications();
    }
  } catch (e) {
    print('❌ Error marking notification as read: $e');
  }
}

// ✅ BUILD NOTIFICATION ITEM
Widget _buildNotificationItem({
  required IconData icon,
  required String title,
  required String message,
  required String time,
  required bool isUnread,
}) {
  return Container(
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      color: isUnread ? Colors.blue[50] : Colors.transparent,
    ),
    child: ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.green[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.green[700], size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
          fontSize: 14,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: const TextStyle(fontSize: 12),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            time,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
      trailing: isUnread
          ? Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            )
          : null,
      onTap: () {
        _markAsRead();
        _closeNotificationPopup();
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
  );
}

// ✅ CLOSE NOTIFICATION POPUP - FIXED
void _closeNotificationPopup() {
  if (_notificationOverlayEntry != null) {
    _notificationOverlayEntry!.remove();
    _notificationOverlayEntry = null;
  }
  
  // ✅ CEK MOUNTED SEBELUM SET STATE
  if (!mounted) return;
  
  setState(() {
    _isNotificationPopupOpen = false;
  });
}

// ✅ MARK ALL AS READ (FIXED VERSION)
void _markAllAsRead() async {
  try {
    // Update local state langsung
    setState(() {
      _unreadNotifications = 0;
    });
    
    // Panggil FirebaseService untuk sync
    await firebaseService.markAllNotificationsAsRead();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Semua notifikasi ditandai sebagai dibaca'),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    print('❌ Error marking all as read: $e');
    // Fallback: update local state saja
    setState(() {
      _unreadNotifications = 0;
    });
  }
}

// ✅ MARK AS READ (FIXED VERSION)
void _markAsRead() {
  if (_unreadNotifications > 0) {
    setState(() {
      _unreadNotifications--;
    });
    
    // Optional: Update di FirebaseService juga
    try {
      firebaseService.updateUnreadCount(_unreadNotifications);
    } catch (e) {
      print('⚠️ Error updating unread count in service: $e');
    }
  }
}

// ✅ SHOW ALL NOTIFICATIONS (FULL SCREEN)
void _showAllNotifications() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.notifications),
          SizedBox(width: 8),
          Text('Semua Notifikasi'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Fitur notifikasi lengkap akan segera hadir!'),
            const SizedBox(height: 16),
            if (_unreadNotifications > 0)
              Text(
                'Anda memiliki $_unreadNotifications pesan belum dibaca',
                style: TextStyle(
                  color: Colors.orange[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Tutup'),
        ),
      ],
    ),
  );
}

  // ✅ ERROR WIDGET
  Widget _buildErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
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
            onPressed: _refreshData,
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

  @override
  Widget build(BuildContext context) {
    final saldo = _getSaldoValue();
    final angsuran = _getAngsuranValue();
    final totalTabungan = _calculateTotalTabungan();
    final userData = _currentUser ?? widget.user;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70.0),
        child: AppBar(
          title: const Padding(
            padding: EdgeInsets.only(bottom: 10.0),
            child: Text(
              'Beranda KSMI',
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
          automaticallyImplyLeading: false,
          centerTitle: true,
            actions: [
            // ✅ NOTIFICATION BUTTON WITH BADGE
            Padding(
              padding: const EdgeInsets.only(bottom: 10.0, right: 8.0),
              child: Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications),
                    onPressed: _showNotificationPopup, // ✅ UBAH INI,
                    tooltip: 'Notifikasi',
                  ),
                  if (_unreadNotifications > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          _unreadNotifications > 9 ? '9+' : _unreadNotifications.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ✅ REFRESH BUTTON
            Padding(
              padding: const EdgeInsets.only(bottom: 10.0, right: 8.0),
              child: IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _refreshData,
                tooltip: 'Refresh Data',
              ),
            ),
          ],
        ),
      ),
      backgroundColor: Colors.green[50],
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshData,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                if (_hasError)
                  _buildErrorWidget()
                else if (_isLoading) 
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        CircularProgressIndicator(color: Colors.green[700]),
                        const SizedBox(height: 16),
                        Text(
                          'Memuat data...',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                else 
                  Column(
                    children: [
                      // TOTAL TABUNGAN SECTION
                      InkWell(
                        onTap: () {
                          _navigateToRiwayatTabungan(context, _allMenuItems[0], userData);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue[100]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.savings, color: Colors.blue[700], size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Total Tabungan',
                                      style: TextStyle(
                                        color: Colors.blue[800],
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatCurrency(totalTabungan),
                                      style: TextStyle(
                                        color: Colors.blue[700],
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Pokok + Wajib + Sukarela + SiTabung + Simuna + Taqsith',
                                      style: TextStyle(
                                        color: Colors.blue[600],
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: totalTabungan > 0 ? Colors.blue[100] : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  totalTabungan > 0 ? 'Aktif' : 'Kosong',
                                  style: TextStyle(
                                    color: totalTabungan > 0 ? Colors.blue[800] : Colors.grey[600],
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.blue[700]),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ANGSURAN SECTION
                      InkWell(
                        onTap: () {
                          _navigateToRiwayatAngsuran(context, userData);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green[100]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.payments, color: Colors.green[700], size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Total Angsuran',
                                      style: TextStyle(
                                        color: Colors.grey[800],
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatCurrency(angsuran),
                                      style: TextStyle(
                                        color: Colors.green[700],
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Pembiayaan Taqsith Aktif',
                                      style: TextStyle(
                                        color: Colors.green[600],
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: angsuran > 0 ? Colors.green[100] : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  angsuran > 0 ? 'Aktif' : 'Tidak Ada',
                                  style: TextStyle(
                                    color: angsuran > 0 ? Colors.green[800] : Colors.grey[600],
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.green[700]),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 20),

                // ✅ MENU UTAMA
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Menu Utama',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          InkWell(
                            onTap: () {
                              _showEditMenuDialog(context);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.green[100],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green[300]!),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.edit, size: 16, color: Colors.green[700]),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Edit',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // ✅ GRID MENU UTAMA
                      Container(
                        height: 200,
                        child: ListView.builder(
                          controller: _scrollController,
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: (_activeMenuItems.length / 4).ceil(),
                          itemBuilder: (context, pageIndex) {
                            return Container(
                              width: MediaQuery.of(context).size.width - 32,
                              child: Column(
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: List.generate(4, (index) {
                                        final itemIndex = pageIndex * 4 + index;
                                        if (itemIndex >= _activeMenuItems.length) {
                                          return Expanded(child: Container());
                                        }
                                        final menu = _activeMenuItems[itemIndex];
                                        return Expanded(
                                          child: _buildSmallMenuIcon(
                                            menu,
                                            menu.type == MenuType.angsuran 
                                                ? _getAngsuranValue() 
                                                : _getApiValue(menu.key, _saldoData),
                                            context,
                                          ),
                                        );
                                      }),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Expanded(
                                    child: Row(
                                      children: List.generate(4, (index) {
                                        final itemIndex = pageIndex * 4 + 4 + index;
                                        if (itemIndex >= _activeMenuItems.length) {
                                          return Expanded(child: Container());
                                        }
                                        final menu = _activeMenuItems[itemIndex];
                                        return Expanded(
                                          child: _buildSmallMenuIcon(
                                            menu,
                                            menu.type == MenuType.angsuran 
                                                ? _getAngsuranValue() 
                                                : _getApiValue(menu.key, _saldoData),
                                            context,
                                          ),
                                        );
                                      }),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSmallMenuIcon(MenuIcon menu, int value, BuildContext context) {
    return GestureDetector(
      onTap: () {
        _handleMenuTap(menu, context);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: menu.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: menu.color.withOpacity(0.3)),
              ),
              child: Icon(menu.icon, color: menu.color, size: 24),
            ),
            const SizedBox(height: 6),
            Text(
              menu.title,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              _formatCurrency(value),
              style: TextStyle(
                fontSize: 8,
                color: value > 0 ? Colors.green[700] : Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ✅ FUNGSI EDIT MENU
  void _showEditMenuDialog(BuildContext context) {
    List<MenuIcon> tempMenuItems = List.from(_activeMenuItems);
    
    for (var menu in _allMenuItems) {
      if (!tempMenuItems.any((item) => item.key == menu.key)) {
        tempMenuItems.add(menu);
      }
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Menu Utama'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Pilih menu yang ingin ditampilkan:',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _allMenuItems.map((menu) {
                        final isActive = tempMenuItems.any((item) => item.key == menu.key);
                        return FilterChip(
                          label: Text(menu.title),
                          selected: isActive,
                          onSelected: (selected) {
                            setDialogState(() {
                              if (selected) {
                                if (!tempMenuItems.any((item) => item.key == menu.key)) {
                                  tempMenuItems.add(menu);
                                }
                              } else {
                                tempMenuItems.removeWhere((item) => item.key == menu.key);
                              }
                            });
                          },
                          backgroundColor: Colors.grey[200],
                          selectedColor: Colors.green[100],
                          checkmarkColor: Colors.green[700],
                          labelStyle: TextStyle(
                            color: isActive ? Colors.green[700] : Colors.grey[700],
                            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${tempMenuItems.length} dari ${_allMenuItems.length} menu dipilih',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _activeMenuItems = List.from(tempMenuItems);
                    });
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Menu berhasil diupdate (${_activeMenuItems.length} item)'),
                        backgroundColor: Colors.green[700],
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // === 🧪 ANDROID SYSTEM NOTIFICATION TEST METHODS ===

// ✅ TEST 1: Basic System Notification
void _testAndroidSystemBasic() async {
  try {
    print('🧪 TEST 1: Basic System Notification');
    
    final systemNotifier = SystemNotifier();
    await systemNotifier.initialize();
    
    await systemNotifier.showSystemNotification(
      id: 1001,
      title: '🔔 TEST BASIC - KSMI',
      body: 'Ini test notifikasi SYSTEM dasar - harus muncul di panel Android!',
    );
    
    // Tampilkan snackbar konfirmasi
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ TEST 1 BERHASIL - Buka panel notifikasi Android!'),
          backgroundColor: Colors.green,
        ),
      );
    }
    
  } catch (e) {
    print('❌ TEST 1 GAGAL: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ TEST 1 GAGAL: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// ✅ TEST 2: Multiple Notifications  
void _testAndroidSystemMultiple() async {
  try {
    print('🧪 TEST 2: Multiple System Notifications');
    
    final systemNotifier = SystemNotifier();
    await systemNotifier.initialize();
    
    // Notification 1
    await systemNotifier.showSystemNotification(
      id: 2001,
      title: '💰 SETORAN BERHASIL',
      body: 'Setoran Pokok Rp 50.000 berhasil - KSMI',
    );
    
    await Future.delayed(Duration(seconds: 2));
    
    // Notification 2
    await systemNotifier.showSystemNotification(
      id: 2002,
      title: '📨 PESAN BARU',
      body: 'Anda memiliki 3 pesan belum dibaca - KSMI',
    );
    
    await Future.delayed(Duration(seconds: 2));
    
    // Notification 3
    await systemNotifier.showSystemNotification(
      id: 2003,
      title: '📊 LAPORAN BULANAN',
      body: 'Laporan keuangan Januari 2024 sudah tersedia - KSMI',
    );
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ 3 Notifikasi dikirim! Buka panel Android!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 5),
        ),
      );
    }
    
  } catch (e) {
    print('❌ TEST 2 GAGAL: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ TEST 2 GAGAL: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// ✅ TEST 3: Real Scenario Notifications
void _testAndroidSystemRealScenarios() async {
  try {
    print('🧪 TEST 3: Real Scenario Notifications');
    
    final systemNotifier = SystemNotifier();
    await systemNotifier.initialize();
    
    // Simulasi notifikasi transaksi
    await systemNotifier.showSystemNotification(
      id: 3001,
      title: '💳 TRANSAKSI BERHASIL',
      body: 'Penarikan SiTabung Rp 100.000 berhasil - No. TRX: TRX001',
    );
    
    await Future.delayed(Duration(seconds: 3));
    
    // Simulasi notifikasi angsuran
    await systemNotifier.showSystemNotification(
      id: 3002,
      title: '📅 JATUH TEMPO',
      body: 'Angsuran Taqsith akan jatuh tempo 3 hari lagi - Rp 250.000',
    );
    
    await Future.delayed(Duration(seconds: 3));
    
    // Simulasi notifikasi system
    await systemNotifier.showSystemNotification(
      id: 3003,
      title: '🎉 SELAMAT!',
      body: 'Saldo Anda bertambah Rp 75.000 dari bagi hasil - KSMI',
    );
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Notifikasi real scenario dikirim!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 5),
        ),
      );
    }
    
  } catch (e) {
    print('❌ TEST 3 GAGAL: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ TEST 3 GAGAL: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// ✅ TEST 4: Clear All Notifications
void _testAndroidSystemClearAll() async {
  try {
    print('🧪 TEST 4: Clear All Notifications');
    
    final systemNotifier = SystemNotifier();
    await systemNotifier.initialize();
    
    await systemNotifier.clearAllNotifications();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🧹 Semua notifikasi dihapus dari system!'),
          backgroundColor: Colors.blue,
        ),
      );
    }
    
  } catch (e) {
    print('❌ TEST 4 GAGAL: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ TEST 4 GAGAL: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// ✅ DIALOG UNTUK PILIH TEST
void _showAndroidSystemTestDialog() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.android, color: Colors.green),
          SizedBox(width: 8),
          Text('🧪 Test System Android'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pilih jenis test notifikasi SYSTEM Android:'),
          SizedBox(height: 16),
          Text(
            '📱 BUKA PANEL NOTIFIKASI ANDROID SETELAH TEST!',
            style: TextStyle(
              fontSize: 12,
              color: Colors.orange,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      actions: [
        // Test Basic
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            _testAndroidSystemBasic();
          },
          child: Text('Test Basic'),
        ),
        
        // Test Multiple
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            _testAndroidSystemMultiple();
          },
          child: Text('Test Multiple'),
        ),
        
        // Test Real Scenario
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            _testAndroidSystemRealScenarios();
          },
          child: Text('Test Real'),
        ),
        
        // Clear All
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            _testAndroidSystemClearAll();
          },
          child: Text('Clear All'),
        ),
      ],
    ),
  );
}
}

// ✅ MODEL UNTUK MENU ICON DENGAN TYPE
class MenuIcon {
  final String title;
  final IconData icon;
  final Color color;
  final String key;
  final MenuType type;

  MenuIcon(this.title, this.icon, this.color, this.key, this.type);
}

// ✅ ENUM UNTUK JENIS MENU
enum MenuType {
  tabungan,
  angsuran,
  saldo,
}
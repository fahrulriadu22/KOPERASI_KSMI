import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_main.dart';
import 'screens/upload_dokumen_screen.dart';
import 'screens/aktivasi_akun_screen.dart';
import 'screens/syarat_dan_ketentuan.dart';
import 'screens/aktivasi_berhasil_screen.dart';
import 'services/api_service.dart';
import 'services/firebase_service.dart';
import 'package:workmanager/workmanager.dart';
import 'screens/profile_screen.dart';

// Global keys
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = 
    GlobalKey<ScaffoldMessengerState>();

// Firebase Service Instance
final FirebaseService firebaseService = FirebaseService();

// ✅ WORKMANAGER CALLBACK DISPATCHER - FIXED
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print("🔄 Native background task: $task");
    
    try {
      switch (task) {
        case 'inbox-sync-task':
          await _executeBackgroundSync();
          print("✅ Background inbox sync completed");
          return true;
          
        case 'notification-check-task':
          await _executeNotificationCheck();
          print("✅ Background notification check completed");
          return true;
          
        default:
          print("⚠️ Unknown background task: $task");
          return false;
      }
    } catch (e) {
      print("❌ Background task failed: $e");
      return false;
    }
  });
}

// ✅ BACKGROUND SYNC TANPA FIREBASE INIT
Future<void> _executeBackgroundSync() async {
  try {
    final ApiService apiService = ApiService();
    print("🔄 Executing background sync...");
  } catch (e) {
    print("❌ Background sync error: $e");
  }
}

// ✅ NOTIFICATION CHECK TANPA FIREBASE INIT  
Future<void> _executeNotificationCheck() async {
  try {
    print("🔄 Checking for notifications...");
  } catch (e) {
    print("❌ Notification check error: $e");
  }
}

// ✅ REGISTER BACKGROUND TASKS - WITH PROPER ERROR HANDLING
Future<void> _registerBackgroundTasks() async {
  try {
    print('🔄 Registering background tasks...');
    
    await Workmanager().registerPeriodicTask(
      "inbox-sync-task",
      "inbox-sync-task",
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      initialDelay: const Duration(seconds: 30),
    );
    
    print('✅ Background tasks registered successfully');
  } catch (e) {
    print('❌ Error registering background tasks: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('🚀 STARTING KOPERASI KSMI APP...');
  
  // ✅ 1. INITIALIZE FIREBASE FIRST
  try {
    print('🔥 Initializing Firebase Core...');
    await Firebase.initializeApp();
    print('✅ Firebase Core initialized successfully');
  } catch (e) {
    print('❌ Firebase Core initialization failed: $e');
  }

  // ✅ 2. INITIALIZE SHARED PREFERENCES
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  print('✅ SharedPreferences initialized');

  // ✅ 3. ENABLE WORKMANAGER - TEST DENGAN GIT VERSION
  try {
    print('🔄 Initializing WorkManager for background sync...');
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: true,
    );
    print('✅ WorkManager initialized successfully');
  } catch (e) {
    print('❌ WorkManager initialization failed: $e');
  }

  // ✅ 4. INITIALIZE APP SERVICES
  await _initializeAppServices();
  
  runApp(const KoperasiKSMIApp());
}

// ✅ INITIALIZE APP SERVICES - SIMPLIFIED
Future<void> _initializeAppServices() async {
  try {
    print('🔄 Initializing app services...');
    
    // Initialize Firebase Services
    await _initializeFirebaseServices();
    
    // ✅ ENABLE BACKGROUND TASKS
    await _registerBackgroundTasks();
    
    print('✅ All app services initialized successfully');
  } catch (e) {
    print('❌ ERROR Initializing App Services: $e');
  }
}

// ✅ INITIALIZE FIREBASE SERVICES - WITH PROPER ERROR HANDLING
Future<void> _initializeFirebaseServices() async {
  try {
    print('🔄 Initializing Firebase Services...');
    await firebaseService.initialize();
    _setupNotificationCallbacks();
    
    print('✅ Firebase Services initialized successfully');
  } catch (e) {
    print('❌ Firebase Services initialization failed: $e');
    print('⚠️ Continuing without Firebase Services...');
  }
}

void _setupNotificationCallbacks() {
  FirebaseService.onNotificationTap = (Map<String, dynamic> data) {
    _handleNotificationNavigation(data);
  };
  
  FirebaseService.onNotificationReceived = (Map<String, dynamic> data) {
    _handleNotificationData(data);
  };
}

void _handleNotificationNavigation(Map<String, dynamic> data) {
  try {
    final type = data['type']?.toString() ?? '';
    final id = data['id']?.toString() ?? '';
    final screen = data['screen']?.toString() ?? '';
    
    print('📱 Notification tapped - Type: $type, ID: $id, Screen: $screen');
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigatorKey.currentState?.context != null) {
        switch (screen) {
          case 'inbox':
          case 'notifikasi':
            navigatorKey.currentState!.pushNamed('/inbox');
            break;
          case 'profile':
          case 'profil':
            navigatorKey.currentState!.pushNamed('/profile');
            break;
          default:
            _forceDashboardRefresh();
            break;
        }
      }
    });
    
  } catch (e) {
    print('❌ Error handling notification navigation: $e');
  }
}

void _forceDashboardRefresh() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final currentContext = navigatorKey.currentState?.context;
    if (currentContext != null) {
      final currentRoute = ModalRoute.of(currentContext)?.settings.name;
      if (currentRoute == '/dashboard' || currentRoute == '/') {
        print('🔄 Force refreshing dashboard...');
        firebaseService.triggerManualSync();
      }
    }
  });
}

void _handleNotificationData(Map<String, dynamic> data) {
  try {
    final title = data['title']?.toString() ?? 'KSMI Koperasi';
    final body = data['body']?.toString() ?? 'Pesan baru';
    
    print('📱 Notification received - Title: $title, Body: $body');
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scaffoldMessengerKey.currentState?.context != null) {
        scaffoldMessengerKey.currentState!.showSnackBar(
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
                _forceDashboardRefresh();
              },
            ),
          ),
        );
      }
    });
    
  } catch (e) {
    print('❌ Error handling notification data: $e');
  }
}

class KoperasiKSMIApp extends StatefulWidget {
  const KoperasiKSMIApp({super.key});

  @override
  State<KoperasiKSMIApp> createState() => _KoperasiKSMIAppState();
}

class _KoperasiKSMIAppState extends State<KoperasiKSMIApp> with WidgetsBindingObserver {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  bool _isLoggedIn = false;
  Map<String, dynamic> _userData = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAuthStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('📱 App lifecycle state: $state');
    
    if (state == AppLifecycleState.resumed) {
      print('🔄 App resumed, checking for updates...');
      _checkForBackgroundUpdates();
    }
  }

  Future<void> _checkForBackgroundUpdates() async {
    try {
      print('🔄 Checking for background updates...');
      await firebaseService.checkPendingNotifications();
      await firebaseService.triggerManualSync();
      print('✅ Background updates check completed');
    } catch (e) {
      print('❌ Error checking background updates: $e');
    }
  }

  Future<void> _checkAuthStatus() async {
    try {
      print('🔐 Checking authentication status...');
      
      final isLoggedIn = await _apiService.isLoggedIn();
      print('🔐 Login status: $isLoggedIn');
      
      if (isLoggedIn) {
        final userData = await _apiService.getCurrentUser();
        
        if (userData != null && userData.isNotEmpty) {
          setState(() {
            _isLoggedIn = true;
            _userData = userData;
          });
          await _subscribeToUserTopics(userData);
        } else {
          await _handleLogout();
        }
      } else {
        setState(() {
          _isLoggedIn = false;
          _userData = {};
        });
      }
    } catch (e) {
      print('❌ Error checking auth status: $e');
      setState(() {
        _isLoggedIn = false;
        _userData = {};
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      print('🔐 Auth check completed. Loading: $_isLoading, Logged in: $_isLoggedIn');
    }
  }

  Future<void> _subscribeToUserTopics(Map<String, dynamic> userData) async {
    try {
      final userId = userData['user_id']?.toString() ?? userData['id']?.toString();
      if (userId != null && userId.isNotEmpty) {
        print('🔔 Subscribing to topics for user: $userId');
        await firebaseService.subscribeToTopic('user_$userId');
        await firebaseService.subscribeToTopic('koperasi_ksmi');
        print('✅ Subscribed to topics successfully');
      }
    } catch (e) {
      print('❌ ERROR subscribing to topics: $e');
    }
  }

  void _handleLoginSuccess(Map<String, dynamic> userData) {
    print('🎉 Login success callback triggered');
    
    setState(() {
      _isLoggedIn = true;
      _userData = userData;
    });
    
    _subscribeToUserTopics(userData);
    
    // ✅ REFRESH UI UNTUK MENAMPILKAN SCREEN YANG BENAR
    if (mounted) {
      setState(() {});
    }
    
    print('🎯 Login success handled, UI will refresh automatically');
  }

  Future<void> _handleLogout() async {
    try {
      print('🚪 Handling logout...');
      
      setState(() => _isLoading = true);
      
      final userId = _userData['user_id']?.toString() ?? _userData['id']?.toString();
      if (userId != null && userId.isNotEmpty) {
        try {
          await firebaseService.unsubscribeFromTopic('user_$userId');
          print('🔔 Unsubscribed from user topic');
        } catch (e) {
          print('❌ Error unsubscribing from topic: $e');
        }
      }
      
      try {
        await Workmanager().cancelByTag("inbox-sync-task");
        print('✅ Background tasks cancelled');
      } catch (e) {
        print('⚠️ Error cancelling background tasks: $e');
      }
      
      final logoutResult = await _apiService.logout();
      print('🔐 Logout API result: ${logoutResult['success']}');
      
      setState(() {
        _isLoggedIn = false;
        _userData = {};
      });
      
    } catch (e) {
      print('❌ Error during logout: $e');
      setState(() {
        _isLoading = false;
        _isLoggedIn = false;
        _userData = {};
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    print('''
🏗️ Building app:
  - Loading: $_isLoading
  - Logged in: $_isLoggedIn
  - User Data: ${_userData.isNotEmpty ? 'Available' : 'Empty'}
  - User Status: ${_userData['status_user'] ?? 'N/A'}
''');
    
    return MaterialApp(
      title: 'Koperasi KSMI',
      debugShowCheckedModeBanner: false,
      theme: _buildAppTheme(),
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,
      home: _isLoading
          ? _buildLoadingScreen()
          : _isLoggedIn
              ? _buildHomeScreen()
              : LoginScreen(onLoginSuccess: _handleLoginSuccess),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.green[50],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Colors.green[700],
            ),
            const SizedBox(height: 16),
            Text(
              'Memuat aplikasi...',
              style: TextStyle(
                color: Colors.green[700],
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ FIXED: Return Widget berdasarkan status user - TANPA NAVIGASI
  Widget _buildHomeScreen() {
    final statusUser = _userData['status_user']?.toString() ?? '0';
    final isVerified = statusUser == '1';
    
    // ✅ CEK STATUS DOKUMEN DENGAN VALIDASI YANG LEBIH BAIK
    final fotoKtp = _userData['foto_ktp']?.toString() ?? '';
    final fotoKk = _userData['foto_kk']?.toString() ?? '';
    final fotoDiri = _userData['foto_diri']?.toString() ?? '';
    final fotoBukti = _userData['foto_bukti']?.toString() ?? '';
    
    final hasUploadedDocuments = _isDocumentValid(fotoKtp) && 
                                _isDocumentValid(fotoKk) && 
                                _isDocumentValid(fotoDiri) && 
                                _isDocumentValid(fotoBukti);

    print('''
🏠 Home Screen Decision:
  - Status User: $statusUser
  - Verified: $isVerified
  - Documents Uploaded: $hasUploadedDocuments
  - KTP: ${_isDocumentValid(fotoKtp)} ($fotoKtp)
  - KK: ${_isDocumentValid(fotoKk)} ($fotoKk)
  - Diri: ${_isDocumentValid(fotoDiri)} ($fotoDiri)
  - Bukti: ${_isDocumentValid(fotoBukti)} ($fotoBukti)
''');

    if (isVerified) {
      print('📱 Returning DashboardMain');
      return DashboardMain(user: _userData);
    } else if (hasUploadedDocuments) {
      print('📱 Returning ProfileScreen (documents uploaded)');
      return ProfileScreen(user: _userData);
    } else {
      print('📱 Returning AktivasiAkunScreen (new user)');
      return AktivasiAkunScreen(user: _userData);
    }
  }

  // ✅ HELPER: Validasi dokumen yang lebih akurat
  bool _isDocumentValid(String documentUrl) {
    if (documentUrl.isEmpty || 
        documentUrl == 'null' || 
        documentUrl == 'uploaded' ||
        documentUrl.trim().isEmpty) {
      return false;
    }
    
    // Cek jika mengandung ekstensi gambar
    return documentUrl.toLowerCase().contains('.jpg') ||
           documentUrl.toLowerCase().contains('.jpeg') ||
           documentUrl.toLowerCase().contains('.png');
  }

  ThemeData _buildAppTheme() {
    return ThemeData(
      primaryColor: Colors.green[800],
      primarySwatch: Colors.green,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.green[800]!,
        primary: Colors.green[800]!,
        secondary: Colors.greenAccent[400]!,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        elevation: 4,
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.green[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.green[600]!, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green[700],
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      useMaterial3: true,
    );
  }
}
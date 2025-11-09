import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_main.dart';
import 'screens/upload_dokumen_screen.dart';
import 'services/api_service.dart';
import 'services/firebase_service.dart';
import 'package:workmanager/workmanager.dart';

// Global keys
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = 
    GlobalKey<ScaffoldMessengerState>();

// Firebase Service Instance
final FirebaseService firebaseService = FirebaseService();

// ✅ WORKMANAGER CALLBACK DISPATCHER
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print("🔄 Native background task: $task");
    
    try {
      // Initialize Firebase untuk background task
      await Firebase.initializeApp();
      
      switch (task) {
        case 'inbox-sync-task':
          await firebaseService.triggerManualSync();
          print("✅ Background inbox sync completed");
          break;
          
        case 'notification-check-task':
          await firebaseService.checkPendingNotifications();
          print("✅ Background notification check completed");
          break;
          
        default:
          print("⚠️ Unknown background task: $task");
      }
      
      return true;
    } catch (e) {
      print("❌ Background task failed: $e");
      return false;
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('🚀 STARTING KOPERASI KSMI APP...');
  
  // ✅ INITIALIZE WORKMANAGER UNTUK BACKGROUND SYNC
  try {
    print('🔄 Initializing WorkManager for background sync...');
    Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: true, // Set false untuk production
    );
    print('✅ WorkManager initialized successfully');
  } catch (e) {
    print('❌ WorkManager initialization failed: $e');
  }
  
  // Initialize SharedPreferences
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  print('✅ SharedPreferences initialized');
  
  // Initialize Firebase Core
  try {
    print('🔥 Initializing Firebase Core...');
    await Firebase.initializeApp();
    print('✅ Firebase Core initialized successfully');
  } catch (e) {
    print('❌ Firebase Core initialization failed: $e');
  }
  
  // Initialize App Services
  await _initializeAppServices();
  
  runApp(const KoperasiKSMIApp());
}

// Initialize App Services
Future<void> _initializeAppServices() async {
  try {
    print('🔄 Initializing app services...');
    
    // Initialize Firebase Services
    await _initializeFirebaseServices();
    
    // ✅ REGISTER BACKGROUND TASKS
    await _registerBackgroundTasks();
    
    print('✅ All app services initialized successfully');
  } catch (e) {
    print('❌ ERROR Initializing App Services: $e');
  }
}

// ✅ REGISTER BACKGROUND TASKS
Future<void> _registerBackgroundTasks() async {
  try {
    print('🔄 Registering background tasks...');
    
    // Periodic sync setiap 15 menit untuk inbox data
    await Workmanager().registerPeriodicTask(
      "inbox-sync-task",
      "inbox-sync-task",
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      initialDelay: const Duration(seconds: 10),
    );
    
    // Periodic check untuk pending notifications setiap 30 menit
    await Workmanager().registerPeriodicTask(
      "notification-check-task", 
      "notification-check-task",
      frequency: const Duration(minutes: 30),
      initialDelay: const Duration(seconds: 30),
    );
    
    print('✅ Background tasks registered successfully');
  } catch (e) {
    print('❌ Error registering background tasks: $e');
  }
}

// Initialize Firebase Services
Future<void> _initializeFirebaseServices() async {
  try {
    print('🔄 Initializing Firebase Services...');
    await firebaseService.initialize();
    _setupNotificationCallbacks();
    
    // ✅ CHECK PENDING NOTIFICATIONS SAAT APP DIBUKA
    await firebaseService.checkPendingNotifications();
    
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
  
  // ✅ ADD REAL-TIME UNREAD COUNT CALLBACK
  FirebaseService.onUnreadCountUpdated = (int unreadCount) {
    _handleUnreadCountUpdate(unreadCount);
  };
}

// ✅ HANDLE REAL-TIME UNREAD COUNT UPDATES
void _handleUnreadCountUpdate(int unreadCount) {
  print('📱 Real-time unread count update: $unreadCount');
  
  // Bisa digunakan untuk update badge di home screen (jika menggunakan)
  // Atau trigger global state update
}

void _handleNotificationNavigation(Map<String, dynamic> data) {
  try {
    final type = data['type']?.toString() ?? '';
    final id = data['id']?.toString() ?? '';
    final screen = data['screen']?.toString() ?? '';
    
    print('📱 Notification tapped - Type: $type, ID: $id, Screen: $screen');
    
    // Navigation berdasarkan notification type
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigatorKey.currentState?.context != null) {
        switch (screen) {
          case 'inbox':
          case 'notifikasi':
            navigatorKey.currentState!.pushNamed('/inbox');
            break;
          case 'transaction':
          case 'transaksi':
            navigatorKey.currentState!.pushNamed('/transaction', arguments: {'id': id});
            break;
          case 'tabungan':
            navigatorKey.currentState!.pushNamed('/tabungan');
            break;
          case 'angsuran':
          case 'taqsith':
            navigatorKey.currentState!.pushNamed('/angsuran');
            break;
          case 'profile':
          case 'profil':
            navigatorKey.currentState!.pushNamed('/profile');
            break;
          default:
            // ✅ FORCE REFRESH DASHBOARD JIKA SEDANG AKTIF
            _forceDashboardRefresh();
            break;
        }
      }
    });
    
  } catch (e) {
    print('❌ Error handling notification navigation: $e');
  }
}

// ✅ FORCE DASHBOARD REFRESH
void _forceDashboardRefresh() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final currentContext = navigatorKey.currentState?.context;
    if (currentContext != null) {
      // Cek jika dashboard sedang aktif, trigger refresh
      final currentRoute = ModalRoute.of(currentContext)?.settings.name;
      if (currentRoute == '/dashboard' || currentRoute == '/') {
        print('🔄 Force refreshing dashboard...');
        // Bisa menggunakan event bus, provider, atau method channel
        // Untuk sekarang kita trigger manual sync
        firebaseService.triggerManualSync();
      }
    }
  });
}

void _handleNotificationData(Map<String, dynamic> data) {
  try {
    final title = data['title']?.toString() ?? 'KSMI Koperasi';
    final body = data['body']?.toString() ?? 'Pesan baru';
    final type = data['type']?.toString() ?? '';
    
    print('📱 Notification received - Title: $title, Body: $body, Type: $type');
    
    // Tampilkan snackbar
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
    
    // ✅ OBSERVE APP LIFECYCLE UNTUK BACKGROUND/FOREGROUND
    WidgetsBinding.instance.addObserver(this);
    
    _checkAuthStatus();
  }

  @override
  void dispose() {
    // ✅ REMOVE OBSERVER
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ✅ APP LIFECYCLE OBSERVER
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('📱 App lifecycle state: $state');
    
    switch (state) {
      case AppLifecycleState.resumed:
        // App kembali ke foreground
        print('🔄 App resumed, checking for updates...');
        _checkForBackgroundUpdates();
        break;
        
      case AppLifecycleState.paused:
        // App masuk background
        print('⏸️ App paused, ensuring background sync...');
        _ensureBackgroundSync();
        break;
        
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // States lainnya
        break;
    }
  }

  // ✅ CHECK FOR BACKGROUND UPDATES SAAT APP RESUME
  Future<void> _checkForBackgroundUpdates() async {
    try {
      print('🔄 Checking for background updates...');
      
      // Check pending notifications
      await firebaseService.checkPendingNotifications();
      
      // Trigger manual sync untuk data terbaru
      await firebaseService.triggerManualSync();
      
      print('✅ Background updates check completed');
    } catch (e) {
      print('❌ Error checking background updates: $e');
    }
  }

  // ✅ ENSURE BACKGROUND SYNC SAAT APP PAUSED
  Future<void> _ensureBackgroundSync() async {
    try {
      print('🔄 Ensuring background sync is active...');
      
      // WorkManager sudah handle periodic tasks
      // Kita bisa trigger immediate sync jika perlu
      if (_isLoggedIn) {
        Workmanager().registerOneOffTask(
          "immediate-sync-task",
          "inbox-sync-task",
          initialDelay: const Duration(seconds: 5),
        );
      }
      
      print('✅ Background sync ensured');
    } catch (e) {
      print('❌ Error ensuring background sync: $e');
    }
  }

  Future<void> _checkAuthStatus() async {
    try {
      print('🔐 Checking authentication status...');
      
      final isLoggedIn = await _apiService.isLoggedIn();
      print('🔐 Login status: $isLoggedIn');
      
      if (isLoggedIn) {
        final userData = await _apiService.getCurrentUser();
        print('🔐 User data loaded: ${userData != null && userData.isNotEmpty}');
        
        if (userData != null && userData.isNotEmpty) {
          setState(() {
            _isLoggedIn = true;
            _userData = userData;
          });
          await _subscribeToUserTopics(userData);
        } else {
          print('❌ User data empty or null, forcing logout');
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
        
        // Subscribe ke topic user spesifik dan topic umum
        await firebaseService.subscribeToTopic('user_$userId');
        await firebaseService.subscribeToTopic('koperasi_ksmi');
        await firebaseService.subscribeToTopic('all_users');
        
        print('✅ Subscribed to topics successfully for user: $userId');
      } else {
        print('⚠️ User ID not found, skipping topic subscription');
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
    _checkDokumenStatusAndNavigate(userData);
  }

  void _checkDokumenStatusAndNavigate(Map<String, dynamic> userData) {
    try {
      print('📄 Checking document status for navigation...');
      
      final fotoKtp = userData['foto_ktp']?.toString() ?? '';
      final fotoKk = userData['foto_kk']?.toString() ?? '';
      final fotoDiri = userData['foto_diri']?.toString() ?? '';
      
      final bool hasKTP = fotoKtp.isNotEmpty && fotoKtp != 'uploaded' && fotoKtp != 'null';
      final bool hasKK = fotoKk.isNotEmpty && fotoKk != 'uploaded' && fotoKk != 'null';
      final bool hasFotoDiri = fotoDiri.isNotEmpty && fotoDiri != 'uploaded' && fotoDiri != 'null';
      
      final bool allDokumenUploaded = hasKTP && hasKK && hasFotoDiri;
      
      print('''
📄 Document Status Check:
  - KTP: $hasKTP ($fotoKtp)
  - KK: $hasKK ($fotoKk)  
  - Foto Diri: $hasFotoDiri ($fotoDiri)
  - All Complete: $allDokumenUploaded
''');
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && navigatorKey.currentState?.context != null) {
          if (!allDokumenUploaded) {
            print('📱 Navigating to UploadDokumenScreen');
            navigatorKey.currentState!.pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => UploadDokumenScreen(user: userData),
              ),
              (route) => false,
            );
          } else {
            print('📱 Navigating directly to Dashboard');
            _navigateToDashboard(userData);
          }
        }
      });
    } catch (e) {
      print('❌ Error checking document status: $e');
      _navigateToDashboard(userData);
    }
  }

  void _navigateToDashboard(Map<String, dynamic> userData) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && navigatorKey.currentState?.context != null) {
        navigatorKey.currentState!.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => DashboardMain(user: userData),
          ),
          (route) => false,
        );
      }
    });
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
      
      // ✅ CANCEL BACKGROUND TASKS SAAT LOGOUT
      try {
        await Workmanager().cancelByTag("inbox-sync-task");
        await Workmanager().cancelByTag("notification-check-task");
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
      
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          _navigateToLogin();
        }
      });
      
    } catch (e) {
      print('❌ Error during logout: $e');
      
      setState(() {
        _isLoading = false;
        _isLoggedIn = false;
        _userData = {};
      });
      
      _navigateToLogin();
    }
  }

  void _navigateToLogin() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && navigatorKey.currentState?.context != null) {
        navigatorKey.currentState!.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => LoginScreen(onLoginSuccess: _handleLoginSuccess),
          ),
          (route) => false,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    print('🏗️ Building app - Loading: $_isLoading, Logged in: $_isLoggedIn');
    
    return MaterialApp(
      title: 'Koperasi KSMI',
      debugShowCheckedModeBanner: false,
      theme: _buildAppTheme(),
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,
      
      routes: {
        '/login': (context) => LoginScreen(onLoginSuccess: _handleLoginSuccess),
        '/dashboard': (context) => DashboardMain(user: _userData),
        '/upload_dokumen': (context) => UploadDokumenScreen(user: _userData),
      },
      
      onGenerateRoute: (settings) {
        print('🔄 Generating route for: ${settings.name}');
        
        return MaterialPageRoute(
          builder: (context) => _isLoggedIn 
              ? DashboardMain(user: _userData)
              : LoginScreen(onLoginSuccess: _handleLoginSuccess),
        );
      },
      
      home: _isLoading
          ? _buildLoadingScreen()
          : _isLoggedIn
              ? DashboardMain(user: _userData)
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
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.green[800],
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.account_balance_wallet,
                color: Colors.white,
                size: 50,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Koperasi KSMI',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Menghubungkan ke server...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.green[600],
              ),
            ),
            const SizedBox(height: 24),
            CircularProgressIndicator(
              color: Colors.green[700],
              strokeWidth: 3,
            ),
            const SizedBox(height: 16),
            Text(
              'Memeriksa status login...',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  ThemeData _buildAppTheme() {
    return ThemeData(
      primaryColor: Colors.green[800],
      primarySwatch: Colors.green,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.green[800]!,
        primary: Colors.green[800]!,
        secondary: Colors.greenAccent[400]!,
        background: Colors.green[50]!,
      ),
      scaffoldBackgroundColor: Colors.green[50],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        elevation: 4,
        shadowColor: Colors.green.withOpacity(0.5),
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
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
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.green[300]!),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: TextStyle(color: Colors.grey[700]),
        hintStyle: TextStyle(color: Colors.grey[500]),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green[700],
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      useMaterial3: true,
    );
  }
}
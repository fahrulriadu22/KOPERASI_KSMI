import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'system_notifier.dart';
import 'package:workmanager/workmanager.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  // Firebase instances
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Service instances
  final ApiService _apiService = ApiService();
  final SystemNotifier systemNotifier = SystemNotifier();

  // Constants
  static const String baseUrl = 'http://demo.bsdeveloper.id/api';

  // Notification channels
  static const String _channelId = 'ksmi_channel_id';
  static const String _channelName = 'KSMI Koperasi';
  static const String _channelDescription = 'Channel untuk notifikasi Koperasi KSMI';

  // ✅ REAL-TIME STREAMS
  final StreamController<Map<String, dynamic>> _notificationStreamController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<int> _unreadCountStreamController = 
      StreamController<int>.broadcast();
  final StreamController<List<Map<String, dynamic>>> _inboxDataStreamController =
      StreamController<List<Map<String, dynamic>>>.broadcast();

  // Getter untuk streams
  Stream<Map<String, dynamic>> get notificationStream => _notificationStreamController.stream;
  Stream<int> get unreadCountStream => _unreadCountStreamController.stream;
  Stream<List<Map<String, dynamic>>> get inboxDataStream => _inboxDataStreamController.stream;

  // Callback functions
  static Function(Map<String, dynamic>)? onNotificationTap;
  static Function(Map<String, dynamic>)? onNotificationReceived;
  static Function(int)? onUnreadCountUpdated;

  // Track initialization status
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // Track last unread count
  int _lastUnreadCount = 0;

  // ✅ PERIODIC SYNC TIMER
  Timer? _syncTimer;
  Timer? _inboxSyncTimer;

  // ✅ INITIALIZE FIREBASE SERVICES DENGAN REAL-TIME FEATURES
  Future<void> initialize() async {
    try {
      if (_isInitialized) {
        print('✅ FirebaseService already initialized');
        return;
      }

      print('🚀 INITIALIZING FIREBASE SERVICES WITH REAL-TIME FCM...');

      // 1. Initialize Firebase Core
      print('🔥 Initializing Firebase Core...');
      await Firebase.initializeApp();
      print('✅ Firebase Core initialized');

      // 2. Initialize SystemNotifier
      print('🔄 Initializing SystemNotifier...');
      await systemNotifier.initialize();
      print('✅ SystemNotifier initialized');

      // 3. Setup FCM Token & Messaging
      print('🔄 Setting up FCM...');
      await _setupFCM();
      print('✅ FCM setup completed');

      // 4. Load Initial Inbox Data
      print('🔄 Loading initial inbox data...');
      await _loadInitialInboxData();
      print('✅ Initial inbox data loaded');

      // 5. Start Periodic Sync
      print('🔄 Starting periodic sync...');
      await _startPeriodicSync();
      print('✅ Periodic sync started');

      _isInitialized = true;
      print('🎉 FIREBASE SERVICES WITH REAL-TIME FCM INITIALIZED SUCCESSFULLY!');

    } catch (e) {
      print('❌ ERROR Initializing Firebase Services: $e');
      _isInitialized = false;
    }
  }

  // ✅ SETUP FCM TOKEN & MESSAGING DENGAN REAL-TIME HANDLERS
  Future<void> _setupFCM() async {
    try {
      // Request permission
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      print('📱 Notification Permission: ${settings.authorizationStatus}');

      // Get FCM token
      String? token = await _firebaseMessaging.getToken();
      print('🔑 FCM Token: $token');

      // Save token to server
      if (token != null && token.isNotEmpty) {
        await _saveFCMTokenToServer(token);
      }

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) async {
        print('🔄 FCM Token Refreshed: $newToken');
        await _saveFCMTokenToServer(newToken);
      });

      // Setup message handlers dengan real-time features
      await _setupRealTimeMessageHandlers();

    } catch (e) {
      print('❌ ERROR setting up FCM: $e');
    }
  }

  // ✅ ADD BACKGROUND SYNC WITH WORKMANAGER
void _setupBackgroundSync() {
  Workmanager().initialize(
    _backgroundCallbackDispatcher,
    isInDebugMode: true,
  );
  
  // Register periodic background task (setiap 15 menit)
  Workmanager().registerPeriodicTask(
    "inbox-sync-task",
    "inboxSyncBackground",
    frequency: const Duration(minutes: 15),
    constraints: Constraints(
      networkType: NetworkType.connected,
    ),
  );
}

// ✅ BACKGROUND CALLBACK DISPATCHER
@pragma('vm:entry-point')
static void _backgroundCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print("🔄 Background sync running: $task");
    
    try {
      await Firebase.initializeApp();
      final service = FirebaseService();
      await service._syncInboxData();
      await service._syncUnreadCount();
      
      print("✅ Background sync completed");
      return true;
    } catch (e) {
      print("❌ Background sync failed: $e");
      return false;
    }
  });
}


  // ✅ SETUP REAL-TIME MESSAGE HANDLERS
  Future<void> _setupRealTimeMessageHandlers() async {
    try {
      // Handle background messages dengan real-time update
      FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

      // Handle foreground messages dengan stream
      FirebaseMessaging.onMessage.listen(_firebaseForegroundHandler);

      // Handle when app is opened from terminated state
      FirebaseMessaging.instance.getInitialMessage().then(_handleInitialMessage);

      // Handle when app is in background and opened via notification
      FirebaseMessaging.onMessageOpenedApp.listen(_firebaseBackgroundOpenedHandler);

      print('✅ REAL-TIME FCM message handlers registered');

    } catch (e) {
      print('❌ ERROR setting up real-time FCM message handlers: $e');
    }
  }

// ✅ PERBAIKI BACKGROUND HANDLER UNTUK AUTO-SYNC
@pragma('vm:entry-point')
static Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('📱 FCM BACKGROUND MESSAGE: ${message.data}');
  
  // ✅ AUTO SYNC DATA MESKI APP DI BACKGROUND
  final service = FirebaseService();
  await service._syncInboxData();
  await service._syncUnreadCount();
  
  // Simpan data notifikasi untuk dibuka nanti
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('pending_notification', jsonEncode({
    'title': message.notification?.title,
    'body': message.notification?.body,
    'data': message.data,
    'timestamp': DateTime.now().millisecondsSinceEpoch,
  }));
  
  // Tampilkan system notification
  await _showSystemNotificationFromFCM(message);
}

// ✅ CHECK PENDING NOTIFICATIONS SAAT APP DIBUKA
Future<void> checkPendingNotifications() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final pendingNotification = prefs.getString('pending_notification');
    
    if (pendingNotification != null) {
      final notificationData = jsonDecode(pendingNotification);
      
      // Trigger stream update
      _notificationStreamController.add(notificationData);
      
      // Clear pending notification
      await prefs.remove('pending_notification');
      
      print('✅ Processed pending notification');
    }
  } catch (e) {
    print('❌ Error checking pending notifications: $e');
  }
}

  // ✅ REAL-TIME FOREGROUND MESSAGE HANDLER
  static Future<void> _firebaseForegroundHandler(RemoteMessage message) async {
    print('📱 FCM FOREGROUND MESSAGE: ${message.data}');
    
    final notificationData = {
      'title': message.notification?.title ?? 'KSMI Koperasi',
      'body': message.notification?.body ?? 'Pesan baru',
      'data': message.data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'type': 'foreground',
      'messageId': message.messageId,
    };
    
    // ✅ KIRIM KE STREAM UNTUK REAL-TIME UPDATE
    _instance._notificationStreamController.add(notificationData);
    
    // Auto-increment unread count
    final prefs = await SharedPreferences.getInstance();
    final currentCount = prefs.getInt('unread_notifications') ?? 0;
    final newCount = currentCount + 1;
    await prefs.setInt('unread_notifications', newCount);
    
    // ✅ KIRIM UPDATE UNREAD COUNT KE STREAM
    _instance._unreadCountStreamController.add(newCount);
    
    // Trigger inbox sync
    _instance._syncInboxData();
    
    // Notify callback
    if (onNotificationReceived != null) {
      onNotificationReceived!(notificationData);
    }
    
    // Tampilkan system notification
    await _showSystemNotificationFromFCM(message);
    
    print('✅ Foreground message processed, unread count: $newCount');
  }

  // ✅ HANDLE INITIAL MESSAGE
  static void _handleInitialMessage(RemoteMessage? message) {
    if (message != null) {
      print('📱 FCM INITIAL MESSAGE: ${message.data}');
      
      final notificationData = {
        'title': message.notification?.title ?? 'KSMI Koperasi',
        'body': message.notification?.body ?? 'Pesan baru',
        'data': message.data,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'type': 'initial',
        'messageId': message.messageId,
      };
      
      // Kirim ke stream
      _instance._notificationStreamController.add(notificationData);
      
      // Trigger callback
      if (onNotificationTap != null) {
        onNotificationTap!(notificationData);
      }
    }
  }

  // ✅ BACKGROUND OPENED HANDLER DENGAN REAL-TIME UPDATE
  static void _firebaseBackgroundOpenedHandler(RemoteMessage message) {
    print('📱 FCM BACKGROUND OPENED: ${message.data}');
    
    final notificationData = {
      'title': message.notification?.title ?? 'KSMI Koperasi',
      'body': message.notification?.body ?? 'Pesan baru',
      'data': message.data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'type': 'background_opened',
      'messageId': message.messageId,
    };
    
    // Kirim ke stream
    _instance._notificationStreamController.add(notificationData);
    
    // Trigger callback untuk navigation
    if (onNotificationTap != null) {
      onNotificationTap!(notificationData);
    }
    
    // Trigger inbox sync
    _instance._syncInboxData();
  }

  // ✅ SHOW SYSTEM NOTIFICATION DARI FCM
  static Future<void> _showSystemNotificationFromFCM(RemoteMessage message) async {
    try {
      final notifier = SystemNotifier();
      await notifier.initialize();
      
      await notifier.showSystemNotification(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: message.notification?.title ?? 'KSMI Koperasi',
        body: message.notification?.body ?? 'Pesan baru dari Koperasi KSMI',
      );
      
    } catch (e) {
      print('❌ ERROR showing FCM notification: $e');
    }
  }

  // ✅ START PERIODIC SYNC UNTUK REAL-TIME UPDATES
  Future<void> _startPeriodicSync() async {
    // Stop existing timers
    _syncTimer?.cancel();
    _inboxSyncTimer?.cancel();
    
    // Sync unread count setiap 30 detik
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      await _syncUnreadCount();
    });
    
    // Sync inbox data setiap 60 detik
    _inboxSyncTimer = Timer.periodic(const Duration(seconds: 60), (timer) async {
      await _syncInboxData();
    });
    
    print('✅ Periodic sync timers started');
  }

  // ✅ SYNC UNREAD COUNT
  Future<void> _syncUnreadCount() async {
    try {
      print('🔄 Syncing unread count...');
      final result = await getAllInbox();
      
      if (result['success'] == true) {
        final unreadCount = result['unread_count'] ?? 0;
        
        // Update shared preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('unread_notifications', unreadCount);
        
        // Update stream
        _unreadCountStreamController.add(unreadCount);
        
        // Update callback
        if (onUnreadCountUpdated != null) {
          onUnreadCountUpdated!(unreadCount);
        }
        
        print('✅ Unread count synced: $unreadCount');
      }
    } catch (e) {
      print('❌ Unread count sync error: $e');
    }
  }

  // ✅ SYNC INBOX DATA
  Future<void> _syncInboxData() async {
    try {
      print('🔄 Syncing inbox data...');
      final inboxData = await getRealInboxData();
      
      // Update stream dengan data terbaru
      _inboxDataStreamController.add(inboxData);
      
      print('✅ Inbox data synced: ${inboxData.length} items');
    } catch (e) {
      print('❌ Inbox data sync error: $e');
    }
  }

  // ✅ GET ALL INBOX DENGAN REAL-TIME UPDATES
  Future<Map<String, dynamic>> getAllInbox() async {
    try {
      final headers = await getProtectedHeaders();

      final response = await http.post(
        Uri.parse('$baseUrl/transaction/getAllinbox'),
        headers: headers,
        body: '',
      ).timeout(const Duration(seconds: 30));

      print('📡 Inbox Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['status'] == true) {
          final inboxData = data['data'] ?? {};
          final unreadCount = _calculateUnreadCount(inboxData);
          
          // ✅ TRIGGER SYSTEM NOTIFICATION JIKA ADA PESAN BARU
          if (unreadCount > _lastUnreadCount && unreadCount > 0) {
            await _triggerInboxNotification(unreadCount);
          }
          
          // ✅ UPDATE UNREAD COUNT STREAM
          _unreadCountStreamController.add(unreadCount);
          
          // ✅ UPDATE CALLBACK
          if (onUnreadCountUpdated != null) {
            onUnreadCountUpdated!(unreadCount);
          }
          
          _lastUnreadCount = unreadCount;
          
          return {
            'success': true,
            'data': inboxData,
            'message': data['message'] ?? 'Success get inbox',
            'unread_count': unreadCount,
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Gagal mengambil data inbox'
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Gagal mengambil data inbox: ${response.statusCode}'
        };
      }
    } catch (e) {
      print('❌ Inbox API Exception: $e');
      return {
        'success': false,
        'message': 'Error: $e'
      };
    }
  }

  // ✅ TRIGGER INBOX NOTIFICATION
  Future<void> _triggerInboxNotification(int currentUnreadCount) async {
    try {
      print('📧 Checking inbox: last=$_lastUnreadCount, current=$currentUnreadCount');
      
      final newMessagesCount = currentUnreadCount - _lastUnreadCount;
      
      if (newMessagesCount > 0) {
        print('🎯 New inbox messages: $newMessagesCount');
        
        await systemNotifier.showSystemNotification(
          id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
          title: newMessagesCount == 1 ? 'Pesan Baru - KSMI' : '$newMessagesCount Pesan Baru - KSMI',
          body: newMessagesCount == 1 
              ? 'Anda memiliki 1 pesan belum dibaca di inbox' 
              : 'Anda memiliki $newMessagesCount pesan belum dibaca di inbox',
        );
      }
      
    } catch (e) {
      print('❌ Error triggering inbox notification: $e');
    }
  }

  // ✅ CALCULATE UNREAD COUNT
  static int _calculateUnreadCount(Map<String, dynamic> inboxData) {
    try {
      final inboxList = inboxData['inbox'] ?? [];
      final unreadCount = inboxList.where((item) {
        if (item is Map<String, dynamic>) {
          final readStatus = item['read_status']?.toString() ?? '1';
          return readStatus == '0';
        }
        return false;
      }).length;
      
      print('✅ Unread count calculated: $unreadCount');
      return unreadCount;
    } catch (e) {
      print('❌ Error calculating unread count: $e');
      return 0;
    }
  }

  // ✅ GET PROTECTED HEADERS
  Future<Map<String, String>> getProtectedHeaders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userKey = prefs.getString('token');
      final sessionCookie = prefs.getString('ci_session');
      
      final headers = <String, String>{
        'DEVICE-ID': '12341231313131',
        'DEVICE-TOKEN': '1234232423424',
        'Content-Type': 'application/x-www-form-urlencoded',
      };
      
      if (userKey != null && userKey.isNotEmpty) {
        headers['x-api-key'] = userKey;
      }
      
      if (sessionCookie != null && sessionCookie.isNotEmpty) {
        headers['Cookie'] = 'ci_session=$sessionCookie';
      }
      
      return headers;
    } catch (e) {
      print('❌ Error getProtectedHeaders: $e');
      return {
        'DEVICE-ID': '12341231313131',
        'DEVICE-TOKEN': '1234232423424',
        'Content-Type': 'application/x-www-form-urlencoded',
      };
    }
  }

  // ✅ SAVE FCM TOKEN TO SERVER
  Future<void> _saveFCMTokenToServer(String token) async {
    try {
      print('💾 Saving FCM token to server: $token');
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', token);
      
      // Kirim token ke API Anda
      final currentUser = await _apiService.getCurrentUser();
      if (currentUser != null && currentUser.isNotEmpty) {
        final result = await _apiService.updateDeviceToken(token);
        if (result['success'] == true) {
          print('✅ FCM token saved to server successfully');
        } else {
          print('⚠️ Failed to save FCM token to server: ${result['message']}');
        }
      }
      
    } catch (e) {
      print('❌ ERROR saving FCM token: $e');
    }
  }

  // ✅ SUBSCRIBE TO TOPIC
  Future<void> subscribeToTopic(String topic) async {
    try {
      if (topic.isNotEmpty) {
        print('🔔 Subscribing to topic: $topic');
        await _firebaseMessaging.subscribeToTopic(topic);
        print('✅ Successfully subscribed to topic: $topic');
      } else {
        print('⚠️ Cannot subscribe to empty topic');
      }
    } catch (e) {
      print('❌ ERROR subscribing to topic $topic: $e');
      throw e;
    }
  }

  // ✅ UNSUBSCRIBE FROM TOPIC
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      if (topic.isNotEmpty) {
        print('🔔 Unsubscribing from topic: $topic');
        await _firebaseMessaging.unsubscribeFromTopic(topic);
        print('✅ Successfully unsubscribed from topic: $topic');
      } else {
        print('⚠️ Cannot unsubscribe from empty topic');
      }
    } catch (e) {
      print('❌ ERROR unsubscribing from topic $topic: $e');
      throw e;
    }
  }

  // ✅ SUBSCRIBE TO MULTIPLE TOPICS
  Future<void> subscribeToTopics(List<String> topics) async {
    try {
      for (final topic in topics) {
        if (topic.isNotEmpty) {
          await subscribeToTopic(topic);
        }
      }
      print('✅ Successfully subscribed to ${topics.length} topics');
    } catch (e) {
      print('❌ ERROR subscribing to multiple topics: $e');
      throw e;
    }
  }

  // ✅ UNSUBSCRIBE FROM MULTIPLE TOPICS
  Future<void> unsubscribeFromTopics(List<String> topics) async {
    try {
      for (final topic in topics) {
        if (topic.isNotEmpty) {
          await unsubscribeFromTopic(topic);
        }
      }
      print('✅ Successfully unsubscribed from ${topics.length} topics');
    } catch (e) {
      print('❌ ERROR unsubscribing from multiple topics: $e');
      throw e;
    }
  }

  // ✅ LOAD INITIAL INBOX DATA
  Future<void> _loadInitialInboxData() async {
    try {
      print('📥 Loading initial inbox data...');
      final result = await getAllInbox();
      
      if (result['success'] == true) {
        final inboxData = result['data'] ?? {};
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setString('last_inbox_data', jsonEncode(inboxData));
        await prefs.setInt('unread_notifications', result['unread_count'] ?? 0);
        
        print('✅ Initial inbox loaded: ${result['unread_count']} unread messages');
      }
    } catch (e) {
      print('❌ Error loading initial inbox data: $e');
    }
  }

  // ✅ MARK ALL NOTIFICATIONS AS READ
  Future<void> markAllNotificationsAsRead() async {
    try {
      print('📝 Marking all notifications as read...');
      
      // Update di SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('unread_notifications', 0);
      
      // Update last unread count
      _lastUnreadCount = 0;
      
      // Update stream
      _unreadCountStreamController.add(0);
      
      // Notify listeners
      if (onUnreadCountUpdated != null) {
        onUnreadCountUpdated!(0);
      }
      
      print('✅ All notifications marked as read');
    } catch (e) {
      print('❌ Error marking notifications as read: $e');
      throw e;
    }
  }

  // ✅ MARK SINGLE NOTIFICATION AS READ
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      print('📝 Marking notification $notificationId as read...');
      
      // Get current count
      final currentCount = await getUnreadNotificationsCount();
      if (currentCount > 0) {
        final newCount = currentCount - 1;
        
        // Update di SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('unread_notifications', newCount);
        
        // Update last unread count
        _lastUnreadCount = newCount;
        
        // Update stream
        _unreadCountStreamController.add(newCount);
        
        // Notify listeners
        if (onUnreadCountUpdated != null) {
          onUnreadCountUpdated!(newCount);
        }
        
        print('✅ Notification marked as read. New count: $newCount');
      }
    } catch (e) {
      print('❌ Error marking notification as read: $e');
      throw e;
    }
  }

  // ✅ UPDATE UNREAD COUNT MANUALLY
  Future<void> updateUnreadCount(int newCount) async {
    try {
      print('🔄 Updating unread count to: $newCount');
      
      // Update di SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('unread_notifications', newCount);
      
      // Update last unread count
      _lastUnreadCount = newCount;
      
      // Update stream
      _unreadCountStreamController.add(newCount);
      
      // Notify listeners
      if (onUnreadCountUpdated != null) {
        onUnreadCountUpdated!(newCount);
      }
      
      print('✅ Unread count updated to: $newCount');
    } catch (e) {
      print('❌ Error updating unread count: $e');
      throw e;
    }
  }

  // ✅ GET REAL INBOX DATA FOR POPUP
  Future<List<Map<String, dynamic>>> getRealInboxData() async {
    try {
      print('📥 Getting real inbox data for popup...');
      
      final result = await getAllInbox();
      
      if (result['success'] == true) {
        final inboxData = result['data'] ?? {};
        final inboxList = inboxData['inbox'] ?? [];
        
        // Convert to List<Map<String, dynamic>>
        List<Map<String, dynamic>> realInbox = [];
        
        for (var item in inboxList) {
          if (item is Map<String, dynamic>) {
            realInbox.add({
              'id': item['id']?.toString() ?? '',
              'subject': item['subject']?.toString() ?? '',
              'message': item['keterangan']?.toString() ?? '',
              'time': _formatTimeAgo(item['date_created']?.toString() ?? ''),
              'isUnread': (item['read_status']?.toString() ?? '1') == '0',
              'date_created': item['date_created']?.toString() ?? '',
            });
          }
        }
        
        // Sort by date (newest first)
        realInbox.sort((a, b) => b['date_created'].compareTo(a['date_created']));
        
        print('✅ Real inbox data loaded: ${realInbox.length} items');
        return realInbox;
      }
      
      return [];
    } catch (e) {
      print('❌ Error getting real inbox data: $e');
      return [];
    }
  }

  // ✅ FORMAT TIME AGO
  String _formatTimeAgo(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inMinutes < 1) return 'Baru saja';
      if (difference.inMinutes < 60) return '${difference.inMinutes} menit lalu';
      if (difference.inHours < 24) return '${difference.inHours} jam lalu';
      if (difference.inDays < 7) return '${difference.inDays} hari lalu';
      
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  // ✅ REFRESH INBOX DATA
  Future<Map<String, dynamic>> refreshInboxData() async {
    return await getAllInbox();
  }

  // ✅ GET CURRENT UNREAD COUNT
  Future<int> getUnreadNotificationsCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('unread_notifications') ?? 0;
    } catch (e) {
      print('❌ Error getting unread count: $e');
      return 0;
    }
  }

  // ✅ GET FCM TOKEN
  Future<String?> getFCMToken() async {
    try {
      return await _firebaseMessaging.getToken();
    } catch (e) {
      print('❌ ERROR getting FCM token: $e');
      return null;
    }
  }

  // ✅ TEST SYSTEM NOTIFICATIONS
  Future<void> testSystemNotifications() async {
    try {
      await systemNotifier.testBasicNotification();
    } catch (e) {
      print('❌ System notification test failed: $e');
    }
  }

  // ✅ MANUAL SYNC TRIGGER
  Future<void> triggerManualSync() async {
    await _syncUnreadCount();
    await _syncInboxData();
  }

  // ✅ STOP PERIODIC SYNC
  void stopPeriodicSync() {
    _syncTimer?.cancel();
    _inboxSyncTimer?.cancel();
    _syncTimer = null;
    _inboxSyncTimer = null;
    print('🛑 Periodic sync stopped');
  }

  // ✅ GET CURRENT UNREAD COUNT (SYNC)
  int getCurrentUnreadCount() {
    return _lastUnreadCount;
  }

  // ✅ DISPOSE
  void dispose() {
    print('🧹 Firebase Service disposed');
    stopPeriodicSync();
    _notificationStreamController.close();
    _unreadCountStreamController.close();
    _inboxDataStreamController.close();
    _isInitialized = false;
  }
}

// Global instance
final firebaseService = FirebaseService();
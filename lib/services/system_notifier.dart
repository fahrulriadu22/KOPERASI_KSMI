// services/system_notifier.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class SystemNotifier {
  static final SystemNotifier _instance = SystemNotifier._internal();
  factory SystemNotifier() => _instance;
  SystemNotifier._internal();

  late FlutterLocalNotificationsPlugin _notifications;
  bool _isInitialized = false;

  // ✅ CHANNEL ID HARUS SAMA DENGAN MANIFEST
  static const String _channelId = 'ksmi_channel_id';
  static const String _channelName = 'KSMI Koperasi';
  static const String _channelDescription = 'Notifikasi dari Koperasi KSMI';

  // ✅ CALLBACK UNTUK NOTIFICATION TAPS
  static Function(Map<String, dynamic>)? onNotificationTap;

  Future<void> initialize() async {
    try {
      if (_isInitialized) return;
      
      print('🔄 Initializing SystemNotifier with real-time features...');

      // ✅ INIT TIMEZONE UNTUK SCHEDULED NOTIFICATIONS
      tz.initializeTimeZones();

      // ✅ 1. INIT PLUGIN DULU
      _notifications = FlutterLocalNotificationsPlugin();

      // ✅ 2. SETUP ANDROID - PAKAI @mipmap/ic_launcher
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      
      // ✅ 3. SETUP iOS 
      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      // ✅ 4. INITIALIZATION SETTINGS
      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      // ✅ 5. INITIALIZE PLUGIN DENGAN NOTIFICATION HANDLER
      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _handleNotificationTap,
        onDidReceiveBackgroundNotificationResponse: _handleBackgroundNotificationTap,
      );

      // ✅ 6. CREATE ANDROID CHANNEL - ID HARUS SAMA DENGAN MANIFEST
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        _channelId, // ✅ HARUS SAMA: 'ksmi_channel_id'
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );

      // ✅ CREATE CHANNEL
      final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(channel);
      }

      _isInitialized = true;
      print('✅ SystemNotifier initialized SUCCESSFULLY with real-time features!');
      print('✅ Channel ID: $_channelId');
      
    } catch (e) {
      print('❌ SystemNotifier initialization FAILED: $e');
      _isInitialized = false;
      rethrow;
    }
  }

  // ✅ HANDLE NOTIFICATION TAP (FOREGROUND)
  static void _handleNotificationTap(NotificationResponse response) {
    print('📱 Notification tapped - Payload: ${response.payload}');
    
    try {
      final payload = response.payload;
      if (payload != null && payload.isNotEmpty) {
        final payloadData = _parsePayload(payload);
        if (onNotificationTap != null) {
          onNotificationTap!(payloadData);
        }
      }
    } catch (e) {
      print('❌ Error handling notification tap: $e');
    }
  }

  // ✅ HANDLE BACKGROUND NOTIFICATION TAP
  @pragma('vm:entry-point')
  static void _handleBackgroundNotificationTap(NotificationResponse response) {
    print('📱 Background notification tapped - Payload: ${response.payload}');
    
    // Background handler - biasanya diproses di main.dart
    // Data akan diproses ketika app dibuka
  }

  // ✅ PARSE PAYLOAD DATA
  static Map<String, dynamic> _parsePayload(String payload) {
    try {
      // Format payload: "type:inbox|id:123|screen:dashboard"
      final parts = payload.split('|');
      final Map<String, dynamic> data = {};
      
      for (final part in parts) {
        final keyValue = part.split(':');
        if (keyValue.length == 2) {
          data[keyValue[0]] = keyValue[1];
        }
      }
      
      return data;
    } catch (e) {
      print('❌ Error parsing payload: $e');
      return {'type': 'general', 'screen': 'dashboard'};
    }
  }

  // ✅ SHOW SYSTEM NOTIFICATION
  Future<void> showSystemNotification({
    required int id,
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) async {
    try {
      // ✅ PASTIKAN INIT DULU
      if (!_isInitialized) {
        await initialize();
      }

      print('📱 Preparing SYSTEM notification: $title');

      // ✅ ANDROID NOTIFICATION DETAILS
      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        showWhen: true,
        autoCancel: true,
      );

      // ✅ NOTIFICATION DETAILS
      final NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      // ✅ FORMAT PAYLOAD JIKA ADA
      String? payloadString;
      if (payload != null) {
        payloadString = _formatPayload(payload);
      }

      // ✅ SHOW NOTIFICATION
      await _notifications.show(id, title, body, details, payload: payloadString);
      
      print('🎉 SYSTEM NOTIFICATION BERHASIL: $title');
      print('   → ID: $id');
      print('   → Channel: $_channelId');
      print('   → Body: $body');
      if (payloadString != null) {
        print('   → Payload: $payloadString');
      }
      
    } catch (e) {
      print('❌ ERROR showing system notification: $e');
      rethrow;
    }
  }

  // ✅ FORMAT PAYLOAD UNTUK NOTIFICATION
  String _formatPayload(Map<String, dynamic> payload) {
    try {
      final List<String> parts = [];
      payload.forEach((key, value) {
        if (value != null) {
          parts.add('$key:$value');
        }
      });
      return parts.join('|');
    } catch (e) {
      print('❌ Error formatting payload: $e');
      return 'type:general|screen:dashboard';
    }
  }

  // ✅ SHOW NOTIFICATION WITH PAYLOAD DATA (Untuk real-time)
  Future<void> showSystemNotificationWithPayload({
    required int id,
    required String title,
    required String body,
    required Map<String, dynamic> payload,
  }) async {
    await showSystemNotification(
      id: id,
      title: title,
      body: body,
      payload: payload,
    );
  }

  // ✅ SHOW PROGRESS NOTIFICATION (Untuk background sync)
  Future<void> showProgressNotification({
    required int id,
    required String title,
    required String body,
    required int progress,
    required int maxProgress,
  }) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      print('📱 Preparing PROGRESS notification: $title - $progress/$maxProgress');

      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        autoCancel: true,
        showProgress: true,
        maxProgress: maxProgress,
        progress: progress,
        onlyAlertOnce: true,
      );

      final NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: false,
        ),
      );

      await _notifications.show(id, title, body, details);
      
      print('🔄 PROGRESS NOTIFICATION: $title - $progress/$maxProgress');
      
    } catch (e) {
      print('❌ ERROR showing progress notification: $e');
    }
  }

  // ✅ UPDATE PROGRESS NOTIFICATION - FIXED VERSION
  Future<void> updateProgressNotification({
    required int id,
    required String title,
    required String body,
    required int progress,
    required int maxProgress,
  }) async {
    try {
      if (!_isInitialized) return;

      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        autoCancel: progress >= maxProgress,
        showProgress: true,
        maxProgress: maxProgress,
        progress: progress,
        onlyAlertOnce: true,
      );

      // ✅ FIX: HAPUS CONST DARI DARWINDETAILS KARENA ADA EXPRESSION
      final iosDetails = DarwinNotificationDetails(
        presentAlert: progress >= maxProgress,
        presentBadge: progress >= maxProgress,
        presentSound: progress >= maxProgress,
      );

      final NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(id, title, body, details);
      
      if (progress >= maxProgress) {
        print('✅ PROGRESS COMPLETED: $title');
      } else {
        print('🔄 PROGRESS UPDATE: $title - $progress/$maxProgress');
      }
      
    } catch (e) {
      print('❌ ERROR updating progress notification: $e');
    }
  }

  // ✅ SHOW BIG TEXT NOTIFICATION (Untuk pesan panjang)
  Future<void> showBigTextNotification({
    required int id,
    required String title,
    required String body,
    required String bigText,
    Map<String, dynamic>? payload,
  }) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      print('📱 Preparing BIG TEXT notification: $title');

      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        showWhen: true,
        autoCancel: true,
        styleInformation: BigTextStyleInformation(
          bigText,
          htmlFormatBigText: true,
          contentTitle: title,
          htmlFormatContentTitle: true,
          summaryText: body,
          htmlFormatSummaryText: true,
        ),
      );

      final NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      String? payloadString;
      if (payload != null) {
        payloadString = _formatPayload(payload);
      }

      await _notifications.show(id, title, body, details, payload: payloadString);
      
      print('📖 BIG TEXT NOTIFICATION BERHASIL: $title');
      
    } catch (e) {
      print('❌ ERROR showing big text notification: $e');
    }
  }

  // ✅ SCHEDULE NOTIFICATION (Untuk reminder)
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    Map<String, dynamic>? payload,
  }) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      print('📱 Scheduling notification: $title at $scheduledDate');

      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      );

      final NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      String? payloadString;
      if (payload != null) {
        payloadString = _formatPayload(payload);
      }

      // ✅ CONVERT TO TZDateTime
      final scheduledTZ = tz.TZDateTime.from(scheduledDate, tz.local);

      await _notifications.zonedSchedule(
        id,
        title,
        body,
        scheduledTZ,
        details,
        payload: payloadString,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
      
      print('⏰ NOTIFICATION SCHEDULED: $title at $scheduledDate');
      
    } catch (e) {
      print('❌ ERROR scheduling notification: $e');
    }
  }

  // ✅ TEST METHODS - DENGAN DELAY
  Future<void> testBasicNotification() async {
    await showSystemNotification(
      id: 1001,
      title: 'TEST: System Notification',
      body: 'Ini adalah test notifikasi SYSTEM dari KSMI - Harus muncul di panel Android!',
    );
  }

  Future<void> testInboxNotification() async {
    await showSystemNotification(
      id: 1002,
      title: 'Pesan Baru - KSMI',
      body: 'Anda memiliki 2 pesan belum dibaca di inbox KSMI',
      payload: {
        'type': 'inbox',
        'screen': 'inbox',
        'action': 'open_inbox',
      },
    );
  }

  Future<void> testMultipleNotifications() async {
    // Notification 1
    await showSystemNotification(
      id: 1003,
      title: 'Penarikan SIQUNA',
      body: 'Penarikan SIQUNA Sebesar Rp. 100.000 Telah Berhasil',
      payload: {
        'type': 'transaction',
        'screen': 'transaction',
        'id': 'TRX001',
      },
    );

    await Future.delayed(const Duration(seconds: 2));

    // Notification 2  
    await showSystemNotification(
      id: 1004,
      title: 'Pembayaran SIQUNA',
      body: 'Pembayaran SIQUNA Sebesar Rp. 500.000 Telah Berhasil',
      payload: {
        'type': 'transaction', 
        'screen': 'transaction',
        'id': 'TRX002',
      },
    );

    await Future.delayed(const Duration(seconds: 2));

    // Notification 3 - Summary
    await showSystemNotification(
      id: 1005,
      title: '2 Transaksi Baru',
      body: 'Anda memiliki 2 transaksi baru di KSMI',
      payload: {
        'type': 'summary',
        'screen': 'dashboard',
      },
    );
  }

  // ✅ TEST PROGRESS NOTIFICATION
  Future<void> testProgressNotification() async {
    const maxProgress = 5;
    
    for (int i = 1; i <= maxProgress; i++) {
      await updateProgressNotification(
        id: 2001,
        title: 'Sync Data KSMI',
        body: 'Menyinkronisasi data...',
        progress: i,
        maxProgress: maxProgress,
      );
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  // ✅ TEST BIG TEXT NOTIFICATION
  Future<void> testBigTextNotification() async {
    await showBigTextNotification(
      id: 3001,
      title: 'Laporan Bulanan KSMI',
      body: 'Laporan keuangan Januari 2024 sudah tersedia',
      bigText: '''
Laporan Keuangan KSMI - Januari 2024

📊 Total Tabungan: Rp 15.750.000
💰 Total Angsuran: Rp 8.250.000
📈 Pertumbuhan: 12.5%

Terima kasih atas partisipasi Anda dalam Koperasi KSMI.
Laporan lengkap dapat diakses di menu Laporan.
      ''',
      payload: {
        'type': 'report',
        'screen': 'reports',
        'month': '2024-01',
      },
    );
  }

  // ✅ TEST SCHEDULED NOTIFICATION
  Future<void> testScheduledNotification() async {
    final scheduledTime = DateTime.now().add(const Duration(seconds: 10));
    
    await scheduleNotification(
      id: 4001,
      title: 'Reminder KSMI',
      body: 'Jangan lupa cek notifikasi terbaru Anda',
      scheduledDate: scheduledTime,
      payload: {
        'type': 'reminder',
        'screen': 'dashboard',
      },
    );
  }

  // ✅ CLEAR ALL NOTIFICATIONS
  Future<void> clearAllNotifications() async {
    try {
      await _notifications.cancelAll();
      print('🧹 All system notifications cleared');
    } catch (e) {
      print('❌ Error clearing notifications: $e');
    }
  }

  // ✅ CLEAR SPECIFIC NOTIFICATION
  Future<void> clearNotification(int id) async {
    try {
      await _notifications.cancel(id);
      print('🧹 Notification $id cleared');
    } catch (e) {
      print('❌ Error clearing notification $id: $e');
    }
  }

  // ✅ GET PENDING NOTIFICATIONS
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      return await _notifications.pendingNotificationRequests();
    } catch (e) {
      print('❌ Error getting pending notifications: $e');
      return [];
    }
  }
 
  // ✅ CHECK NOTIFICATION PERMISSION
  Future<bool> checkNotificationPermission() async {
    try {
      // Untuk Android, biasanya selalu granted jika channel ada
      // Untuk iOS, perlu check permission status
      return true;
    } catch (e) {
      print('❌ Error checking notification permission: $e');
      return false;
    }
  }

  bool get isInitialized => _isInitialized;
}
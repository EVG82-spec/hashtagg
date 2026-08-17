import 'dart:async';
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hashtagg/core/network/api_config.dart';
import 'package:http/http.dart' as http;
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Background service для polling уведомлений
/// Опрашивает API каждые 15 минут и показывает новые уведомления
class NotificationPollingService {
  static final NotificationPollingService _instance = NotificationPollingService._internal();
  factory NotificationPollingService() => _instance;
  NotificationPollingService._internal();

  static const String _taskName = 'notification_polling';
  static const String _uniqueName = 'notification_polling_unique';
  static const String _shownNotificationsKey = 'shown_notifications';
  
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isRunning = false;
  
  // Callback для обработки клика на уведомление
  static Function(String dialogId, bool isSupport)? onNotificationTap;

  /// Инициализация WorkManager для фоновых задач
  static Future<void> initializeWorkManager() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: true, // Включаем для отладки
    );
    print('✅ [PollingService] WorkManager initialized');
  }

  /// Запуск polling сервиса
  Future<void> start({
    required String userId,
    required String authToken,
  }) async {
    if (_isRunning) {
      print('⚠️ [PollingService] Already running');
      return;
    }

    _isRunning = true;
    print('🚀 [PollingService] Starting for user $userId');

    // Инициализируем уведомления
    await _initializeNotifications();

    // Сохраняем credentials для фоновой задачи
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', userId);
    await prefs.setString('auth_token', authToken);

    // Регистрируем периодическую задачу (каждые 15 минут - минимум для Android)
    await Workmanager().registerPeriodicTask(
      _uniqueName,
      _taskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      inputData: {
        'user_id': userId,
        'auth_token': authToken,
      },
    );

    // Делаем первую проверку сразу
    await _checkNotifications(userId, authToken);

    print('✅ [PollingService] Started successfully');
  }

  /// Остановка polling сервиса
  Future<void> stop() async {
    if (!_isRunning) {
      print('⚠️ [PollingService] Not running');
      return;
    }

    print('🛑 [PollingService] Stopping...');

    _isRunning = false;
    await Workmanager().cancelByUniqueName(_uniqueName);

    // Очищаем credentials
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('auth_token');

    print('✅ [PollingService] Stopped');
  }

  /// Инициализация уведомлений
  Future<void> _initializeNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();

    await _notifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  /// Обработчик клика на уведомление
  static void _onNotificationTapped(NotificationResponse response) {
    try {
      if (response.payload == null) return;

      final data = jsonDecode(response.payload!);
      final dialogId = data['dialog_id'] as String?;
      final isSupport = data['is_support'] as bool? ?? false;

      if (dialogId != null) {
        print('🔔 [PollingService] Notification tapped: dialogId=$dialogId, isSupport=$isSupport');
        onNotificationTap?.call(dialogId, isSupport);
      }
    } catch (e) {
      print('❌ [PollingService] Error handling notification tap: $e');
    }
  }

  /// Проверка новых уведомлений
  static Future<void> _checkNotifications(String userId, String authToken) async {
    try {
      print('🔍 [PollingService] Checking notifications for user $userId');

      final prefs = await SharedPreferences.getInstance();
      
      // Получаем список уже показанных уведомлений
      final shownNotifications = prefs.getStringList(_shownNotificationsKey) ?? [];
      
      // Запрашиваем непрочитанные уведомления с сервера
      final url = '${ApiConfig.baseUrl}/systems/api/controller.php?key=${ApiConfig.apiKey}&route=profile/notifications/getUnread';
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Bearer $authToken',
        },
        body: {
          'id_user': userId,
          'token': authToken,
        },
      );

      if (response.statusCode != 200) {
        print('❌ [PollingService] API error: ${response.statusCode}');
        print('   Response body: ${response.body}');
        return;
      }

      final data = jsonDecode(response.body);
      
      if (data['status'] != true) {
        print('❌ [PollingService] API returned error');
        return;
      }

      // Логируем debug информацию
      if (data['debug'] != null) {
        print('🐛 [PollingService] Debug info: ${data['debug']}');
      }

      final notifications = data['notifications'] as List<dynamic>;
      print('📬 [PollingService] Found ${notifications.length} notifications');

      // Показываем только новые уведомления
      final newShownNotifications = <String>[];
      
      for (final notification in notifications) {
        final notificationId = notification['id'] as String;
        
        // Пропускаем если уже показывали
        if (shownNotifications.contains(notificationId)) {
          continue;
        }

        // Показываем уведомление
        await _showNotification(notification);
        
        // Добавляем в список показанных
        newShownNotifications.add(notificationId);
      }

      // Обновляем список показанных уведомлений
      // Храним только последние 100 ID чтобы не раздувать хранилище
      final updatedShownNotifications = [
        ...shownNotifications,
        ...newShownNotifications,
      ].take(100).toList();
      
      await prefs.setStringList(_shownNotificationsKey, updatedShownNotifications);

      print('✅ [PollingService] Showed ${newShownNotifications.length} new notifications');
    } catch (e) {
      print('❌ [PollingService] Error checking notifications: $e');
    }
  }

  /// Показ уведомления
  static Future<void> _showNotification(Map<String, dynamic> notification) async {
    final notifications = FlutterLocalNotificationsPlugin();
    
    // Инициализируем если еще не инициализировано
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await notifications.initialize(
      const InitializationSettings(android: androidSettings),
    );

    const androidDetails = AndroidNotificationDetails(
      'chat_messages',
      'Сообщения',
      channelDescription: 'Уведомления о новых сообщениях',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    const details = NotificationDetails(android: androidDetails);

    final title = notification['sender_name'] ?? 'Новое сообщение';
    final body = notification['message'] ?? '';
    final payload = jsonEncode({
      'dialog_id': notification['dialog_id'],
      'is_support': notification['is_support'] ?? false,
    });

    await notifications.show(
      notification['timestamp'] ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );

    print('📨 [PollingService] Notification shown: $title');
  }

  /// Проверка состояния
  bool get isRunning => _isRunning;
  
  /// Ручная проверка уведомлений (для тестирования)
  Future<void> checkNow(String userId, String authToken) async {
    print('🔍 [PollingService] Manual check triggered');
    await _checkNotifications(userId, authToken);
  }
  
  /// Регистрация одноразовой задачи для тестирования (запустится через 1 минуту)
  Future<void> scheduleTestTask() async {
    await Workmanager().registerOneOffTask(
      'test_notification_check',
      _taskName,
      initialDelay: const Duration(minutes: 1),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
    print('✅ [PollingService] Test task scheduled for 1 minute');
  }
}

/// Callback для WorkManager (выполняется в фоне)
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print('🔄 [WorkManager] Task started: $task');

    try {
      // Получаем credentials из SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      final authToken = prefs.getString('auth_token');

      if (userId == null || authToken == null) {
        print('❌ [WorkManager] Missing credentials');
        return Future.value(false);
      }

      // Проверяем уведомления
      await NotificationPollingService._checkNotifications(userId, authToken);

      return Future.value(true);
    } catch (e) {
      print('❌ [WorkManager] Task failed: $e');
      return Future.value(false);
    }
  });
}

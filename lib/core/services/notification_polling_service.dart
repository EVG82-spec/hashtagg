// lib/core/services/notification_polling_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hashtagg/core/network/api_config.dart';
import 'package:http/http.dart' as http;
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationPollingService {
  static final NotificationPollingService _instance = NotificationPollingService._internal();
  factory NotificationPollingService() => _instance;
  NotificationPollingService._internal();

  // 🔥 НОВЫЙ ИНТЕРВАЛ - 15 СЕКУНД!
  static const Duration checkInterval = Duration(seconds: 15);

  static const String _taskName = 'notification_polling';
  static const String _shownNotificationsKey = 'shown_notifications';

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isRunning = false;
  Timer? _foregroundTimer; // Для проверок когда приложение активно

  static Function(String dialogId, bool isSupport)? onNotificationTap;

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
    print('🚀 [PollingService] Starting with ${checkInterval.inSeconds}s interval for user $userId');

    // Инициализируем уведомления
    await _initializeNotifications();

    // Сохраняем credentials
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', userId);
    await prefs.setString('auth_token', authToken);

    // 1️⃣ ЗАПУСКАЕМ ФОНОВУЮ ЗАДАЧУ (WorkManager)
    await _registerBackgroundTask(userId, authToken);

    // 2️⃣ ЗАПУСКАЕМ ПРОВЕРКИ В ФОРГРАУНДЕ (когда приложение активно)
    _startForegroundChecks(userId, authToken);

    // 3️⃣ ДЕЛАЕМ ПЕРВУЮ ПРОВЕРКУ СРАЗУ
    await _checkNotifications(userId, authToken);

    print('✅ [PollingService] Started successfully');
  }

  /// Регистрация фоновой задачи в WorkManager
  Future<void> _registerBackgroundTask(String userId, String authToken) async {
    // Отменяем старые задачи
    await Workmanager().cancelAll();

    // Регистрируем периодическую задачу (каждые 15 минут - для Android)
    // Это резервный механизм, если приложение убито
    await Workmanager().registerPeriodicTask(
      'polling_periodic',
      _taskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      inputData: {
        'user_id': userId,
        'auth_token': authToken,
      },
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );

    // Регистрируем цепочку быстрых проверок (каждые 15 секунд)
    // Используем одноразовые задачи для быстрых интервалов
    await _scheduleNextQuickCheck(userId, authToken);

    print('📅 [PollingService] Background tasks registered');
  }

  /// Планирование следующей быстрой проверки
  Future<void> _scheduleNextQuickCheck(String userId, String authToken) async {
    if (!_isRunning) return;

    final uniqueName = 'quick_check_${DateTime.now().millisecondsSinceEpoch}';

    await Workmanager().registerOneOffTask(
      uniqueName,
      _taskName,
      initialDelay: checkInterval, // 🔥 15 СЕКУНД!
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      inputData: {
        'user_id': userId,
        'auth_token': authToken,
      },
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );

    print('⏱️ [PollingService] Next check scheduled in ${checkInterval.inSeconds}s');
  }

  /// Запуск проверок в форграунде (когда приложение активно)
  void _startForegroundChecks(String userId, String authToken) {
    _foregroundTimer?.cancel();

    _foregroundTimer = Timer.periodic(checkInterval, (timer) async {
      if (_isRunning) {
        await _checkNotifications(userId, authToken);
      } else {
        timer.cancel();
      }
    });

    print('⏱️ [PollingService] Foreground checks started (every ${checkInterval.inSeconds}s)');
  }

  /// Проверка новых уведомлений
  static Future<void> _checkNotifications(String userId, String authToken) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Получаем список уже показанных уведомлений
      final shownNotifications = prefs.getStringList(_shownNotificationsKey) ?? [];

      // 🔥 ОПТИМИЗИРОВАННЫЙ ЗАПРОС - только количество непрочитанных
      // Если есть новые - тогда запрашиваем детали
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
          'limit': '10', // Ограничиваем количество
        },
      );

      if (response.statusCode != 200) {
        return;
      }

      final data = jsonDecode(response.body);

      if (data['status'] != true) {
        return;
      }

      final notifications = data['notifications'] as List<dynamic>? ?? [];

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
        newShownNotifications.add(notificationId);
      }

      // Обновляем список показанных уведомлений
      if (newShownNotifications.isNotEmpty) {
        final updatedShownNotifications = [
          ...shownNotifications,
          ...newShownNotifications,
        ].take(100).toList();

        await prefs.setStringList(_shownNotificationsKey, updatedShownNotifications);
        print('📬 [PollingService] Showed ${newShownNotifications.length} new notifications');
      }
    } catch (e) {
      print('❌ [PollingService] Error checking notifications: $e');
    }
  }

  /// Показ уведомления
  static Future<void> _showNotification(Map<String, dynamic> notification) async {
    final notifications = FlutterLocalNotificationsPlugin();

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
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Остановка сервиса
  Future<void> stop() async {
    if (!_isRunning) return;

    print('🛑 [PollingService] Stopping...');
    _isRunning = false;

    _foregroundTimer?.cancel();
    await Workmanager().cancelAll();

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

  static void _onNotificationTapped(NotificationResponse response) {
    try {
      if (response.payload == null) return;

      final data = jsonDecode(response.payload!);
      final dialogId = data['dialog_id'] as String?;
      final isSupport = data['is_support'] as bool? ?? false;

      if (dialogId != null) {
        print('🔔 [PollingService] Notification tapped');
        onNotificationTap?.call(dialogId, isSupport);
      }
    } catch (e) {
      print('❌ [PollingService] Error: $e');
    }
  }

  bool get isRunning => _isRunning;
}

/// Callback для WorkManager
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print('🔄 [WorkManager] Task started: $task');

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = inputData?['user_id'] ?? prefs.getString('user_id');
      final authToken = inputData?['auth_token'] ?? prefs.getString('auth_token');

      if (userId == null || authToken == null) {
        print('❌ [WorkManager] Missing credentials');
        return Future.value(false);
      }

      await NotificationPollingService._checkNotifications(userId, authToken);

      // Планируем следующую проверку
      await NotificationPollingService()._scheduleNextQuickCheck(userId, authToken);

      return Future.value(true);
    } catch (e) {
      print('❌ [WorkManager] Task failed: $e');
      return Future.value(false);
    }
  });
}
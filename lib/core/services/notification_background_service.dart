import 'dart:async';
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hashtagg/core/network/api_config.dart';
import 'package:http/http.dart' as http;
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Фоновый сервис для уведомлений с гибридным подходом:
/// 1. Цепочка одноразовых задач (каждые 5 минут) - для частых проверок
/// 2. Периодическая задача (каждые 15 минут) - страховка, восстанавливает цепочку
class NotificationBackgroundService {
  static final NotificationBackgroundService _instance = NotificationBackgroundService._internal();
  factory NotificationBackgroundService() => _instance;
  NotificationBackgroundService._internal();

  // Публичные константы для использования в callback dispatcher
  static const String oneOffTaskName = 'notification_check_oneoff';
  static const String periodicTaskName = 'notification_check_periodic';
  static const String periodicUniqueName = 'notification_periodic_unique';
  static const String shownNotificationsKey = 'shown_notifications';
  
  // Интервал для одноразовых задач (можно настроить: 1, 3, 5, 10 минут)
  static const Duration quickCheckInterval = Duration(minutes: 5);
  
  // Интервал для периодической задачи (минимум 15 минут)
  static const Duration periodicCheckInterval = Duration(minutes: 15);
  
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isRunning = false;
  
  // Callback для обработки клика на уведомление (используется только в foreground)
  static Function(String dialogId, bool isSupport)? onNotificationTap;

  /// Запуск фонового сервиса
  Future<void> start({
    required String userId,
    required String authToken,
  }) async {
    if (_isRunning) {
      print('⚠️ [BackgroundService] Already running');
      return;
    }

    _isRunning = true;
    print('🚀 [BackgroundService] Starting (DISABLED - using main.dart callback only)');

    // Инициализируем уведомления для foreground
    await _initializeNotifications();

    // Сохраняем credentials для фоновой задачи
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', userId);
    await prefs.setString('auth_token', authToken);
    await prefs.setBool('background_service_enabled', true);

    // НЕ регистрируем задачи здесь - они регистрируются в main.dart!
    print('✅ [BackgroundService] Credentials saved (tasks managed by main.dart)');
  }

  /// Остановка фонового сервиса
  Future<void> stop() async {
    if (!_isRunning) {
      print('⚠️ [BackgroundService] Not running');
      return;
    }

    print('🛑 [BackgroundService] Stopping...');

    _isRunning = false;
    
    // Отменяем все задачи
    await Workmanager().cancelAll();

    // Очищаем credentials
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('auth_token');
    await prefs.setBool('background_service_enabled', false);

    print('✅ [BackgroundService] Stopped');
  }

  /// Планирование следующей быстрой проверки (одноразовая задача)
  static Future<void> scheduleNextQuickCheck() async {
    // Генерируем уникальное имя для каждой задачи
    final uniqueName = 'quick_check_${DateTime.now().millisecondsSinceEpoch}';
    
    await Workmanager().registerOneOffTask(
      uniqueName,
      oneOffTaskName,
      initialDelay: quickCheckInterval,
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
    
    print('📅 [BackgroundService] Next quick check in ${quickCheckInterval.inMinutes} min');
  }

  /// Инициализация уведомлений (только для foreground)
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

  /// Обработчик клика на уведомление (только для foreground)
  static void _onNotificationTapped(NotificationResponse response) {
    try {
      if (response.payload == null) return;

      final data = jsonDecode(response.payload!);
      final dialogId = data['dialog_id'] as String?;
      final isSupport = data['is_support'] as bool? ?? false;

      if (dialogId != null) {
        print('🔔 [BackgroundService] Notification tapped: dialogId=$dialogId, isSupport=$isSupport');
        onNotificationTap?.call(dialogId, isSupport);
      }
    } catch (e) {
      print('❌ [BackgroundService] Error handling notification tap: $e');
    }
  }

  /// Проверка состояния
  bool get isRunning => _isRunning;
}

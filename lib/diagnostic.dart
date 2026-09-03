import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class DiagnosticScreen extends StatefulWidget {
  const DiagnosticScreen({super.key});

  @override
  State<DiagnosticScreen> createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends State<DiagnosticScreen> {
  String _log = '';
  bool _isRunning = false;

  void _addLog(String message) {
    setState(() {
      _log += '$message\n';
    });
    print(message);
  }

  Future<void> _runDiagnostics() async {
    if (_isRunning) return;
    setState(() {
      _isRunning = true;
      _log = '';
    });

    _addLog('═══════════════════════════════════════');
    _addLog('🔍 ДИАГНОСТИКА FCM И УВЕДОМЛЕНИЙ');
    _addLog('═══════════════════════════════════════\n');

    try {
      // ============================================================
      // 1. ПРОВЕРКА FIREBASE
      // ============================================================
      _addLog('📦 1. ПРОВЕРКА FIREBASE');
      try {
        await Firebase.initializeApp();
        _addLog('   ✅ Firebase инициализирован');
      } catch (e) {
        _addLog('   ❌ Ошибка Firebase: $e');
      }

      // ============================================================
      // 2. ПРОВЕРКА FCM-ТОКЕНА
      // ============================================================
      _addLog('\n📱 2. ПРОВЕРКА FCM-ТОКЕНА');
      try {
        String? token = await FirebaseMessaging.instance.getToken();
        if (token != null && token.isNotEmpty) {
          _addLog('   ✅ Токен получен');
          _addLog('   📍 Длина: ${token.length} символов');
          _addLog('   📍 Начало: ${token.substring(0, 20)}...');
          _addLog('   📍 Конец: ...${token.substring(token.length - 20)}');
        } else {
          _addLog('   ❌ Токен пустой');
        }
      } catch (e) {
        _addLog('   ❌ Ошибка получения токена: $e');
      }

      // ============================================================
      // 3. ПРОВЕРКА РАЗРЕШЕНИЙ
      // ============================================================
      _addLog('\n🔔 3. ПРОВЕРКА РАЗРЕШЕНИЙ');
      try {
        NotificationSettings settings = await FirebaseMessaging.instance
            .requestPermission(alert: true, badge: true, sound: true);
        _addLog('   📍 Статус: ${settings.authorizationStatus}');
        _addLog('   📍 Alert: ${settings.alert}');
        _addLog('   📍 Badge: ${settings.badge}');
        _addLog('   📍 Sound: ${settings.sound}');
        if (settings.authorizationStatus == AuthorizationStatus.authorized) {
          _addLog('   ✅ Разрешения получены');
        } else {
          _addLog('   ⚠️ Разрешения НЕ получены');
        }
      } catch (e) {
        _addLog('   ❌ Ошибка запроса разрешений: $e');
      }

      // ============================================================
      // 4. ПРОВЕРКА ЛОКАЛЬНЫХ УВЕДОМЛЕНИЙ
      // ============================================================
      _addLog('\n📨 4. ПРОВЕРКА ЛОКАЛЬНЫХ УВЕДОМЛЕНИЙ');
      try {
        final plugin = FlutterLocalNotificationsPlugin();
        await plugin.initialize(
          const InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          ),
        );
        _addLog('   ✅ Плагин инициализирован');

        // Тестовое уведомление
        await plugin.show(
          DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'Тест локального уведомления',
          'Это уведомление от диагностики',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'diagnostic_channel',
              'Диагностика',
              channelDescription: 'Канал для диагностики',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
        );
        _addLog('   ✅ Тестовое уведомление отправлено');
        _addLog('   📍 Проверьте шторку уведомлений!');
      } catch (e) {
        _addLog('   ❌ Ошибка локального уведомления: $e');
      }

      // ============================================================
      // 5. ПРОВЕРКА SHARED_PREFERENCES
      // ============================================================
      _addLog('\n💾 5. ПРОВЕРКА SHARED_PREFERENCES');
      try {
        final prefs = await SharedPreferences.getInstance();
        final userId = prefs.getString('user_id');
        final authToken = prefs.getString('auth_token');
        final isEnabled = prefs.getBool('background_service_enabled') ?? false;
        _addLog('   📍 user_id: ${userId ?? "null"}');
        _addLog(
          '   📍 auth_token: ${authToken != null ? "✅ есть (${authToken.length} символов)" : "❌ нет"}',
        );
        _addLog('   📍 background_service_enabled: $isEnabled');
      } catch (e) {
        _addLog('   ❌ Ошибка SharedPreferences: $e');
      }

      // ============================================================
      // 6. ПРОВЕРКА ПОДКЛЮЧЕНИЯ К СЕРВЕРУ
      // ============================================================
      _addLog('\n🌐 6. ПРОВЕРКА ПОДКЛЮЧЕНИЯ К СЕРВЕРУ');
      try {
        final response = await http.get(
          Uri.parse(
            'https://hashtagg.ru/systems/api/controller.php?key=3090379067&route=profile/notifications/getUnread',
          ),
        );
        _addLog('   📍 Статус: ${response.statusCode}');
        if (response.statusCode == 200) {
          _addLog('   ✅ Сервер доступен');
        } else {
          _addLog('   ❌ Сервер вернул ошибку: ${response.statusCode}');
        }
      } catch (e) {
        _addLog('   ❌ Ошибка подключения: $e');
      }

      // ============================================================
      // 7. ПРОВЕРКА РЕГИСТРАЦИИ ТОКЕНА НА СЕРВЕРЕ
      // ============================================================
      _addLog('\n📤 7. ПРОВЕРКА РЕГИСТРАЦИИ ТОКЕНА');
      try {
        final prefs = await SharedPreferences.getInstance();
        final userId = prefs.getString('user_id');
        final authToken = prefs.getString('auth_token');
        final token = await FirebaseMessaging.instance.getToken();

        if (userId != null && authToken != null && token != null) {
          final response = await http.post(
            Uri.parse('https://hashtagg.ru/systems/ajax/push/register'),
            headers: {
              'Authorization': 'Bearer $authToken',
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: {'user_id': userId, 'token': token, 'device_type': 'android'},
          );
          _addLog('   📍 Статус: ${response.statusCode}');
          _addLog('   📍 Ответ: ${response.body}');
          if (response.statusCode == 200) {
            _addLog('   ✅ Токен зарегистрирован на сервере');
          } else {
            _addLog('   ❌ Ошибка регистрации: ${response.statusCode}');
          }
        } else {
          _addLog('   ⚠️ Недостаточно данных для регистрации');
          _addLog('   📍 userId: ${userId ?? "null"}');
          _addLog('   📍 authToken: ${authToken != null ? "есть" : "null"}');
          _addLog('   📍 token: ${token != null ? "есть" : "null"}');
        }
      } catch (e) {
        _addLog('   ❌ Ошибка регистрации: $e');
      }

      // ============================================================
      // 8. ИТОГ
      // ============================================================
      _addLog('\n═══════════════════════════════════════');
      _addLog('✅ ДИАГНОСТИКА ЗАВЕРШЕНА');
      _addLog('═══════════════════════════════════════');
    } catch (e) {
      _addLog('\n❌ КРИТИЧЕСКАЯ ОШИБКА: $e');
    }

    setState(() {
      _isRunning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Диагностика уведомлений')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _isRunning ? null : _runDiagnostics,
              child: Text(
                _isRunning ? 'Идёт проверка...' : '🚀 Запустить диагностику',
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _log,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

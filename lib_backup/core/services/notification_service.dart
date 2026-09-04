import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:hashtagg/core/network/api_config.dart';
import 'package:hashtagg/core/services/notification_background_service.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final NotificationBackgroundService _backgroundService =
      NotificationBackgroundService();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  bool _isInitialized = false;
  bool _isConnected = false;
  String? _currentUserId;
  String? _currentAuthToken;
  String? _socketId;
  Timer? _pingTimer;

  // Callbacks
  Function(String dialogId, bool isSupport)? onNotificationTap;
  Function(Map<String, dynamic> data)? onMessageReceived;

  /// Initialize notification service
  Future<void> initialize({
    required String userId,
    required String authToken,
  }) async {
    print('🔔 Initializing NotificationService for user $userId');
    print(
      '   Current state: initialized=$_isInitialized, connected=$_isConnected, currentUser=$_currentUserId',
    );

    _currentUserId = userId;
    _currentAuthToken = authToken;

    // Initialize local notifications (only once)
    if (!_isInitialized) {
      await _initializeLocalNotifications();
      _isInitialized = true;
    }

    // Start background service to check notifications periodically
    await _backgroundService.start(userId: userId, authToken: authToken);

    // Настраиваем callback для клика на уведомления от background service
    // Используем тот же обработчик что и для WebSocket уведомлений
    NotificationBackgroundService.onNotificationTap = (dialogId, isSupport) {
      print(
        '🔔 [NotificationService] Background notification tapped: dialogId=$dialogId, isSupport=$isSupport',
      );
      onNotificationTap?.call(dialogId, isSupport);
    };

    // Always reinitialize WebSocket connection
    await _initializeWebSocket(userId, authToken);

    print('✅ NotificationService initialized successfully');
  }

  /// Initialize local notifications
  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // ============================================================
    // 🔥 ДОБАВИТЬ: СЛУШАТЕЛЬ УВЕДОМЛЕНИЙ (когда приложение открыто)
    // ============================================================
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print(
        '📨 [FCM] onMessage (приложение открыто): ${message.notification?.title}',
      );

      // Показываем локальное уведомление
      _showLocalNotification(
        title: message.notification?.title ?? 'Новое уведомление',
        body: message.notification?.body ?? '',
        payload: jsonEncode(message.data),
      );
    });

    // ============================================================
    // 🔥 ДОБАВИТЬ: ОБРАБОТЧИК НАЖАТИЯ НА УВЕДОМЛЕНИЕ (когда приложение закрыто)
    // ============================================================
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('📨 [FCM] onMessageOpenedApp: ${message.notification?.title}');
      // Здесь можно открыть нужный экран
    });

    // Request permissions
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }

    print('✅ Local notifications initialized');
  }

  Future<String?> getFcmToken() async {
    try {
      // 🔥 ПРИНУДИТЕЛЬНО УДАЛЯЕМ СТАРЫЙ ТОКЕН
      await FirebaseMessaging.instance.deleteToken();

      // 🔥 ПОЛУЧАЕМ НОВЫЙ
      String? token = await FirebaseMessaging.instance.getToken();
      print('📱 [FCM] НОВЫЙ токен получен: $token');
      return token;
    } catch (e) {
      print('❌ [FCM] Ошибка получения токена: $e');
      return null;
    }
  }

  /// Initialize WebSocket connection
  Future<void> _initializeWebSocket(String userId, String authToken) async {
    try {
      // Disconnect existing connection
      await _disconnectWebSocket();

      _currentAuthToken = authToken;

      final wsScheme = ApiConfig.reverbScheme == 'https' ? 'wss' : 'ws';
      final wsUrl =
          '$wsScheme://${ApiConfig.reverbUrl}:${ApiConfig.reverbPort}/app/${ApiConfig.reverbKey}';

      print('🔌 Connecting to WebSocket: $wsUrl');

      // Create WebSocket connection
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      // Listen to messages
      _subscription = _channel!.stream.listen(
        (message) {
          _handleWebSocketMessage(message);
        },
        onError: (error) {
          print('❌ WebSocket error: $error');
          _isConnected = false;

          // Попытка переподключения через 5 секунд
          Future.delayed(const Duration(seconds: 5), () {
            if (!_isConnected &&
                _currentUserId != null &&
                _currentAuthToken != null) {
              print('🔄 Attempting to reconnect...');
              _initializeWebSocket(_currentUserId!, _currentAuthToken!);
            }
          });
        },
        onDone: () {
          print('🔌 WebSocket connection closed');
          _isConnected = false;

          // Автоматическое переподключение
          Future.delayed(const Duration(seconds: 3), () {
            if (!_isConnected &&
                _currentUserId != null &&
                _currentAuthToken != null) {
              print('🔄 Auto-reconnecting after connection close...');
              _initializeWebSocket(_currentUserId!, _currentAuthToken!);
            }
          });
        },
      );

      // Запускаем ping timer для поддержания соединения
      _startPingTimer();

      _isConnected = true;
      print('✅ WebSocket connected, waiting for socket_id...');
    } catch (e, stackTrace) {
      print('❌ Failed to initialize WebSocket: $e');
      print('Stack trace: $stackTrace');
      _isConnected = false;
    }
  }

  /// Запуск ping timer для поддержания соединения
  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isConnected && _channel != null) {
        print('🏓 Sending ping...');
        _sendMessage({'event': 'pusher:ping', 'data': {}});
      }
    });
  }

  /// Остановка ping timer
  void _stopPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  /// Subscribe to a channel with authorization
  Future<void> _subscribeToChannelWithAuth(
    String channelName,
    String userId,
  ) async {
    if (_socketId == null || _currentAuthToken == null) {
      print('❌ Cannot subscribe: missing socket_id or auth token');
      print('   socket_id: $_socketId');
      print(
        '   auth token: ${_currentAuthToken != null ? "present (${_currentAuthToken!.length} chars)" : "null"}',
      );
      return;
    }

    try {
      print('🔐 Requesting authorization for channel: $channelName');
      print('   socket_id: $_socketId');
      print(
        '   token (first 10 chars): ${_currentAuthToken!.substring(0, _currentAuthToken!.length > 10 ? 10 : _currentAuthToken!.length)}...',
      );
      print(
        '   token (last 4 chars): ...${_currentAuthToken!.substring(_currentAuthToken!.length > 4 ? _currentAuthToken!.length - 4 : 0)}',
      );

      final url =
          '${ApiConfig.baseUrl}/systems/api/controller.php?key=${ApiConfig.apiKey}&route=broadcasting/auth';
      print('   URL: $url');

      // Запрос авторизации с бэкенда
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Bearer $_currentAuthToken',
        },
        body: {
          'socket_id': _socketId!,
          'channel_name': channelName,
          'token': _currentAuthToken!,
        },
      );

      print('📥 Authorization response: ${response.statusCode}');
      print('   Response body: ${response.body}');

      if (response.statusCode == 200) {
        final authData = jsonDecode(response.body);
        final auth = authData['auth'];

        print('✅ Authorization received: $auth');

        // Отправляем подписку с авторизацией
        _sendMessage({
          'event': 'pusher:subscribe',
          'data': {'channel': channelName, 'auth': auth},
        });

        print('📡 Subscribing to channel with auth: $channelName');
      } else {
        print(
          '❌ Authorization failed: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e, stackTrace) {
      print('❌ Error during authorization: $e');
      print('Stack trace: $stackTrace');
    }
  }

  /// Subscribe to a channel (public)
  void _subscribeToChannel(String channelName) {
    _sendMessage({
      'event': 'pusher:subscribe',
      'data': {'channel': channelName},
    });
    print('📡 Subscribing to channel: $channelName');
  }

  /// Send message through WebSocket
  void _sendMessage(Map<String, dynamic> message) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode(message));
    }
  }

  /// Disconnect WebSocket
  Future<void> _disconnectWebSocket() async {
    _stopPingTimer();

    if (_subscription != null) {
      await _subscription!.cancel();
      _subscription = null;
    }
    if (_channel != null) {
      await _channel!.sink.close();
      _channel = null;
    }
    _isConnected = false;
  }

  /// Handle WebSocket message
  Future<void> _handleWebSocketMessage(dynamic rawMessage) async {
    try {
      final message = jsonDecode(rawMessage as String);

      print('📨 WebSocket message: $message');

      // Обработка разных типов событий
      final event = message['event'] as String?;

      if (event == 'pusher:connection_established') {
        final data = message['data'];
        final dataMap = data is String ? jsonDecode(data) : data;
        _socketId = dataMap['socket_id'];

        print('✅ WebSocket connection established, socket_id: $_socketId');
        _isConnected = true;

        // Теперь можем подписаться на приватный канал
        if (_currentUserId != null) {
          _subscribeToChannelWithAuth(
            'private-user.$_currentUserId',
            _currentUserId!,
          );
        }
        return;
      }

      if (event == 'pusher:ping') {
        // Отвечаем на ping сообщение
        print('🏓 Received ping, sending pong...');
        _sendMessage({'event': 'pusher:pong', 'data': {}});
        return;
      }

      if (event == 'pusher:pong') {
        print('🏓 Received pong');
        return;
      }

      if (event == 'pusher_internal:subscription_succeeded') {
        print('✅ Subscription succeeded');
        return;
      }

      if (event == 'pusher:error') {
        final data = message['data'];
        final dataMap = data is String ? jsonDecode(data) : data;
        print(
          '❌ Pusher error: ${dataMap['message']} (code: ${dataMap['code']})',
        );
        return;
      }

      if (event == 'chat.message') {
        final data = message['data'];
        final messageData = data is String ? jsonDecode(data) : data;

        print('💬 Received chat message from ${messageData['from_user_name']}');

        // Формируем ID уведомления (такой же как в polling)
        final notificationId =
            'chat_${messageData['dialog_id']}_${DateTime.now().millisecondsSinceEpoch ~/ 1000}';

        // Добавляем в список просмотренных чтобы не показывать дубликаты при polling
        await _addToShownNotifications(notificationId);

        // Show local notification
        _showLocalNotification(
          title: messageData['from_user_name'] ?? 'Новое сообщение',
          body: messageData['message'] ?? '',
          payload: jsonEncode({
            'dialog_id': messageData['dialog_id'],
            'is_support': messageData['is_support'] ?? false,
          }),
        );

        // Call callback
        onMessageReceived?.call(messageData);
      }
    } catch (e) {
      print('❌ Error handling WebSocket message: $e');
    }
  }

  /// Show local notification
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
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

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Добавить ID уведомления в список просмотренных
  /// Используется для предотвращения дубликатов между WebSocket и Polling
  Future<void> _addToShownNotifications(String notificationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shownNotifications =
          prefs.getStringList('shown_notifications') ?? [];

      if (!shownNotifications.contains(notificationId)) {
        shownNotifications.add(notificationId);

        // Храним только последние 100 ID
        final updatedList = shownNotifications.length > 100
            ? shownNotifications.sublist(shownNotifications.length - 100)
            : shownNotifications;

        await prefs.setStringList('shown_notifications', updatedList);
        print(
          '✅ [NotificationService] Added to shown notifications: $notificationId',
        );
      }
    } catch (e) {
      print('❌ [NotificationService] Error adding to shown notifications: $e');
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    try {
      if (response.payload == null) return;

      final data = jsonDecode(response.payload!);
      final dialogId = data['dialog_id'] as String?;
      final isSupport = data['is_support'] as bool? ?? false;

      if (dialogId != null) {
        onNotificationTap?.call(dialogId, isSupport);
      }
    } catch (e) {
      print('❌ Error handling notification tap: $e');
    }
  }

  /// Disconnect and cleanup
  Future<void> disconnect() async {
    print('🔌 Disconnecting NotificationService');

    await _disconnectWebSocket();
    await _backgroundService.stop();

    _isConnected = false;
    _isInitialized = false;
    _currentUserId = null;
  }

  /// Check if connected
  bool get isConnected => _isConnected;

  /// Get current user ID
  String? get currentUserId => _currentUserId;
}

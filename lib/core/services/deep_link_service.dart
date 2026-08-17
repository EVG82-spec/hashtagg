import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:app_links/app_links.dart';

/// Сервис для обработки deep links
class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();
  final _appLinks = AppLinks();
  StreamSubscription? _sub;

  /// Callback для обработки OAuth результата
  Function(String token, int userId)? onOAuthSuccess;
  Function(String error)? onOAuthError;

  /// Инициализация обработчика deep links
  Future<void> init() async {
    try {
      // Проверяем initial link (когда приложение запущено из deep link)
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }

      // Подписываемся на новые deep links (когда приложение уже запущено)
      _sub = _appLinks.uriLinkStream.listen((Uri uri) {
        _handleDeepLink(uri);
      }, onError: (err) {
        if (kDebugMode) {
          debugPrint('❌ [DeepLink] Error: $err');
        }
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [DeepLink] Init error: $e');
      }
    }
  }

  /// Обработка deep link
  /// Обработка deep link
  void _handleDeepLink(Uri uri) {
    if (kDebugMode) {
      debugPrint('🔗 [DeepLink] Received: $uri');
    }

    // ==========================================
    // 1. ОБРАБОТКА OAuth
    // ==========================================
    if (uri.scheme == 'hashtagg' && uri.host == 'oauth' && uri.pathSegments.contains('callback')) {
      final status = uri.queryParameters['status'];

      if (status == 'success') {
        final token = uri.queryParameters['token'];
        final userIdStr = uri.queryParameters['user_id'];

        if (token != null && userIdStr != null) {
          final userId = int.tryParse(userIdStr);
          if (userId != null) {
            if (kDebugMode) {
              debugPrint('✅ [DeepLink] OAuth success: token=${token.substring(0, 10)}..., userId=$userId');
            }
            onOAuthSuccess?.call(token, userId);
          }
        }
      } else if (status == 'error') {
        final error = uri.queryParameters['error'] ?? 'Unknown error';
        if (kDebugMode) {
          debugPrint('❌ [DeepLink] OAuth error: $error');
        }
        onOAuthError?.call(error);
      }
    }

    // ==========================================
    // 2. ОБРАБОТКА ПЛАТЕЖА
    // ==========================================
    if (uri.scheme == 'hashtagg' && uri.host == 'payment') {
      if (uri.pathSegments.contains('success')) {
        final orderId = uri.queryParameters['order_id'];
        if (kDebugMode) {
          debugPrint('✅ [DeepLink] Payment success! Order ID: $orderId');
        }
        // TODO: Обновить баланс или вызвать событие в WalletBloc
      } else if (uri.pathSegments.contains('cancel')) {
        if (kDebugMode) {
          debugPrint('❌ [DeepLink] Payment cancelled');
        }
      }
    }
  }

  /// Обработка deep link из WebView
  void handleDeepLink(String url) {
    print('🔗 [9] DeepLinkService.handleDeepLink() вызван: $url');
    final uri = Uri.parse(url);
    final token = uri.queryParameters['token'];
    final userIdStr = uri.queryParameters['user_id'];

    print('🔗 [10] token: $token, userIdStr: $userIdStr');

    if (token != null && userIdStr != null) {
      final userId = int.tryParse(userIdStr);
      if (userId != null) {
        print('✅ [11] Токен и userId получены: token=$token, userId=$userId');
        onOAuthSuccess?.call(token, userId);
      } else {
        print('❌ [12] userId невалидный: $userIdStr');
      }
    } else {
      print('❌ [13] token или userId отсутствуют');
    }
  }

  /// Очистка ресурсов
  void dispose() {
    _sub?.cancel();
  }
}
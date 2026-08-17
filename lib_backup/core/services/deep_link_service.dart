import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:app_links/app_links.dart';

/// Сервис для обработки deep links
class DeepLinkService {
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
  void _handleDeepLink(Uri uri) {
    if (kDebugMode) {
      debugPrint('🔗 [DeepLink] Received: $uri');
    }
    
    // Проверяем что это OAuth callback
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
  }
  
  /// Очистка ресурсов
  void dispose() {
    _sub?.cancel();
  }
}

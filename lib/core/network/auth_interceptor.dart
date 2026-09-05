import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hashtagg/shared/infrastructure/services/auth_cleanup_service.dart';
import 'package:hive_flutter/hive_flutter.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    print('🔑 [AuthInterceptor] Intercepting request: ${options.uri}');
    String? token;
    bool isOAuth = false;
    try {
      var box = Hive.box('user');
      token = box.get('auth_token') as String?;
      isOAuth = box.get('is_oauth', defaultValue: false) as bool;

      if (kDebugMode) {
        debugPrint(
          '[AuthInterceptor] 🔑 Reading token from Hive: ${token != null ? _maskToken(token) : 'NULL'}',
        );
        debugPrint('[AuthInterceptor] 🔐 OAuth mode: $isOAuth');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AuthInterceptor] Ошибка получения токена: $e');
      }
    }

    print(
      '🔑 [AuthInterceptor] Token: ${token != null ? '${token.substring(0, 10)}...' : 'null'}',
    );

    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
      print('🔑 [AuthInterceptor] Added Authorization header');
      if (kDebugMode) {
        debugPrint(
          '[AuthInterceptor] ✅ Set Authorization header: Bearer ${_maskToken(token)}',
        );
      }
    } else {
      if (kDebugMode) {
        debugPrint(
          '[AuthInterceptor] ⚠️ No token found, skipping Authorization header',
        );
      }
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (kDebugMode) {
      debugPrint(
        '[AuthInterceptor] Ошибка запроса: ${err.requestOptions.path} - ${err.message}',
      );
    }

    if (err.response?.statusCode == 401) {
      if (kDebugMode) {
        debugPrint('[AuthInterceptor] Токен недействителен, очистка данных');
      }
      await _clearAuthData();
    }

    handler.next(err);
  }

  Future<void> _clearAuthData() async {
    try {
      if (kDebugMode) {
        debugPrint(
          '[AuthInterceptor] 🔴 Получена 401 ошибка - очищаем все данные',
        );
      }

      // Используем наш сервис для полной очистки
      await AuthCleanupService.clearAllAuthData(logDetails: true);

      if (kDebugMode) {
        debugPrint('[AuthInterceptor] ✅ Данные авторизации очищены');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AuthInterceptor] ❌ Ошибка очистки данных: $e');
      }
    }
  }

  String _maskToken(String token) {
    if (token.length < 10) return '***';
    return '${token.substring(0, 6)}...${token.substring(token.length - 4)}';
  }
}

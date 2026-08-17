import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    String? token;
    bool isOAuth = false;
    try {
      var box = Hive.box('user');
      token = box.get('auth_token') as String?;
      isOAuth = box.get('is_oauth', defaultValue: false) as bool;
      
      if (kDebugMode) {
        debugPrint('[AuthInterceptor] 🔑 Reading token from Hive: ${token != null ? _maskToken(token) : 'NULL'}');
        debugPrint('[AuthInterceptor] 🔐 OAuth mode: $isOAuth');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AuthInterceptor] Ошибка получения токена: $e');
      }
    }

    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
      if (kDebugMode) {
        debugPrint('[AuthInterceptor] ✅ Set Authorization header: Bearer ${_maskToken(token)}');
      }
    } else {
      if (kDebugMode) {
        debugPrint('[AuthInterceptor] ⚠️ No token found, skipping Authorization header');
      }
    }
    
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (kDebugMode) {
      debugPrint('[AuthInterceptor] Ошибка запроса: ${err.requestOptions.path} - ${err.message}');
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
      var box = Hive.box('user');
      await box.put('auth_token', null);
      await box.put('user', null);
      if (kDebugMode) {
        debugPrint('[AuthInterceptor] Данные авторизации очищены');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AuthInterceptor] Ошибка очистки данных: $e');
      }
    }
  }

  String _maskToken(String token) {
    if (token.length < 10) return '***';
    return '${token.substring(0, 6)}...${token.substring(token.length - 4)}';
  }
}

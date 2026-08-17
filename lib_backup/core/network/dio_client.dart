import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'auth_interceptor.dart';
import 'api_config.dart';

class DioClient {
  static Dio createDio() {
    // Проверяем режим OAuth
    final box = Hive.box('user');
    final isOAuth = box.get('is_oauth', defaultValue: false) as bool;
    
    if (kDebugMode) {
      debugPrint('[DioClient] 🔍 Reading is_oauth from Hive: $isOAuth');
      debugPrint('[DioClient] 🔍 All Hive keys: ${box.keys.toList()}');
    }
    
    // Если OAuth - используем oauthUrl, иначе baseUrl
    final baseUrl = isOAuth ? ApiConfig.oauthUrl : ApiConfig.baseUrl;
    
    if (kDebugMode) {
      debugPrint('[DioClient] 🌐 Creating Dio with baseUrl: $baseUrl (OAuth mode: $isOAuth)');
    }
    
    final dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      responseType: ResponseType.json,
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
    ));

    dio.interceptors.add(AuthInterceptor());
    dio.interceptors.add(LogInterceptor(requestBody: true, responseBody: true));

    return dio;
  }
}
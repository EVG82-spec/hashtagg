//G:\hashtagg_app\lib\core\network\dio_client.dart
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'auth_interceptor.dart';
import 'api_config.dart';
import 'package:logger/logger.dart';

class DioClient {
  // ✅ ПРОКСИ ДЛЯ ТЕСТА (через SSH-туннель)
  // ⚠️ В PRODUCTION УБРАТЬ!
  static const bool useProxy = false; // ← включить/выключить прокси
  static const String proxyHost = 'localhost';
  static const int proxyPort = 1080;

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
      debugPrint(
        '[DioClient] 🌐 Creating Dio with baseUrl: $baseUrl (OAuth mode: $isOAuth)',
      );
    }

    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        responseType: ResponseType.json,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      ),
    );

    // ✅ ПРОКСИ + ОТКЛЮЧЕНИЕ SSL (только для теста)
    if (useProxy) {
      (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
        final client = HttpClient();

        // SOCKS5 прокси
        client.findProxy = (uri) {
          return 'SOCKS5 $proxyHost:$proxyPort';
        };

        // ⚠️ Отключение проверки SSL (только для теста!)
        client.badCertificateCallback = (cert, host, port) => true;

        if (kDebugMode) {
          debugPrint('[DioClient] 🔌 Прокси: SOCKS5 $proxyHost:$proxyPort');
          debugPrint('[DioClient] ⚠️ SSL проверка отключена (тест)');
        }

        return client;
      };
    }

    dio.interceptors.add(AuthInterceptor());

    // ===== ЛОГГЕР =====
    dio.interceptors.add(
      LogInterceptor(
        request: true,
        requestBody: true,
        responseBody: true,
        error: true,
        logPrint: (object) {
          print('🌐 $object');
        },
      ),
    );

    return dio;
  }
}
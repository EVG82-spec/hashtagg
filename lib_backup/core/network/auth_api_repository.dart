import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'api_config.dart';

/// Результат вызова API
class ApiResult<T> {
  final bool success;
  final T? data;
  final String? error;

  ApiResult.success(this.data)
      : success = true,
        error = null;

  ApiResult.failure(this.error)
      : success = false,
        data = null;
}

/// Репозиторий для работы с API авторизации
class AuthApiRepository {
  final Dio _dio;
  late final Dio _dioGet;

  AuthApiRepository(Dio dio) : _dio = dio {
    // Создаем отдельный Dio для GET запросов без заголовков
    _dioGet = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      responseType: ResponseType.json,
    ));
  }

  /// Авторизация по логину и паролю
  /// 
  /// Возвращает токен при успехе или ошибку при неудаче
  Future<ApiResult<Map<String, dynamic>>> login({
    required String login,
    required String password,
  }) async {
    try {
      _log('🔐 Авторизация пользователя: $login');

      final response = await _dio.post(
        '/systems/api/controller.php',
        data: {
          'key': ApiConfig.apiKey,
          'route': ApiConfig.loginEndpoint,
          'login': login,
          'pass': password,
        },
      );

      // Парсим JSON если пришел как строка
      final responseData = response.data is String
          ? jsonDecode(response.data)
          : response.data;

      if (kDebugMode) {
        _log('📥 Ответ API: ${_prettyJson(responseData)}');
      }

      if (responseData['status'] == true) {
        final token = responseData['token'];
        final userId = responseData['id'];

        if (token == null) {
          _log('❌ Ошибка: токен не получен в ответе');
          return ApiResult.failure('Токен не получен от сервера');
        }

        _log('✅ Успешная авторизация. Token: ${_maskToken(token)}, UserID: $userId');
        
        return ApiResult.success({
          'token': token,
          'user_id': userId,
        });
      } else {
        final errors = responseData['errors'];
        String errorMessage;
        if (errors is List) {
          errorMessage = errors.join('\n');
        } else if (errors is String) {
          errorMessage = errors;
        } else {
          errorMessage = errors?.toString() ?? 'Неверный логин или пароль';
        }
        _log('❌ Ошибка авторизации: $errorMessage');
        return ApiResult.failure(errorMessage);
      }
    } on DioException catch (e) {
      final errorMessage = _handleDioError(e);
      _log('❌ Dio ошибка: $errorMessage');
      return ApiResult.failure(errorMessage);
    } catch (e) {
      _log('❌ Неожиданная ошибка: $e');
      return ApiResult.failure('Произошла непредвиденная ошибка: $e');
    }
  }

  /// Авторизация по токену (проверка токена)
  Future<ApiResult<Map<String, dynamic>>> authToken({
    required String token,
  }) async {
    try {
      _log('🔑 Проверка токена авторизации');

      final response = await _dio.post(
        '/systems/api/controller.php',
        data: {
          'key': ApiConfig.apiKey,
          'route': ApiConfig.tokenAuthEndpoint,
          'token': token,
        },
      );

      // Парсим JSON если пришел как строка
      final responseData = response.data is String
          ? jsonDecode(response.data)
          : response.data;

      if (kDebugMode) {
        _log('📥 Ответ API: ${_prettyJson(responseData)}');
      }

      if (responseData['status'] == true) {
        _log('✅ Токен валиден');
        return ApiResult.success(responseData);
      } else {
        final errors = responseData['errors'];
        String errorMessage;
        if (errors is List) {
          errorMessage = errors.join('\n');
        } else if (errors is String) {
          errorMessage = errors;
        } else {
          errorMessage = errors?.toString() ?? 'Токен недействителен';
        }
        _log('❌ Токен невалиден: $errorMessage');
        return ApiResult.failure(errorMessage);
      }
    } on DioException catch (e) {
      final errorMessage = _handleDioError(e);
      _log('❌ Dio ошибка: $errorMessage');
      return ApiResult.failure(errorMessage);
    } catch (e) {
      _log('❌ Неожиданная ошибка: $e');
      return ApiResult.failure('Произошла непредвиденная ошибка: $e');
    }
  }

  /// Восстановление пароля
  Future<ApiResult<void>> recovery({
    required String login,
  }) async {
    try {
      _log('🔄 Восстановление пароля для: $login');

      final response = await _dio.post(
        '/systems/api/controller.php',
        data: {
          'key': ApiConfig.apiKey,
          'route': ApiConfig.recoveryEndpoint,
          'login': login,
        },
      );

      // Парсим JSON если пришел как строка
      final responseData = response.data is String
          ? jsonDecode(response.data)
          : response.data;

      if (kDebugMode) {
        _log('📥 Ответ API: ${_prettyJson(responseData)}');
      }

      if (responseData['status'] == true) {
        _log('✅ Письмо для восстановления отправлено');
        return ApiResult.success(null);
      } else {
        final errors = responseData['errors'];
        String errorMessage;
        if (errors is List) {
          errorMessage = errors.join('\n');
        } else if (errors is String) {
          errorMessage = errors;
        } else {
          errorMessage = errors?.toString() ?? 'Ошибка восстановления пароля';
        }
        _log('❌ Ошибка восстановления: $errorMessage');
        return ApiResult.failure(errorMessage);
      }
    } on DioException catch (e) {
      final errorMessage = _handleDioError(e);
      _log('❌ Dio ошибка: $errorMessage');
      return ApiResult.failure(errorMessage);
    } catch (e) {
      _log('❌ Неожиданная ошибка: $e');
      return ApiResult.failure('Произошла непредвиденная ошибка: $e');
    }
  }

  /// Регистрация нового пользователя
  Future<ApiResult<Map<String, dynamic>>> register({
    required String email,
    required String password,
    required String name,
    String? phone,
  }) async {
    try {
      _log('📝 Регистрация пользователя: $email');

      final response = await _dio.post(
        '/systems/api/controller.php',
        data: {
          'key': ApiConfig.apiKey,
          'route': ApiConfig.registrationEndpoint,
          'email': email,
          'pass': password,
          'name': name,
          if (phone != null) 'phone': phone,
        },
      );

      // Парсим JSON если пришел как строка
      final responseData = response.data is String
          ? jsonDecode(response.data)
          : response.data;

      if (kDebugMode) {
        _log('📥 Ответ API: ${_prettyJson(responseData)}');
      }

      if (responseData['status'] == true) {
        final token = responseData['token'];
        final userId = responseData['id'];

        _log('✅ Успешная регистрация. Token: ${_maskToken(token)}, UserID: $userId');
        
        return ApiResult.success({
          'token': token,
          'user_id': userId,
        });
      } else {
        final errors = responseData['errors'];
        String errorMessage;
        if (errors is List) {
          errorMessage = errors.join('\n');
        } else if (errors is String) {
          errorMessage = errors;
        } else {
          errorMessage = errors?.toString() ?? 'Ошибка регистрации';
        }
        _log('❌ Ошибка регистрации: $errorMessage');
        return ApiResult.failure(errorMessage);
      }
    } on DioException catch (e) {
      final errorMessage = _handleDioError(e);
      _log('❌ Dio ошибка: $errorMessage');
      return ApiResult.failure(errorMessage);
    } catch (e) {
      _log('❌ Неожиданная ошибка: $e');
      return ApiResult.failure('Произошла непредвиденная ошибка: $e');
    }
  }

  /// Обработка Dio ошибок
  String _handleDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return 'Превышено время подключения к серверу';
      case DioExceptionType.sendTimeout:
        return 'Превышено время отправки данных';
      case DioExceptionType.receiveTimeout:
        return 'Превышено время получения ответа';
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        switch (statusCode) {
          case 400:
            return 'Неверный запрос';
          case 401:
            return 'Неверные учетные данные';
          case 403:
            return 'Доступ запрещен';
          case 404:
            return 'Ресурс не найден';
          case 500:
            return 'Ошибка сервера';
          default:
            return 'Ошибка сети: код $statusCode';
        }
      case DioExceptionType.cancel:
        return 'Запрос отменен';
      case DioExceptionType.connectionError:
        return 'Ошибка подключения к серверу';
      case DioExceptionType.badCertificate:
        return 'Неверный сертификат';
      case DioExceptionType.unknown:
        return 'Неизвестная ошибка сети';
      case DioExceptionType.transformTimeout:
        return 'Превышено время ожидания преобразования';
      default:
        return 'Неизвестная ошибка сети';
    }
  }

  /// Получение данных профиля пользователя
  Future<ApiResult<Map<String, dynamic>>> getProfileData({
    required int userId,
    required String token,
  }) async {
    try {
      _log('👤 Получение данных профиля для userId: $userId');

      // Отправляем POST с параметрами в URL (как query string)
      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': ApiConfig.profileDataEndpoint,
          'id_user': userId,
          'token': token,
        },
      );

      // Парсим JSON если пришел как строка
      final responseData = response.data is String
          ? jsonDecode(response.data)
          : response.data;

      if (kDebugMode) {
        _log('📥 Ответ API: ${_prettyJson(responseData)}');
      }

      if (responseData['id'] != null) {
        _log('✅ Данные профиля получены: ${responseData['display_name']}');
        return ApiResult.success(responseData);
      } else {
        final error = responseData['error']?.toString() ?? 'Не удалось получить данные профиля';
        _log('❌ Ошибка получения профиля: $error');
        return ApiResult.failure(error);
      }
    } on DioException catch (e) {
      final errorMessage = _handleDioError(e);
      _log('❌ Dio ошибка: $errorMessage');
      return ApiResult.failure(errorMessage);
    } catch (e) {
      _log('❌ Неожиданная ошибка: $e');
      return ApiResult.failure('Произошла непредвиденная ошибка: $e');
    }
  }

  /// Выход из системы (удаление токена на сервере)
  Future<ApiResult<void>> logout({
    required String token,
    required int userId,
  }) async {
    try {
      _log('🚪 Выход из системы для userId: $userId');

      final response = await _dio.post(
        '/systems/api/profile/auth/logout.php',
        queryParameters: {
          'token': token,
          'user_id': userId,
        },
      );

      // Парсим JSON если пришел как строка
      final responseData = response.data is String
          ? jsonDecode(response.data)
          : response.data;

      if (kDebugMode) {
        _log('📥 Ответ API: ${_prettyJson(responseData)}');
      }

      if (responseData['status'] == true) {
        _log('✅ Успешный выход из системы');
        return ApiResult.success(null);
      } else {
        final error = responseData['error']?.toString() ?? 'Ошибка выхода';
        _log('❌ Ошибка выхода: $error');
        return ApiResult.failure(error);
      }
    } on DioException catch (e) {
      final errorMessage = _handleDioError(e);
      _log('❌ Dio ошибка: $errorMessage');
      return ApiResult.failure(errorMessage);
    } catch (e) {
      _log('❌ Неожиданная ошибка: $e');
      return ApiResult.failure('Произошла непредвиденная ошибка: $e');
    }
  }

  /// Отправка кода верификации для регистрации
  /// 
  /// Отправляет код подтверждения на email или телефон
  Future<ApiResult<Map<String, dynamic>>> sendVerificationCode({
    required String login,
    required String name,
    required String password,
  }) async {
    try {
      _log('📧 Отправка кода верификации для: $login');

      final response = await _dio.post(
        '/systems/api/controller.php',
        data: {
          'key': ApiConfig.apiKey,
          'route': 'profile/auth/verify',
          'login': login,
          'name': name,
          'pass': password,
        },
      );

      final responseData = response.data is String
          ? jsonDecode(response.data)
          : response.data;

      if (kDebugMode) {
        _log('📥 Ответ API: ${_prettyJson(responseData)}');
      }

      if (responseData['status'] == true) {
        _log('✅ Код верификации отправлен');
        return ApiResult.success({
          'confirmation': responseData['confirmation'] ?? false,
          'confirmation_title': responseData['confirmation_title'] ?? '',
        });
      } else {
        final errors = responseData['errors'];
        String errorMessage;
        if (errors is List) {
          errorMessage = errors.join('\n');
        } else if (errors is String) {
          errorMessage = errors;
        } else {
          errorMessage = errors?.toString() ?? 'Ошибка отправки кода';
        }
        _log('❌ Ошибка отправки кода: $errorMessage');
        return ApiResult.failure(errorMessage);
      }
    } on DioException catch (e) {
      final errorMessage = _handleDioError(e);
      _log('❌ Dio ошибка: $errorMessage');
      return ApiResult.failure(errorMessage);
    } catch (e) {
      _log('❌ Неожиданная ошибка: $e');
      return ApiResult.failure('Произошла непредвиденная ошибка: $e');
    }
  }

  /// Регистрация с кодом подтверждения
  /// 
  /// Создает аккаунт после ввода кода верификации
  Future<ApiResult<Map<String, dynamic>>> registerWithCode({
    required String login,
    required String name,
    required String password,
    required String verifyCode,
  }) async {
    try {
      _log('📝 Регистрация с кодом для: $login');

      final response = await _dio.post(
        '/systems/api/controller.php',
        data: {
          'key': ApiConfig.apiKey,
          'route': ApiConfig.registrationEndpoint,
          'login': login,
          'name': name,
          'pass': password,
          'verify_code': verifyCode,
        },
      );

      final responseData = response.data is String
          ? jsonDecode(response.data)
          : response.data;

      if (kDebugMode) {
        _log('📥 Ответ API: ${_prettyJson(responseData)}');
      }

      if (responseData['status'] == true) {
        final token = responseData['token'];
        final userId = responseData['id'];

        _log('✅ Успешная регистрация. Token: ${_maskToken(token)}, UserID: $userId');
        _log('🔍 Debug: token type=${token.runtimeType}, userId type=${userId.runtimeType}');
        
        return ApiResult.success({
          'token': token,
          'user_id': userId,
        });
      } else {
        final errors = responseData['errors'];
        String errorMessage;
        if (errors is List) {
          errorMessage = errors.join('\n');
        } else if (errors is String) {
          errorMessage = errors;
        } else {
          errorMessage = errors?.toString() ?? 'Ошибка регистрации';
        }
        _log('❌ Ошибка регистрации: $errorMessage');
        return ApiResult.failure(errorMessage);
      }
    } on DioException catch (e) {
      final errorMessage = _handleDioError(e);
      _log('❌ Dio ошибка: $errorMessage');
      return ApiResult.failure(errorMessage);
    } catch (e) {
      _log('❌ Неожиданная ошибка: $e');
      return ApiResult.failure('Произошла непредвиденная ошибка: $e');
    }
  }

  /// Очистка предыдущих кодов верификации
  /// 
  /// Удаляет старые коды перед отправкой нового
  Future<ApiResult<void>> clearVerificationCodes({
    required String login,
  }) async {
    try {
      _log('🗑️ Очистка кодов верификации для: $login');

      final response = await _dio.post(
        '/systems/api/controller.php',
        data: {
          'key': ApiConfig.apiKey,
          'route': 'profile/auth/verifyPrev',
          'login': login,
        },
      );

      final responseData = response.data is String
          ? jsonDecode(response.data)
          : response.data;

      if (responseData['status'] == true) {
        _log('✅ Коды верификации очищены');
        return ApiResult.success(null);
      } else {
        _log('⚠️ Не удалось очистить коды');
        return ApiResult.success(null); // Не критичная ошибка
      }
    } catch (e) {
      _log('⚠️ Ошибка очистки кодов: $e');
      return ApiResult.success(null); // Не критичная ошибка
    }
  }

  /// Логирование
  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[AuthApi] $message');
    }
  }

  /// Форматирование JSON для логов
  String _prettyJson(dynamic json) {
    try {
      return json.toString();
    } catch (e) {
      return json.toString();
    }
  }

  /// Маскировка токена для логов
  String _maskToken(String token) {
    if (token.length < 10) return '***';
    return '${token.substring(0, 6)}...${token.substring(token.length - 4)}';
  }

  /// OAuth авторизация через социальные сети
  /// 
  /// Принимает authorization code от провайдера и возвращает токен приложения
  Future<ApiResult<Map<String, dynamic>>> oauthLogin({
    required String provider,
    required String code,
    String? codeVerifier, // Для VK PKCE
  }) async {
    try {
      _log('🔐 OAuth авторизация через $provider');

      final response = await _dio.post(
        '/systems/api/controller.php',
        data: {
          'key': ApiConfig.apiKey,
          'route': 'profile/auth/oauth',
          'network': provider,
          'code': code,
          if (codeVerifier != null) 'code_verifier': codeVerifier,
        },
      );

      // Парсим JSON если пришел как строка
      final responseData = response.data is String
          ? jsonDecode(response.data)
          : response.data;

      if (kDebugMode) {
        _log('📥 Ответ API: ${_prettyJson(responseData)}');
      }

      if (responseData['status'] == true) {
        final token = responseData['token'];
        final userId = responseData['id'] ?? responseData['user_id'];

        if (token == null) {
          _log('❌ Ошибка: токен не получен в ответе');
          return ApiResult.failure('Токен не получен от сервера');
        }

        _log('✅ Успешная OAuth авторизация. Token: ${_maskToken(token)}, UserID: $userId');
        
        return ApiResult.success({
          'token': token,
          'user_id': userId,
        });
      } else {
        final errors = responseData['errors'];
        String errorMessage;
        if (errors is List) {
          errorMessage = errors.join('\n');
        } else if (errors is String) {
          errorMessage = errors;
        } else {
          errorMessage = errors?.toString() ?? 'Ошибка OAuth авторизации';
        }
        _log('❌ Ошибка OAuth: $errorMessage');
        return ApiResult.failure(errorMessage);
      }
    } on DioException catch (e) {
      final errorMessage = _handleDioError(e);
      _log('❌ Dio ошибка: $errorMessage');
      return ApiResult.failure(errorMessage);
    } catch (e) {
      _log('❌ Неожиданная ошибка: $e');
      return ApiResult.failure('Произошла непредвиденная ошибка: $e');
    }
  }
}

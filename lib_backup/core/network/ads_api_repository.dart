import 'package:dio/dio.dart';
import 'dart:convert';
import 'api_config.dart';

/// Репозиторий для работы с API создания и редактирования объявлений
class AdsApiRepository {
  final Dio _dio;

  AdsApiRepository({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: ApiConfig.baseUrl,
              headers: {
                'Content-Type': 'application/x-www-form-urlencoded',
              },
            ));

  /// Получение опций для создания объявления
  /// //INTEGRATED
  Future<Map<String, dynamic>> getCreateOptions({
    required int userId,
    required int categoryId,
  }) async {
    try {
      print('🔵 [AdsApi] Getting create options for category: $categoryId');

      final response = await _dio.get(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'create_ad/options',
          'id_user': userId,
          'id_cat': categoryId,
        },
        options: Options(
          validateStatus: (status) => true,
        ),
      );

      print('🔵 [AdsApi] Options response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = response.data is String
            ? json.decode(response.data)
            : response.data;

        print('✅ [AdsApi] Options loaded successfully');
        return {'status': true, 'data': data};
      } else {
        print('🔴 [AdsApi] Server error ${response.statusCode}: ${response.data}');
        return {'status': false, 'error': 'Server error: ${response.statusCode}'};
      }
    } on DioException catch (e) {
      print('🔴 [AdsApi] Options exception: $e');
      return {'status': false, 'error': e.message ?? 'Network error'};
    } catch (e) {
      print('🔴 [AdsApi] Options error: $e');
      return {'status': false, 'error': e.toString()};
    }
  }

  /// Валидация данных объявления
  /// //INTEGRATED
  Future<Map<String, dynamic>> validateAd({
    required int userId,
    required String token,
    required int step, // 1 или 2
    required Map<String, dynamic> adData,
  }) async {
    try {
      print('🔵 [AdsApi] Validating ad step: $step');

      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'create_ad/validation',
        },
        data: {
          'id_user': userId,
          'token': token,
          'step': step,
          ...adData,
        },
        options: Options(
          validateStatus: (status) => true,
        ),
      );

      print('🔵 [AdsApi] Validation response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = response.data is String
            ? json.decode(response.data)
            : response.data;

        if (data['status'] == true) {
          print('✅ [AdsApi] Validation passed');
          return {'status': true};
        } else {
          print('🔴 [AdsApi] Validation failed: ${data['answer']}');
          return {'status': false, 'error': data['answer']};
        }
      } else {
        print('🔴 [AdsApi] Server error ${response.statusCode}: ${response.data}');
        return {'status': false, 'error': 'Server error: ${response.statusCode}'};
      }
    } on DioException catch (e) {
      print('🔴 [AdsApi] Validation exception: $e');
      return {'status': false, 'error': e.message ?? 'Network error'};
    } catch (e) {
      print('🔴 [AdsApi] Validation error: $e');
      return {'status': false, 'error': e.toString()};
    }
  }

  /// Загрузить фото для объявления
  /// 
  /// Параметры:
  /// - [userId]: ID пользователя
  /// - [token]: Токен авторизации
  /// - [imageBase64]: Изображение в base64
  /// 
  /// Возвращает имя и ссылку на загруженное фото
  Future<Map<String, dynamic>> uploadPhoto({
    required int userId,
    required String token,
    required String imageBase64,
  }) async {
    try {
      print('🔵 [AdsApi] Uploading photo');
      
      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'assets/save',
        },
        data: {
          'id_user': userId,
          'token': token,
          'type': 'image',
          'action': 'adAdd',
          'assets': jsonEncode([imageBase64]),
        },
      );
      
      final data = response.data is String 
          ? jsonDecode(response.data) 
          : response.data;
      
      print('✅ [AdsApi] Photo uploaded: ${data['data']}');
      
      return {
        'status': true,
        'name': data['data']['name'],
        'link': data['data']['link'],
      };
    } catch (e) {
      print('🔴 [AdsApi] Upload photo error: $e');
      return {
        'status': false,
        'error': e.toString(),
      };
    }
  }

  /// Создание объявления
  /// //INTEGRATED
  Future<Map<String, dynamic>> createAd({
    required int userId,
    required String token,
    required Map<String, dynamic> adData,
  }) async {
    try {
      print('🔵 [AdsApi] Creating ad');
      print(adData);

      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'create_ad/create',
        },
        data: {
          'id_user': userId,
          'token': token,
          ...adData,
        },
        options: Options(
          validateStatus: (status) => true,
        ),
      );

      print('🔵 [AdsApi] Create response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = response.data is String
            ? json.decode(response.data)
            : response.data;

        if (data['status'] == true) {
          print('✅ [AdsApi] Ad created successfully: ${data['id']}, status: ${data['ad_status']}');
          return {
            'status': true, 
            'id': data['id'],
            'ad_status': data['ad_status'],
          };
        } else {
          print('🔴 [AdsApi] Create failed: ${data['answer']}');
          return {'status': false, 'error': data['answer']};
        }
      } else {
        print('🔴 [AdsApi] Server error ${response.statusCode}: ${response.data}');
        return {'status': false, 'error': 'Server error: ${response.statusCode}'};
      }
    } on DioException catch (e) {
      print('🔴 [AdsApi] Create exception: $e');
      return {'status': false, 'error': e.message ?? 'Network error'};
    } catch (e) {
      print('🔴 [AdsApi] Create error: $e');
      return {'status': false, 'error': e.toString()};
    }
  }

  /// Загрузка данных объявления для редактирования
  /// //INTEGRATED
  Future<Map<String, dynamic>> loadAdForEdit({
    required int userId,
    required String token,
    required int adId,
    int? categoryId,
  }) async {
    try {
      print('🔵 [AdsApi] Loading ad for edit: $adId');

      final response = await _dio.get(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'edit_ad/load',
          'id_user': userId,
          'token': token,
          'id': adId,
          if (categoryId != null) 'id_cat': categoryId,
        },
        options: Options(
          validateStatus: (status) => true,
        ),
      );

      print('🔵 [AdsApi] Load response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = response.data is String
            ? json.decode(response.data)
            : response.data;

        print('✅ [AdsApi] Ad loaded successfully');
        return {'status': true, 'data': data};
      } else {
        print('🔴 [AdsApi] Server error ${response.statusCode}: ${response.data}');
        return {'status': false, 'error': 'Server error: ${response.statusCode}'};
      }
    } on DioException catch (e) {
      print('🔴 [AdsApi] Load exception: $e');
      return {'status': false, 'error': e.message ?? 'Network error'};
    } catch (e) {
      print('🔴 [AdsApi] Load error: $e');
      return {'status': false, 'error': e.toString()};
    }
  }

  /// Валидация данных при редактировании
  /// //INTEGRATED
  Future<Map<String, dynamic>> validateEditAd({
    required int userId,
    required String token,
    required int step,
    required Map<String, dynamic> adData,
  }) async {
    try {
      print('🔵 [AdsApi] Validating edit ad step: $step');

      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'edit_ad/validation',
        },
        data: {
          'id_user': userId,
          'token': token,
          'step': step,
          ...adData,
        },
        options: Options(
          validateStatus: (status) => true,
        ),
      );

      print('🔵 [AdsApi] Edit validation response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = response.data is String
            ? json.decode(response.data)
            : response.data;

        if (data['status'] == true) {
          print('✅ [AdsApi] Edit validation passed');
          return {'status': true};
        } else {
          print('🔴 [AdsApi] Edit validation failed: ${data['answer']}');
          return {'status': false, 'error': data['answer']};
        }
      } else {
        print('🔴 [AdsApi] Server error ${response.statusCode}: ${response.data}');
        return {'status': false, 'error': 'Server error: ${response.statusCode}'};
      }
    } on DioException catch (e) {
      print('🔴 [AdsApi] Edit validation exception: $e');
      return {'status': false, 'error': e.message ?? 'Network error'};
    } catch (e) {
      print('🔴 [AdsApi] Edit validation error: $e');
      return {'status': false, 'error': e.toString()};
    }
  }

  /// Редактирование объявления
  /// //INTEGRATED
  Future<Map<String, dynamic>> editAd({
    required int userId,
    required String token,
    required int adId,
    required Map<String, dynamic> adData,
  }) async {
    try {
      print('🔵 [AdsApi] Editing ad: $adId');

      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'edit_ad/edit',
        },
        data: {
          'id_user': userId,
          'token': token,
          'id': adId,
          ...adData,
        },
        options: Options(
          validateStatus: (status) => true,
        ),
      );

      print('🔵 [AdsApi] Edit response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = response.data is String
            ? json.decode(response.data)
            : response.data;

        if (data['status'] == true) {
          print('✅ [AdsApi] Ad edited successfully');
          return {'status': true};
        } else {
          print('🔴 [AdsApi] Edit failed: ${data['answer']}');
          return {'status': false, 'error': data['answer']};
        }
      } else {
        print('🔴 [AdsApi] Server error ${response.statusCode}: ${response.data}');
        return {'status': false, 'error': 'Server error: ${response.statusCode}'};
      }
    } on DioException catch (e) {
      print('🔴 [AdsApi] Edit exception: $e');
      return {'status': false, 'error': e.message ?? 'Network error'};
    } catch (e) {
      print('🔴 [AdsApi] Edit error: $e');
      return {'status': false, 'error': e.toString()};
    }
  }

  /// Сохранить телефон пользователя
  /// Используется при создании объявления
  /// Возвращает {'status': true, 'verify': bool} если успешно
  /// verify=true означает что нужно ввести код подтверждения
  Future<Map<String, dynamic>> savePhone({
    required int userId,
    required String token,
    required String phone,
  }) async {
    try {
      print('🔵 [AdsApi] Saving phone: $phone for user: $userId');

      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'verify/send_phone',
        },
        data: {
          'id_user': userId,
          'token': token,
          'phone': phone,
        },
        options: Options(
          validateStatus: (status) => true,
        ),
      );

      print('🔵 [AdsApi] Save phone response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = response.data is String
            ? json.decode(response.data)
            : response.data;

        print('📥 [AdsApi] Save phone response data: $data');

        if (data['status'] == true) {
          print('✅ [AdsApi] Phone save initiated, verify=${data['verify']}');
          return {
            'status': true,
            'verify': data['verify'] ?? false,
            'title': data['title'],
          };
        } else {
          print('🔴 [AdsApi] Save phone failed: ${data['answer']}');
          return {'status': false, 'error': data['answer']};
        }
      } else {
        print('🔴 [AdsApi] Server error ${response.statusCode}: ${response.data}');
        return {'status': false, 'error': 'Server error: ${response.statusCode}'};
      }
    } on DioException catch (e) {
      print('🔴 [AdsApi] Save phone exception: $e');
      return {'status': false, 'error': e.message ?? 'Network error'};
    } catch (e) {
      print('🔴 [AdsApi] Save phone error: $e');
      return {'status': false, 'error': e.toString()};
    }
  }

  /// Подтвердить телефон кодом из SMS
  /// Используется если savePhone вернул verify=true
  Future<Map<String, dynamic>> verifyPhone({
    required int userId,
    required String token,
    required String phone,
    required String code,
  }) async {
    try {
      print('🔵 [AdsApi] Verifying phone: $phone with code: $code');

      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'verify/verify_phone',
        },
        data: {
          'id_user': userId,
          'token': token,
          'phone': phone,
          'code': code,
        },
        options: Options(
          validateStatus: (status) => true,
        ),
      );

      print('🔵 [AdsApi] Verify phone response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = response.data is String
            ? json.decode(response.data)
            : response.data;

        print('📥 [AdsApi] Verify phone response data: $data');

        if (data['status'] == true) {
          print('✅ [AdsApi] Phone verified successfully');
          return {'status': true};
        } else {
          print('🔴 [AdsApi] Verify phone failed: ${data['answer']}');
          return {'status': false, 'error': data['answer']};
        }
      } else {
        print('🔴 [AdsApi] Server error ${response.statusCode}: ${response.data}');
        return {'status': false, 'error': 'Server error: ${response.statusCode}'};
      }
    } on DioException catch (e) {
      print('🔴 [AdsApi] Verify phone exception: $e');
      return {'status': false, 'error': e.message ?? 'Network error'};
    } catch (e) {
      print('🔴 [AdsApi] Verify phone error: $e');
      return {'status': false, 'error': e.toString()};
    }
  }
}

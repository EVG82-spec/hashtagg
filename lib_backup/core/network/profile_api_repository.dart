import 'package:dio/dio.dart';
import 'dart:convert';
import 'api_config.dart';
import 'package:hashtagg/core/network/api_config.dart';

class ProfileApiRepository {
  final Dio _dio;

  ProfileApiRepository({Dio? dio}) : _dio = dio ?? Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    validateStatus: (status) => status! < 500,
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
  ));

  /// Выход из аккаунта (удаление токена на сервере)
  Future<Map<String, dynamic>> logout({
    required String token,
    required int userId,
  }) async {
    try {
      print('🔵 [ProfileApi] Logout request for user: $userId');
      
      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: {
          'key': '3090379067',
          'route': 'profile/auth/logout',
          'token': token,
          'user_id': userId,
        },
      );

      print('🔵 [ProfileApi] Logout response: ${response.data}');
      
      if (response.statusCode == 200) {
        return {'status': true};
      } else {
        return {'status': false, 'error': 'Logout failed'};
      }
    } on DioException catch (e) {
      print('🔴 [ProfileApi] Logout exception: $e');
      return {'status': false, 'error': e.message ?? 'Network error'};
    } catch (e) {
      print('🔴 [ProfileApi] Logout error: $e');
      return {'status': false, 'error': e.toString()};
    }
  }

  /// Получение данных своего профиля
  Future<Map<String, dynamic>> getProfile({
    required String token,
    required int userId,
  }) async {
    try {
      print('🔵 [ProfileApi] Get profile request for user: $userId');
      
      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: {
          'key': '3090379067',
          'route': 'profile/card/getData',
          'token': token,
          'id_user': userId,
        },
      );

      print('🔵 [ProfileApi] Profile response: ${response.data}');
      print('🔵 [ProfileApi] Profile response type: ${response.data.runtimeType}');
      
      if (response.statusCode == 200) {
        // Парсим ответ если это строка
        final data = response.data is String 
            ? json.decode(response.data) 
            : response.data;
            
        if (data is Map) {
          return data as Map<String, dynamic>;
        } else {
          return {'status': false, 'error': 'Invalid response format'};
        }
      } else {
        return {'status': false, 'error': 'Failed to load profile'};
      }
    } on DioException catch (e) {
      print('🔴 [ProfileApi] Profile exception: $e');
      return {'status': false, 'error': e.message ?? 'Network error'};
    } catch (e) {
      print('🔴 [ProfileApi] Profile error: $e');
      return {'status': false, 'error': e.toString()};
    }
  }

  /// Получение данных пользователя (обертка для getProfile)
  Future<Map<String, dynamic>> getUserData({
    required int userId,
    required String token,
  }) async {
    try {
      final data = await getProfile(token: token, userId: userId);
      
      // getProfile возвращает данные напрямую без поля status
      // Проверяем наличие обязательных полей
      if (data.containsKey('id') && data.containsKey('balance')) {
        return {'status': true, 'data': data};
      }
      
      // Если есть поле error, значит произошла ошибка
      if (data.containsKey('error')) {
        return {'status': false, 'error': data['error']};
      }
      
      return {'status': false, 'error': 'Invalid response format'};
    } catch (e) {
      print('🔴 [ProfileApi] getUserData error: $e');
      return {'status': false, 'error': e.toString()};
    }
  }

  /// Получение публичного профиля другого пользователя через card_user/getData
  Future<Map<String, dynamic>> getPublicProfile({
    required int userId,
    int? authUserId,
    String? token,
  }) async {
    try {
      print('🔵 [ProfileApi] Get public profile request for user: $userId');
      
      final Map<String, dynamic> params = {
        'key': '3090379067',
        'route': 'card_user/getData',
        'id_user': userId,
      };
      
      // Добавляем авторизацию если есть
      if (authUserId != null && token != null) {
        params['id_user_auth'] = authUserId;
        params['token'] = token;
      } else {
        params['id_user_auth'] = 0;
      }
      
      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: params,
      );

      print('🔵 [ProfileApi] Public profile response: ${response.data}');
      
      if (response.statusCode == 200) {
        // Парсим ответ если это строка
        final data = response.data is String 
            ? json.decode(response.data) as Map<String, dynamic>
            : response.data as Map<String, dynamic>;
            
        return data;
      } else {
        return {'status': false, 'error': 'Failed to load public profile'};
      }
    } on DioException catch (e) {
      print('🔴 [ProfileApi] Public profile exception: $e');
      return {'status': false, 'error': e.message ?? 'Network error'};
    } catch (e) {
      print('🔴 [ProfileApi] Public profile error: $e');
      return {'status': false, 'error': e.toString()};
    }
  }

  /// Получение объявлений пользователя
  Future<Map<String, dynamic>> getUserAds({
    required int userId,
    String status = 'active',
    int page = 1,
  }) async {
    try {
      print('🔵 [ProfileApi] Get user ads request for user: $userId, status: $status');
      
      // Формируем query в зависимости от статуса
      String queryFilter;
      if (status == 'active') {
        queryFilter = "ads_id_user='$userId' and ads_status='1' and ads_period_publication > now()";
      } else if (status == 'sold') {
        queryFilter = "ads_id_user='$userId' and ads_status IN(5,4)";
      } else if (status == 'archive') {
        queryFilter = "ads_id_user='$userId' and (ads_status NOT IN(1,5,4) or ads_period_publication < now()) and ads_status!=8";
      } else {
        queryFilter = "ads_id_user='$userId' and ads_status='1' and ads_period_publication > now()";
      }
      
      // Используем catalog/getAds с фильтром по владельцу
      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: {
          'key': '3090379067',
          'route': 'catalog/getAds',
          'page': page,
          'id_user_owner': userId,
        },
      );

      print('🔵 [ProfileApi] User ads response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = response.data is String 
            ? json.decode(response.data) as Map<String, dynamic>
            : response.data as Map<String, dynamic>;
            
        print('🔵 [ProfileApi] User ads count: ${data['count']}');
        
        // Фильтруем объявления по статусу на клиенте
        List<dynamic> allAds = data['data'] as List? ?? [];
        List<dynamic> filteredAds = [];
        
        for (var ad in allAds) {
          final adStatus = ad['ads_status']?.toString() ?? '0';
          final periodPublication = ad['ads_period_publication'];
          
          bool shouldInclude = false;
          if (status == 'active') {
            shouldInclude = adStatus == '1';
          } else if (status == 'sold') {
            shouldInclude = adStatus == '5' || adStatus == '4';
          } else if (status == 'archive') {
            shouldInclude = !(adStatus == '1' || adStatus == '5' || adStatus == '4') && adStatus != '8';
          }
          
          if (shouldInclude) {
            filteredAds.add(ad);
          }
        }
        
        print('🔵 [ProfileApi] Filtered ads count: ${filteredAds.length} (status: $status)');
        
        // Логируем первое объявление для проверки структуры
        if (filteredAds.isNotEmpty) {
          print('🔵 [ProfileApi] First filtered ad sample: ${filteredAds.first}');
        }
        
        // Заменяем localhost на настроенный mediaUrl в изображениях
        for (var ad in filteredAds) {
          if (ad['images'] != null && ad['images'] is List) {
            ad['images'] = (ad['images'] as List).map((img) {
              if (img is String) {
                return ApiConfig.replaceMediaUrl(img);
              }
              return img;
            }).toList();
          }
        }
        
        // Возвращаем отфильтрованные данные
        return {
          'status': true,
          'data': filteredAds,
          'count': filteredAds.length,
          'pages': (filteredAds.length / 30).ceil(),
        };
      } else {
        return {'status': false, 'error': 'Failed to load user ads', 'data': []};
      }
    } on DioException catch (e) {
      print('🔴 [ProfileApi] User ads exception: $e');
      return {'status': false, 'error': e.message ?? 'Network error', 'data': []};
    } catch (e) {
      print('🔴 [ProfileApi] User ads error: $e');
      return {'status': false, 'error': e.toString(), 'data': []};
    }
  }

  /// Получение своих объявлений
  Future<Map<String, dynamic>> getMyAds({
    required String token,
    required int userId,
    int page = 1,
    String sorting = 'active', // active, sold, archive, all
  }) async {
    try {
      print('🔵 [ProfileApi] Loading my ads for user: $userId, page: $page, sorting: $sorting');
      
      final response = await _dio.get(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'profile/card/getAds',
          'token': token,
          'id_user': userId,
          'page': page,
          'sorting': sorting,
        },
      );

      print('🔵 [ProfileApi] My ads response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = response.data is String 
            ? jsonDecode(response.data) 
            : response.data;
        
        // Логируем первое объявление ДО замены
        if (data['data'] != null && (data['data'] as List).isNotEmpty) {
          print('🔵 [ProfileApi] First ad BEFORE localhost replace: ${(data['data'] as List).first}');
        }
        
        // Заменяем localhost на 192.168.1.3:8000 в изображениях
        if (data['data'] != null && data['data'] is List) {
          for (var ad in data['data']) {
            if (ad['ads_images'] != null && ad['ads_images'] is List) {
              ad['ads_images'] = (ad['ads_images'] as List).map((img) {
                if (img is String) {
                  final replaced = ApiConfig.replaceMediaUrl(img);
                  if (img != replaced) {
                    print('🔵 [ProfileApi] Replaced image URL: $img -> $replaced');
                  }
                  return replaced;
                }
                return img;
              }).toList();
            }
          }
        }
        
        // Логируем первое объявление ПОСЛЕ замены
        if (data['data'] != null && (data['data'] as List).isNotEmpty) {
          print('🔵 [ProfileApi] First ad AFTER localhost replace: ${(data['data'] as List).first}');
        }
        
        print('✅ [ProfileApi] My ads loaded: ${data['count'] ?? 0} total');
        return {'status': true, ...data};
      } else {
        return {'status': false, 'error': 'Failed to load my ads', 'data': []};
      }
    } on DioException catch (e) {
      print('🔴 [ProfileApi] My ads exception: $e');
      return {'status': false, 'error': e.message ?? 'Network error', 'data': []};
    } catch (e) {
      print('🔴 [ProfileApi] My ads error: $e');
      return {'status': false, 'error': e.toString(), 'data': []};
    }
  }

  /// Подписка/отписка от пользователя
  Future<Map<String, dynamic>> toggleSubscribe({
    required String token,
    required int userIdFrom,
    required int userIdTo,
  }) async {
    try {
      print('🔵 [ProfileApi] Toggle subscribe: $userIdFrom -> $userIdTo');
      print('🔵 [ProfileApi] Token: ${token.substring(0, 20)}... (length: ${token.length})');
      
      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: {
          'key': '3090379067',
          'route': 'card_user/subscribe',
          'id_user_from': userIdFrom,
          'token': token,
          'id_user_to': userIdTo,
        },
      );

      print('🔵 [ProfileApi] Subscribe response: ${response.data}');
      
      if (response.statusCode == 200) {
        final data = response.data is String 
            ? json.decode(response.data) 
            : response.data;
        
        // API возвращает {"status":"added"/"deleted","count":2}
        // Добавляем success флаг
        return {'success': true, ...data};
      } else {
        return {'success': false, 'error': 'Failed to toggle subscribe'};
      }
    } on DioException catch (e) {
      print('🔴 [ProfileApi] Subscribe exception: $e');
      
      // Пытаемся извлечь детальную информацию об ошибке из ответа
      if (e.response?.data != null) {
        try {
          final errorData = e.response!.data is String 
              ? json.decode(e.response!.data) 
              : e.response!.data;
          
          print('🔴 [ProfileApi] Error details: $errorData');
          
          if (errorData is Map) {
            return {
              'success': false, 
              'error': errorData['error'] ?? e.message,
              'trace': errorData['trace'],
              'file': errorData['file'],
              'line': errorData['line'],
            };
          }
        } catch (parseError) {
          print('🔴 [ProfileApi] Failed to parse error: $parseError');
        }
      }
      
      return {'success': false, 'error': e.message ?? 'Network error'};
    } catch (e) {
      print('🔴 [ProfileApi] Subscribe error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Получение списка подписок
  Future<Map<String, dynamic>> getSubscriptions({
    required String token,
    required int userId,
  }) async {
    try {
      print('🔵 [ProfileApi] Getting subscriptions for user: $userId');
      
      final response = await _dio.get(
        '/systems/api/controller.php',
        queryParameters: {
          'key': '3090379067',
          'route': 'profile/subscriptions/getSubscriptions',
          'token': token,
          'id_user': userId,
        },
      );

      print('🔵 [ProfileApi] Subscriptions response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = response.data is String 
            ? json.decode(response.data) 
            : response.data;
        
        // API возвращает массив напрямую
        if (data is List) {
          // Заменяем localhost на настроенный mediaUrl в аватарах
          for (var user in data) {
            if (user['avatar'] != null && user['avatar'] is String) {
              final originalAvatar = user['avatar'] as String;
              user['avatar'] = ApiConfig.replaceMediaUrl(originalAvatar);
              if (originalAvatar != user['avatar']) {
                print('🔵 [ProfileApi] Replaced avatar URL: $originalAvatar -> ${user['avatar']}');
              }
            }
          }
          
          print('✅ [ProfileApi] Loaded ${data.length} subscriptions');
          return {'status': true, 'data': data};
        } else {
          return {'status': true, 'data': []};
        }
      } else {
        return {'status': false, 'error': 'Failed to load subscriptions', 'data': []};
      }
    } on DioException catch (e) {
      print('🔴 [ProfileApi] Subscriptions exception: $e');
      return {'status': false, 'error': e.message ?? 'Network error', 'data': []};
    } catch (e) {
      print('🔴 [ProfileApi] Subscriptions error: $e');
      return {'status': false, 'error': e.toString(), 'data': []};
    }
  }

  /// Удаление подписки
  Future<Map<String, dynamic>> deleteSubscription({
    required String token,
    required int userId,
    required int subscriptionId,
  }) async {
    try {
      print('🔵 [ProfileApi] Deleting subscription: $subscriptionId');
      
      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: {
          'key': '3090379067',
          'route': 'profile/subscriptions/deleteSubscription',
        },
        data: {
          'id_user': userId,
          'token': token,
          'id_subscription': subscriptionId,
        },
      );

      print('🔵 [ProfileApi] Delete subscription response: ${response.data}');
      
      if (response.statusCode == 200) {
        final data = response.data is String 
            ? json.decode(response.data) 
            : response.data;
        
        if (data['status'] == true) {
          print('✅ [ProfileApi] Subscription deleted');
          return {'status': true};
        } else {
          return {'status': false, 'error': 'Failed to delete subscription'};
        }
      } else {
        return {'status': false, 'error': 'Failed to delete subscription'};
      }
    } on DioException catch (e) {
      print('🔴 [ProfileApi] Delete subscription exception: $e');
      return {'status': false, 'error': e.message ?? 'Network error'};
    } catch (e) {
      print('🔴 [ProfileApi] Delete subscription error: $e');
      return {'status': false, 'error': e.toString()};
    }
  }

  /// Получение черного списка
  Future<Map<String, dynamic>> getBlacklist({
    required String token,
    required int userId,
  }) async {
    try {
      print('🔵 [ProfileApi] Getting blacklist for user: $userId');
      print('🔵 [ProfileApi] Token: ${token.substring(0, 10)}...');
      print('🔵 [ProfileApi] Request URL: /systems/api/controller.php');
      print('🔵 [ProfileApi] Query params: key=3090379067, route=profile/blacklist/getUsers, token=$token, id_user=$userId');
      
      final response = await _dio.get(
        '/systems/api/controller.php',
        queryParameters: {
          'key': '3090379067',
          'route': 'profile/blacklist/getUsers',
          'token': token,
          'id_user': userId,
        },
      );

      print('🔵 [ProfileApi] Blacklist response status: ${response.statusCode}');
      print('🔵 [ProfileApi] Blacklist response data: ${response.data}');
      
      if (response.statusCode == 200) {
        final data = response.data is String 
            ? json.decode(response.data) 
            : response.data;
        
        print('🔵 [ProfileApi] Parsed data type: ${data.runtimeType}');
        print('🔵 [ProfileApi] Parsed data: $data');
        
        // API возвращает массив напрямую
        if (data is List) {
          // Заменяем localhost на настроенный mediaUrl в аватарах
          for (var user in data) {
            if (user['avatar'] != null && user['avatar'] is String) {
              final originalAvatar = user['avatar'] as String;
              user['avatar'] = ApiConfig.replaceMediaUrl(originalAvatar);
              if (originalAvatar != user['avatar']) {
                print('🔵 [ProfileApi] Replaced avatar URL: $originalAvatar -> ${user['avatar']}');
              }
            }
          }
          
          print('✅ [ProfileApi] Loaded ${data.length} blocked users');
          return {'status': true, 'data': data};
        } else {
          print('⚠️ [ProfileApi] Data is not a list, returning empty');
          return {'status': true, 'data': []};
        }
      } else {
        print('🔴 [ProfileApi] Bad status code: ${response.statusCode}');
        return {'status': false, 'error': 'Failed to load blacklist', 'data': []};
      }
    } on DioException catch (e) {
      print('🔴 [ProfileApi] Blacklist exception: $e');
      print('🔴 [ProfileApi] Response status code: ${e.response?.statusCode}');
      print('🔴 [ProfileApi] Response headers: ${e.response?.headers}');
      print('🔴 [ProfileApi] Response data type: ${e.response?.data.runtimeType}');
      print('🔴 [ProfileApi] Response data: ${e.response?.data}');
      print('🔴 [ProfileApi] Request URL: ${e.requestOptions.uri}');
      print('🔴 [ProfileApi] Request method: ${e.requestOptions.method}');
      print('🔴 [ProfileApi] Request query params: ${e.requestOptions.queryParameters}');
      
      // Попробуем распарсить ответ если это HTML с ошибкой
      if (e.response?.data is String) {
        final responseText = e.response!.data as String;
        print('🔴 [ProfileApi] Response text length: ${responseText.length}');
        print('🔴 [ProfileApi] Response text (first 500 chars): ${responseText.substring(0, responseText.length > 500 ? 500 : responseText.length)}');
      }
      
      return {'status': false, 'error': e.message ?? 'Network error', 'data': []};
    } catch (e) {
      print('🔴 [ProfileApi] Blacklist error: $e');
      return {'status': false, 'error': e.toString(), 'data': []};
    }
  }

  /// Удаление пользователя из черного списка (разблокировка)
  Future<Map<String, dynamic>> unblockUser({
    required String token,
    required int userId,
    required int blacklistId,
  }) async {
    try {
      print('🔵 [ProfileApi] Unblocking user: blacklistId=$blacklistId');
      
      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: {
          'key': '3090379067',
          'route': 'profile/blacklist/delete',
        },
        data: {
          'id_user': userId,
          'token': token,
          'id': blacklistId,
        },
      );

      print('🔵 [ProfileApi] Unblock response: ${response.data}');
      
      if (response.statusCode == 200) {
        final data = response.data is String 
            ? json.decode(response.data) 
            : response.data;
        
        if (data['status'] == true) {
          print('✅ [ProfileApi] User unblocked');
          return {'status': true};
        } else {
          return {'status': false, 'error': 'Failed to unblock user'};
        }
      } else {
        return {'status': false, 'error': 'Failed to unblock user'};
      }
    } on DioException catch (e) {
      print('🔴 [ProfileApi] Unblock exception: $e');
      return {'status': false, 'error': e.message ?? 'Network error'};
    } catch (e) {
      print('🔴 [ProfileApi] Unblock error: $e');
      return {'status': false, 'error': e.toString()};
    }
  }

  /// Смена пароля
  Future<Map<String, dynamic>> changePassword({
    required String token,
    required int userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      print('🔵 [ProfileApi] Changing password for user: $userId');
      
      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: {
          'key': '3090379067',
          'route': 'profile/card/editPass',
        },
        data: {
          'id_user': userId,
          'token': token,
          'current_pass': currentPassword,
          'new_pass': newPassword,
        },
      );

      final data = response.data is String 
          ? json.decode(response.data) 
          : response.data;

      if (data['status'] == true) {
        print('✅ [ProfileApi] Password changed successfully');
        return {'status': true};
      } else {
        final errors = data['errors']?.toString() ?? 'Failed to change password';
        print('🔴 [ProfileApi] Password change failed: $errors');
        return {'status': false, 'error': errors};
      }
    } on DioException catch (e) {
      print('🔴 [ProfileApi] Password change exception: $e');
      return {'status': false, 'error': e.message ?? 'Network error'};
    } catch (e) {
      print('🔴 [ProfileApi] Password change error: $e');
      return {'status': false, 'error': e.toString()};
    }
  }

  /// Редактирование текстового статуса профиля
  Future<Map<String, dynamic>> editTextStatus({
    required String token,
    required int userId,
    required String text,
  }) async {
    try {
      print('🔵 [ProfileApi] Editing text status for user: $userId');
      
      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: {
          'key': '3090379067',
          'route': 'profile/card/editTextStatus',
        },
        data: {
          'id_user': userId,
          'token': token,
          'text': text,
        },
      );

      print('🔵 [ProfileApi] Edit text status response: ${response.data}');
      
      if (response.statusCode == 200) {
        final data = response.data is String 
            ? json.decode(response.data) 
            : response.data;
        
        if (data['status'] == true) {
          print('✅ [ProfileApi] Text status updated');
          return {'status': true};
        } else {
          return {'status': false, 'error': 'Failed to update text status'};
        }
      } else {
        return {'status': false, 'error': 'Failed to update text status'};
      }
    } on DioException catch (e) {
      print('🔴 [ProfileApi] Edit text status exception: $e');
      return {'status': false, 'error': e.message ?? 'Network error'};
    } catch (e) {
      print('🔴 [ProfileApi] Edit text status error: $e');
      return {'status': false, 'error': e.toString()};
    }
  }

  /// Очистка черного списка
  Future<Map<String, dynamic>> clearBlacklist({
    required String token,
    required int userId,
  }) async {
    try {
      print('🔵 [ProfileApi] Clearing blacklist for user: $userId');
      
      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: {
          'key': '3090379067',
          'route': 'profile/blacklist/clear',
        },
        data: {
          'id_user': userId,
          'token': token,
        },
      );

      print('🔵 [ProfileApi] Clear blacklist response: ${response.data}');
      
      if (response.statusCode == 200) {
        final data = response.data is String 
            ? json.decode(response.data) 
            : response.data;
        
        if (data['status'] == true) {
          print('✅ [ProfileApi] Blacklist cleared');
          return {'status': true};
        } else {
          return {'status': false, 'error': 'Failed to clear blacklist'};
        }
      } else {
        return {'status': false, 'error': 'Failed to clear blacklist'};
      }
    } on DioException catch (e) {
      print('🔴 [ProfileApi] Clear blacklist exception: $e');
      return {'status': false, 'error': e.message ?? 'Network error'};
    } catch (e) {
      print('🔴 [ProfileApi] Clear blacklist error: $e');
      return {'status': false, 'error': e.toString()};
    }
  }


  /// Обновление статуса пользователя
  //INTEGRATED
  Future<Map<String, dynamic>> updateStatus({
    required String token,
    required int userId,
    required String status,
  }) async {
    try {
      print('🔵 [ProfileApi] Updating status for user: $userId');
      print('🔵 [ProfileApi] New status: $status');
      print('🔵 [ProfileApi] Token: ${token.substring(0, 20)}...');
      print('🔵 [ProfileApi] Full token: $token');
      
      // Manually encode as URL-encoded form data
      final Map<String, dynamic> formData = {
        'id_user': userId,
        'token': token,
        'text': status,
      };
      
      print('🔵 [ProfileApi] FormData to send: $formData');
      print('🔵 [ProfileApi] BaseURL: ${ApiConfig.baseUrl}');
      print('🔵 [ProfileApi] Full URL: ${ApiConfig.baseUrl}/systems/api/controller.php?key=3090379067&route=profile/card/editTextStatus');
      
      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: {
          'key': '3090379067',
          'route': 'profile/card/editTextStatus',
          'id_user': userId,
          'token': token,
          'text': status,
        },
      );

      print('🔵 [ProfileApi] Update status response status: ${response.statusCode}');
      print('🔵 [ProfileApi] Response headers: ${response.headers}');
      print('📥 [ProfileApi] Update status response: ${response.data}');
      print('📥 [ProfileApi] Response type: ${response.data.runtimeType}');
      
      if (response.statusCode == 200) {
        final data = response.data is String 
            ? json.decode(response.data) 
            : response.data;
        
        print('✅ [ProfileApi] Status updated successfully');
        return {'status': true, 'data': data};
      } else {
        print('🔴 [ProfileApi] Server error ${response.statusCode}: ${response.data}');
        return {'status': false, 'error': 'Server error: ${response.statusCode}', 'response': response.data};
      }
    } on DioException catch (e) {
      print('🔴 [ProfileApi] Update status exception: $e');
      print('🔴 [ProfileApi] Exception type: ${e.type}');
      print('🔴 [ProfileApi] Request options: ${e.requestOptions.uri}');
      print('🔴 [ProfileApi] Request data: ${e.requestOptions.data}');
      print('🔴 [ProfileApi] Request headers: ${e.requestOptions.headers}');
      print('🔴 [ProfileApi] Response status: ${e.response?.statusCode}');
      print('🔴 [ProfileApi] Response data: ${e.response?.data}');
      print('🔴 [ProfileApi] Response headers: ${e.response?.headers}');
      return {'status': false, 'error': e.message ?? 'Network error'};
    } catch (e) {
      print('🔴 [ProfileApi] Update status error: $e');
      return {'status': false, 'error': e.toString()};
    }
  }

  /// Загрузка файла во временную папку (dropzone)
  Future<Map<String, dynamic>> uploadTempFile({
    required String filePath,
  }) async {
    try {
      print('🔵 [ProfileApi] Uploading temp file: $filePath');
      
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
      });

      final response = await _dio.post(
        '/systems/ajax/dropzone.php',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );

      print('🔵 [ProfileApi] Upload response status: ${response.statusCode}');
      print('📥 [ProfileApi] Upload response: ${response.data}');
      
      if (response.statusCode == 200) {
        final data = response.data is String 
            ? json.decode(response.data) 
            : response.data;
        
        print('✅ [ProfileApi] File uploaded successfully');
        return {'status': true, 'data': data};
      } else {
        print('🔴 [ProfileApi] Upload error ${response.statusCode}');
        return {'status': false, 'error': 'Upload failed'};
      }
    } on DioException catch (e) {
      print('🔴 [ProfileApi] Upload exception: $e');
      return {'status': false, 'error': e.message ?? 'Network error'};
    } catch (e) {
      print('🔴 [ProfileApi] Upload error: $e');
      return {'status': false, 'error': e.toString()};
    }
  }

  /// Загрузка аватара в temp через assets/save
  Future<Map<String, dynamic>> uploadAvatarToTemp({
    required int userId,
    required String token,
    required String fileBase64,
  }) async {
    try {
      print('🔵 [ProfileApi] Uploading avatar to temp');
      
      final data = {
        'id_user': userId,
        'token': token,
        'assets': fileBase64,
        'action': 'userAvatar',
      };
      
      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: {
          'key': '3090379067',
          'route': 'assets/save',
        },
        data: data,
      );

      print('🔵 [ProfileApi] Upload avatar response status: ${response.statusCode}');
      print('📥 [ProfileApi] Upload avatar response: ${response.data}');
      
      if (response.statusCode == 200) {
        final responseData = response.data is String 
            ? json.decode(response.data) 
            : response.data;
        
        print('✅ [ProfileApi] Avatar uploaded to temp');
        return {'status': true, 'data': responseData['data']};
      } else {
        print('🔴 [ProfileApi] Upload error ${response.statusCode}');
        return {'status': false, 'error': 'Upload failed'};
      }
    } on DioException catch (e) {
      print('🔴 [ProfileApi] Upload avatar exception: $e');
      return {'status': false, 'error': e.message ?? 'Network error'};
    } catch (e) {
      print('🔴 [ProfileApi] Upload avatar error: $e');
      return {'status': false, 'error': e.toString()};
    }
  }

  /// Обновление профиля с аватаром
  Future<Map<String, dynamic>> updateProfile({
    required int userId,
    required String token,
    String? name,
    String? surname,
    String? middleName,
    String? typePerson,
    String? nameCompany,
    String? nicname,
    int? viewPhone,
    int? secureStatus,
    int? deliveryStatus,
    String? deliveryIdPointSend,
    List<Map<String, String>>? avatar,
  }) async {
    try {
      print('🔵 [ProfileApi] Updating profile for user: $userId');
      
      final data = {
        'id_user': userId.toString(),
        'token': token,
      };

      if (name != null) data['name'] = name;
      if (surname != null) data['surname'] = surname;
      if (middleName != null) data['middle_name'] = middleName;
      if (typePerson != null) data['type_person'] = typePerson;
      if (nameCompany != null) data['name_company'] = nameCompany;
      if (nicname != null) data['nicname'] = nicname;
      if (viewPhone != null) data['view_phone'] = viewPhone.toString();
      if (secureStatus != null) data['secure_status'] = secureStatus.toString();
      if (deliveryStatus != null) data['delivery_status'] = deliveryStatus.toString();
      if (deliveryIdPointSend != null) data['delivery_id_point_send'] = deliveryIdPointSend;

      if (avatar != null && avatar.isNotEmpty) {
        data['avatar'] = json.encode(avatar);
      }

      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: {
          'key': '3090379067',
          'route': 'profile/card/editCard',
        },
        data: data,
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
        ),
      );

      print('🔵 [ProfileApi] Update profile response status: ${response.statusCode}');
      print('📥 [ProfileApi] Update profile response: ${response.data}');
      
      if (response.statusCode == 200) {
        final responseData = response.data is String 
            ? json.decode(response.data) 
            : response.data;
        
        print('✅ [ProfileApi] Profile updated successfully');
        return {'status': true, 'data': responseData};
      } else {
        print('🔴 [ProfileApi] Update error ${response.statusCode}');
        return {'status': false, 'error': 'Update failed'};
      }
    } on DioException catch (e) {
      print('🔴 [ProfileApi] Update profile exception: $e');
      return {'status': false, 'error': e.message ?? 'Network error'};
    } catch (e) {
      print('🔴 [ProfileApi] Update profile error: $e');
      return {'status': false, 'error': e.toString()};
    }
  }

  /// Оплата публикации объявления в категории
  Future<Map<String, dynamic>> payCategoryPublication({
    required String token,
    required int userId,
    required int adId,
  }) async {
    try {
      print('🔵 [ProfileApi] Paying for category publication: adId=$adId, userId=$userId');
      
      final response = await _dio.get(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'ads/payCategoryPublication',
          'token': token,
          'id_user': userId,
          'id_ad': adId,
        },
      );

      print('🔵 [ProfileApi] Pay category publication response status: ${response.statusCode}');
      print('📥 [ProfileApi] Pay category publication response: ${response.data}');
      
      if (response.statusCode == 200) {
        final data = response.data is String 
            ? jsonDecode(response.data) 
            : response.data;
        
        if (data['status'] == true) {
          print('✅ [ProfileApi] Category publication paid successfully');
          return {'status': true, 'message': data['message']};
        } else {
          // Если недостаточно баланса
          if (data['error'] == 'insufficient_balance') {
            print('🔴 [ProfileApi] Insufficient balance: ${data['balance']} / ${data['required']}');
            return {
              'status': false,
              'error': 'insufficient_balance',
              'balance': data['balance'],
              'required': data['required'],
            };
          }
          
          print('🔴 [ProfileApi] Payment failed: ${data['error']}');
          return {'status': false, 'error': data['error'] ?? 'Payment failed'};
        }
      } else {
        print('🔴 [ProfileApi] Server error ${response.statusCode}');
        return {'status': false, 'error': 'Server error: ${response.statusCode}'};
      }
    } on DioException catch (e) {
      print('🔴 [ProfileApi] Pay category publication exception: $e');
      return {'status': false, 'error': e.message ?? 'Network error'};
    } catch (e) {
      print('🔴 [ProfileApi] Pay category publication error: $e');
      return {'status': false, 'error': e.toString()};
    }
  }

  /// Заблокировать/разблокировать пользователя
  Future<Map<String, dynamic>> blockUser({
    required int idUserFrom,
    required String token,
    required int idUserTo,
  }) async {
    try {
      print('🔵 [ProfileApi] Block/unblock user request: from=$idUserFrom, to=$idUserTo');
      
      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'card_user/block',
        },
        data: {
          'id_user_from': idUserFrom,
          'token': token,
          'id_user_to': idUserTo,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      print('🔵 [ProfileApi] Block response: ${response.data}');
      
      final responseData = response.data is String
          ? jsonDecode(response.data)
          : response.data;
      
      return responseData;
    } on DioException catch (e) {
      print('🔴 [ProfileApi] Block exception: $e');
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      print('🔴 [ProfileApi] Block error: $e');
      throw Exception(e.toString());
    }
  }

  /// Сохранить телефон пользователя
  /// Используется в настройках профиля
  /// Возвращает {'status': true, 'verify': bool} если успешно
  /// verify=true означает что нужно ввести код подтверждения
  Future<Map<String, dynamic>> savePhone({
    required int userId,
    required String token,
    required String phone,
  }) async {
    try {
      print('🔵 [ProfileApi] Saving phone: $phone for user: $userId');

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

      print('🔵 [ProfileApi] Save phone response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = response.data is String
            ? json.decode(response.data)
            : response.data;

        print('📥 [ProfileApi] Save phone response data: $data');

        if (data['status'] == true) {
          print('✅ [ProfileApi] Phone save initiated, verify=${data['verify']}');
          return {
            'status': true,
            'verify': data['verify'] ?? false,
            'title': data['title'],
          };
        } else {
          print('🔴 [ProfileApi] Save phone failed: ${data['answer']}');
          return {'status': false, 'error': data['answer']};
        }
      } else {
        print('🔴 [ProfileApi] Server error ${response.statusCode}: ${response.data}');
        return {'status': false, 'error': 'Server error: ${response.statusCode}'};
      }
    } on DioException catch (e) {
      print('🔴 [ProfileApi] Save phone exception: $e');
      return {'status': false, 'error': e.message ?? 'Network error'};
    } catch (e) {
      print('🔴 [ProfileApi] Save phone error: $e');
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
      print('🔵 [ProfileApi] Verifying phone: $phone with code: $code');

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

      print('🔵 [ProfileApi] Verify phone response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = response.data is String
            ? json.decode(response.data)
            : response.data;

        print('📥 [ProfileApi] Verify phone response data: $data');

        if (data['status'] == true) {
          print('✅ [ProfileApi] Phone verified successfully');
          return {'status': true};
        } else {
          print('🔴 [ProfileApi] Verify phone failed: ${data['answer']}');
          return {'status': false, 'error': data['answer']};
        }
      } else {
        print('🔴 [ProfileApi] Server error ${response.statusCode}: ${response.data}');
        return {'status': false, 'error': 'Server error: ${response.statusCode}'};
      }
    } on DioException catch (e) {
      print('🔴 [ProfileApi] Verify phone exception: $e');
      return {'status': false, 'error': e.message ?? 'Network error'};
    } catch (e) {
      print('🔴 [ProfileApi] Verify phone error: $e');
      return {'status': false, 'error': e.toString()};
    }
  }

  /// Пожаловаться на пользователя
  Future<Map<String, dynamic>> complainUser({
    required int idUserFrom,
    required String token,
    required int idUserTo,
    required String text,
  }) async {
    try {
      print('🔵 [ProfileApi] Complain user request: from=$idUserFrom, to=$idUserTo');
      
      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'card_user/complain',
        },
        data: {
          'id_user_from': idUserFrom,
          'token': token,
          'id_user_to': idUserTo,
          'text': text,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      print('🔵 [ProfileApi] Complain response: ${response.data}');
      
      final responseData = response.data is String
          ? jsonDecode(response.data)
          : response.data;
      
      return responseData;
    } on DioException catch (e) {
      print('🔴 [ProfileApi] Complain exception: $e');
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      print('🔴 [ProfileApi] Complain error: $e');
      throw Exception(e.toString());
    }
  }
}
import 'package:dio/dio.dart';
import 'dart:convert';
import 'dart:io';
import 'api_config.dart';
import 'package:hashtagg/core/network/api_config.dart';

class StoriesApiRepository {
  final Dio _dio;

  StoriesApiRepository({Dio? dio}) : _dio = dio ?? Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
  ));

  /// Получение всех сторисов
  /// Получение всех сторисов
  Future<Map<String, dynamic>> getStories({
    int? userId,
    int? idUserAuth,
    int? cityId,
    int? regionId,
    int? countryId,
    int? catId,
  }) async {
    try {
      print('🔵 [StoriesApi] Getting stories with params:');
      print('🔵 [StoriesApi] - userId: $userId');
      print('🔵 [StoriesApi] - idUserAuth: $idUserAuth');
      print('🔵 [StoriesApi] - cityId: $cityId');
      print('🔵 [StoriesApi] - regionId: $regionId');
      print('🔵 [StoriesApi] - countryId: $countryId');
      print('🔵 [StoriesApi] - catId: $catId');

      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: {
          'key': '3090379067',
          'route': 'stories/getStories',
        },
        data: {
          if (userId != null) 'id_user': userId,
          if (idUserAuth != null) 'id_user_auth': idUserAuth,
          if (cityId != null) 'city_id': cityId,
          if (regionId != null) 'region_id': regionId,
          if (countryId != null) 'country_id': countryId,
          if (catId != null) 'cat_id': catId,
        },
        options: Options(
          validateStatus: (status) => true,
        ),
      );

      print('🔵 [StoriesApi] Request URL: ${response.requestOptions.uri}');
      print('🔵 [StoriesApi] Stories response status: ${response.statusCode}');
      print('📥 [StoriesApi] Stories raw response: ${response.data}');

      if (response.statusCode == 200) {
        // ✅ ПРОСТО ПАРСИМ JSON, БЕЗ replaceMediaUrl!
        final data = response.data is String
            ? json.decode(response.data)
            : response.data;

        print('✅ [StoriesApi] Loaded stories');
        return {'status': true, 'data': data};
      } else {
        print('🔴 [StoriesApi] Server error ${response.statusCode}: ${response.data}');
        return {'status': false, 'error': 'Server error: ${response.statusCode}'};
      }
    } on DioException catch (e) {
      print('🔴 [StoriesApi] Stories exception: $e');
      print('🔴 [StoriesApi] Response data: ${e.response?.data}');
      return {'status': false, 'error': e.message ?? 'Network error'};
    } catch (e) {
      print('🔴 [StoriesApi] Stories error: $e');
      return {'status': false, 'error': e.toString()};
    }
  }

  /// Получение сторисов конкретного пользователя
  Future<Map<String, dynamic>> getUserStories({
    required int userId,
    int? idUserAuth,
  }) async {
    try {
      print('🔵 [StoriesApi] Getting user stories - userId: $userId');

      final response = await _dio.get(
        '/systems/ajax/controller.php',  // ← БЫЛО /systems/api/controller.php
        queryParameters: {
          'key': '3090379067',
          'action': 'profile/load_user_stories',  // ← БЫЛО route: 'stories/getStories'
          'id': userId,
          if (idUserAuth != null) 'id_user_auth': idUserAuth,
        },
      );

      print('🔵 [StoriesApi] User stories response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = response.data is String 
            ? json.decode(response.data) 
            : response.data;
        
        print('✅ [StoriesApi] Loaded user stories');
        return {'status': true, 'data': data};
      } else {
        return {'status': false, 'error': 'Server error: ${response.statusCode}'};
      }
    } on DioException catch (e) {
      print('🔴 [StoriesApi] User stories exception: $e');
      return {'status': false, 'error': e.message ?? 'Network error'};
    } catch (e) {
      print('🔴 [StoriesApi] User stories error: $e');
      return {'status': false, 'error': e.toString()};
    }
  }

  /// Обновление счетчика просмотров
  Future<Map<String, dynamic>> updateCountView({
    required int storyId,
    required String ip,
  }) async {
    try {
      print('🔵 [StoriesApi] Updating view count - storyId: $storyId');
      
      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: {
          'key': '3090379067',
          'route': 'stories/updateCountView',
        },
        data: {
          'id': storyId,
          'ip': ip,
        },
      );

      print('🔵 [StoriesApi] Update view response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = response.data is String 
            ? json.decode(response.data) 
            : response.data;
        
        print('✅ [StoriesApi] View count updated');
        return {'status': true, 'data': data};
      } else {
        return {'status': false, 'error': 'Server error: ${response.statusCode}'};
      }
    } on DioException catch (e) {
      print('🔴 [StoriesApi] Update view exception: $e');
      return {'status': false, 'error': e.message ?? 'Network error'};
    } catch (e) {
      print('🔴 [StoriesApi] Update view error: $e');
      return {'status': false, 'error': e.toString()};
    }
  }

  /// Удаление стории
  Future<Map<String, dynamic>> deleteStory({
    required int userId,
    required String token,
    required int storyId,
  }) async {
    try {
      print('🔵 [StoriesApi] Deleting story - storyId: $storyId');
      
      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: {
          'key': '3090379067',
          'route': 'stories/delete',
        },
        data: {
          'id_user': userId,
          'token': token,
          'id': storyId,
        },
      );

      print('🔵 [StoriesApi] Delete story response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = response.data is String 
            ? json.decode(response.data) 
            : response.data;
        
        print('✅ [StoriesApi] Story deleted');
        return {'status': true, 'data': data};
      } else {
        return {'status': false, 'error': 'Server error: ${response.statusCode}'};
      }
    } on DioException catch (e) {
      print('🔴 [StoriesApi] Delete story exception: $e');
      return {'status': false, 'error': e.message ?? 'Network error'};
    } catch (e) {
      print('🔴 [StoriesApi] Delete story error: $e');
      return {'status': false, 'error': e.toString()};
    }
  }

  /// Загрузка фото стории
  Future<Map<String, dynamic>> uploadImage({
    required int userId,
    required String token,
    required String filePath,
    required String fileName,
    int cityId = 0,
    int regionId = 0,
    int countryId = 0,
    int catId = 0,
    String link = 'profile',
    int id = 0,
  }) async {
    try {
      print('🔵 [StoriesApi] Uploading image - fileName: $fileName');
      print('🔵 [StoriesApi] Params: userId=$userId, cityId=$cityId, regionId=$regionId, countryId=$countryId, catId=$catId, link=$link, id=$id');
      
      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: {
          'key': '3090379067',
          'route': 'stories/addImage',
        },
        data: {
          'id_user': userId,
          'token': token,
          'file_name': fileName,
          'type': 'image',
          'city_id': cityId,
          'region_id': regionId,
          'country_id': countryId,
          'cat_id': catId,
          'link': link,
          'id': id,
        },
        options: Options(
          validateStatus: (status) => true,
        ),
      );

      print('🔵 [StoriesApi] Upload image response status: ${response.statusCode}');
      print('📥 [StoriesApi] Upload image response: ${response.data}');
      
      if (response.statusCode == 200) {
        final data = response.data is String 
            ? json.decode(response.data) 
            : response.data;
        
        print('✅ [StoriesApi] Image uploaded');
        return {'status': true, 'data': data};
      } else {
        print('🔴 [StoriesApi] Server error ${response.statusCode}: ${response.data}');
        return {'status': false, 'error': 'Server error: ${response.statusCode}'};
      }
    } on DioException catch (e) {
      print('🔴 [StoriesApi] Upload image exception: $e');
      print('🔴 [StoriesApi] Response: ${e.response?.data}');
      return {'status': false, 'error': e.message ?? 'Network error'};
    } catch (e) {
      print('🔴 [StoriesApi] Upload image error: $e');
      return {'status': false, 'error': e.toString()};
    }
  }

  /// Загрузка видео стории
  Future<Map<String, dynamic>> uploadVideo({
    required int userId,
    required String token,
    required String fileBase64,
    required String fileName,
    required int videoDuration,
    int cityId = 0,
    int regionId = 0,
    int countryId = 0,
    int catId = 0,
    String link = 'profile',
    int id = 0,
  }) async {
    try {
      print('🔵 [StoriesApi] Uploading video - fileName: $fileName');
      
      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: {
          'key': '3090379067',
          'route': 'stories/addVideo',
        },
        data: {
          'id_user': userId,
          'token': token,
          'file_name': fileName,
          'file_base64': fileBase64,
          'type': 'video',
          'video_duration': videoDuration,
          'city_id': cityId,
          'region_id': regionId,
          'country_id': countryId,
          'cat_id': catId,
          'link': link,
          'id': id,
        },
      );

      print('🔵 [StoriesApi] Upload video response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = response.data is String 
            ? json.decode(response.data) 
            : response.data;
        
        print('✅ [StoriesApi] Video uploaded');
        return {'status': true, 'data': data};
      } else {
        return {'status': false, 'error': 'Server error: ${response.statusCode}'};
      }
    } on DioException catch (e) {
      print('🔴 [StoriesApi] Upload video exception: $e');
      return {'status': false, 'error': e.message ?? 'Network error'};
    } catch (e) {
      print('🔴 [StoriesApi] Upload video error: $e');
      return {'status': false, 'error': e.toString()};
    }
  }

  /// Обновление изображения стории
  Future<Map<String, dynamic>> updateImage({
    required int userId,
    required String token,
    required int mediaId,
    required String fileName,
  }) async {
    try {
      print('🔵 [StoriesApi] Updating image - mediaId: $mediaId, fileName: $fileName');
      
      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: {
          'key': '3090379067',
          'route': 'stories/updateImage',
        },
        data: {
          'id_user': userId,
          'token': token,
          'media_id': mediaId,
          'file_name': fileName,
        },
        options: Options(
          validateStatus: (status) => true,
        ),
      );

      print('🔵 [StoriesApi] Update image response status: ${response.statusCode}');
      print('📥 [StoriesApi] Update image response: ${response.data}');
      
      if (response.statusCode == 200) {
        final data = response.data is String 
            ? json.decode(response.data) 
            : response.data;
        
        print('✅ [StoriesApi] Image updated');
        return {'status': true, 'data': data};
      } else {
        print('🔴 [StoriesApi] Server error ${response.statusCode}: ${response.data}');
        return {'status': false, 'error': 'Server error: ${response.statusCode}'};
      }
    } on DioException catch (e) {
      print('🔴 [StoriesApi] Update image exception: $e');
      print('🔴 [StoriesApi] Response: ${e.response?.data}');
      return {'status': false, 'error': e.message ?? 'Network error'};
    } catch (e) {
      print('🔴 [StoriesApi] Update image error: $e');
      return {'status': false, 'error': e.toString()};
    }
  }

  /// Обновление видео стории
  Future<Map<String, dynamic>> updateVideo({
    required int userId,
    required String token,
    required int mediaId,
    required String fileName,
    required String fileBase64,
    required int videoDuration,
  }) async {
    try {
      print('🔵 [StoriesApi] Updating video - mediaId: $mediaId, fileName: $fileName');
      
      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: {
          'key': '3090379067',
          'route': 'stories/updateVideo',
        },
        data: {
          'id_user': userId,
          'token': token,
          'media_id': mediaId,
          'file_name': fileName.replaceAll('.mp4', '').replaceAll('.webp', ''), // Убираем расширение, сервер добавит сам
          'file_base64': fileBase64,
          'video_duration': videoDuration,
        },
        options: Options(
          validateStatus: (status) => true,
        ),
      );

      print('🔵 [StoriesApi] Update video response status: ${response.statusCode}');
      print('📥 [StoriesApi] Update video response: ${response.data}');
      
      if (response.statusCode == 200) {
        final data = response.data is String 
            ? json.decode(response.data) 
            : response.data;
        
        print('✅ [StoriesApi] Video updated');
        return {'status': true, 'data': data};
      } else {
        print('🔴 [StoriesApi] Server error ${response.statusCode}: ${response.data}');
        return {'status': false, 'error': 'Server error: ${response.statusCode}'};
      }
    } on DioException catch (e) {
      print('🔴 [StoriesApi] Update video exception: $e');
      print('🔴 [StoriesApi] Response: ${e.response?.data}');
      return {'status': false, 'error': e.message ?? 'Network error'};
    } catch (e) {
      print('🔴 [StoriesApi] Update video error: $e');
      return {'status': false, 'error': e.toString()};
    }
  }

  /// Загрузка файла в temp для стории
  Future<Map<String, dynamic>> uploadToTemp({
    required int userId,
    required String token,
    required String fileBase64,
  }) async {
    try {
      print('🔵 [StoriesApi] Uploading to temp');
      print('🔵 [StoriesApi] userId: $userId');
      print('🔵 [StoriesApi] token length: ${token.length}');
      print('🔵 [StoriesApi] fileBase64 length: ${fileBase64.length}');
      print('🔵 [StoriesApi] fileBase64 preview: ${fileBase64.substring(0, fileBase64.length > 100 ? 100 : fileBase64.length)}...');
      
      final data = {
        'id_user': userId,
        'token': token,
        'assets': fileBase64,
        'action': 'storyAdd',
      };
      
      print('🔵 [StoriesApi] Request data keys: ${data.keys.toList()}');
      print('🔵 [StoriesApi] Request URL: /systems/api/controller.php?key=3090379067&route=assets/save');
      
      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: {
          'key': '3090379067',
          'route': 'assets/save',
        },
        data: data,
        options: Options(
          validateStatus: (status) => true, // Не выбрасывать исключение на любой статус
        ),
      );

      print('🔵 [StoriesApi] Upload to temp response status: ${response.statusCode}');
      print('📥 [StoriesApi] Upload to temp response: ${response.data}');
      
      if (response.statusCode == 200) {
        final data = response.data is String 
            ? json.decode(response.data) 
            : response.data;
        
        print('✅ [StoriesApi] Uploaded to temp: ${data['data']}');
        return {'status': true, 'data': data['data']};
      } else {
        print('🔴 [StoriesApi] Server error ${response.statusCode}: ${response.data}');
        return {'status': false, 'error': 'Server error: ${response.statusCode}'};
      }
    } on DioException catch (e) {
      print('🔴 [StoriesApi] Upload to temp exception: $e');
      print('🔴 [StoriesApi] Exception type: ${e.type}');
      print('🔴 [StoriesApi] Exception message: ${e.message}');
      print('🔴 [StoriesApi] Response status: ${e.response?.statusCode}');
      print('🔴 [StoriesApi] Response data: ${e.response?.data}');
      return {'status': false, 'error': e.message ?? 'Network error'};
    } catch (e) {
      print('🔴 [StoriesApi] Upload to temp error: $e');
      print('🔴 [StoriesApi] Error type: ${e.runtimeType}');
      return {'status': false, 'error': e.toString()};
    }
  }
}

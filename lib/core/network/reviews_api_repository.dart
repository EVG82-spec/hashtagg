import 'package:dio/dio.dart';
import 'dart:convert';
import 'api_config.dart';

class ReviewsApiRepository {
  final Dio _dio;

  ReviewsApiRepository({Dio? dio}) : _dio = dio ?? Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    validateStatus: (status) => status! < 500,
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
  ));

  /// Получение отзывов о пользователе
  Future<Map<String, dynamic>> getReviews({
    required int userId,
    int page = 1,
  }) async {
    try {
      print('🔵 [ReviewsApi] Getting reviews for user: $userId, page: $page');
      
      final response = await _dio.get(
        '/systems/api/controller.php',
        queryParameters: {
          'key': '3090379067',
          'route': 'reviews/getReviews',
          'id_user': userId,
          'page': page,
        },
      );

      print('🔵 [ReviewsApi] Reviews response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = response.data is String 
            ? json.decode(response.data) 
            : response.data;
        
        // Заменяем localhost на 192.168.1.3:8000 в аватарах
        if (data['data'] != null && data['data'] is List) {
          for (var review in data['data']) {
            if (review['avatar'] != null && review['avatar'] is String) {
              final originalAvatar = review['avatar'] as String;
              review['avatar'] = ApiConfig.replaceMediaUrl(originalAvatar);
              if (originalAvatar != review['avatar']) {
                print('🔵 [ReviewsApi] Replaced avatar URL: $originalAvatar -> ${review['avatar']}');
              }
            }
          }
        }
        
        print('✅ [ReviewsApi] Loaded ${data['count'] ?? 0} reviews');
        return {'status': true, ...data};
      } else {
        return {'status': false, 'error': 'Failed to load reviews', 'data': []};
      }
    } on DioException catch (e) {
      print('🔴 [ReviewsApi] Reviews exception: $e');
      return {'status': false, 'error': e.message ?? 'Network error', 'data': []};
    } catch (e) {
      print('🔴 [ReviewsApi] Reviews error: $e');
      return {'status': false, 'error': e.toString(), 'data': []};
    }
  }

  /// Добавление отзыва о пользователе
  Future<Map<String, dynamic>> addReview({
    required String token,
    required int userIdFrom,
    required int userIdTo,
    required int adId,
    required int rating,
    required String text,
    required int deal, // 1 - успешная сделка, 2 - неуспешная
  }) async {
    try {
      print('🔵 [ReviewsApi] Adding review: from=$userIdFrom, to=$userIdTo, ad=$adId, rating=$rating');
      
      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: {
          'key': '3090379067',
          'route': 'reviews/add',
        },
        data: {
          'id_user_auth': userIdFrom,
          'token': token,
          'id_user_to': userIdTo,
          'id_ad': adId,
          'rating': rating,
          'text': text,
          'deal': deal,
        },
      );

      final data = response.data is String 
          ? json.decode(response.data) 
          : response.data;

      if (data['status'] == true) {
        print('✅ [ReviewsApi] Review added successfully');
        return {'status': true};
      } else {
        final error = data['answer']?.toString() ?? 'Failed to add review';
        print('🔴 [ReviewsApi] Review add failed: $error');
        return {'status': false, 'error': error};
      }
    } on DioException catch (e) {
      print('🔴 [ReviewsApi] Add review exception: $e');
      return {'status': false, 'error': e.message ?? 'Network error'};
    } catch (e) {
      print('🔴 [ReviewsApi] Add review error: $e');
      return {'status': false, 'error': e.toString()};
    }
  }
}

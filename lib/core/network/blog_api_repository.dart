import 'package:dio/dio.dart';
import 'dart:convert';
import 'api_config.dart';

class BlogApiRepository {
  final Dio _dio;

  BlogApiRepository({Dio? dio}) : _dio = dio ?? Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    validateStatus: (status) => status! < 500,
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
  ));

  /// Получение списка статей блога
  Future<Map<String, dynamic>> getArticles({
    int? categoryId,
    int page = 1,
  }) async {
    try {
      print('🔵 [BlogApi] Getting articles - categoryId: $categoryId, page: $page');
      
      final response = await _dio.get(
        '/systems/api/controller.php',
        queryParameters: {
          'key': '3090379067',
          'route': 'blog/getArticles',
          if (categoryId != null) 'cat_id': categoryId,
          'page': page,
        },
      );

      print('🔵 [BlogApi] Articles response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = response.data is String 
            ? json.decode(response.data) 
            : response.data;
        
        // Заменяем localhost на 192.168.1.3:8000 в изображениях
        if (data['data'] != null && data['data'] is List) {
          for (var article in data['data']) {
            if (article['image'] != null && article['image'] is String) {
              final originalImage = article['image'] as String;
              article['image'] = ApiConfig.replaceMediaUrl(originalImage);
              if (originalImage != article['image']) {
                print('🔵 [BlogApi] Replaced image URL: $originalImage -> ${article['image']}');
              }
            }
          }
        }
        
        print('✅ [BlogApi] Loaded ${data['count'] ?? 0} articles');
        return {'status': true, ...data};
      } else {
        return {'status': false, 'error': 'Failed to load articles', 'data': []};
      }
    } on DioException catch (e) {
      print('🔴 [BlogApi] Articles exception: $e');
      return {'status': false, 'error': e.message ?? 'Network error', 'data': []};
    } catch (e) {
      print('🔴 [BlogApi] Articles error: $e');
      return {'status': false, 'error': e.toString(), 'data': []};
    }
  }

  /// Получение детальной информации о статье
  Future<Map<String, dynamic>> getArticle({
    required int articleId,
  }) async {
    try {
      print('🔵 [BlogApi] Getting article: $articleId');
      
      final response = await _dio.get(
        '/systems/api/controller.php',
        queryParameters: {
          'key': '3090379067',
          'route': 'blog/getArticle',
          'id': articleId,
        },
      );

      print('🔵 [BlogApi] Article response status: ${response.statusCode}');
      print('📥 [BlogApi] Article raw response: ${response.data}');
      
      if (response.statusCode == 200) {
        final data = response.data is String 
            ? json.decode(response.data) 
            : response.data;
        
        print('📥 [BlogApi] Article parsed JSON: $data');
        
        // Заменяем localhost на 192.168.1.3:8000 в изображении
        if (data['image'] != null && data['image'] is String) {
          final originalImage = data['image'] as String;
          data['image'] = ApiConfig.replaceMediaUrl(originalImage);
          if (originalImage != data['image']) {
            print('🔵 [BlogApi] Replaced image URL: $originalImage -> ${data['image']}');
          }
        }
        
        print('✅ [BlogApi] Article loaded: ${data['title']}');
        return {'status': true, ...data};
      } else {
        return {'status': false, 'error': 'Failed to load article'};
      }
    } on DioException catch (e) {
      print('🔴 [BlogApi] Article exception: $e');
      return {'status': false, 'error': e.message ?? 'Network error'};
    } catch (e) {
      print('🔴 [BlogApi] Article error: $e');
      return {'status': false, 'error': e.toString()};
    }
  }
}

import 'dart:convert';
import 'package:hashtagg/core/network/dio_client.dart';
import 'package:hashtagg/core/network/api_config.dart';
import 'package:dio/dio.dart';

class CategoriesApiRepository {
  final _dio = DioClient.createDio();

  /// Получить категории по родительскому ID
  /// 
  /// Параметры:
  /// - [parentId]: ID родительской категории (0 для корневых категорий)
  /// 
  /// Возвращает:
  /// ```dart
  /// {
  ///   'status': true,
  ///   'main': true, // true если это корневые категории
  ///   'title': 'Название родительской категории',
  ///   'data': [
  ///     {
  ///       'category_board_id': 1,
  ///       'category_board_name': 'Недвижимость',
  ///       'category_board_image': 'https://...',
  ///       'category_board_id_parent': 0,
  ///       'subcategory': true, // есть ли подкатегории
  ///       'breadcrumb': 'Недвижимость'
  ///     }
  ///   ]
  /// }
  /// ```
  Future<Map<String, dynamic>> getCategories({int parentId = 0}) async {
    try {
      print('🔵 [CategoriesApi] Loading categories with parentId=$parentId');
      
      final response = await _dio.get(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'catalog/getCategories',
          'id': parentId,
        },
      );
      
      final data = response.data is String 
          ? json.decode(response.data) 
          : response.data;
      
      print('✅ [CategoriesApi] Loaded ${(data['data'] as List?)?.length ?? 0} categories');
      return {
        'status': true,
        'main': data['main'] ?? false,
        'title': data['title'],
        'data': data['data'] ?? [],
      };
    } catch (e) {
      print('🔴 [CategoriesApi] Exception: $e');
      return {
        'status': false,
        'error': e.toString(),
        'data': [],
      };
    }
  }

  /// Получить все категории (плоский список и иерархия)
  /// 
  /// Возвращает:
  /// ```dart
  /// {
  ///   'status': true,
  ///   'data': {
  ///     'category': {
  ///       '1': {
  ///         'category_board_id': 1,
  ///         'category_board_name': 'Недвижимость',
  ///         'category_board_image': 'https://...',
  ///         'category_board_id_parent': 0,
  ///         'subcategory': true,
  ///         'breadcrumb': 'Недвижимость',
  ///         'nested': [...]
  ///       }
  ///     },
  ///     'parent': {
  ///       '0': [...], // корневые категории
  ///       '1': [...], // подкатегории категории с ID=1
  ///     }
  ///   }
  /// }
  /// ```
  Future<Map<String, dynamic>> getAllCategories() async {
    try {
      print('🔵 [CategoriesApi] Loading all categories');
      
      final response = await _dio.get(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'catalog/getAllCategories',
        },
      );
      
      final data = response.data is String 
          ? json.decode(response.data) 
          : response.data;
      
      print('✅ [CategoriesApi] Loaded all categories');
      return {
        'status': true,
        'data': data['data'] ?? {},
      };
    } catch (e) {
      print('🔴 [CategoriesApi] Exception: $e');
      return {
        'status': false,
        'error': e.toString(),
        'data': {},
      };
    }
  }

  /// Получить вложенные категории (простой формат)
  /// 
  /// Возвращает:
  /// ```dart
  /// {
  ///   'status': true,
  ///   'data': {
  ///     '0': [
  ///       {'name': 'Недвижимость', 'id': 1},
  ///       {'name': 'Транспорт', 'id': 2}
  ///     ],
  ///     '1': [
  ///       {'name': 'Квартиры', 'id': 10},
  ///       {'name': 'Дома', 'id': 11}
  ///     ]
  ///   }
  /// }
  /// ```
  Future<Map<String, dynamic>> getCategoriesNested() async {
    try {
      print('🔵 [CategoriesApi] Loading nested categories');
      
      final response = await _dio.get(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'catalog/getCategoriesNested',
        },
      );
      
      final data = response.data is String 
          ? json.decode(response.data) 
          : response.data;
      
      print('✅ [CategoriesApi] Loaded nested categories');
      return {
        'status': true,
        'data': data['data'] ?? {},
      };
    } catch (e) {
      print('🔴 [CategoriesApi] Exception: $e');
      return {
        'status': false,
        'error': e.toString(),
        'data': {},
      };
    }
  }

  Future<Map<String, dynamic>> searchCategories(String query) async {
    try {
      print('🔵 [CategoriesApi] Searching categories: $query');

      final response = await _dio.get(
        '/api/ads/smart-search',
        queryParameters: {
          'key': '3090379067',
          'query': query, // ← ПЕРЕДАЁМ ЧЕРЕЗ queryParameters
        },
        options: Options(
          validateStatus: (status) => true,
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data is String
            ? json.decode(response.data)
            : response.data;

        print('✅ [CategoriesApi] Search results: ${data['data']}');
        return {'status': true, 'data': data['data']};
      } else {
        return {'status': false, 'error': 'Server error: ${response.statusCode}'};
      }
    } catch (e) {
      print('🔴 [CategoriesApi] Search error: $e');
      return {'status': false, 'error': e.toString()};
    }
  }



}

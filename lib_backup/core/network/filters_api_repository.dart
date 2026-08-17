import 'dart:convert';
import 'package:hashtagg/core/network/dio_client.dart';
import 'package:hashtagg/core/network/api_config.dart';

/// Репозиторий для работы с API фильтров
class FiltersApiRepository {
  final _dio = DioClient.createDio();

  /// Получение опций фильтров для категории
  /// 
  /// Параметры:
  /// - [categoryId]: ID категории (0 для всех категорий)
  /// - [filters]: Текущие выбранные фильтры (для подфильтров)
  /// 
  /// Возвращает:
  /// ```dart
  /// {
  ///   'status': true,
  ///   'data': {
  ///     'options': {
  ///       'secure': 'Безопасная сделка',
  ///       'online_view': 'Онлайн-показ',
  ///       'auction': 'Аукцион',
  ///       'vip': 'VIP объявления',
  ///       'condition_status': 'Новые товары',
  ///       'booking': 'Онлайн-бронирование'
  ///     },
  ///     'price_name': 'Цена',
  ///     'filters': [
  ///       {
  ///         'id': 123,
  ///         'view': 'select', // или 'checkbox', 'input'
  ///         'name': 'Тип',
  ///         'items': [
  ///           {'id': 456, 'name': 'Легковые', 'podfilter': false}
  ///         ],
  ///         'required': true,
  ///         'podfilter': false,
  ///         'ids_podfilter': [124, 125]
  ///       }
  ///     ]
  ///   }
  /// }
  /// ```
  Future<Map<String, dynamic>> getFilterOptions({
    required int categoryId,
    Map<String, List<String>>? filters,
  }) async {
    try {
      print('🔵 [FiltersApi] Getting filter options for category: $categoryId');
      
      final response = await _dio.get(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'filters/getOptions',
          'id_cat': categoryId,
          if (filters != null && filters.isNotEmpty)
            'filters': jsonEncode(filters),
        },
      );
      
      final data = response.data is String 
          ? json.decode(response.data) 
          : response.data;
      
      print('✅ [FiltersApi] Filter options loaded');
      
      return {
        'status': true,
        'data': data['data'],
      };
    } catch (e) {
      print('🔴 [FiltersApi] Exception: $e');
      return {
        'status': false,
        'error': e.toString(),
        'data': null,
      };
    }
  }
}

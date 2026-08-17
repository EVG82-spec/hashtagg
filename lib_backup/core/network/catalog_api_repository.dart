import 'package:dio/dio.dart';
import 'dart:convert';
import 'package:hashtagg/core/network/api_config.dart';
import 'package:hashtagg/core/network/home_api_repository.dart';

/// API Result wrapper
class ApiResult<T> {
  final bool success;
  final T? data;
  final String? error;

  ApiResult({required this.success, this.data, this.error});
}

/// Параметры поиска/фильтрации объявлений
class CatalogSearchParams {
  final int? categoryId;
  final int? cityId;
  final int? regionId;
  final int? countryId;
  final String? search;
  final double? priceStart;
  final double? priceEnd;
  final String? sorting; // 'default', 'news', 'price_asc', 'price_desc'
  final int page;
  final bool? secure;
  final bool? vip;
  final bool? onlineView;
  final bool? auction;
  final bool? booking;
  final Map<String, dynamic>? filters;

  CatalogSearchParams({
    this.categoryId,
    this.cityId,
    this.regionId,
    this.countryId,
    this.search,
    this.priceStart,
    this.priceEnd,
    this.sorting = 'default',
    this.page = 1,
    this.secure,
    this.vip,
    this.onlineView,
    this.auction,
    this.booking,
    this.filters,
  });

  Map<String, dynamic> toQueryParams() {
    final params = <String, dynamic>{};
    
    if (categoryId != null) params['cat_id'] = categoryId;
    if (cityId != null) params['city_id'] = cityId;
    if (regionId != null) params['region_id'] = regionId;
    if (countryId != null) params['country_id'] = countryId;
    if (search != null && search!.isNotEmpty) params['search'] = search;
    if (priceStart != null) params['price_start'] = priceStart;
    if (priceEnd != null) params['price_end'] = priceEnd;
    if (sorting != null) params['sorting'] = sorting;
    params['page'] = page;
    if (secure == true) params['secure'] = 'true';
    if (vip == true) params['vip'] = 'true';
    if (onlineView == true) params['online_view'] = 'true';
    if (auction == true) params['auction'] = 'true';
    if (booking == true) params['booking'] = 'true';
    
    // Преобразуем фильтры в формат, ожидаемый бэкендом
    // Из {"1": ["6387", "6388"]} в [{"filterId": "1", "item": "6387"}, {"filterId": "1", "item": "6388"}]
    if (filters != null && filters!.isNotEmpty) {
      final filtersList = <Map<String, dynamic>>[];
      filters!.forEach((filterId, items) {
        if (items is List) {
          for (var item in items) {
            filtersList.add({
              'filterId': filterId,
              'item': item.toString(),
            });
          }
        }
      });
      if (filtersList.isNotEmpty) {
        params['filters'] = jsonEncode(filtersList);
        print('🔵 [CatalogApi] Filters formatted: $filtersList');
      }
    }
    
    return params;
  }
}

/// Репозиторий для работы с каталогом и поиском объявлений
class CatalogApiRepository {
  final Dio _dio;

  CatalogApiRepository(Dio dio) : _dio = dio;

  /// Получить объявления по параметрам (каталог/поиск)
  Future<ApiResult<Map<String, dynamic>>> getAds(CatalogSearchParams params) async {
    try {
      print('🔵 [CatalogApi] Getting ads with params: cat=${params.categoryId}, search=${params.search}, page=${params.page}');
      
      final queryParams = params.toQueryParams();
      queryParams['key'] = ApiConfig.apiKey;
      queryParams['route'] = 'catalog/getAds';
      
      // Используем POST но параметры в query string (так как PHP использует $_GET)
      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: queryParams,
      );

      final responseData = response.data is String
          ? jsonDecode(response.data)
          : response.data;

      print('🔵 [CatalogApi] Response: count=${responseData['count']}');

      if (responseData['data'] != null) {
        // Преобразуем localhost URL
        final ads = (responseData['data'] as List).map((ad) {
          if (ad['images'] != null && ad['images'] is List) {
            ad['images'] = (ad['images'] as List).map((url) {
              return ApiConfig.replaceMediaUrl(url as String);
            }).toList();
          }
          return ad;
        }).toList();

        print('✅ [CatalogApi] Loaded ${ads.length} ads');
        
        return ApiResult(
          success: true,
          data: {
            'data': ads,
            'count': responseData['count'],
            'pages': responseData['pages'],
            'map': responseData['map'],
          },
        );
      } else {
        print('🔴 [CatalogApi] No data in response');
        return ApiResult(success: true, data: {'data': [], 'count': '0', 'pages': 0});
      }
    } catch (e) {
      print('🔴 [CatalogApi] Exception: $e');
      return ApiResult(success: false, error: e.toString());
    }
  }

  /// Быстрый поиск (подсказки, теги, магазины)
  Future<ApiResult<Map<String, dynamic>>> quickSearch({
    required String query,
    int? cityId,
    int? regionId,
    int? countryId,
  }) async {
    try {
      print('🔵 [CatalogApi] Quick search: $query');
      
      // Используем POST но параметры в query string
      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'catalog/search',
          'query': query,
          if (cityId != null) 'city_id': cityId,
          if (regionId != null) 'region_id': regionId,
          if (countryId != null) 'country_id': countryId,
        },
      );

      final responseData = response.data is String
          ? jsonDecode(response.data)
          : response.data;

      print('🔵 [CatalogApi] Quick search response received');

      if (responseData['data'] != null) {
        final data = responseData['data'];
        
        // Преобразуем localhost URL в ads
        if (data['ads'] != null) {
          data['ads'] = (data['ads'] as List).map((ad) {
            if (ad['image'] != null) {
              ad['image'] = ApiConfig.replaceMediaUrl(ad['image'] as String);
            }
            return ad;
          }).toList();
        }
        
        print('✅ [CatalogApi] Quick search completed');
        return ApiResult(success: true, data: data);
      } else {
        return ApiResult(success: true, data: {});
      }
    } catch (e) {
      print('🔴 [CatalogApi] Exception: $e');
      return ApiResult(success: false, error: e.toString());
    }
  }
}

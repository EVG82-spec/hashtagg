import 'dart:convert';
import 'package:hashtagg/core/network/dio_client.dart';
import 'package:hashtagg/core/network/api_config.dart';

class GeoApiRepository {
  final _dio = DioClient.createDio();

  /// Поиск городов
  /// 
  /// Параметры:
  /// - [query]: Поисковый запрос (минимум 2 символа)
  /// - [onlyCity]: Искать только города (по умолчанию true)
  /// - [allCities]: Получить все города, а не только популярные (по умолчанию false)
  /// 
  /// Если query пустой и allCities=false, возвращает популярные города
  /// Если query пустой и allCities=true, возвращает все города
  /// 
  /// Возвращает:
  /// ```dart
  /// {
  ///   'status': true,
  ///   'data': [
  ///     {
  ///       'geo_name': 'Владивосток',
  ///       'city_name': 'Владивосток',
  ///       'region_name': 'Приморский край',
  ///       'country_name': 'Россия',
  ///       'city_id': 123,
  ///       'region_id': 45,
  ///       'country_id': 1,
  ///       'lat': 43.1332,
  ///       'lon': 131.9113,
  ///       'declination': 'Владивостоке'
  ///     }
  ///   ]
  /// }
  /// ```
  Future<Map<String, dynamic>> searchCities({
    String query = '',
    bool onlyCity = true,
    bool allCities = false,
  }) async {
    try {
      print('🔵 [GeoApi] Searching cities with query="$query", allCities=$allCities');
      
      final response = await _dio.get(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'geo/search',
          if (query.isNotEmpty) 'query': query,
          'only_city': onlyCity ? 1 : 0,
          'all_cities': allCities ? 1 : 0,
        },
      );
      
      final data = response.data is String 
          ? json.decode(response.data) 
          : response.data;
      
      final cities = data is List ? data : [];
      print('✅ [GeoApi] Found ${cities.length} cities');
      
      return {
        'status': true,
        'data': cities,
      };
    } catch (e) {
      print('🔴 [GeoApi] Exception: $e');
      return {
        'status': false,
        'error': e.toString(),
        'data': [],
      };
    }
  }

  /// Поиск адресов с координатами
  /// 
  /// Параметры:
  /// - [query]: Поисковый запрос адреса
  /// - [cityId]: ID города для уточнения поиска
  /// 
  /// Возвращает:
  /// ```dart
  /// {
  ///   'status': true,
  ///   'data': [
  ///     {
  ///       'address': 'ул. Ленина, 1',
  ///       'lat': '43.1332',
  ///       'lon': '131.9113'
  ///     }
  ///   ]
  /// }
  /// ```
  Future<Map<String, dynamic>> searchAddress({
    required String query,
    int? cityId,
  }) async {
    try {
      print('🔵 [GeoApi] Searching address: "$query"');
      
      final response = await _dio.get(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'map/searchAddress',
          'query': query,
          if (cityId != null) 'city_id': cityId,
        },
      );
      
      final data = response.data is String 
          ? json.decode(response.data) 
          : response.data;
      
      final addresses = data is List ? data : [];
      print('✅ [GeoApi] Found ${addresses.length} addresses');
      
      return {
        'status': true,
        'data': addresses,
      };
    } catch (e) {
      print('🔴 [GeoApi] Exception: $e');
      return {
        'status': false,
        'error': e.toString(),
        'data': [],
      };
    }
  }

    /// Обратное геокодирование: координаты → адрес
  Future<Map<String, dynamic>> reverseGeocode({
    required double lat,
    required double lon,
  }) async {
    try {
      print('🔵 [GeoApi] Reverse geocoding: $lat, $lon');
      final response = await _dio.get(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'geo/coordinatesDecodingAddress',
          'lat': lat,
          'lng': lon,
        },
      );
      final addressData = response.data is String
          ? json.decode(response.data)
          : response.data;
      final address = addressData['address'] as String?;
      return {
        'status': address != null,
        'address': address,
      };
    } catch (e) {
      print('🔴 [GeoApi] Exception: $e');
      return {
        'status': false,
        'error': e.toString(),
      };
    }
  }

  /// Получить город по координатам
  /// 
  /// Параметры:
  /// - [lat]: Широта
  /// - [lon]: Долгота
  /// 
  /// Возвращает:
  /// ```dart
  /// {
  ///   'status': true,
  ///   'data': {
  ///     'city_id': 123,
  ///     'city_name': 'Владивосток',
  ///     'lat': 43.1332,
  ///     'lon': 131.9113,
  ///     'declination': 'Владивостоке'
  ///   }
  /// }
  /// ```
  Future<Map<String, dynamic>> getCityByCoordinates({
    required double lat,
    required double lon,
  }) async {
    try {
      print('🔵 [GeoApi] Getting city by coordinates: $lat, $lon');
      
      // Сначала получаем адрес по координатам
      final addressResponse = await _dio.get(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'geo/coordinatesDecodingAddress',
          'lat': lat,
          'lng': lon,
        },
      );
      
      final addressData = addressResponse.data is String 
          ? json.decode(addressResponse.data) 
          : addressResponse.data;
      
      final address = addressData['address'] as String?;
      print('🔵 [GeoApi] Got address: $address');
      
      if (address == null || address.isEmpty) {
        return {
          'status': false,
          'error': 'Address not found',
          'data': null,
        };
      }
      
      // Извлекаем название города из адреса
      // Адрес может быть в формате: "улица, город" или "улица, городской округ Город"
      final addressParts = address.split(', ');
      String? cityName;
      
      // Ищем часть с названием города
      for (final part in addressParts.reversed) {
        // Убираем префиксы типа "городской округ", "город", "г."
        final cleaned = part
            .replaceAll(RegExp(r'^городской округ\s+', caseSensitive: false), '')
            .replaceAll(RegExp(r'^город\s+', caseSensitive: false), '')
            .replaceAll(RegExp(r'^г\.\s*', caseSensitive: false), '')
            .trim();
        
        if (cleaned.isNotEmpty && !cleaned.contains('улица') && !cleaned.contains('проспект')) {
          cityName = cleaned;
          break;
        }
      }
      
      if (cityName == null) {
        return {
          'status': false,
          'error': 'City name not found in address',
          'data': null,
        };
      }
      
      print('🔵 [GeoApi] Extracted city name: $cityName');
      
      // Ищем город в базе через поиск
      final searchResult = await searchCities(query: cityName, onlyCity: true);
      
      if (searchResult['status'] == true && searchResult['data'] != null) {
        final cities = searchResult['data'] as List;
        if (cities.isNotEmpty) {
          final city = cities.first;
          print('✅ [GeoApi] Found city: ${city['city_name']} (ID: ${city['city_id']})');
          
          return {
            'status': true,
            'data': {
              'city_id': city['city_id'],
              'city_name': city['city_name'],
              'region_name': city['region_name'],
              'country_name': city['country_name'],
              'lat': city['lat'],
              'lon': city['lon'],
              'declination': city['declination'],
            },
          };
        }
      }
      
      return {
        'status': false,
        'error': 'City not found in database',
        'data': null,
      };
    } catch (e) {
      print('🔴 [GeoApi] Exception: $e');
      return {
        'status': false,
        'error': e.toString(),
        'data': null,
      };
    }
  }

  /// Получить список регионов/краев
  /// 
  /// Возвращает:
  /// ```dart
  /// {
  ///   'status': true,
  ///   'data': [
  ///     {
  ///       'region_id': 1,
  ///       'region_name': 'Приморский край',
  ///       'country_id': 1,
  ///       'country_name': 'Россия'
  ///     }
  ///   ]
  /// }
  /// ```
  Future<Map<String, dynamic>> getRegions() async {
    try {
      print('🔵 [GeoApi] Getting regions list');
      
      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'geo/getRegions',
        },
      );
      
      final data = response.data is String 
          ? json.decode(response.data) 
          : response.data;
      
      if (data is Map && data['status'] == true) {
        final regions = data['data'] as List? ?? [];
        print('✅ [GeoApi] Found ${regions.length} regions');
        
        return {
          'status': true,
          'data': regions,
        };
      }
      
      return {
        'status': false,
        'error': 'Invalid response format',
        'data': [],
      };
    } catch (e) {
      print('🔴 [GeoApi] Exception: $e');
      return {
        'status': false,
        'error': e.toString(),
        'data': [],
      };
    }
  }

  /// Получить города по региону
  /// 
  /// Параметры:
  /// - [regionId]: ID региона (или "all" для всех городов)
  /// 
  /// Возвращает список городов в регионе
  Future<Map<String, dynamic>> getCitiesByRegion({
    required dynamic regionId,
  }) async {
    try {
      print('🔵 [GeoApi] Getting cities for region $regionId');
      
      // Если regionId == "all", возвращаем все города
      if (regionId == "all") {
        return searchCities(query: '', onlyCity: true, allCities: true);
      }
      
      final response = await _dio.get(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'geo/getCitiesByRegion',
          'region_id': regionId,
        },
      );
      
      final data = response.data is String 
          ? json.decode(response.data) 
          : response.data;
      
      if (data is Map && data['status'] == true) {
        final cities = data['data'] as List? ?? [];
        print('✅ [GeoApi] Found ${cities.length} cities in region');
        
        return {
          'status': true,
          'data': cities,
        };
      }
      
      return {
        'status': false,
        'error': 'Invalid response format',
        'data': [],
      };
    } catch (e) {
      print('🔴 [GeoApi] Exception: $e');
      return {
        'status': false,
        'error': e.toString(),
        'data': [],
      };
    }
  }
}

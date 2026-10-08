// G:\hashtagg_app\lib\core\network\map_api_repository.dart

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hashtagg/features/search/screens/search_filters_screen.dart';

// ─────────────────────────────────────────────────────────────────────
// МОДЕЛЬ ТОЧКИ
// ─────────────────────────────────────────────────────────────────────

/// Точка на карте (одно объявление)
class MapPoint {
  final int adId;
  final double latitude;
  final double longitude;

  const MapPoint({
    required this.adId,
    required this.latitude,
    required this.longitude,
  });

  factory MapPoint.fromFeature(Map<String, dynamic> feature) {
    final id = feature['id'];
    final geometry = feature['geometry'] as Map<String, dynamic>?;
    final coordinates = geometry?['coordinates'] as List?;

    final adId = id is int ? id : int.tryParse(id?.toString() ?? '0') ?? 0;

    double lat = 0.0;
    double lon = 0.0;

    if (coordinates != null && coordinates.length >= 2) {
      // Бекенд с map_vendor=yandex/google отдаёт [lat, lon]
      lat = _parseDouble(coordinates[0]);
      lon = _parseDouble(coordinates[1]);
    }

    return MapPoint(adId: adId, latitude: lat, longitude: lon);
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  @override
  String toString() => 'MapPoint(id: $adId, lat: $latitude, lon: $longitude)';
}

// ─────────────────────────────────────────────────────────────────────
// РЕЗУЛЬТАТ ЗАГРУЗКИ
// ─────────────────────────────────────────────────────────────────────

class MapPointsResult {
  final List<MapPoint> points;
  final int total;
  final int pages;
  final bool success;
  final String? error;

  const MapPointsResult({
    required this.points,
    required this.total,
    required this.pages,
    required this.success,
    this.error,
  });

  factory MapPointsResult.empty() =>
      const MapPointsResult(points: [], total: 0, pages: 0, success: true);

  factory MapPointsResult.error(String error) => MapPointsResult(
    points: const [],
    total: 0,
    pages: 0,
    success: false,
    error: error,
  );
}

// ─────────────────────────────────────────────────────────────────────
// РЕПОЗИТОРИЙ
// ─────────────────────────────────────────────────────────────────────

class MapApiRepository {
  final Dio _dio;

  MapApiRepository(this._dio);

  /// Загрузка точек (маркеров) объявлений по видимой области карты
  ///
  /// [coorTopLeft]     — верхний левый угол (lat)
  /// [coorTopRight]    — верхний правый угол (lon)
  /// [coorBottomLeft]  — нижний левый угол (lat)
  /// [coorBottomRight] — нижний правый угол (lon)
  /// [page]            — страница с 1 (на странице до 2000 записей)
  /// [filters]         — фильтры поиска
  Future<MapPointsResult> loadPoints({
    required double coorTopLeft,
    required double coorTopRight,
    required double coorBottomLeft,
    required double coorBottomRight,
    int page = 1,
    SearchFilters? filters,
  }) async {
    try {
      debugPrint('🗺️ [MapApi] loadPoints: page=$page');
      debugPrint(
        '🗺️ [MapApi] bounds: TL=($coorTopLeft, $coorTopRight) BR=($coorBottomLeft, $coorBottomRight)',
      );

      // Формируем тело запроса (application/x-www-form-urlencoded)
      final data = <String, dynamic>{
        'action': 'ads/load_points_map',
        'coorTopLeft': coorTopLeft.toString(),
        'coorTopRight': coorTopRight.toString(),
        'coorBottomLeft': coorBottomLeft.toString(),
        'coorBottomRight': coorBottomRight.toString(),
        'page': page.toString(),
      };

      if (filters != null) {
        _appendFilters(data, filters);
      }

      debugPrint('🗺️ [MapApi] data keys: ${data.keys.toList()}');

      final response = await _dio.post(
        '/systems/ajax/controller.php',
        data: data,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      debugPrint('🗺️ [MapApi] HTTP: ${response.statusCode}');
      debugPrint('🗺️ [MapApi] Body type: ${response.data.runtimeType}');

      if (response.statusCode != 200) {
        return MapPointsResult.error('HTTP ${response.statusCode}');
      }

      // Парсим JSON
      final Map<String, dynamic>? json;
      if (response.data is String) {
        try {
          final decoded = jsonDecode(response.data as String);
          json = decoded is Map<String, dynamic> ? decoded : null;
        } catch (e) {
          debugPrint('🔴 [MapApi] JSON parse error: $e');
          debugPrint(
            '🔴 [MapApi] Raw: ${(response.data as String).substring(0, 300)}',
          );
          return MapPointsResult.error('Invalid JSON');
        }
      } else if (response.data is Map) {
        json = Map<String, dynamic>.from(response.data as Map);
      } else {
        return MapPointsResult.error('Unexpected data type');
      }

      if (json == null) {
        return MapPointsResult.error('Empty response');
      }

      final features = json['features'] as List? ?? [];
      final total = _parseInt(json['total']);
      final pages = _parseInt(json['pages']);

      debugPrint(
        '🗺️ [MapApi] features=${features.length}, total=$total, pages=$pages',
      );

      final points = <MapPoint>[];
      for (final feature in features) {
        if (feature is Map<String, dynamic>) {
          final point = MapPoint.fromFeature(feature);
          if (point.latitude != 0 && point.longitude != 0) {
            points.add(point);
          }
        }
      }

      debugPrint('🗺️ [MapApi] parsed points=${points.length}');

      return MapPointsResult(
        points: points,
        total: total,
        pages: pages,
        success: true,
      );
    } on DioException catch (e) {
      debugPrint('🔴 [MapApi] DioException: ${e.message}');
      debugPrint('🔴 [MapApi] Response: ${e.response?.data}');
      return MapPointsResult.error(e.message ?? 'Network error');
    } catch (e, st) {
      debugPrint('🔴 [MapApi] Error: $e');
      debugPrint('🔴 [MapApi] Stack: $st');
      return MapPointsResult.error(e.toString());
    }
  }

  /// Загрузка всех страниц (осторожно — при большом total может быть долго)
  Future<MapPointsResult> loadAllPoints({
    required double coorTopLeft,
    required double coorTopRight,
    required double coorBottomLeft,
    required double coorBottomRight,
    SearchFilters? filters,
    int maxPages = 5,
  }) async {
    final allPoints = <MapPoint>[];
    int total = 0;
    int pages = 0;

    for (int page = 1; page <= maxPages; page++) {
      final result = await loadPoints(
        coorTopLeft: coorTopLeft,
        coorTopRight: coorTopRight,
        coorBottomLeft: coorBottomLeft,
        coorBottomRight: coorBottomRight,
        page: page,
        filters: filters,
      );

      if (!result.success) {
        if (allPoints.isEmpty) return result;
        break;
      }

      allPoints.addAll(result.points);
      total = result.total;
      pages = result.pages;

      if (page >= pages) break;
    }

    return MapPointsResult(
      points: allPoints,
      total: total,
      pages: pages,
      success: true,
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Вспомогательные методы
  // ─────────────────────────────────────────────────────────────────────

  /// Добавление фильтров в тело запроса
  ///
  /// Формат — как на сайте:
  ///   city_id, id_c, filter[price][from], filter[price][to],
  ///   filter[vip], filter[secure], filter[<custom>][0], ...
  void _appendFilters(Map<String, dynamic> data, SearchFilters filters) {
    // Город
    if (filters.cityId != null && filters.cityId! > 0) {
      data['city_id'] = filters.cityId.toString();
    }

    // Категория
    if (filters.categoryId != null && filters.categoryId! > 0) {
      data['id_c'] = filters.categoryId.toString();
    }

    // Цена
    if (filters.priceFrom != null && filters.priceFrom! > 0) {
      data['filter[price][from]'] = filters.priceFrom.toString();
    }
    if (filters.priceTo != null && filters.priceTo! > 0) {
      data['filter[price][to]'] = filters.priceTo.toString();
    }

    // Опции (галочки)
    final options = filters.options;
    if (options['vip'] == true) data['filter[vip]'] = '1';
    if (options['secure'] == true) data['filter[secure]'] = '1';
    if (options['online_view'] == true) data['filter[online_view]'] = '1';
    if (options['auction'] == true) data['filter[auction]'] = '1';
    if (options['booking'] == true) data['filter[booking]'] = '1';
    if (options['condition_status'] == true) {
      data['filter[condition_status]'] = '1';
    }

    // Произвольные фильтры категории
    // filters.filters = { "123": ["1", "2"], "456": ["3"] }
    // → filter[123][0]=1&filter[123][1]=2&filter[456][0]=3
    final customFilters = filters.filters;
    if (customFilters.isNotEmpty) {
      customFilters.forEach((key, values) {
        for (int i = 0; i < values.length; i++) {
          data['filter[$key][$i]'] = values[i];
        }
      });
    }
  }

  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      final match = RegExp(r'\d+').firstMatch(value);
      return match != null ? int.parse(match.group(0)!) : 0;
    }
    return 0;
  }
}

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:hashtagg/core/network/api_config.dart';

/// Модель категории для главного экрана
class HomeCategory {
  final int id;
  final String name;
  final String? image;
  final bool hasSubcategories;
  final String breadcrumb;

  HomeCategory({
    required this.id,
    required this.name,
    this.image,
    this.hasSubcategories = false,
    required this.breadcrumb,
  });

  factory HomeCategory.fromJson(Map<String, dynamic> json) {
    return HomeCategory(
      id: HomeApiRepository._parseIntFromJson(json['category_board_id']),
      name: (json['category_board_name'] as String?) ?? '',
      image: json['category_board_image'] as String?,
      hasSubcategories: json['subcategory'] as bool? ?? false,
      breadcrumb: (json['breadcrumb'] as String?) ?? '',
    );
  }
}

/// Модель объявления для ленты
class FeedAd {
  final int id;
  final String title;
  final String price;
  final List<String> images;
  final String text;
  final String cityName;
  final String? cityArea;
  final int countView;
  final String dateTimeAdd;
  final FeedUser user;
  final bool vip;
  final Map<String, MarkerInfo?> markers; // новое поле
  final double? latitude;
  final double? longitude;

  FeedAd({
    required this.id,
    required this.title,
    required this.price,
    required this.images,
    required this.text,
    required this.cityName,
    this.cityArea,
    required this.countView,
    this.dateTimeAdd = 'Дата не указана',
    required this.user,
    required this.markers,
    this.vip = false,
    this.latitude,
    this.longitude,
  });

  factory FeedAd.fromJson(Map<String, dynamic> json) {
    // Парсим images
    List<String> images = [];
    if (json['ads_images'] != null) {
      try {
        final imagesData = json['ads_images'];
        if (imagesData is String) {
          // Проверяем, не JSON ли это массив
          if (imagesData.startsWith('[') && imagesData.endsWith(']')) {
            final decoded = jsonDecode(imagesData);
            if (decoded is List) {
              images = decoded.map((e) => e.toString()).toList();
            }
          } else {
            images = [imagesData];
          }
        } else if (imagesData is List) {
          images = imagesData.map((e) => e.toString()).toList();
        }
      } catch (e) {
        print('⚠️ [FeedAd] Error parsing images: $e');
        images = [];
      }
    }

    // Применяем replaceMediaUrl только к именам файлов
    images = images.map((url) {
      if (url.startsWith('http://') || url.startsWith('https://')) {
        return url; // Уже полный URL
      }
      return ApiConfig.replaceMediaUrl(url);
    }).toList();

    // Форматируем цену
    String price = '';
    if (json['ads_price'] != null) {
      final rawPrice = json['ads_price'];
      if (rawPrice is int) {
        price = '${rawPrice.toString()} ₽';
      } else if (rawPrice is String) {
        price = rawPrice;
      } else if (rawPrice is Map && rawPrice['now'] != null) {
        price = rawPrice['now'].toString();
      }
    }

    // Получаем название города
    String cityName = json['city_name'] as String? ?? '';
    if (cityName.isEmpty && json['ads_city_id'] != null) {
      cityName = 'Город ${json['ads_city_id']}';
    }

    // Парсим пользователя
    FeedUser user = FeedUser(id: 0, name: '');
    if (json['ads_id_user'] != null) {
      final userId = json['ads_id_user'] is int
          ? json['ads_id_user']
          : int.tryParse(json['ads_id_user'].toString()) ?? 0;
      String userName = json['user_name'] as String? ?? '';
      if (userName.isEmpty && json['ads_id_user'] != null) {
        userName = 'Пользователь ${json['ads_id_user']}';
      }
      user = FeedUser(id: userId, name: userName);
    }

    return FeedAd(
      id: json['ads_id'] is int
          ? json['ads_id']
          : int.tryParse(json['ads_id'].toString()) ?? 0,
      title: json['ads_title'] as String? ?? '',
      price: price,
      images: images,
      text: json['ads_text'] as String? ?? '',
      cityName: cityName,
      cityArea: json['city_area'] as String?,
      countView: json['ads_count_display'] as int? ?? 0,
      dateTimeAdd: json['ads_datetime_add'] as String? ?? 'Дата не указана',
      user: user,
      markers: {},
      vip: json['ads_vip'] == 1 || json['ads_vip'] == true,
      latitude:
          json['ads_latitude'] != null &&
              json['ads_latitude'].toString().isNotEmpty
          ? double.tryParse(json['ads_latitude'].toString())
          : null,
      longitude:
          json['ads_longitude'] != null &&
              json['ads_longitude'].toString().isNotEmpty
          ? double.tryParse(json['ads_longitude'].toString())
          : null,
    );
  }

  static Map<String, MarkerInfo?> _parseMarkers(dynamic markersJson) {
    if (markersJson is! Map) return {};
    final map = <String, MarkerInfo?>{};
    markersJson.forEach((key, value) {
      if (value != null) {
        map[key.toString()] = MarkerInfo.fromJson(value);
      } else {
        map[key.toString()] = null;
      }
    });
    return map;
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed == 0 ? null : parsed;
    }
    return null;
  }
}

class MarkerInfo {
  final String name;
  final String iconUrl;

  MarkerInfo({required this.name, required this.iconUrl});

  factory MarkerInfo.fromJson(Map<String, dynamic> json) {
    return MarkerInfo(name: json['name'] ?? '', iconUrl: json['icon'] ?? '');
  }
}

/// Модель пользователя
class FeedUser {
  final int id;
  final String name;
  final String? avatar;
  final bool? isCompany;
  final String? companyName;

  FeedUser({
    required this.id,
    required this.name,
    this.avatar,
    this.isCompany,
    this.companyName,
  });

  factory FeedUser.fromJson(Map<String, dynamic> json) {
    return FeedUser(
      id: HomeApiRepository._parseIntFromJson(json['id']),
      name:
          (json['name'] as String?) ?? (json['display_name'] as String?) ?? '',
      avatar: json['avatar'] as String?,
      isCompany: json['isCompany'] as bool?,
      companyName: json['companyName'] as String?,
    );
  }
}

/// Модель элемента ленты
class FeedItem {
  final String action;
  final String title;
  final String date;
  final List<FeedAd>? ads;

  FeedItem({
    required this.action,
    required this.title,
    required this.date,
    this.ads,
  });

  factory FeedItem.fromJson(Map<String, dynamic> json) {
    return FeedItem(
      action: json['action'] as String,
      title: json['title'] as String,
      date: json['date'] as String,
      ads: json['ads'] != null
          ? List<FeedAd>.from(json['ads'].map((x) => FeedAd.fromJson(x)))
          : null,
    );
  }
}

/// Модель данных ленты объявлений (из ads/mobileGetAds)
class AdsFeedData {
  final List<FeedAd> ads;
  final String count;
  final int pages;
  final List<FeedAd>? advertisement;
  final bool hasNext;
  final int pageSize;

  AdsFeedData({
    required this.ads,
    required this.count,
    required this.pages,
    this.advertisement,
    required this.hasNext,
    required this.pageSize,
  });

  factory AdsFeedData.fromJson(Map<String, dynamic> json) {
    return AdsFeedData(
      ads: json['data'] != null
          ? List<FeedAd>.from(json['data'].map((x) => FeedAd.fromJson(x)))
          : [],
      count: (json['count'] as String?) ?? '0',
      pages: HomeApiRepository._parseIntFromJson(json['pages']),
      advertisement: json['advertisement'] != null
          ? List<FeedAd>.from(
              json['advertisement'].map((x) => FeedAd.fromJson(x)),
            )
          : null,
      hasNext: json['has_next'] == true || json['has_next'] == 1,
      pageSize: HomeApiRepository._parseIntFromJson(json['page_size'] ?? 8),
    );
  }
}

/// Репозиторий для работы с API главного экрана
class HomeApiRepository {
  final Dio _dio;

  HomeApiRepository(Dio dio) : _dio = dio;

  /// Получение категорий (из home/getData)
  Future<ApiResult<List<HomeCategory>>> getCategories() async {
    try {
      _log('📋 Получение категорий');

      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: {'key': ApiConfig.apiKey, 'route': 'home/getData'},
      );

      final responseData = response.data is String
          ? jsonDecode(response.data)
          : response.data;

      if (kDebugMode) {
        _log('📥 Ответ API: ${_prettyJson(responseData)}');
      }

      if (responseData['categories'] != null) {
        final categoriesJson = responseData['categories'] as List;
        final categories = categoriesJson
            .map((json) => HomeCategory.fromJson(json as Map<String, dynamic>))
            .toList();
        _log('✅ Категории получены: ${categories.length} шт.');
        return ApiResult.success(categories);
      } else {
        _log('❌ Ошибка: категории не получены');
        return ApiResult.failure('Категории не найдены');
      }
    } on DioException catch (e) {
      _log('❌ Dio ошибка: ${e.type} - ${e.message}');
      if (e.response != null) {
        _log('❌ Response status: ${e.response?.statusCode}');
        _log('❌ Response data: ${e.response?.data}');
      }
      final errorMessage = _handleDioError(e);
      _log('❌ Обработанная ошибка: $errorMessage');
      return ApiResult.failure(errorMessage);
    } catch (e) {
      _log('❌ Неожиданная ошибка: $e');
      return ApiResult.failure('Произошла непредвиденная ошибка: $e');
    }
  }

  /// Получение ленты объявлений (из ads/mobileGetAds)
  /// [category] - категория ленты: 'recommendations', 'fresh', 'companies'
  Future<ApiResult<AdsFeedData>> getAdsFeed({
    required String category,
    int page = 1,
    int pageSize = 8,
    int? cityId,
    int? regionId,
    int? countryId,
  }) async {
    try {
      _log('📰 Получение ленты: $category, страница: $page');

      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'ads/mobileGetAds',
          'page': page,
          'page_size': pageSize,
          'recommendations': category == 'recommendations' ? 'true' : 'false',
          'fresh': category == 'fresh' ? 'true' : 'false',
          'shop': category == 'companies' ? 1 : 0,
          if (cityId != null) 'city_id': cityId,
          if (regionId != null) 'region_id': regionId,
          if (countryId != null) 'country_id': countryId,
        },
      );

      final responseData = response.data is String
          ? jsonDecode(response.data)
          : response.data;

      if (kDebugMode) {
        _log('📥 Ответ API: ${_prettyJson(responseData)}');
      }

      if (responseData['data'] != null) {
        final feedData = AdsFeedData.fromJson(responseData);
        _log(
          '✅ Лента получена: ${feedData.ads.length} объявлений, hasNext: ${feedData.hasNext}',
        );
        return ApiResult.success(feedData);
      } else {
        _log('❌ Ошибка: лента не получена');
        return ApiResult.failure('Объявления не найдены');
      }
    } on DioException catch (e) {
      _log('❌ Dio ошибка: ${e.type} - ${e.message}');
      if (e.response != null) {
        _log('❌ Response status: ${e.response?.statusCode}');
        _log('❌ Response data: ${e.response?.data}');
      }
      final errorMessage = _handleDioError(e);
      _log('❌ Обработанная ошибка: $errorMessage');
      return ApiResult.failure(errorMessage);
    } catch (e) {
      _log('❌ Неожиданная ошибка: $e');
      return ApiResult.failure('Произошла непредвиденная ошибка: $e');
    }
  }

  String _handleDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return 'Превышено время подключения к серверу';
      case DioExceptionType.sendTimeout:
        return 'Превышено время отправки данных';
      case DioExceptionType.receiveTimeout:
        return 'Превышено время получения ответа';
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        switch (statusCode) {
          case 400:
            return 'Неверный запрос';
          case 401:
            return 'Неверные учетные данные';
          case 403:
            return 'Доступ запрещен';
          case 404:
            return 'Ресурс не найден';
          case 500:
            return 'Ошибка сервера';
          default:
            return 'Ошибка сети: код $statusCode';
        }
      case DioExceptionType.cancel:
        return 'Запрос отменен';
      case DioExceptionType.connectionError:
        return 'Ошибка подключения к серверу';
      case DioExceptionType.badCertificate:
        return 'Неверный сертификат';
      case DioExceptionType.unknown:
        return 'Неизвестная ошибка сети';
      case DioExceptionType.transformTimeout:
        return 'Превышено время ожидания преобразования';
      default:
        return 'Неизвестная ошибка сети';
    }
  }

  void _log(String message) {
    // if (kDebugMode) {
    //   debugPrint('[HomeApi] $message');
    // }
  }

  String _prettyJson(dynamic json) {
    try {
      return json.toString();
    } catch (e) {
      return json.toString();
    }
  }

  /// Безопасная конвертация значения в int (может быть int или String)
  static int _parseIntFromJson(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) {
      try {
        return int.parse(value);
      } catch (e) {
        return 0;
      }
    }
    return 0;
  }

  /// Получение информационных баннеров (магазин, турбо, безопасность)
  Future<List<Map<String, dynamic>>> getInfoBanners() async {
    try {
      _log('🔵 Getting info banners');

      final response = await _dio.get(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'home/getPromoBanners',
        },
      );

      _log('📥 Info banners response: ${_prettyJson(response.data)}');

      if (response.statusCode == 200) {
        final data = response.data is String
            ? json.decode(response.data)
            : response.data;

        if (data['status'] == true && data['data'] != null) {
          final banners = (data['data'] as List)
              .map((item) => Map<String, dynamic>.from(item))
              .toList();

          _log('✅ Loaded ${banners.length} info banners');
          return banners;
        }
      }

      _log('⚠️ No info banners found');
      return [];
    } catch (e) {
      _log('🔴 Error getting info banners: $e');
      return [];
    }
  }
}

/// Результат вызова API (дублируется из auth_api_repository)
class ApiResult<T> {
  final bool success;
  final T? data;
  final String? error;

  ApiResult.success(this.data) : success = true, error = null;

  ApiResult.failure(this.error) : success = false, data = null;
}

import 'package:dio/dio.dart';
import 'dart:convert';
import 'package:hashtagg/core/network/api_config.dart';
import 'package:hashtagg/shared/domain/entities/listing.dart';

/// API Result wrapper
class ApiResult<T> {
  final bool success;
  final T? data;
  final String? error;

  ApiResult({required this.success, this.data, this.error});
}

/// Репозиторий для работы с API объявлений
class ListingApiRepository {
  final Dio _dio;

  ListingApiRepository(Dio dio) : _dio = dio;

  /// Получение деталей объявления по ID
  Future<ApiResult<Listing>> getListingById(String itemId, {String? token, int? userId}) async {
    try {
      final queryParams = {
        'key': ApiConfig.apiKey,
        'route': 'card_ad/getCard',
        'action': 'card_ad/getCard',  // пробуем action
        'id': itemId,
        'ip': 'mobile_app', // Передаём идентификатор мобильного приложения
      };
      
      // Добавляем токен и ID пользователя если доступны
      if (token != null) {
        queryParams['token'] = token;
      }
      if (userId != null) {
        queryParams['id_user'] = userId.toString();
      }
      
      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: queryParams,
      );

      final responseData = response.data is String
          ? jsonDecode(response.data)
          : response.data;

      // card_ad/getCard возвращает данные прямо в корне ответа, без обёртки
      // Если пришло ads_id, значит успешный ответ
      if (responseData['ads_id'] != null) {
        final listing = _parseListing(responseData);
        return ApiResult(success: true, data: listing);
      } else if (responseData['status'] == true || responseData['success'] == true) {
        final listing = _parseListing(responseData['data'] ?? responseData);
        return ApiResult(success: true, data: listing);
      } else {
        return ApiResult(
          success: false,
          error: responseData['message'] ?? 'Unknown error',
        );
      }
    } catch (e) {
      return ApiResult(success: false, error: e.toString());
    }
  }

  /// Парсинг объявления из JSON (card_ad/getCard эндпоинт)
  Listing _parseListing(Map<String, dynamic> json) {
    print('🔵 [ListingApi] Parsing listing, available keys: ${json.keys.toList()}');
    
    final id = _parseInt(json['ads_id']);
    final title = json['ads_title'] ?? '';
    
    // Парсим breadcrumbs
    List<BreadcrumbItem>? breadcrumbs;
    if (json['breadcrumbs'] != null && json['breadcrumbs'] is List) {
      breadcrumbs = (json['breadcrumbs'] as List)
          .map((item) => BreadcrumbItem.fromJson(item))
          .toList();
    }
    
    final description = json['ads_text'] ?? '';
    
    // Парсим цену - она приходит как {нов: "...", олд: "..."}
    final price = _extractPriceFromObject(json['ads_price']);
    
    final location = json['city_name'] ?? '';
    final cityAlias = json['city_alias'] ?? json['ads_city_alias'] ?? '';
    final listingAlias = json['ads_alias'] ?? '';
    final link = json['link'] ?? '';
    
    print('🔵 [ListingApi] city_alias: "$cityAlias"');
    print('🔵 [ListingApi] ads_alias: "$listingAlias"');
    print('🔵 [ListingApi] link: "$link"');
    
    final views = _parseInt(json['count_view'] ?? 0);
    final status = _parseStatus(json['ads_status']);
    
    final userId = json['user'] != null && json['user'] is Map 
        ? _parseInt(json['user']['clients_id'] ?? json['user']['id'] ?? 0)
        : _parseInt(json['ads_id_user'] ?? 0);
    
    final publishedAt = json['ads_datetime_add'] ?? '';
    
    // Парсим изображения
    final List<String>? images = json['ads_images'] != null
        ? List<String>.from(json['ads_images'].map((x) {
            final url = x.toString();
            // Заменяем localhost на настроенный mediaUrl
            return ApiConfig.replaceMediaUrl(url);
          }))
        : null;
    
    // Парсим данные пользователя
    String? userName;
    String? userAvatar;
    double? userRating;
    String? userPhone;
    if (json['user'] != null && json['user'] is Map) {
      userName = json['user']['display_name'] ?? json['user']['name'] ?? '';
      userAvatar = json['user']['avatar'];
      userRating = _parseDouble(json['user']['rating']);
      userPhone = json['user']['phone'];
    }

    return Listing(
      id: id,
      title: title,
      breadcrumbs: breadcrumbs,
      description: description,
      price: price,
      location: location,
      cityAlias: cityAlias,
      listingAlias: listingAlias,
      link: link,
      views: views,
      status: status,
      userId: userId,
      publishedAt: publishedAt,
      images: images,
      userName: userName,
      userAvatar: userAvatar,
      userRating: userRating,
      userPhone: userPhone,
    );
  }

  /// Парсинг статуса ads_status (1=active, 2=completed, 3=archived, 7=moderation)
  ListingStatus _parseStatus(dynamic adsStatus) {
    final statusCode = _parseInt(adsStatus);
    switch (statusCode) {
      case 2:
        return ListingStatus.completed;
      case 3:
        return ListingStatus.archived;
      case 7:
        return ListingStatus.moderation;
      case 1:
      default:
        return ListingStatus.active;
    }
  }

  /// Экстрактион цены из объекта {now: "...", old: "..."}
  int _extractPriceFromObject(dynamic priceObj) {
    if (priceObj is Map) {
      final nowPrice = priceObj['now']?.toString() ?? '0';
      return _parseInt(nowPrice.replaceAll(RegExp(r'[^0-9]'), ''));
    }
    if (priceObj is String) {
      return _parseInt(priceObj.replaceAll(RegExp(r'[^0-9]'), ''));
    }
    return 0;
  }

  /// Безопасный парсинг int
  int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  /// Безопасный парсинг double
  double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  /// Пожаловаться на объявление
  Future<ApiResult<String>> reportListing({
    required int userId,
    required String token,
    required int listingId,
    required String text,
  }) async {
    try {
      print('🔵 [ListingApi] Reporting listing: $listingId');
      
      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'card_ad/addComplain',
        },
        data: {
          'id_user_from': userId,
          'token': token,
          'id_ad': listingId,
          'text': text,
        },
      );

      final responseData = response.data is String
          ? jsonDecode(response.data)
          : response.data;

      if (responseData['status'] == true) {
        final answer = responseData['answer']?.toString() ?? 'Жалоба отправлена';
        print('✅ [ListingApi] Listing reported: $answer');
        return ApiResult(success: true, data: answer);
      } else {
        final error = responseData['answer']?.toString() ?? 'Failed to report listing';
        return ApiResult(success: false, error: error);
      }
    } catch (e) {
      print('🔴 [ListingApi] Exception: $e');
      return ApiResult(success: false, error: e.toString());
    }
  }

  /// Получение похожих объявлений
  Future<ApiResult<List<Listing>>> getSimilarAds({
    required int listingId,
  }) async {
    try {
      print('🔵 [ListingApi] Getting similar ads for: $listingId');
      
      final response = await _dio.get(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'card_ad/getSimilarAds',
          'id': listingId,
        },
      );

      final responseData = response.data is String
          ? jsonDecode(response.data)
          : response.data;

      if (responseData['data'] != null) {
        final List<dynamic> adsData = responseData['data'];
        final List<Listing> listings = adsData.map((ad) => _parseSimilarAd(ad)).toList();
        
        print('✅ [ListingApi] Loaded ${listings.length} similar ads');
        return ApiResult(success: true, data: listings);
      } else {
        return ApiResult(success: true, data: []);
      }
    } catch (e) {
      print('🔴 [ListingApi] Exception: $e');
      return ApiResult(success: false, error: e.toString());
    }
  }

  /// Парсинг похожего объявления (упрощенная структура)
  Listing _parseSimilarAd(Map<String, dynamic> json) {
    final id = _parseInt(json['id'] ?? json['ads_id']);
    final title = json['title'] ?? json['ads_title'] ?? '';
    final price = _extractPriceFromObject(json['price'] ?? json['ads_price']);
    final location = json['city_name'] ?? '';
    final views = _parseInt(json['count_view']);
    final publishedAt = json['ads_datetime_add'] as String?;
    
    // Парсим изображения из ads_images и заменяем localhost на mediaUrl
    List<String>? images;
    if (json['ads_images'] != null) {
      images = List<String>.from(json['ads_images'].map((x) {
        final url = x.toString();
        // Заменяем localhost на настроенный mediaUrl
        return ApiConfig.replaceMediaUrl(url);
      }));
    } else if (json['images'] != null) {
      images = List<String>.from(json['images'].map((x) {
        final url = x.toString();
        return ApiConfig.replaceMediaUrl(url);
      }));
    }

    return Listing(
      id: id,
      title: title,
      price: price,
      location: location,
      views: views,
      publishedAt: publishedAt,
      images: images,
      status: ListingStatus.active,
    );
  }

  /// Изменение статуса объявления
  Future<ApiResult<bool>> changeAdStatus({
    required int userId,
    required String token,
    required int adId,
    required int status, // 1=active, 5=sold, 8=delete, 3=archive
  }) async {
    try {
      print('🔵 [ListingApi] Changing ad status: $adId to $status');
      
      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'card_ad/changeStatus',
        },
        data: {
          'id_user': userId,
          'token': token,
          'id_ad': adId,
          'status': status,
        },
      );

      final responseData = response.data is String
          ? jsonDecode(response.data)
          : response.data;

      if (responseData['status'] == true) {
        print('✅ [ListingApi] Ad status changed successfully');
        return ApiResult(success: true, data: true);
      } else {
        return ApiResult(success: false, error: 'Failed to change status');
      }
    } catch (e) {
      print('🔴 [ListingApi] Exception: $e');
      return ApiResult(success: false, error: e.toString());
    }
  }
}

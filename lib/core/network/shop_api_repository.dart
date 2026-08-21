// lib/core/network/shop_api_repository.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:io';
import 'package:hashtagg/core/network/api_config.dart';
import 'package:hashtagg/core/network/catalog_api_repository.dart' as catalog;
import 'package:hashtagg/core/network/home_api_repository.dart';
import 'package:hashtagg/features/shop/models/shop.dart';

class ShopApiRepository {
  final Dio _dio;

  ShopApiRepository(this._dio);

  /// Получение списка всех магазинов через JSON API
  Future<List<Shop>> getShops() async {
    print('📥 [ShopApi] Loading shops...');
    try {
      final response = await _dio.post(
        '/systems/ajax/controller.php',
        data: {'key': ApiConfig.apiKey, 'action': 'shop/getShopsJson'},
      );

      final data = response.data is Map
          ? response.data as Map<String, dynamic>
          : _parseResponse(response.data);

      if (data['status'] != true || data['data'] == null) {
        print('⚠️ [ShopApi] No shops found');
        return [];
      }

      final List<dynamic> items = data['data'] is List ? data['data'] : [];
      print('📦 [ShopApi] Got ${items.length} shops from API');

      if (items.isNotEmpty) {
        final first = items.first;
        print('🔍 [ShopApi] First shop raw data:');
        print('   Keys: ${first.keys.join(', ')}');
        print('   ID: ${first['clients_shops_id']}');
        print('   Title: ${first['clients_shops_title']}');
        print('   Logo: ${first['clients_shops_logo']}');
        print('   Has sliders: ${first.containsKey('sliders')}');
        print('   Has pages: ${first.containsKey('pages')}');
        print('   Has links: ${first.containsKey('link_1_link')}');
      }

      final shops = items.map((json) => Shop.fromJson(json)).toList();
      print('✅ [ShopApi] Loaded ${shops.length} shops');
      return shops;
    } catch (e) {
      print('❌ [ShopApi] Error: $e');
      return [];
    }
  }

  /// Получение данных магазина для редактирования
  Future<Map<String, dynamic>> getShopData({
    required int userId,
    required String token,
    required int shopId,
  }) async {
    print('🔵🔵🔵 [ShopApi] getShopData() START');
    print('   userId: $userId');
    print('   shopId: $shopId');
    print('   shopId type: ${shopId.runtimeType}');
    try {
      _log('📋 Getting shop data for editing');

      final response = await _dio.get(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'profile/shop/getData',
          'id_user': userId,
          'token': token,
          'id': shopId,
        },
      );

      final responseData = _parseResponse(response.data);
      _log('✅ Shop data loaded');

      return responseData;
    } catch (e) {
      _log('❌ Error getting shop data: $e');
      rethrow;
    }
  }

  /// Создание магазина
  Future<Map<String, dynamic>> createShop({
    required int userId,
    required String token,
  }) async {
    try {
      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: {'key': ApiConfig.apiKey, 'route': 'profile/shop/add'},
        data: {'id_user': userId, 'token': token},
      );
      return _parseResponse(response.data);
    } catch (e) {
      print('❌ [ShopApi] Error creating shop: $e');
      rethrow;
    }
  }

  /// Редактирование магазина
  Future<Map<String, dynamic>> updateShop({
    required int userId,
    required String token,
    required int shopId,
    required String title,
    String? description,
    int? themeCategoryId,
    String? shopIdHash,
    List<Map<String, String>>? sliders,
    List<Map<String, String>>? logo,
    List<ShopLink>? links,
    int? status, // 👈 ДОБАВИТЬ НОВЫЙ ПАРАМЕТР
  }) async {
    print('📤 [ShopApi] updateShop called');
    print('   shopId: $shopId');
    print('   title: $title');
    print('   description: $description');
    try {
      _log('✏️ Updating shop');

      final formData = FormData.fromMap({
        'id_user': userId,
        'token': token,
        'id': shopId,
        'title': title, // 👈 ИСПРАВЛЕНО: было 'shop_title', стало 'title'
        'text':
            description ?? '', // 👈 ИСПРАВЛЕНО: было 'shop_desc', стало 'text'
        'shop_theme_category': themeCategoryId ?? 0,
        'shop_id': shopIdHash ?? '',
        if (status != null) 'status': status,
      });

      if (sliders != null) {
        formData.fields.add(MapEntry('slider', jsonEncode(sliders)));
      }

      if (logo != null) {
        formData.fields.add(MapEntry('logo', jsonEncode(logo)));
      }

      if (links != null) {
        print('📤 [ShopApi] Processing ${links.length} links:');
        for (int i = 0; i < links.length && i < 3; i++) {
          final link = links[i];
          print('   link_${i + 1}_text: ${link.text}');
          print('   link_${i + 1}_link: ${link.link}');
          formData.fields.add(MapEntry('link_${i + 1}_text', link.text ?? ''));
          formData.fields.add(MapEntry('link_${i + 1}_link', link.link ?? ''));

          if (link.image != null && link.image!.isNotEmpty) {
            if (link.image!.startsWith('http')) {
              final fileName = link.image!.split('/').last;
              formData.fields.add(MapEntry('link_${i + 1}_image', fileName));
            } else {
              formData.fields.add(MapEntry('link_${i + 1}_image', link.image!));
            }
          }
        }
      }

      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'profile/shop/edit',
        },
        data: formData,
      );

      // ✅ ПРИНТ ВСЕХ ПОЛЕЙ ПЕРЕД ОТПРАВКОЙ
      print('📤 [ShopApi] Final formData fields:');
      for (var field in formData.fields) {
        print('   ${field.key}: ${field.value}');
      }

      final responseData = _parseResponse(response.data);
      _log('✅ Shop updated');

      return responseData;
    } catch (e) {
      _log('❌ Error updating shop: $e');
      rethrow;
    }
  }

  /// Универсальный метод (оставляем для личного кабинета)
  Future<Shop> getShop({
    required String shopId,
    int? userId,
    String? token,
  }) async {
    try {
      _log('🏪 Getting shop info (with auth)');

      final queryParams = {
        'key': ApiConfig.apiKey,
        'route': 'shops/getShop',
        'id': shopId,
      };

      if (userId != null) queryParams['id_user'] = userId.toString();
      if (token != null) queryParams['token'] = token;

      final response = await _dio.get(
        '/systems/api/controller.php',
        queryParameters: queryParams,
      );

      final responseData = _parseResponse(response.data);

      if (responseData['data'] == null) {
        throw Exception('Shop not found');
      }

      return Shop.fromJson(responseData['data']);
    } catch (e) {
      _log('❌ Error getting shop: $e');
      rethrow;
    }
  }

  /// Получение товаров магазина
  Future<List<FeedAd>> getShopAds({
    required String shopId,
    int? categoryId, // 👈 ДОБАВЛЯЕМ
  }) async {
    try {
      print('📦 [ShopApi] Loading ads for shop: $shopId');

      final response = await _dio.post(
        '/api/shop/getShopAdsJson',
        data: {
          'shop_id': shopId,
          if (categoryId != null) 'category_id': categoryId, // 👈 ФИЛЬТР
        },
      );

      print('📦 [ShopApi] Response status: ${response.statusCode}');
      print('📦 [ShopApi] Response data: ${response.data}');

      final data = response.data is Map
          ? response.data as Map<String, dynamic>
          : _parseResponse(response.data);

      if (data['status'] != true || data['data'] == null) {
        print('⚠️ [ShopApi] No ads found for shop: $shopId');
        return [];
      }

      final List<dynamic> items = data['data'] as List<dynamic>;
      print('📦 [ShopApi] Found ${items.length} items to parse');

      // ============================================================
      // ОБРАБОТКА ИЗОБРАЖЕНИЙ - ИСПОЛЬЗУЕМ jpg (он точно есть)
      // ============================================================
      final processedItems = items.map((item) {
        final ad = item as Map<String, dynamic>;

        if (ad['ads_images'] != null) {
          try {
            dynamic imagesData = ad['ads_images'];
            List<String> imageUrls = [];

            print(
              '🖼️ [ShopApi] Raw images data: $imagesData (type: ${imagesData.runtimeType})',
            );

            // Функция для формирования URL - сразу jpg
            String buildImageUrl(String fileName) {
              final nameWithoutExt = fileName.split('.').first;
              return 'https://hashtagg.ru/public/media/images_boards/big/$nameWithoutExt.jpg';
            }

            if (imagesData is String) {
              if (imagesData.startsWith('[') && imagesData.endsWith(']')) {
                final parsed = jsonDecode(imagesData);
                if (parsed is List) {
                  imageUrls = parsed.map((fileName) {
                    return buildImageUrl(fileName.toString());
                  }).toList();
                }
              } else {
                imageUrls = [buildImageUrl(imagesData)];
              }
            } else if (imagesData is List) {
              imageUrls = imagesData.map((fileName) {
                return buildImageUrl(fileName.toString());
              }).toList();
            }

            if (imageUrls.isNotEmpty) {
              ad['ads_images'] = imageUrls;
              print('✅ [ShopApi] Fixed images: $imageUrls');
            }
          } catch (e) {
            print('⚠️ [ShopApi] Error fixing images: $e');
          }
        }
        return ad;
      }).toList();

      final ads = processedItems
          .map((json) {
            try {
              final ad = FeedAd.fromJson(json as Map<String, dynamic>);
              print(
                '✅ [ShopApi] Parsed ad: ${ad.id} - ${ad.title}, images: ${ad.images}',
              );
              return ad;
            } catch (e) {
              print('❌ [ShopApi] Error parsing ad: $e');
              print('❌ [ShopApi] Ad data: $json');
              return null;
            }
          })
          .where((ad) => ad != null)
          .cast<FeedAd>()
          .toList();

      print('✅ [ShopApi] Loaded ${ads.length} ads for shop: $shopId');
      return ads;
    } catch (e) {
      print('❌ [ShopApi] Error loading shop ads: $e');
      return [];
    }
  }

  /// Добавление страницы магазина
  Future<Map<String, dynamic>> addShopPage({
    required int userId,
    required String token,
    required int shopId,
    required String name,
    required String text,
    required String alias,
  }) async {
    try {
      _log('📄 Adding shop page');

      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'profile/shop/addPage',
        },
        data: {
          'id_user': userId,
          'token': token,
          'id_shop': shopId,
          'name': name,
          'text': text,
          'alias': alias,
        },
      );

      final responseData = _parseResponse(response.data);
      _log('✅ Shop page added');

      return responseData;
    } catch (e) {
      _log('❌ Error adding shop page: $e');
      rethrow;
    }
  }

  /// Редактирование страницы магазина
  Future<Map<String, dynamic>> updateShopPage({
    required int userId,
    required String token,
    required int pageId,
    required String name,
    required String text,
    required String alias,
  }) async {
    try {
      _log('✏️ Updating shop page');

      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'profile/shop/editPage',
        },
        data: {
          'id_user': userId,
          'token': token,
          'id': pageId,
          'name': name,
          'text': text,
          'alias': alias,
        },
      );

      final responseData = _parseResponse(response.data);
      _log('✅ Shop page updated');

      return responseData;
    } catch (e) {
      _log('❌ Error updating shop page: $e');
      rethrow;
    }
  }

  /// Удаление магазина
  Future<Map<String, dynamic>> deleteShop({
    required int userId,
    required String token,
    required int shopId,
  }) async {
    try {
      print('🗑️ [ShopApi] Deleting shop: $shopId');

      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'profile/shop/delete',
        },
        data: {'id_user': userId, 'token': token, 'id': shopId},
      );

      final responseData = _parseResponse(response.data);
      print('📦 [ShopApi] Delete shop response: $responseData');
      return responseData;
    } catch (e) {
      print('❌ [ShopApi] Error deleting shop: $e');
      rethrow;
    }
  }

  /// Удаление страницы магазина
  Future<Map<String, dynamic>> deleteShopPage({
    required int userId,
    required String token,
    required int pageId,
  }) async {
    try {
      _log('🗑️ Deleting shop page');

      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'profile/shop/deletePage',
        },
        data: {'id_user': userId, 'token': token, 'id': pageId},
      );

      final responseData = _parseResponse(response.data);
      _log('✅ Shop page deleted');

      return responseData;
    } catch (e) {
      _log('❌ Error deleting shop page: $e');
      rethrow;
    }
  }

  /// Загрузка изображения во временную папку
  Future<Map<String, dynamic>> uploadTempImage({
    required String filePath,
    required int userId,
    required String token,
    String action = 'shopSlider', // shopSlider или shopAvatar
  }) async {
    try {
      print('📤 [ShopApi] Uploading temp image with action: $action');
      print('   userId: $userId');
      print('   filePath: $filePath');

      final file = File(filePath);
      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: {'key': ApiConfig.apiKey, 'route': 'assets/save'},
        data: {
          'id_user': userId,
          'token': token,
          'type': 'image',
          'action': action,
          'assets': base64Image,
        },
      );

      final responseData = _parseResponse(response.data);
      print('📦 [ShopApi] uploadTempImage response: $responseData');

      if (responseData['data'] == null) {
        throw Exception('Failed to upload image');
      }

      print('✅ [ShopApi] Image uploaded: ${responseData['data']['name']}');
      return responseData['data'];
    } catch (e) {
      print('❌ [ShopApi] Error uploading temp image: $e');
      rethrow;
    }
  }

  /// Загрузка изображения во временную папку
  Future<Map<String, dynamic>> uploadShopImage({
    required String filePath,
    required int userId,
    required String token,
    required String shopHash,
    required String type,
  }) async {
    try {
      print('📤📤📤 [ShopApi] uploadShopImage START');
      print('   userId: $userId');
      print('   shopHash: $shopHash');
      print('   type: $type');
      print('   filePath: $filePath');

      final file = File(filePath);
      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);

      final fileName = type == 'banner' ? 'banner.jpg' : 'avatar.jpg';
      final savePath = '/media/users/$userId/shop/$shopHash/$fileName';

      print('   savePath: $savePath');

      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: {'key': ApiConfig.apiKey, 'route': 'assets/save'},
        data: {
          'id_user': userId,
          'token': token,
          'type': 'image',
          'action': type == 'banner' ? 'shopSlider' : 'shopAvatar',
          'assets': base64Image,
          'path': savePath,
        },
      );

      print('📡 [ShopApi] Response status: ${response.statusCode}');
      print('📡 [ShopApi] Response data: ${response.data}');

      final responseData = _parseResponse(response.data);
      print('📦 [ShopApi] uploadShopImage response: $responseData');

      if (responseData['data'] == null) {
        print('❌ [ShopApi] No data in response');
        throw Exception('Failed to upload image');
      }

      print('✅ [ShopApi] uploadShopImage SUCCESS');
      return {
        'status': true,
        'name': fileName,
        'path': savePath,
        'data': responseData['data'],
      };
    } catch (e) {
      print('❌❌❌ [ShopApi] uploadShopImage ERROR: $e');
      rethrow;
    }
  }

  /// Получение магазина для публичного просмотра
  Future<Shop> getPublicShop({required String shopId}) async {
    try {
      final response = await _dio.get(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'shops/getShop',
          'id': shopId,
        },
      );

      final data = _parseResponse(response.data);

      print('📦 [ShopApi] Raw response: ${response.data}');
      print('📦 [ShopApi] Parsed data: $data');
      print('📦 [ShopApi] Data["data"]: ${data['data']}');

      if (data['data'] == null) {
        throw Exception('Shop not found');
      }

      return Shop.fromJson(data['data']);
    } catch (e) {
      print('❌ [ShopApi] Error parsing shop: $e');
      rethrow;
    }
  }

  Map<String, dynamic> _parseResponse(dynamic data) {
    if (data is String) {
      return jsonDecode(data);
    }
    return data as Map<String, dynamic>;
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[ShopApi] $message');
    }
  }

  /// Получение категорий магазина
  Future<List<ShopCategory>> getShopCategories({required int shopId}) async {
    try {
      print('📂 [ShopApi] Loading ALL categories');

      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'catalog/getAllCategories',
        },
      );

      final data = _parseResponse(response.data);
      print('📦 [ShopApi] Parsed data: $data');

      // ✅ БЕРЕМ ДАННЫЕ ИЗ parent["0"] (корневые категории)
      if (data['data'] != null && data['data']['parent'] != null) {
        final parentData = data['data']['parent'];
        final List<dynamic> rootCategories = parentData['0'] ?? [];

        print('📦 [ShopApi] Root categories count: ${rootCategories.length}');

        return rootCategories
            .map((json) => ShopCategory.fromJson(json))
            .toList();
      }
      return [];
    } catch (e) {
      print('❌ [ShopApi] Error loading categories: $e');
      return [];
    }
  }

  /// Быстрый поиск по магазину (умный поиск)
  Future<catalog.ApiResult<Map<String, dynamic>>> quickSearchShop({
    required int shopId,
    required String query,
  }) async {
    try {
      print('🔵 [ShopApi] Quick search in shop: $shopId, query: $query');

      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'catalog/searchAdsShop',
          'shop_id': shopId, // 👈 ПЕРЕНОСИМ В QUERY PARAMETERS!
          'query': query, // 👈 ПЕРЕНОСИМ В QUERY PARAMETERS!
        },
        data: {'shop_id': shopId, 'query': query},
      );

      final data = _parseResponse(response.data);
      print('📦 [ShopApi] Quick search response: $data');

      if (data['data'] != null) {
        return catalog.ApiResult(
          success: true,
          data: data['data'] as Map<String, dynamic>,
        );
      }
      return catalog.ApiResult(success: true, data: {});
    } catch (e) {
      print('❌ [ShopApi] Quick search error: $e');
      return catalog.ApiResult(success: false, error: e.toString());
    }
  }
}

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:io';
import 'package:hashtagg/core/network/api_config.dart';
import 'package:hashtagg/features/shop/models/shop.dart';

class ShopApiRepository {
  final Dio _dio;

  ShopApiRepository(this._dio);

  /// Получение данных магазина для редактирования
  Future<Map<String, dynamic>> getShopData({
    required int userId,
    required String token,
    required int shopId,
  }) async {
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
      _log('🏪 Creating shop');

      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'profile/shop/add',
        },
        data: {
          'id_user': userId,
          'token': token,
        },
      );

      final responseData = _parseResponse(response.data);
      _log('✅ Shop created: ${responseData['id']}');

      return responseData;
    } catch (e) {
      _log('❌ Error creating shop: $e');
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
  }) async {
    try {
      _log('✏️ Updating shop');

      final formData = FormData.fromMap({
        'id_user': userId,
        'token': token,
        'id': shopId,
        'shop_title': title,
        'shop_desc': description ?? '',
        'shop_theme_category': themeCategoryId ?? 0,
        'shop_id': shopIdHash ?? '',
      });

      if (sliders != null) {
        formData.fields.add(MapEntry('slider', jsonEncode(sliders)));
      }

      if (logo != null) {
        formData.fields.add(MapEntry('logo', jsonEncode(logo)));
      }

      // Добавляем ссылки (до 3 штук)
      if (links != null) {
        for (int i = 0; i < links.length && i < 3; i++) {
          final link = links[i];
          formData.fields.add(MapEntry('link_${i + 1}_text', link.text ?? ''));
          formData.fields.add(MapEntry('link_${i + 1}_link', link.link ?? ''));
          
          // Отправляем имя файла изображения (если есть)
          if (link.image != null && link.image!.isNotEmpty) {
            // Если это URL (начинается с http), извлекаем имя файла
            if (link.image!.startsWith('http')) {
              final fileName = link.image!.split('/').last;
              formData.fields.add(MapEntry('link_${i + 1}_image', fileName));
            } else {
              // Если это уже имя файла
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

      final responseData = _parseResponse(response.data);
      _log('✅ Shop updated');

      return responseData;
    } catch (e) {
      _log('❌ Error updating shop: $e');
      rethrow;
    }
  }

  /// Получение публичной информации о магазине
  Future<Shop> getShop({
    required String shopId,
    int? userId,
    String? token,
  }) async {
    try {
      _log('🏪 Getting shop info');

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

      final shop = Shop.fromJson(responseData['data']);
      _log('✅ Shop loaded: ${shop.title}');

      return shop;
    } catch (e) {
      _log('❌ Error getting shop: $e');
      rethrow;
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
        data: {
          'id_user': userId,
          'token': token,
          'id': pageId,
        },
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
      _log('📤 Uploading temp image with action: $action');

      // Читаем файл и конвертируем в base64
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'assets/save',
        },
        data: {
          'id_user': userId,
          'token': token,
          'type': 'image',
          'action': action,
          'assets': base64Image,
        },
      );

      final responseData = _parseResponse(response.data);
      
      if (responseData['data'] == null) {
        throw Exception('Failed to upload image');
      }
      
      _log('✅ Image uploaded: ${responseData['data']['name']}');

      return responseData['data'];
    } catch (e) {
      _log('❌ Error uploading image: $e');
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
}

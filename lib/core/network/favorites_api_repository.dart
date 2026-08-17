import 'package:dio/dio.dart';
import 'dart:convert';
import 'package:hashtagg/core/network/api_config.dart';
import 'package:hashtagg/shared/presentation/bloc/auth_bloc.dart';

/// API Result wrapper
class ApiResult<T> {
  final bool success;
  final T? data;
  final String? error;

  ApiResult({required this.success, this.data, this.error});
}

/// Репозиторий для работы с избранными объявлениями (API)
class FavoritesApiRepository {
  final Dio _dio;
  final int? userId;
  final String? token;

  FavoritesApiRepository(Dio dio, {this.userId, this.token}) : _dio = dio;

  /// Добавить/удалить объявление из избранного (toggle)
  Future<ApiResult<bool>> toggleFavorite(int listingId) async {
    try {
      print('🔵 [FavoritesApi] Toggle favorite for listing: $listingId');
      print('🔵 [FavoritesApi] userId: $userId, token: ${token != null ? "***" : "null"}');
      
      if (userId == null || token == null) {
        print('🔴 [FavoritesApi] User not authenticated');
        return ApiResult(success: false, error: 'User not authenticated');
      }
      
      print('🔵 [FavoritesApi] Sending request...');
      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'favorite/actionFavorite',
        },
        data: {
          'id_user': userId,
          'token': token,
          'id_ad': listingId,
        },
      );

      final responseData = response.data is String
          ? jsonDecode(response.data)
          : response.data;

      print('🔵 [FavoritesApi] Response: $responseData');

      // Проверяем успешность ответа
      // API возвращает {'action':'delete'} или {'action':'added'}
      if (responseData['action'] == 'delete' || 
          responseData['action'] == 'added' ||
          response.statusCode == 200) {
        print('✅ [FavoritesApi] Success: ${responseData['action']}');
        return ApiResult(success: true, data: true);
      } else {
        print('🔴 [FavoritesApi] Failed: ${responseData['message']}');
        return ApiResult(
          success: false,
          error: responseData['message'] ?? 'Unknown error',
        );
      }
    } catch (e) {
      print('🔴 [FavoritesApi] Exception: $e');
      return ApiResult(success: false, error: e.toString());
    }
  }

  /// Удалить объявление из избранного
  @Deprecated('Use toggleFavorite instead')
  Future<ApiResult<bool>> removeFavorite(int listingId) async {
    return toggleFavorite(listingId);
  }

  /// Получить список избранных объявлений
  Future<ApiResult<List<int>>> getFavorites() async {
    try {
      if (userId == null || token == null) {
        return ApiResult(success: true, data: []);
      }
      
      final response = await _dio.get(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'profile/favorites/getFavorites',
          'id_user': userId,
          'token': token,
        },
      );

      final responseData = response.data is String
          ? jsonDecode(response.data)
          : response.data;

      // Обрабатываем ответ
      if (responseData is List) {
        final favorites = List<int>.from(
          (responseData as List).map((x) => _parseInt(x['ad_id'])),
        );
        return ApiResult(success: true, data: favorites);
      } else {
        return ApiResult(success: true, data: []);
      }
    } catch (e) {
      return ApiResult(success: false, error: e.toString());
    }
  }

  /// Получить полные данные избранных объявлений с сервера
  Future<ApiResult<List<Map<String, dynamic>>>> getFavoritesWithData() async {
    try {
      if (userId == null || token == null) {
        print('🔴 [FavoritesApi] User not authenticated');
        return ApiResult(success: true, data: []);
      }
      
      print('🔵 [FavoritesApi] Loading favorites from server...');
      final response = await _dio.get(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'profile/favorites/getFavoritesSubscriptions',
          'id_user': userId,
          'token': token,
        },
      );

      final responseData = response.data is String
          ? jsonDecode(response.data)
          : response.data;

      print('🔵 [FavoritesApi] Response: $responseData');

      // Обрабатываем ответ
      if (responseData is Map && responseData['favorites'] != null) {
        final favorites = List<Map<String, dynamic>>.from(
          (responseData['favorites'] as List).map((x) => Map<String, dynamic>.from(x)),
        );
        print('✅ [FavoritesApi] Loaded ${favorites.length} favorites');
        return ApiResult(success: true, data: favorites);
      } else {
        print('🔵 [FavoritesApi] No favorites found');
        return ApiResult(success: true, data: []);
      }
    } catch (e) {
      print('🔴 [FavoritesApi] Exception: $e');
      return ApiResult(success: false, error: e.toString());
    }
  }

  int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

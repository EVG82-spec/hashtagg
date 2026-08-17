import 'package:dio/dio.dart';
import 'dart:convert';
import 'api_config.dart';

class ShopsApiRepository {
  final Dio _dio;

  ShopsApiRepository({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: ApiConfig.baseUrl,
              headers: {
                'Content-Type': 'application/x-www-form-urlencoded',
              },
            ));

  /// Получение списка магазинов
  /// //INTEGRATED
  Future<Map<String, dynamic>> getShops({
    int page = 1,
    int? catId,
  }) async {
    try {
      print('🔵 [ShopsApi] Getting shops - page: $page');

      final response = await _dio.get(
        '/systems/api/controller.php',
        queryParameters: {
          'key': '3090379067',
          'route': 'shops/getShops',
          'page': page,
          if (catId != null) 'cat_id': catId,
        },
        options: Options(
          validateStatus: (status) => true,
        ),
      );

      print('🔵 [ShopsApi] Shops response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = response.data is String
            ? json.decode(response.data)
            : response.data;

        print('✅ [ShopsApi] Loaded ${data['data']?.length ?? 0} shops');
        return {'status': true, 'data': data};
      } else {
        print('🔴 [ShopsApi] Server error ${response.statusCode}: ${response.data}');
        return {'status': false, 'error': 'Server error: ${response.statusCode}'};
      }
    } on DioException catch (e) {
      print('🔴 [ShopsApi] Shops exception: $e');
      return {'status': false, 'error': e.message ?? 'Network error'};
    } catch (e) {
      print('🔴 [ShopsApi] Shops error: $e');
      return {'status': false, 'error': e.toString()};
    }
  }

  /// Получение данных конкретного магазина
  /// //INTEGRATED
  Future<Map<String, dynamic>> getShop({
    required String shopId,
    int? userId,
    String? token,
  }) async {
    try {
      print('🔵 [ShopsApi] Getting shop - shopId: $shopId');

      final response = await _dio.get(
        '/systems/api/controller.php',
        queryParameters: {
          'key': '3090379067',
          'route': 'shops/getShop',
          'id': shopId,
          if (userId != null) 'id_user': userId,
          if (token != null) 'token': token,
        },
        options: Options(
          validateStatus: (status) => true,
        ),
      );

      print('🔵 [ShopsApi] Shop response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = response.data is String
            ? json.decode(response.data)
            : response.data;

        print('✅ [ShopsApi] Loaded shop: ${data['data']?['title']}');
        print('🔵 [ShopsApi] Full shop data: ${json.encode(data['data'])}');
        return {'status': true, 'data': data['data']};
      } else {
        print('🔴 [ShopsApi] Server error ${response.statusCode}: ${response.data}');
        return {'status': false, 'error': 'Server error: ${response.statusCode}'};
      }
    } on DioException catch (e) {
      print('🔴 [ShopsApi] Shop exception: $e');
      return {'status': false, 'error': e.message ?? 'Network error'};
    } catch (e) {
      print('🔴 [ShopsApi] Shop error: $e');
      return {'status': false, 'error': e.toString()};
    }
  }
}

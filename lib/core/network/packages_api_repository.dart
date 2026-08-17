import 'package:dio/dio.dart';
import 'dart:convert';
import 'api_config.dart';

class PackagesApiRepository {
  final Dio _dio;

  PackagesApiRepository({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: ApiConfig.baseUrl,
              headers: {
                'Content-Type': 'application/x-www-form-urlencoded',
              },
            ));

  /// Получение категорий пакетов
  /// //INTEGRATED
  Future<Map<String, dynamic>> getCategories({int? catId}) async {
    try {
      print('🔵 [PackagesApi] Getting categories${catId != null ? ' for parent: $catId' : ' (root)'}');

      final response = await _dio.get(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'packages/getCategories',
          if (catId != null) 'id': catId,
        },
        options: Options(
          validateStatus: (status) => true,
        ),
      );

      print('🔵 [PackagesApi] Categories response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = response.data is String
            ? json.decode(response.data)
            : response.data;

        print('✅ [PackagesApi] Loaded ${data['data']?.length ?? 0} categories');
        return {'status': true, 'data': data};
      } else {
        print('🔴 [PackagesApi] Server error ${response.statusCode}: ${response.data}');
        return {'status': false, 'error': 'Server error: ${response.statusCode}'};
      }
    } on DioException catch (e) {
      print('🔴 [PackagesApi] Categories exception: $e');
      return {'status': false, 'error': e.message ?? 'Network error'};
    } catch (e) {
      print('🔴 [PackagesApi] Categories error: $e');
      return {'status': false, 'error': e.toString()};
    }
  }

  /// Получение пакетов для категории
  /// //INTEGRATED
  Future<Map<String, dynamic>> getPackages({
    required int userId,
    required String token,
    required int catId,
  }) async {
    try {
      print('🔵 [PackagesApi] Getting packages for category: $catId');

      final response = await _dio.get(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'packages/getPackages',
          'id_user': userId,
          'token': token,
          'cat_id': catId,
        },
        options: Options(
          validateStatus: (status) => true,
        ),
      );

      print('🔵 [PackagesApi] Packages response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = response.data is String
            ? json.decode(response.data)
            : response.data;

        final packages = data['packages'] ?? [];
        print('✅ [PackagesApi] Loaded ${packages.length} packages');
        return {'status': true, 'packages': packages};
      } else {
        print('🔴 [PackagesApi] Server error ${response.statusCode}: ${response.data}');
        return {'status': false, 'error': 'Server error: ${response.statusCode}', 'packages': []};
      }
    } on DioException catch (e) {
      print('🔴 [PackagesApi] Packages exception: $e');
      return {'status': false, 'error': e.message ?? 'Network error', 'packages': []};
    } catch (e) {
      print('🔴 [PackagesApi] Packages error: $e');
      return {'status': false, 'error': e.toString(), 'packages': []};
    }
  }

  /// Получение заказов пакетов (активные и завершённые)
  /// //INTEGRATED
  Future<Map<String, dynamic>> getOrdersPackages({
    required int userId,
    required String token,
  }) async {
    try {
      print('🔵 [PackagesApi] Getting orders for user: $userId');
      print('🔵 [PackagesApi] Token (first 20 chars): ${token.substring(0, token.length > 20 ? 20 : token.length)}...');

      final response = await _dio.get(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'packages/getOrdersPackages',
          'id_user': userId,
          'token': token,
        },
        options: Options(
          validateStatus: (status) => true,
        ),
      );

      print('🔵 [PackagesApi] Orders response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = response.data is String
            ? json.decode(response.data)
            : response.data;

        // active и completed могут быть null
        final active = data['active'] ?? [];
        final completed = data['completed'] ?? [];
        
        print('✅ [PackagesApi] Loaded ${active.length} active, ${completed.length} completed orders');
        return {
          'status': true,
          'active': active,
          'completed': completed,
        };
      } else {
        print('🔴 [PackagesApi] Server error ${response.statusCode}: ${response.data}');
        return {
          'status': false,
          'error': 'Server error: ${response.statusCode}',
          'active': [],
          'completed': [],
        };
      }
    } on DioException catch (e) {
      print('🔴 [PackagesApi] Orders exception: $e');
      return {
        'status': false,
        'error': e.message ?? 'Network error',
        'active': [],
        'completed': [],
      };
    } catch (e) {
      print('🔴 [PackagesApi] Orders error: $e');
      return {
        'status': false,
        'error': e.toString(),
        'active': [],
        'completed': [],
      };
    }
  }

  /// Оплата пакета
  /// //INTEGRATED
  Future<Map<String, dynamic>> payment({
    required int userId,
    required String token,
    required int packageId,
    required int catId,
  }) async {
    try {
      print('🔵 [PackagesApi] Payment for package: $packageId, category: $catId');

      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'packages/payment',
        },
        data: {
          'id_user': userId,
          'token': token,
          'id': packageId,
          'cat_id': catId,
          'type': 'balance',
        },
        options: Options(
          validateStatus: (status) => true,
        ),
      );

      print('🔵 [PackagesApi] Payment response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = response.data is String
            ? json.decode(response.data)
            : response.data;

        if (data['status'] == true) {
          print('✅ [PackagesApi] Payment successful');
          return {'status': true, 'type': data['type']};
        } else if (data['balance'] != null) {
          // Недостаточно средств (balance - строка с форматированием)
          print('🔴 [PackagesApi] Insufficient funds: ${data['balance']}');
          return {'status': false, 'balance': data['balance']};
        } else if (data['answer'] != null) {
          // Ошибка валидации
          print('🔴 [PackagesApi] Payment error: ${data['answer']}');
          return {'status': false, 'answer': data['answer']};
        } else {
          print('🔴 [PackagesApi] Unknown error');
          return {'status': false, 'error': 'Unknown error'};
        }
      } else {
        print('🔴 [PackagesApi] Server error ${response.statusCode}: ${response.data}');
        return {'status': false, 'error': 'Server error: ${response.statusCode}'};
      }
    } on DioException catch (e) {
      print('🔴 [PackagesApi] Payment exception: $e');
      return {'status': false, 'error': e.message ?? 'Network error'};
    } catch (e) {
      print('🔴 [PackagesApi] Payment error: $e');
      return {'status': false, 'error': e.toString()};
    }
  }
}

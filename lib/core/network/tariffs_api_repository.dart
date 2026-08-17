import 'package:dio/dio.dart';
import 'dart:convert';
import 'api_config.dart';

class TariffsApiRepository {
  final Dio _dio;

  TariffsApiRepository({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: ApiConfig.baseUrl,
              headers: {
                'Content-Type': 'application/x-www-form-urlencoded',
              },
            ));

  /// Получение данных о тарифах
  /// //INTEGRATED
  Future<Map<String, dynamic>> getData({
    required int userId,
    required String token,
  }) async {
    try {
      print('🔵 [TariffsApi] Getting tariffs data for user: $userId');

      final response = await _dio.get(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'profile/tariff/getData',
          'id_user': userId,
          'token': token,
        },
        options: Options(
          validateStatus: (status) => true,
        ),
      );

      print('🔵 [TariffsApi] Tariffs response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = response.data is String
            ? json.decode(response.data)
            : response.data;

        // Ответ - массив, не объект
        if (data is List) {
          print('✅ [TariffsApi] Loaded ${data.length} tariffs');
          return {'status': true, 'data': data};
        } else {
          print('🔴 [TariffsApi] Unexpected response format');
          return {'status': false, 'error': 'Invalid response format', 'data': []};
        }
      } else {
        print('🔴 [TariffsApi] Server error ${response.statusCode}: ${response.data}');
        return {'status': false, 'error': 'Server error: ${response.statusCode}', 'data': []};
      }
    } on DioException catch (e) {
      print('🔴 [TariffsApi] Tariffs exception: $e');
      return {'status': false, 'error': e.message ?? 'Network error', 'data': []};
    } catch (e) {
      print('🔴 [TariffsApi] Tariffs error: $e');
      return {'status': false, 'error': e.toString(), 'data': []};
    }
  }

  /// Активация тарифа
  /// //INTEGRATED
  Future<Map<String, dynamic>> activate({
    required int userId,
    required String token,
    required int tariffId,
  }) async {
    try {
      print('🔵 [TariffsApi] Activating tariff: $tariffId for user: $userId');

      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'profile/tariff/activate',
        },
        data: {
          'id_user': userId,
          'token': token,
          'id': tariffId,
        },
        options: Options(
          validateStatus: (status) => true,
        ),
      );

      print('🔵 [TariffsApi] Activate response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = response.data is String
            ? json.decode(response.data)
            : response.data;

        if (data['status'] == true) {
          print('✅ [TariffsApi] Tariff activated successfully');
          return {'status': true};
        } else if (data['balance'] == false) {
          // Недостаточно средств
          print('🔴 [TariffsApi] Insufficient funds');
          return {'status': false, 'balance': false};
        } else if (data['answer'] != null) {
          // Ошибка (нельзя понизить тариф или одноразовый)
          print('🔴 [TariffsApi] Activation error: ${data['answer']}');
          return {'status': false, 'answer': data['answer']};
        } else {
          print('🔴 [TariffsApi] Unknown error');
          return {'status': false, 'error': 'Unknown error'};
        }
      } else {
        print('🔴 [TariffsApi] Server error ${response.statusCode}: ${response.data}');
        return {'status': false, 'error': 'Server error: ${response.statusCode}'};
      }
    } on DioException catch (e) {
      print('🔴 [TariffsApi] Activate exception: $e');
      return {'status': false, 'error': e.message ?? 'Network error'};
    } catch (e) {
      print('🔴 [TariffsApi] Activate error: $e');
      return {'status': false, 'error': e.toString()};
    }
  }

  /// Удаление тарифа
  /// //INTEGRATED
  Future<Map<String, dynamic>> deleteTariff({
    required int userId,
    required String token,
  }) async {
    try {
      print('🔵 [TariffsApi] Deleting tariff for user: $userId');

      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'profile/tariff/delete',
        },
        data: {
          'id_user': userId,
          'token': token,
        },
        options: Options(
          validateStatus: (status) => true,
        ),
      );

      print('🔵 [TariffsApi] Delete response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = response.data is String
            ? json.decode(response.data)
            : response.data;

        if (data['status'] == true) {
          print('✅ [TariffsApi] Tariff deleted successfully');
          return {'status': true};
        } else {
          print('🔴 [TariffsApi] Delete failed');
          return {'status': false, 'error': 'Failed to delete tariff'};
        }
      } else {
        print('🔴 [TariffsApi] Server error ${response.statusCode}: ${response.data}');
        return {'status': false, 'error': 'Server error: ${response.statusCode}'};
      }
    } on DioException catch (e) {
      print('🔴 [TariffsApi] Delete exception: $e');
      return {'status': false, 'error': e.message ?? 'Network error'};
    } catch (e) {
      print('🔴 [TariffsApi] Delete error: $e');
      return {'status': false, 'error': e.toString()};
    }
  }

  /// Получение статистики объявления
  /// //INTEGRATED
  Future<Map<String, dynamic>> getStatisticsAd({
    required int userId,
    required String token,
    required int adId,
    String? dateStart,
    String? dateEnd,
  }) async {
    try {
      print('🔵 [TariffsApi] Getting statistics for ad: $adId');

      final response = await _dio.get(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'profile/tariff/getStatisticsAd',
          'id_user': userId,
          'token': token,
          'ad_id': adId,
          if (dateStart != null) 'date_start': dateStart,
          if (dateEnd != null) 'date_end': dateEnd,
        },
        options: Options(
          validateStatus: (status) => true,
        ),
      );

      print('🔵 [TariffsApi] Statistics response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = response.data is String
            ? json.decode(response.data)
            : response.data;

        print('✅ [TariffsApi] Loaded statistics');
        return {'status': true, 'data': data};
      } else {
        print('🔴 [TariffsApi] Server error ${response.statusCode}: ${response.data}');
        return {'status': false, 'error': 'Server error: ${response.statusCode}'};
      }
    } on DioException catch (e) {
      print('🔴 [TariffsApi] Statistics exception: $e');
      return {'status': false, 'error': e.message ?? 'Network error'};
    } catch (e) {
      print('🔴 [TariffsApi] Statistics error: $e');
      return {'status': false, 'error': e.toString()};
    }
  }
}

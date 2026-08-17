import 'package:dio/dio.dart';
import 'package:hashtagg/core/network/api_client.dart';

abstract class BaseRepository {
  final Dio _dio = ApiClient.instance.dio;

  Future<dynamic> post(String route, {Map<String, dynamic>? data}) async {
    try {
      final response = await _dio.post(
        '/systems/api/controller.php',
        data: {
          'route': route,
          ...?data,
        },
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<dynamic> get(String route, {Map<String, dynamic>? queryParameters}) async {
    try {
      final response = await _dio.get(
        '/systems/api/controller.php',
        queryParameters: {
          'route': route,
          ...?queryParameters,
        },
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Exception _handleError(DioException e) {
    // Здесь можно добавить более сложную обработку
    return Exception('Ошибка сети: ${e.message}');
  }
}
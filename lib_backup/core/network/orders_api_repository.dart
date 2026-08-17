import 'package:dio/dio.dart';
import 'dart:convert';
import 'api_config.dart';

class OrdersApiRepository {
  final Dio _dio;

  OrdersApiRepository({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: ApiConfig.baseUrl,
              headers: {
                'Content-Type': 'application/x-www-form-urlencoded',
              },
            ));

  /// Получение заказов пользователя (покупки, продажи, бронирование)
  /// //INTEGRATED
  Future<Map<String, dynamic>> getOrders({
    required int userId,
    required String token,
  }) async {
    try {
      print('🔵 [OrdersApi] Getting orders for user: $userId');

      final response = await _dio.get(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'profile/orders/getOrders',
          'id_user': userId,
          'token': token,
        },
        options: Options(
          validateStatus: (status) => true,
        ),
      );

      print('🔵 [OrdersApi] Orders response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = response.data is String
            ? json.decode(response.data)
            : response.data;

        final buy = data['buy'] ?? [];
        final sell = data['sell'] ?? [];
        final booking = data['booking'] ?? [];
        
        print('✅ [OrdersApi] Loaded ${buy.length} buy, ${sell.length} sell, ${booking.length} booking orders');
        return {
          'status': true,
          'buy': buy,
          'sell': sell,
          'booking': booking,
        };
      } else {
        print('🔴 [OrdersApi] Server error ${response.statusCode}: ${response.data}');
        return {
          'status': false,
          'error': 'Server error: ${response.statusCode}',
          'buy': [],
          'sell': [],
          'booking': [],
        };
      }
    } on DioException catch (e) {
      print('🔴 [OrdersApi] Orders exception: $e');
      return {
        'status': false,
        'error': e.message ?? 'Network error',
        'buy': [],
        'sell': [],
        'booking': [],
      };
    } catch (e) {
      print('🔴 [OrdersApi] Orders error: $e');
      return {
        'status': false,
        'error': e.toString(),
        'buy': [],
        'sell': [],
        'booking': [],
      };
    }
  }
}

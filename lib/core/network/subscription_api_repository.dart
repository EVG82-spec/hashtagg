import 'package:dio/dio.dart';
import 'package:hashtagg/core/network/api_config.dart';
import 'package:hashtagg/core/network/dio_client.dart';
import 'package:hive/hive.dart';

class SubscriptionApiRepository {
  final Dio _dio;

  SubscriptionApiRepository() : _dio = DioClient.createDio();

  /// Подписаться на магазин
  Future<bool> subscribeShop({required int userId, required int shopId}) async {
    try {
      final box = Hive.box('user');
      final token = box.get('auth_token');

      print('🔵 [SubscriptionApi] SUBSCRIBE START');
      print('   userId: $userId');
      print('   shopId: $shopId');
      print('   token: ${token != null ? token.substring(0, 10) : 'null'}');

      final response = await _dio.post(
        '/systems/ajax/controller.php',
        data: {
          'action': 'shop/subscribe',
          'id_user': userId,
          'id_shop': shopId,
          'token': token,
        },
      );

      print('📦 [SubscriptionApi] Response: ${response.data}');
      return response.data['status'] == true;
    } catch (e) {
      print('❌ [SubscriptionApi] Subscribe error: $e');
      return false;
    }
  }

  /// Отписаться от магазина
  Future<bool> unsubscribeShop({
    required int userId,
    required int shopId,
  }) async {
    try {
      print('🔵 [SubscriptionApi] Unsubscribing from shop: $shopId');

      final response = await _dio.post(
        '/systems/ajax/controller.php',
        data: {
          'action': 'shop/unsubscribe',
          'id_user': userId,
          'id_shop': shopId,
        },
      );

      print('📦 [SubscriptionApi] Response: ${response.data}');
      return response.data['status'] == true;
    } catch (e) {
      print('❌ [SubscriptionApi] Error: $e');
      return false;
    }
  }

  /// Получить список подписок пользователя
  Future<List<int>> getUserSubscriptions(int userId) async {
    try {
      print('🔵 [SubscriptionApi] Getting subscriptions for user: $userId');

      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'profile/subscriptions/getSubscriptions',
        },
        data: {'id_user': userId},
      );

      print('📦 [SubscriptionApi] Response: ${response.data}');

      if (response.data is List) {
        final List<int> ids = [];
        for (var item in response.data) {
          ids.add(item['id_user_to'] ?? 0);
        }
        return ids;
      }
      return [];
    } catch (e) {
      print('❌ [SubscriptionApi] Error: $e');
      return [];
    }
  }
}

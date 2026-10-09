import 'package:dio/dio.dart';
import 'package:hashtagg/core/network/api_config.dart';
import 'package:hive/hive.dart';
import '../models/auction_status.dart';

class AuctionApiRepository {
  final Dio _dio;

  AuctionApiRepository(this._dio);

  /// Получить ID пользователя и токен из Hive
  Map<String, dynamic> _getAuthData() {
    try {
      final box = Hive.box('user');
      final userData = box.get('user') as Map?;
      final token = box.get('auth_token') as String?;

      int userId = 0;
      if (userData != null && userData['id'] != null) {
        final id = userData['id'];
        userId = id is int ? id : int.tryParse(id.toString()) ?? 0;
      }

      return {'user_id': userId, 'token': token ?? ''};
    } catch (e) {
      print('❌ [AuctionApi] Error getting auth data: $e');
      return {'user_id': 0, 'token': ''};
    }
  }

  /// Получить статус аукциона для магазина
  Future<AuctionStatus> getStatus({required int shopId}) async {
    final auth = _getAuthData();

    print(
      '📡 [AuctionApi] getStatus - shopId: $shopId, userId: ${auth['user_id']}',
    );

    final response = await _dio.post(
      '/systems/ajax/controller.php',
      data: {
        'action': 'auction/status',
        'shop_id': shopId,
        'proxy_user_id': auth['user_id'],
        'token': auth['token'],
      },
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    print('📦 [AuctionApi] getStatus response: ${response.data}');

    if (response.data is Map && response.data['success'] == true) {
      final data = response.data['data'];
      return AuctionStatus.fromJson(data as Map<String, dynamic>);
    }

    throw Exception(response.data?['message'] ?? 'Ошибка загрузки аукциона');
  }

  /// Сделать ставку
  Future<Map<String, dynamic>> placeBid({
    required int shopId,
    required int targetPlace,
    required double bidPrice,
  }) async {
    final auth = _getAuthData();

    print('📡 [AuctionApi] placeBid - shopId: $shopId, place: $targetPlace');

    final response = await _dio.post(
      '/systems/ajax/controller.php',
      data: {
        'action': 'auction/bid',
        'shop_id': shopId,
        'target_place': targetPlace,
        'bid_price': bidPrice, // 👈 ДОБАВИТЬ
        'proxy_user_id': auth['user_id'],
        'token': auth['token'],
      },
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    print('📦 [AuctionApi] placeBid response: ${response.data}');
    return response.data as Map<String, dynamic>;
  }

  /// Активировать участие (500₽)
  Future<Map<String, dynamic>> activateParticipation({
    required int shopId,
  }) async {
    final auth = _getAuthData();

    print('📡 [AuctionApi] activateParticipation - shopId: $shopId');

    final response = await _dio.post(
      '/systems/ajax/controller.php',
      data: {
        'action': 'auction/activate',
        'shop_id': shopId,
        'proxy_user_id': auth['user_id'],
        'token': auth['token'],
      },
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    print('📦 [AuctionApi] activateParticipation response: ${response.data}');
    return response.data as Map<String, dynamic>;
  }

  /// Сохранить настройки автопилота
  Future<Map<String, dynamic>> saveAutoSettings({
    required int shopId,
    required bool isEnabled,
    required double dailyLimit,
    required int bidIntervalMinutes,
  }) async {
    final auth = _getAuthData();

    print(
      '📡 [AuctionApi] saveAutoSettings - shopId: $shopId, enabled: $isEnabled',
    );

    final response = await _dio.post(
      '/systems/ajax/controller.php',
      data: {
        'action': 'auction/auto/settings',
        'shop_id': shopId,
        'is_enabled': isEnabled ? 1 : 0,
        'target_place': 1,
        'max_bid_step': 50,
        'daily_limit': dailyLimit,
        'bid_interval_minutes': bidIntervalMinutes,
        'proxy_user_id': auth['user_id'],
        'token': auth['token'],
      },
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    print('📦 [AuctionApi] saveAutoSettings response: ${response.data}');
    return response.data as Map<String, dynamic>;
  }

  /// Получить историю автопилота
  Future<Map<String, dynamic>> getAutoHistory({required int shopId}) async {
    final auth = _getAuthData();

    final response = await _dio.post(
      '/systems/ajax/controller.php',
      data: {
        'action': 'auction/auto/history',
        'shop_id': shopId,
        'proxy_user_id': auth['user_id'],
        'token': auth['token'],
      },
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    return response.data as Map<String, dynamic>;
  }

  /// Получить полную историю операций
  Future<List<Map<String, dynamic>>> getFullHistory() async {
    final auth = _getAuthData();

    final response = await _dio.post(
      '/systems/ajax/controller.php',
      data: {
        'action': 'auction/full/history',
        'proxy_user_id': auth['user_id'],
        'token': auth['token'],
      },
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    if (response.data is Map && response.data['success'] == true) {
      final history = response.data['history'] as List? ?? [];
      return history.cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// Выполнить автоставку (для теста/крона)
  Future<Map<String, dynamic>> placeAutoBid({required int shopId}) async {
    final auth = _getAuthData();

    final response = await _dio.post(
      '/systems/ajax/controller.php',
      data: {
        'action': 'auction/auto/bid',
        'shop_id': shopId,
        'proxy_user_id': auth['user_id'],
        'token': auth['token'],
      },
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    return response.data as Map<String, dynamic>;
  }

  /// Проверить, согласился ли пользователь с правилами
  Future<bool> getAgreementStatus({required int shopId}) async {
    try {
      final auth = _getAuthData();

      print('📡 [AuctionApi] getAgreementStatus - shopId: $shopId');

      final response = await _dio.post(
        '/systems/ajax/controller.php',
        data: {
          'action': 'auction/agreement/get',
          'shop_id': shopId,
          'proxy_user_id': auth['user_id'],
          'token': auth['token'],
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      print('📦 [AuctionApi] getAgreementStatus response: ${response.data}');

      if (response.data is Map) {
        return response.data['agreed'] == true ||
            response.data['status'] == true;
      }
      return false;
    } catch (e) {
      print('🔴 [AuctionApi] getAgreementStatus error: $e');
      return false;
    }
  }

  /// Получить текст условий участия в «Битве за ТОП»
  Future<Map<String, dynamic>?> getAuctionRules() async {
    try {
      final auth = _getAuthData();

      print('📡 [AuctionApi] getAuctionRules');

      final response = await _dio.post(
        '/systems/ajax/controller.php',
        data: {
          'action': 'auction/rules/get',
          'proxy_user_id': auth['user_id'],
          'token': auth['token'],
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      print('📦 [AuctionApi] getAuctionRules response: ${response.data}');

      if (response.data is Map && response.data['status'] == true) {
        return response.data['data'];
      }
      return null;
    } catch (e) {
      print('🔴 [AuctionApi] getAuctionRules error: $e');
      return null;
    }
  }

  /// Сохранить согласие пользователя с правилами
  Future<bool> saveAgreement({required int shopId}) async {
    try {
      final auth = _getAuthData();

      print('📡 [AuctionApi] saveAgreement - shopId: $shopId');

      final response = await _dio.post(
        '/systems/ajax/controller.php',
        data: {
          'action': 'auction/agreement/save',
          'shop_id': shopId,
          'proxy_user_id': auth['user_id'],
          'token': auth['token'],
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      print('📦 [AuctionApi] saveAgreement response: ${response.data}');

      if (response.data is Map) {
        return response.data['status'] == true;
      }
      return false;
    } catch (e) {
      print('🔴 [AuctionApi] saveAgreement error: $e');
      return false;
    }
  }
}

import 'package:dio/dio.dart';
import 'dart:convert';
import 'api_config.dart';

class WalletApiRepository {
  final Dio _dio;

  WalletApiRepository({Dio? dio}) : _dio = dio ?? Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    validateStatus: (status) => status! < 500,
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
  ));

  /// Получение истории транзакций кошелька
  Future<Map<String, dynamic>> getHistory({
    required int userId,
    required String token,
  }) async {
    try {
      print('🔵 [WalletApi] Getting history - userId: $userId, token: ${token.isEmpty ? "EMPTY" : "present"}');
      
      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: {
          'key': '3090379067',
          'route': 'profile/balance/getHistory',
          'id_user': userId,
          'token': token,
        },
        options: Options(
          validateStatus: (status) => true, // Не выбрасывать исключение на любой статус
        ),
      );

      print('🔵 [WalletApi] History response status: ${response.statusCode}');
      print('📥 [WalletApi] History raw response: ${response.data}');
      
      if (response.statusCode == 200) {
        final data = response.data is String 
            ? json.decode(response.data) 
            : response.data;
        
        print('📥 [WalletApi] History parsed JSON: $data');
        
        if (data is List) {
          print('✅ [WalletApi] Loaded ${data.length} history records');
          return {'status': true, 'data': data};
        } else {
          return {'status': false, 'error': 'Invalid response format', 'data': []};
        }
      } else {
        print('🔴 [WalletApi] History failed with status ${response.statusCode}');
        return {'status': false, 'error': 'Server error: ${response.statusCode}', 'data': []};
      }
    } on DioException catch (e) {
      print('🔴 [WalletApi] History exception: $e');
      return {'status': false, 'error': e.message ?? 'Network error', 'data': []};
    } catch (e) {
      print('🔴 [WalletApi] History error: $e');
      return {'status': false, 'error': e.toString(), 'data': []};
    }
  }


  /// Инициализация платежа для пополнения баланса
  Future<Map<String, dynamic>> initPayment({
    required int userId,
    required String token,
    required double amount,
    required String codePayment,
  }) async {
    try {
      print('🔵 [WalletApi] Initiating payment - userId: $userId, amount: $amount, codePayment: $codePayment');

      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: {
          'key': '3090379067',
          'route': 'profile/balance/initPayment',
        },
        data: {
          'id_user': userId,
          'token': token,
          'amount': amount,
          'code_payment': codePayment,

          // ✅ ДОБАВЛЯЕМ ЭТУ СТРОКУ: сообщаем серверу, что запрос из приложения
          'is_app': 'true',
        },
        options: Options(
          validateStatus: (status) => true,
        ),
      );

      print('🔵 [WalletApi] InitPayment response status: ${response.statusCode}');
      print('📥 [WalletApi] InitPayment raw response: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data is String
            ? json.decode(response.data)
            : response.data;

        print('📥 [WalletApi] InitPayment parsed JSON: $data');

        if (data['status'] == true) {
          print('✅ [WalletApi] Payment initialized - link: ${data['link']}, orderId: ${data['id_order']}');
          return {
            'status': true,
            'link': data['link'],
            'id_order': data['id_order'],
          };
        } else {
          print('🔴 [WalletApi] Payment init failed: ${data['error']}');
          return {
            'status': false,
            'error': data['error'] ?? 'Failed to initialize payment',
          };
        }
      } else {
        print('🔴 [WalletApi] InitPayment failed with status ${response.statusCode}');
        return {'status': false, 'error': 'Server error: ${response.statusCode}'};
      }
    } on DioException catch (e) {
      print('🔴 [WalletApi] InitPayment exception: $e');
      return {'status': false, 'error': e.message ?? 'Network error'};
    } catch (e) {
      print('🔴 [WalletApi] InitPayment error: $e');
      return {'status': false, 'error': e.toString()};
    }
  }

  /// Проверка статуса платежа
  Future<Map<String, dynamic>> checkPaymentStatus({
    required int userId,
    required String token,
    required int orderId,
  }) async {
    try {
      print('🔵 [WalletApi] Checking payment status - userId: $userId, orderId: $orderId');
      
      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: {
          'key': '3090379067',
          'route': 'profile/balance/statusPayment',
        },
        data: {
          'id_user': userId,
          'token': token,
          'id_order': orderId,
        },
      );

      print('🔵 [WalletApi] StatusPayment response status: ${response.statusCode}');
      print('📥 [WalletApi] StatusPayment raw response: ${response.data}');
      
      if (response.statusCode == 200) {
        final data = response.data is String 
            ? json.decode(response.data) 
            : response.data;
        
        print('📥 [WalletApi] StatusPayment parsed JSON: $data');
        
        final isPaid = data['status'] == true;
        print(isPaid ? '✅ [WalletApi] Payment completed' : '🔵 [WalletApi] Payment not completed yet');
        
        return {'status': true, 'is_paid': isPaid};
      } else {
        return {'status': false, 'error': 'Failed to check payment status'};
      }
    } on DioException catch (e) {
      print('🔴 [WalletApi] StatusPayment exception: $e');
      return {'status': false, 'error': e.message ?? 'Network error'};
    } catch (e) {
      print('🔴 [WalletApi] StatusPayment error: $e');
      return {'status': false, 'error': e.toString()};
    }
  }
}

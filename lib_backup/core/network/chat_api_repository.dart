import 'package:dio/dio.dart';
import 'dart:convert';
import 'package:hashtagg/core/network/api_config.dart';

/// API Result wrapper
class ApiResult<T> {
  final bool success;
  final T? data;
  final String? error;

  ApiResult({required this.success, this.data, this.error});
}

/// Репозиторий для работы с чатами (API)
class ChatApiRepository {
  final Dio _dio;
  final int? userId;
  final String? token;

  ChatApiRepository(Dio dio, {this.userId, this.token}) : _dio = dio;

  /// Получить список диалогов
  Future<ApiResult<Map<String, dynamic>>> getDialogs() async {
    try {
      print('🔵 [ChatApi] Loading dialogs...');
      
      if (userId == null || token == null) {
        print('🔴 [ChatApi] User not authenticated');
        return ApiResult(success: false, error: 'User not authenticated');
      }

      print('🔵 [ChatApi] Request params: userId=$userId, token=${token?.substring(0, 10)}...');

      final response = await _dio.get(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'profile/chat/getUsers',
          'id_user': userId,
          'token': token,
        },
      );

      print('🔵 [ChatApi] Response status: ${response.statusCode}');
      print('🔵 [ChatApi] Response data type: ${response.data.runtimeType}');
      
      if (response.data is String) {
        print('🔵 [ChatApi] Response string (first 500 chars): ${(response.data as String).substring(0, (response.data as String).length > 500 ? 500 : (response.data as String).length)}');
      }

      final responseData = response.data is String
          ? jsonDecode(response.data)
          : response.data;

      print('✅ [ChatApi] Loaded ${responseData['count_dialogs'] ?? 0} dialogs');
      return ApiResult(success: true, data: responseData);
    } catch (e, stackTrace) {
      print('🔴 [ChatApi] Exception: $e');
      print('🔴 [ChatApi] Stack trace: $stackTrace');
      
      if (e is DioException) {
        print('🔴 [ChatApi] DioException details:');
        print('  - Type: ${e.type}');
        print('  - Message: ${e.message}');
        print('  - Response status: ${e.response?.statusCode}');
        print('  - Response data type: ${e.response?.data.runtimeType}');
        
        if (e.response?.data is String) {
          final responseStr = e.response!.data as String;
          print('  - Response data (first 1000 chars): ${responseStr.substring(0, responseStr.length > 1000 ? 1000 : responseStr.length)}');
        } else {
          print('  - Response data: ${e.response?.data}');
        }
      }
      
      return ApiResult(success: false, error: e.toString());
    }
  }

  /// Получить диалог с пользователем
  Future<ApiResult<Map<String, dynamic>>> getDialog({
    required String dialogId,
    int? adId,
    int? userToId,
    bool isSupport = false,
  }) async {
    try {
      print('🔵 [ChatApi] Loading dialog: $dialogId');
      
      if (userId == null || token == null) {
        return ApiResult(success: false, error: 'User not authenticated');
      }

      final queryParams = {
        'key': ApiConfig.apiKey,
        'route': 'profile/chat/getDialog',
        'id_user': userId,
        'token': token,
        'id': dialogId,
        'support': isSupport ? 1 : 0,
      };

      if (adId != null) queryParams['id_ad'] = adId;
      if (userToId != null) queryParams['id_user_to'] = userToId;

      final response = await _dio.get(
        '/systems/api/controller.php',
        queryParameters: queryParams,
      );

      final responseData = response.data is String
          ? jsonDecode(response.data)
          : response.data;

      print('✅ [ChatApi] Dialog loaded');
      return ApiResult(success: true, data: responseData);
    } catch (e) {
      print('🔴 [ChatApi] Exception: $e');
      return ApiResult(success: false, error: e.toString());
    }
  }

  /// Отправить сообщение
  Future<ApiResult<bool>> sendMessage({
    required String dialogId,
    required String text,
    List<String>? attachments,
    bool isSupport = false,
  }) async {
    try {
      print('🔵 [ChatApi] Sending message to: $dialogId');
      print('🔵 [ChatApi] Text: $text');
      print('🔵 [ChatApi] Attachments: $attachments');
      
      if (userId == null || token == null) {
        return ApiResult(success: false, error: 'User not authenticated');
      }

      final data = {
        'id_user': userId,
        'token': token,
        'id': dialogId,
        'text': text,
        'support': isSupport ? 1 : 0,
      };

      if (attachments != null && attachments.isNotEmpty) {
        final attachJson = jsonEncode(
          attachments.map((name) => {'name': name}).toList(),
        );
        data['attach'] = attachJson;
        print('🔵 [ChatApi] Attach JSON: $attachJson');
      }

      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'profile/chat/sendMessage',
        },
        data: data,
      );

      final responseData = response.data is String
          ? jsonDecode(response.data)
          : response.data;

      if (responseData['status'] == true) {
        print('✅ [ChatApi] Message sent');
        return ApiResult(success: true, data: true);
      } else {
        return ApiResult(success: false, error: 'Failed to send message');
      }
    } catch (e) {
      print('🔴 [ChatApi] Exception: $e');
      return ApiResult(success: false, error: e.toString());
    }
  }

  /// Обновить диалог (получить новые сообщения)
  Future<ApiResult<Map<String, dynamic>>> updateDialog({
    required String dialogId,
    bool isSupport = false,
  }) async {
    try {
      if (userId == null || token == null) {
        return ApiResult(success: false, error: 'User not authenticated');
      }

      final response = await _dio.get(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'profile/chat/updateDialog',
          'id_user': userId,
          'token': token,
          'id': dialogId,
          'support': isSupport ? 1 : 0,
        },
      );

      final responseData = response.data is String
          ? jsonDecode(response.data)
          : response.data;

      return ApiResult(success: true, data: responseData);
    } catch (e) {
      print('🔴 [ChatApi] Exception: $e');
      return ApiResult(success: false, error: e.toString());
    }
  }

  /// Удалить диалог
  Future<ApiResult<bool>> deleteDialog(String dialogId) async {
    try {
      print('🔵 [ChatApi] Deleting dialog: $dialogId');
      
      if (userId == null || token == null) {
        return ApiResult(success: false, error: 'User not authenticated');
      }

      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'profile/chat/deleteDialog',
        },
        data: {
          'id_user': userId,
          'token': token,
          'id': dialogId,
        },
      );

      final responseData = response.data is String
          ? jsonDecode(response.data)
          : response.data;

      if (responseData['status'] == true) {
        print('✅ [ChatApi] Dialog deleted');
        return ApiResult(success: true, data: true);
      } else {
        return ApiResult(success: false, error: 'Failed to delete dialog');
      }
    } catch (e) {
      print('🔴 [ChatApi] Exception: $e');
      return ApiResult(success: false, error: e.toString());
    }
  }

  /// Очистить все диалоги
  Future<ApiResult<bool>> clearAllDialogs() async {
    try {
      print('🔵 [ChatApi] Clearing all dialogs...');
      
      if (userId == null || token == null) {
        return ApiResult(success: false, error: 'User not authenticated');
      }

      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'profile/chat/clearDialogs',
        },
        data: {
          'id_user': userId,
          'token': token,
        },
      );

      final responseData = response.data is String
          ? jsonDecode(response.data)
          : response.data;

      if (responseData['status'] == true) {
        print('✅ [ChatApi] All dialogs cleared');
        return ApiResult(success: true, data: true);
      } else {
        return ApiResult(success: false, error: 'Failed to clear dialogs');
      }
    } catch (e) {
      print('🔴 [ChatApi] Exception: $e');
      return ApiResult(success: false, error: e.toString());
    }
  }

  /// Получить количество непрочитанных сообщений
  Future<ApiResult<int>> getUnreadCount() async {
    try {
      if (userId == null || token == null) {
        return ApiResult(success: true, data: 0);
      }

      final response = await _dio.get(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'profile/chat/getCount',
          'id_user': userId,
          'token': token,
        },
      );

      final responseData = response.data is String
          ? jsonDecode(response.data)
          : response.data;

      final count = responseData['count_messages'] ?? 0;
      return ApiResult(success: true, data: count is int ? count : 0);
    } catch (e) {
      print('🔴 [ChatApi] Exception: $e');
      return ApiResult(success: false, error: e.toString());
    }
  }

  /// Загрузить файл для чата
  Future<ApiResult<Map<String, dynamic>>> uploadChatFile(String base64Data) async {
    try {
      print('🔵 [ChatApi] Uploading file...');
      
      if (userId == null || token == null) {
        return ApiResult(success: false, error: 'User not authenticated');
      }

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
          'action': 'chat',
          'assets': jsonEncode([base64Data]),
        },
      );

      final responseData = response.data is String
          ? jsonDecode(response.data)
          : response.data;

      if (responseData['data'] != null) {
        print('✅ [ChatApi] File uploaded');
        return ApiResult(success: true, data: responseData['data']);
      } else {
        return ApiResult(success: false, error: 'Failed to upload file');
      }
    } catch (e) {
      print('🔴 [ChatApi] Exception: $e');
      return ApiResult(success: false, error: e.toString());
    }
  }

  /// Заблокировать/разблокировать пользователя
  Future<ApiResult<String>> blockUser(int userToId) async {
    try {
      print('🔵 [ChatApi] Toggling block for user: $userToId');
      
      if (userId == null || token == null) {
        return ApiResult(success: false, error: 'User not authenticated');
      }

      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'card_user/block',
        },
        data: {
          'id_user_from': userId,
          'token': token,
          'id_user_to': userToId,
        },
      );

      final responseData = response.data is String
          ? jsonDecode(response.data)
          : response.data;

      final status = responseData['status']?.toString() ?? '';
      print('✅ [ChatApi] Block status: $status');
      return ApiResult(success: true, data: status);
    } catch (e) {
      print('🔴 [ChatApi] Exception: $e');
      return ApiResult(success: false, error: e.toString());
    }
  }

  /// Пожаловаться на пользователя
  Future<ApiResult<String>> reportUser({
    required int userToId,
    required String text,
  }) async {
    try {
      print('🔵 [ChatApi] Reporting user: $userToId');
      
      if (userId == null || token == null) {
        return ApiResult(success: false, error: 'User not authenticated');
      }

      final response = await _dio.post(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'card_user/complain',
        },
        data: {
          'id_user_from': userId,
          'token': token,
          'id_user_to': userToId,
          'text': text,
        },
      );

      final responseData = response.data is String
          ? jsonDecode(response.data)
          : response.data;

      if (responseData['status'] == true) {
        final answer = responseData['answer']?.toString() ?? 'Жалоба отправлена';
        print('✅ [ChatApi] User reported: $answer');
        return ApiResult(success: true, data: answer);
      } else {
        final error = responseData['answer']?.toString() ?? 'Failed to report user';
        return ApiResult(success: false, error: error);
      }
    } catch (e) {
      print('🔴 [ChatApi] Exception: $e');
      return ApiResult(success: false, error: e.toString());
    }
  }
}

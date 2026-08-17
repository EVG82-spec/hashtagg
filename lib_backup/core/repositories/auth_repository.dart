import 'package:hashtagg/data/models/user_model.dart';
import 'package:hashtagg/data/repositories/base_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthRepository extends BaseRepository {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<UserModel> login(String login, String password) async {
    final response = await post('profile/auth/auth', data: {
      'login': login,
      'pass': password,
    });

    if (response['status'] == true) {
      final token = response['token'];
      final userId = response['id'];
      await _storage.write(key: 'auth_token', value: token);
      await _storage.write(key: 'user_id', value: userId.toString());

      return await getUserData(userId, token);
    } else {
      throw Exception(response['errors'] ?? 'Ошибка входа');
    }
  }

  Future<UserModel> getUserData(int userId, String token) async {
    final response = await post('profile/auth/authToken', data: {
      'id_user': userId,
      'token': token,
    });
    if (response['status'] == true) {
      return UserModel.fromJson(response);
    } else {
      throw Exception(response['errors'] ?? 'Ошибка загрузки профиля');
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: 'auth_token');
    await _storage.delete(key: 'user_id');
  }

  Future<UserModel?> getCurrentUser() async {
    final token = await _storage.read(key: 'auth_token');
    final userId = await _storage.read(key: 'user_id');
    if (token != null && userId != null) {
      try {
        return await getUserData(int.parse(userId), token);
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
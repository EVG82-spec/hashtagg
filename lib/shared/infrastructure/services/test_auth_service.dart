import 'package:hashtagg/shared/domain/entities/user.dart';
import 'package:hashtagg/shared/domain/services/auth_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';

class TestAuthService implements AuthService {
  TestAuthService();

  @override
  User? login(String email, String password) {
    return User(
      id: 0,
      name: 'Тестовый пользователь',
      email: 'example@gmail.com',
      phone: '+7 (999) 999-99-99',
      last_name: 'Тестовая фамилия',
      surname: 'Тестовое отчество',
      shortname: '2391fds9ash9gsgf9a819',
    );
  }

  // lib/shared/infrastructure/services/test_auth_service.dart

  @override
  Future<bool> logout() async {
    // 👈 ДОБАВЬ async И Future<bool>
    try {
      var box = Hive.box('user');
      await box.delete('auth_token');
      await box.delete('user');
      await box.delete('is_oauth');

      if (kDebugMode) {
        debugPrint('[TestAuthService] Logout completed');
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  User? getCurrentUser(String token) {
    return User(
      id: 0,
      name: 'Тестовый пользователь',
      email: 'example@gmail.com',
      phone: '79999999999',
      last_name: 'Тестовая фамилия',
      surname: 'Тестовое отчество',
      shortname: '2391fds9ash9gsgf9a819',
    );
  }
}

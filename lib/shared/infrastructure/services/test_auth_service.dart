import 'package:hashtagg/shared/domain/entities/user.dart';
import 'package:hashtagg/shared/domain/services/auth_service.dart';
import 'package:hive_flutter/hive_flutter.dart';

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

  @override
  bool logout() {
    var box = Hive.box('user');
    
    // ВАЖНО: Сбрасываем флаг OAuth перед очисткой
    box.put('is_oauth', false);
    
    // Очищаем данные пользователя
    box.delete('user');
    box.delete('auth_token');
    
    return true;
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

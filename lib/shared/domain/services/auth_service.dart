import 'package:hashtagg/shared/domain/entities/user.dart';

abstract class AuthService {
  AuthService();

  User? login(String email, String password);
  bool logout();
  User? getCurrentUser(String token);
}
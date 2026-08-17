import 'package:hashtagg/shared/domain/entities/user.dart';
import 'package:hashtagg/shared/domain/services/auth_service.dart';

class LoginUseCase {
  final AuthService _authRepository;
  LoginUseCase(this._authRepository);

  User? execute(String email, String password) {
    return _authRepository.login(email, password);
  }
}
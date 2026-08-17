import 'package:hashtagg/shared/domain/services/auth_service.dart';

class LogoutUseCase {
  final AuthService _authRepository;
  LogoutUseCase(this._authRepository);

  bool execute() {
    return _authRepository.logout();
  }
}
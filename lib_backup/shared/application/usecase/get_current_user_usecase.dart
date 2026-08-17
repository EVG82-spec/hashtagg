import 'package:hashtagg/shared/domain/entities/user.dart';
import 'package:hashtagg/shared/domain/services/auth_service.dart';

class GetCurrentUserUseCase {
  final AuthService _authRepository;
  GetCurrentUserUseCase(this._authRepository);

  User? execute(String token) {
    return _authRepository.getCurrentUser(token);
  }
}
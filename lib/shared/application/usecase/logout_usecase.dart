import 'package:hashtagg/shared/domain/services/auth_service.dart';

// lib/shared/application/usecase/logout_usecase.dart

class LogoutUsecase {
  final AuthService _authService;

  LogoutUsecase(this._authService);

  // ✅ ИЗМЕНИ НА Future<bool>
  Future<bool> execute() async {
    return await _authService.logout();
  }
}

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hashtagg/core/repositories/auth_repository.dart';
import 'package:hashtagg/data/models/user_model.dart';
import 'package:hashtagg/data/repositories/auth_repository.dart';

abstract class AuthEvent {}

class LoginRequested extends AuthEvent {
  final String login;
  final String password;
  LoginRequested(this.login, this.password);
}

class LogoutRequested extends AuthEvent {}

class AuthCheckRequested extends AuthEvent {}

abstract class AuthState {
  final UserModel? user;
  const AuthState(this.user);
}

class AuthInitial extends AuthState {
  AuthInitial() : super(null);
}

class AuthLoading extends AuthState {
  AuthLoading() : super(null);
}

class Authenticated extends AuthState {
  const Authenticated(UserModel user) : super(user);
}

class Unauthenticated extends AuthState {
  const Unauthenticated() : super(null);
}

class AuthError extends AuthState {
  final String message;
  AuthError(this.message) : super(null);
}

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;

  AuthBloc(this._authRepository) : super(AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheck);
    on<LoginRequested>(_onLogin);
    on<LogoutRequested>(_onLogout);
  }

  Future<void> _onAuthCheck(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    final user = await _authRepository.getCurrentUser();
    if (user != null) {
      emit(Authenticated(user));
    } else {
      emit(Unauthenticated());
    }
  }

  Future<void> _onLogin(LoginRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final user = await _authRepository.login(event.login, event.password);
      emit(Authenticated(user));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onLogout(LogoutRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    await _authRepository.logout();
    emit(Unauthenticated());
  }
}

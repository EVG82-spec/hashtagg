import 'package:flutter/foundation.dart';
import 'package:hashtagg/shared/application/usecase/get_current_user_usecase.dart';
import 'package:hashtagg/shared/application/usecase/login_usecase.dart';
import 'package:hashtagg/shared/application/usecase/logout_usecase.dart';
import 'package:hashtagg/shared/domain/entities/user.dart';
import 'package:hashtagg/shared/infrastructure/services/api_auth_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hashtagg/shared/infrastructure/services/auth_cleanup_service.dart';
import 'package:hive/hive.dart';
import 'package:hashtagg/features/chats/chat_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

// presentation/bloc/auth/auth_event.dart
abstract class AuthEvent {}

class LoginRequested extends AuthEvent {
  final String email;
  final String password;
  LoginRequested(this.email, this.password);
}

class OAuthLoginRequested extends AuthEvent {
  final String provider;
  final String code;
  final String? codeVerifier;

  OAuthLoginRequested({
    required this.provider,
    required this.code,
    this.codeVerifier,
  });
}

class OAuthCallbackReceived extends AuthEvent {
  final String token;
  final int userId;

  OAuthCallbackReceived({required this.token, required this.userId});
}

class OAuthCallbackError extends AuthEvent {
  final String error;

  OAuthCallbackError({required this.error});
}

class LogoutRequested extends AuthEvent {}

class AuthCheckRequested extends AuthEvent {}

class UserUpdated extends AuthEvent {
  final User user;
  UserUpdated(this.user);
}

// presentation/bloc/auth/auth_state.dart
abstract class AuthState {
  User? get user;
}

class AuthInitial extends AuthState {
  @override
  final User? user;

  AuthInitial() : user = _loadUserFromHive();

  static User? _loadUserFromHive() {
    var box = Hive.box('user');
    var userData = box.get('user');

    if (kDebugMode) {
      debugPrint("auth initial $userData");
      debugPrint("🔗 [AuthInitial] Full userData keys: ${userData?.keys}");
      debugPrint(
        "🔗 [AuthInitial] referralLink from Hive: ${userData?['referralLink']}",
      );
      debugPrint(
        "🔗 [AuthInitial] Has referralLink key: ${userData?.containsKey('referralLink')}",
      );
    }

    if (userData != null) {
      // Безопасное преобразование activeServices
      List<String>? activeServices;
      if (userData['activeServices'] != null) {
        if (userData['activeServices'] is List) {
          activeServices = (userData['activeServices'] as List)
              .map((s) => s.toString())
              .toList();
        }
      }

      return User(
        id: userData['id'],
        name: userData['name'],
        last_name: userData['last_name'],
        surname: userData['surname'],
        phone: userData['phone'],
        email: userData['email'],
        avatar: userData['avatar'],
        status: userData['status'],
        token: userData['token'],
        shortname: userData['shortname'],
        isCompany: userData['isCompany'],
        companyName: userData['companyName'],
        safeDealEnabled: userData['safeDealEnabled'],
        ymoneyAccount: userData['ymoneyAccount'],
        bookingEnabled: userData['bookingEnabled'],
        cardNumber: userData['cardNumber'],
        showPhoneInListings: userData['showPhoneInListings'],
        walletBalance: userData['walletBalance'] ?? 0,
        tariffId: userData['tariffId'],
        activeServices: activeServices,
        referralLink: userData['referralLink'],
      );
    }
    return null;
  }
}

class AuthLoading extends AuthState {
  @override
  User? get user => null;
}

class Authenticated extends AuthState {
  @override
  final User user;

  Authenticated(this.user);
}

class Unauthenticated extends AuthState {
  @override
  User? get user => null;
}

// presentation/bloc/auth/auth_bloc.dart
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final LoginUseCase loginUseCase;
  final LogoutUsecase logoutUseCase;
  final GetCurrentUserUseCase getCurrentUserUseCase;

  AuthBloc({
    required this.loginUseCase,
    required this.logoutUseCase,
    required this.getCurrentUserUseCase,
  }) : super(AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<LoginRequested>(_onLoginRequested);
    on<OAuthLoginRequested>(_onOAuthLoginRequested);
    on<OAuthCallbackReceived>(_onOAuthCallbackReceived);
    on<OAuthCallbackError>(_onOAuthCallbackError);
    on<LogoutRequested>(_onLogoutRequested);
    on<UserUpdated>(_onUserUpdated);
  }

  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    // Загружаем пользователя из Hive
    final user = getCurrentUserUseCase.execute('123');

    if (user != null) {
      emit(Authenticated(user));

      // Асинхронно обновляем данные тарифа с сервера
      _updateTariffServices(user);
    } else {
      emit(Unauthenticated());
    }
  }

  /// Обновление данных тарифа пользователя в фоне
  Future<void> _updateTariffServices(User user) async {
    try {
      if (user.tariffId == null) return;

      final box = Hive.box('user');
      final token = box.get('auth_token');
      if (token == null) return;

      // Загружаем свежие данные профиля с API (включая activeServices)
      final authService = ApiAuthService();
      final updatedUser = await authService.getCurrentUserFromApi(
        token,
        user.id,
      );

      if (updatedUser != null && updatedUser.activeServices != null) {
        // Обновляем пользователя с новыми данными
        add(UserUpdated(updatedUser));

        if (kDebugMode) {
          debugPrint(
            '[AuthBloc] ✅ Обновлены сервисы тарифа: ${updatedUser.activeServices}',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AuthBloc] 🔴 Ошибка обновления сервисов тарифа: $e');
      }
    }
  }

  Future<void> _onLoginRequested(
    LoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      debugPrint('🔑 [AuthBloc] Начало логина для: ${event.email}');

      // ✅ ПРОВЕРЯЕМ ТЕКУЩЕЕ СОСТОЯНИЕ ПЕРЕД ОЧИСТКОЙ
      await AuthCleanupService.checkAuthStorage();

      // ✅ ПРИНУДИТЕЛЬНАЯ ОЧИСТКА ВСЕХ ДАННЫХ
      await AuthCleanupService.clearAllAuthData(logDetails: true);

      // ✅ ПРОВЕРЯЕМ ПОСЛЕ ОЧИСТКИ
      await AuthCleanupService.checkAuthStorage();

      final User? user = loginUseCase.execute(event.email, event.password);

      if (user != null) {
        debugPrint(
          '🔑 [AuthBloc] Пользователь получен: ID=${user.id}, email=${user.email}',
        );
        debugPrint('🔑 [AuthBloc] Новый токен: ${_maskToken(user.token!)}');

        // ✅ 2. СОХРАНЯЕМ НОВЫЕ ДАННЫЕ
        var box = Hive.box('user');
        await box.put('auth_token', user.token);
        await box.put('user', {
          'id': user.id,
          'name': user.name,
          'email': user.email,
          'phone': user.phone,
          'avatar': user.avatar,
          'status': user.status,
          'token': user.token,
          'last_name': user.last_name,
          'surname': user.surname,
          'shortname': user.shortname,
          'isCompany': user.isCompany,
          'companyName': user.companyName,
          'safeDealEnabled': user.safeDealEnabled,
          'ymoneyAccount': user.ymoneyAccount,
          'bookingEnabled': user.bookingEnabled,
          'cardNumber': user.cardNumber,
          'showPhoneInListings': user.showPhoneInListings,
          'walletBalance': user.walletBalance,
          'tariffId': user.tariffId,
          'activeServices': user.activeServices,
          'referralLink': user.referralLink,
        });
        await box.put('is_oauth', false);

        // Сохраняем в SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', user.token!);
        await prefs.setInt('user_id', user.id);
        await prefs.setBool('is_oauth', false);

        // ✅ ПРОВЕРЯЕМ ЧТО СОХРАНИЛОСЬ
        debugPrint('🔑 [AuthBloc] Проверка сохранения:');
        final savedToken = box.get('auth_token') as String?;
        final savedUserId = box.get('user')?['id'];
        debugPrint(
          '🔑 [AuthBloc]   - Сохраненный токен: ${savedToken != null ? _maskToken(savedToken) : '❌ НЕ СОХРАНИЛСЯ!'}',
        );
        debugPrint('🔑 [AuthBloc]   - Сохраненный user.id: $savedUserId');

        emit(Authenticated(user));
        debugPrint('🔑 [AuthBloc] ✅ Логин успешен для пользователя ${user.id}');
      } else {
        debugPrint('🔑 [AuthBloc] ❌ Пользователь не получен');
        emit(Unauthenticated());
      }
    } catch (e, stackTrace) {
      debugPrint('🔑 [AuthBloc] ❌ Ошибка логина: $e');
      debugPrint('🔑 [AuthBloc] 📚 StackTrace: $stackTrace');
      emit(Unauthenticated());
    }
  }

  String _maskToken(String token) {
    if (token.length < 10) return '***';
    return '${token.substring(0, 10)}...${token.substring(token.length - 6)}';
  }

  Future<void> _onOAuthLoginRequested(
    OAuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      if (kDebugMode) {
        debugPrint('🔐 [AuthBloc] OAuth login requested: ${event.provider}');
        debugPrint('🔐 [AuthBloc] Code: ${event.code.substring(0, 10)}...');
        debugPrint(
          '🔐 [AuthBloc] CodeVerifier: ${event.codeVerifier != null ? 'present' : 'null'}',
        );
      }

      // ✅ ПРОВЕРЯЕМ ТЕКУЩЕЕ СОСТОЯНИЕ ПЕРЕД ОЧИСТКОЙ
      await AuthCleanupService.checkAuthStorage();

      // ✅ ПРИНУДИТЕЛЬНАЯ ОЧИСТКА ВСЕХ ДАННЫХ
      await AuthCleanupService.clearAllAuthData(logDetails: true);

      // ✅ ПРОВЕРЯЕМ ПОСЛЕ ОЧИСТКИ
      await AuthCleanupService.checkAuthStorage();

      final authService = ApiAuthService();
      final (user, error) = await authService.loginWithOAuth(
        provider: event.provider,
        code: event.code,
        codeVerifier: event.codeVerifier,
      );

      if (user != null) {
        if (kDebugMode) {
          debugPrint(
            '🔐 [AuthBloc] ✅ OAuth user received: ID=${user.id}, email=${user.email}',
          );
          debugPrint('🔐 [AuthBloc] 🔑 New token: ${_maskToken(user.token!)}');
        }

        // ✅ СОХРАНЯЕМ НОВЫЕ ДАННЫЕ
        var box = Hive.box('user');

        // Сохраняем токен отдельно
        await box.put('auth_token', user.token);

        // Сохраняем пользователя
        await box.put('user', {
          'id': user.id,
          'name': user.name,
          'email': user.email,
          'phone': user.phone,
          'avatar': user.avatar,
          'status': user.status,
          'token': user.token,
          'last_name': user.last_name,
          'surname': user.surname,
          'shortname': user.shortname,
          'isCompany': user.isCompany,
          'companyName': user.companyName,
          'safeDealEnabled': user.safeDealEnabled,
          'ymoneyAccount': user.ymoneyAccount,
          'bookingEnabled': user.bookingEnabled,
          'cardNumber': user.cardNumber,
          'showPhoneInListings': user.showPhoneInListings,
          'walletBalance': user.walletBalance,
          'tariffId': user.tariffId,
          'activeServices': user.activeServices,
          'referralLink': user.referralLink,
        });
        await box.put('is_oauth', true);

        // Сохраняем в SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', user.token!);
        await prefs.setInt('user_id', user.id);
        await prefs.setBool('is_oauth', true);

        // ✅ ПРОВЕРЯЕМ ЧТО СОХРАНИЛОСЬ
        if (kDebugMode) {
          final savedToken = box.get('auth_token') as String?;
          final savedUser = box.get('user');
          debugPrint('🔐 [AuthBloc] 📦 Проверка сохранения в Hive:');
          debugPrint(
            '🔐 [AuthBloc]   - auth_token: ${savedToken != null ? _maskToken(savedToken) : '❌ НЕ СОХРАНИЛСЯ!'}',
          );
          debugPrint(
            '🔐 [AuthBloc]   - user.id: ${savedUser?['id'] ?? '❌ НЕ СОХРАНИЛСЯ!'}',
          );
          debugPrint('🔐 [AuthBloc]   - is_oauth: ${box.get('is_oauth')}');

          final prefsToken = prefs.getString('auth_token');
          final prefsUserId = prefs.getInt('user_id');
          debugPrint(
            '🔐 [AuthBloc] 💾 Проверка сохранения в SharedPreferences:',
          );
          debugPrint(
            '🔐 [AuthBloc]   - auth_token: ${prefsToken != null ? _maskToken(prefsToken) : '❌ НЕ СОХРАНИЛСЯ!'}',
          );
          debugPrint(
            '🔐 [AuthBloc]   - user_id: ${prefsUserId ?? '❌ НЕ СОХРАНИЛСЯ!'}',
          );
        }

        emit(Authenticated(user));

        if (kDebugMode) {
          debugPrint(
            '🔐 [AuthBloc] ✅ OAuth login successful for user ${user.id}: ${user.name}',
          );
        }
      } else {
        if (kDebugMode) {
          debugPrint('🔐 [AuthBloc] ❌ OAuth login failed: $error');
        }
        emit(Unauthenticated());
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('🔐 [AuthBloc] ❌ OAuth exception: $e');
        debugPrint('🔐 [AuthBloc] 📚 StackTrace: $stackTrace');
      }
      emit(Unauthenticated());
    }
  }

  Future<void> _onOAuthCallbackReceived(
    OAuthCallbackReceived event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      if (kDebugMode) {
        debugPrint('🔐 [AuthBloc] OAuth callback received:');
        debugPrint('🔐 [AuthBloc]   - token: ${_maskToken(event.token)}');
        debugPrint('🔐 [AuthBloc]   - userId: ${event.userId}');
      }

      // ✅ ПРОВЕРЯЕМ ТЕКУЩЕЕ СОСТОЯНИЕ ПЕРЕД ОЧИСТКОЙ
      await AuthCleanupService.checkAuthStorage();

      // ✅ ПРИНУДИТЕЛЬНАЯ ОЧИСТКА ВСЕХ ДАННЫХ
      await AuthCleanupService.clearAllAuthData(logDetails: true);

      // ✅ ПРОВЕРЯЕМ ПОСЛЕ ОЧИСТКИ
      await AuthCleanupService.checkAuthStorage();

      final authService = ApiAuthService();
      final (user, error) = await authService.loginWithToken(
        token: event.token,
        userId: event.userId,
      );

      if (user != null) {
        if (kDebugMode) {
          debugPrint(
            '🔐 [AuthBloc] ✅ OAuth callback user received: ID=${user.id}, email=${user.email}',
          );
          debugPrint('🔐 [AuthBloc] 🔑 New token: ${_maskToken(user.token!)}');
        }

        // ✅ СОХРАНЯЕМ НОВЫЕ ДАННЫЕ
        var box = Hive.box('user');

        // Сохраняем токен отдельно
        await box.put('auth_token', user.token);

        // Сохраняем пользователя
        await box.put('user', {
          'id': user.id,
          'name': user.name,
          'email': user.email,
          'phone': user.phone,
          'avatar': user.avatar,
          'status': user.status,
          'token': user.token,
          'last_name': user.last_name,
          'surname': user.surname,
          'shortname': user.shortname,
          'isCompany': user.isCompany,
          'companyName': user.companyName,
          'safeDealEnabled': user.safeDealEnabled,
          'ymoneyAccount': user.ymoneyAccount,
          'bookingEnabled': user.bookingEnabled,
          'cardNumber': user.cardNumber,
          'showPhoneInListings': user.showPhoneInListings,
          'walletBalance': user.walletBalance,
          'tariffId': user.tariffId,
          'activeServices': user.activeServices,
          'referralLink': user.referralLink,
        });

        // Для OAuth callback устанавливаем is_oauth = true
        await box.put('is_oauth', true);

        // Сохраняем в SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', user.token!);
        await prefs.setInt('user_id', user.id);
        await prefs.setBool('is_oauth', true);

        // ✅ ПРОВЕРЯЕМ ЧТО СОХРАНИЛОСЬ
        if (kDebugMode) {
          final savedToken = box.get('auth_token') as String?;
          final savedUser = box.get('user');
          debugPrint('🔐 [AuthBloc] 📦 Проверка сохранения в Hive:');
          debugPrint(
            '🔐 [AuthBloc]   - auth_token: ${savedToken != null ? _maskToken(savedToken) : '❌ НЕ СОХРАНИЛСЯ!'}',
          );
          debugPrint(
            '🔐 [AuthBloc]   - user.id: ${savedUser?['id'] ?? '❌ НЕ СОХРАНИЛСЯ!'}',
          );
          debugPrint('🔐 [AuthBloc]   - is_oauth: ${box.get('is_oauth')}');

          final prefsToken = prefs.getString('auth_token');
          final prefsUserId = prefs.getInt('user_id');
          debugPrint(
            '🔐 [AuthBloc] 💾 Проверка сохранения в SharedPreferences:',
          );
          debugPrint(
            '🔐 [AuthBloc]   - auth_token: ${prefsToken != null ? _maskToken(prefsToken) : '❌ НЕ СОХРАНИЛСЯ!'}',
          );
          debugPrint(
            '🔐 [AuthBloc]   - user_id: ${prefsUserId ?? '❌ НЕ СОХРАНИЛСЯ!'}',
          );
        }

        emit(Authenticated(user));

        if (kDebugMode) {
          debugPrint(
            '🔐 [AuthBloc] ✅ OAuth callback successful for user ${user.id}: ${user.name}',
          );
        }
      } else {
        if (kDebugMode) {
          debugPrint('🔐 [AuthBloc] ❌ OAuth callback failed: $error');
        }
        emit(Unauthenticated());
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('🔐 [AuthBloc] ❌ OAuth callback exception: $e');
        debugPrint('🔐 [AuthBloc] 📚 StackTrace: $stackTrace');
      }
      emit(Unauthenticated());
    }
  }

  Future<void> _onOAuthCallbackError(
    OAuthCallbackError event,
    Emitter<AuthState> emit,
  ) async {
    if (kDebugMode) {
      debugPrint('[AuthBloc] ❌ OAuth callback error: ${event.error}');
    }
    emit(Unauthenticated());
  }

  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    logoutUseCase.execute();
    await ChatStorageService().clearAll();
    emit(Unauthenticated());
  }

  void _onUserUpdated(UserUpdated event, Emitter<AuthState> emit) {
    // Сохраняем обновленные данные в Hive
    var box = Hive.box('user');

    // Сохраняем токен авторизации (если он есть)
    if (event.user.token != null) {
      box.put('auth_token', event.user.token);
      if (kDebugMode) {
        debugPrint(
          '🔑 [UserUpdated] Saved auth_token to Hive: ${event.user.token!.substring(0, 10)}...${event.user.token!.substring(event.user.token!.length - 4)}',
        );
      }
    } else {
      if (kDebugMode) {
        debugPrint('⚠️ [UserUpdated] No token in user object!');
      }
    }

    box.put('user', {
      'name': event.user.name,
      'email': event.user.email,
      'phone': event.user.phone,
      'avatar': event.user.avatar,
      'status': event.user.status,
      'token': event.user.token,
      'id': event.user.id,
      'last_name': event.user.last_name,
      'surname': event.user.surname,
      'shortname': event.user.shortname,
      'isCompany': event.user.isCompany,
      'companyName': event.user.companyName,
      'safeDealEnabled': event.user.safeDealEnabled,
      'ymoneyAccount': event.user.ymoneyAccount,
      'bookingEnabled': event.user.bookingEnabled,
      'cardNumber': event.user.cardNumber,
      'showPhoneInListings': event.user.showPhoneInListings,
      'walletBalance': event.user.walletBalance,
      'tariffId': event.user.tariffId,
      'activeServices': event.user.activeServices,
      'referralLink': event.user.referralLink,
    });

    emit(Authenticated(event.user));

    if (kDebugMode) {
      debugPrint(
        "UserUpdated: ${event.user.name}, tariffId: ${event.user.tariffId}, activeServices: ${event.user.activeServices}",
      );
      debugPrint(
        "🔗 [UserUpdated] Saved referralLink: ${event.user.referralLink}",
      );

      // Проверяем, что токен действительно сохранился
      final savedToken = box.get('auth_token');
      debugPrint(
        "🔍 [UserUpdated] Verification - token in Hive: ${savedToken != null ? (savedToken as String).substring(0, 10) + '...' : 'NULL'}",
      );
    }
  }
}

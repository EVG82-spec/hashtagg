import 'package:flutter/foundation.dart';
import 'package:hashtagg/shared/domain/entities/user.dart';
import 'package:hashtagg/shared/domain/services/auth_service.dart';
import 'package:hashtagg/core/network/auth_api_repository.dart';
import 'package:hashtagg/core/network/dio_client.dart';
import 'package:hashtagg/core/network/api_config.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';

/// Реализация AuthService для работы с реальным API
class ApiAuthService implements AuthService {
  late AuthApiRepository _apiRepository;

  ApiAuthService() {
    _apiRepository = AuthApiRepository(DioClient.createDio());
  }
  
  /// Пересоздание репозитория (используется после logout)
  void _refreshRepository() {
    if (kDebugMode) {
      debugPrint('[ApiAuthService] 🔄 Refreshing API repository...');
    }
    _apiRepository = AuthApiRepository(DioClient.createDio());
  }

  @override
  User? login(String login, String password) {
    throw UnimplementedError('Используйте async метод loginAsync');
  }

  /// Асинхронная авторизация через API
  Future<User?> loginAsync(String login, String password) async {
    try {
      final result = await _apiRepository.login(
        login: login,
        password: password,
      );

      if (result.success && result.data != null) {
        final token = result.data!['token'];
        // user_id может прийти как String или int
        final userId = result.data!['user_id'] is String
            ? int.parse(result.data!['user_id'])
            : result.data!['user_id'] as int;

        // Получаем данные пользователя
        final user = await getCurrentUserFromApi(token, userId);

        if (user != null) {
          // Сохраняем токен и данные пользователя
          await _saveAuthData(token, user);
          return user;
        }
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ApiAuthService] Ошибка при авторизации: $e');
      }
      return null;
    }
  }

  /// Получение ошибки после последней попытки авторизации
  String? lastError;

  /// Асинхронная авторизация через API с возвратом ошибки
  Future<(User?, String?)> loginWithErrors(String login, String password) async {
    try {
      lastError = null;

      final result = await _apiRepository.login(
        login: login,
        password: password,
      );

      if (result.success && result.data != null) {
        final token = result.data!['token'];
        // user_id может прийти как String или int
        final userId = result.data!['user_id'] is String
            ? int.parse(result.data!['user_id'])
            : result.data!['user_id'] as int;

        // Получаем данные пользователя
        final user = await getCurrentUserFromApi(token, userId);

        if (user != null) {
          // Сохраняем токен и данные пользователя
          await _saveAuthData(token, user);
          return (user, null);
        } else {
          lastError = 'Не удалось получить данные пользователя';
          return (null, lastError);
        }
      } else {
        lastError = result.error ?? 'Неизвестная ошибка';
        return (null, lastError);
      }
    } catch (e) {
      lastError = 'Ошибка сети: $e';
      if (kDebugMode) {
        debugPrint('[ApiAuthService] Ошибка при авторизации: $e');
      }
      return (null, lastError);
    }
  }

  @override
  bool logout() {
    if (kDebugMode) {
      debugPrint('[ApiAuthService] 🚪 ===== LOGOUT STARTED =====');
    }
    
    try {
      var box = Hive.box('user');
      
      if (kDebugMode) {
        debugPrint('[ApiAuthService] 🔍 BEFORE logout - is_oauth: ${box.get('is_oauth')}');
      }
      
      final token = box.get('auth_token');
      final userData = box.get('user');
      
      if (kDebugMode) {
        debugPrint('[ApiAuthService] 🚪 Logout - current token: ${token != null ? (token as String).substring(0, 10) + '...' : 'NULL'}');
      }
      
      // ВАЖНО: Сначала устанавливаем is_oauth = false ПЕРЕД очисткой
      box.put('is_oauth', false);
      
      if (kDebugMode) {
        debugPrint('[ApiAuthService] 🔐 OAuth mode reset to false BEFORE clear');
        debugPrint('[ApiAuthService] 🔍 AFTER setting false - is_oauth: ${box.get('is_oauth')}');
      }
      
      // Если есть токен и userId, вызываем API logout
      if (token != null && userData != null && userData['id'] != null) {
        _apiRepository.logout(
          token: token,
          userId: userData['id'],
        ).then((result) {
          if (kDebugMode) {
            if (result.success) {
              debugPrint('[ApiAuthService] Logout API успешно');
            } else {
              debugPrint('[ApiAuthService] Logout API ошибка: ${result.error}');
            }
          }
        }).catchError((e) {
          if (kDebugMode) {
            debugPrint('[ApiAuthService] Logout API exception: $e');
          }
        });
      }
      
      // Очищаем данные пользователя, но НЕ is_oauth
      box.delete('user');
      box.delete('auth_token');
      
      if (kDebugMode) {
        debugPrint('[ApiAuthService] 🗑️ Deleted user and auth_token');
        debugPrint('[ApiAuthService] 🔍 AFTER delete - is_oauth: ${box.get('is_oauth')}');
      }
      
      // Пересоздаём репозиторий с новым baseUrl
      _refreshRepository();
      
      if (kDebugMode) {
        debugPrint('[ApiAuthService] 🔄 Repository refreshed');
        debugPrint('[ApiAuthService] Пользователь вышел из системы, данные очищены');
        
        // Проверяем, что токен действительно удален и is_oauth = false
        final checkToken = box.get('auth_token');
        final checkOAuth = box.get('is_oauth');
        debugPrint('[ApiAuthService] 🔍 FINAL Verification - token: ${checkToken != null ? 'STILL EXISTS!' : 'NULL (OK)'}');
        debugPrint('[ApiAuthService] 🔍 FINAL Verification - is_oauth: $checkOAuth');
        debugPrint('[ApiAuthService] 🚪 ===== LOGOUT COMPLETED =====');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ApiAuthService] Ошибка при выходе: $e');
      }
      return false;
    }
  }

  @override
  User? getCurrentUser(String token) {
    // Для обратной совместимости
    return _loadUserFromHive();
  }

  /// Получение текущего пользователя по токену
  Future<User?> getCurrentUserAsync(String token) async {
    try {
      final result = await _apiRepository.authToken(token: token);
      
      if (result.success) {
        // Получаем userId из Hive
        final box = await Hive.openBox('user');
        final userData = box.get('user');
        
        if (userData is Map && userData['id'] != null) {
          final userId = userData['id'] is int 
              ? userData['id'] as int
              : int.parse(userData['id'].toString());
          
          // Обновляем полные данные профиля с сервера
          if (kDebugMode) {
            debugPrint('[ApiAuthService] 🔄 Updating profile data from server...');
          }
          
          final profile = await getCurrentUserFromApi(token, userId);
          if (profile != null) {
            // Сохраняем обновленные данные
            await _saveAuthData(token, profile);
            
            if (kDebugMode) {
              debugPrint('[ApiAuthService] ✅ Profile data updated from server');
            }
            
            return profile;
          }
        }
        
        // Если не удалось обновить, возвращаем данные из Hive
        return _loadUserFromHive();
      }
      
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ApiAuthService] Ошибка при проверке токена: $e');
      }
      return null;
    }
  }

  /// Восстановление пароля
  Future<(bool, String?)> recovery(String login) async {
    try {
      final result = await _apiRepository.recovery(login: login);
      
      if (result.success) {
        return (true, null);
      } else {
        return (false, result.error);
      }
    } catch (e) {
      return (false, 'Ошибка сети: $e');
    }
  }

  /// Регистрация нового пользователя
  Future<(User?, String?)> register({
    required String email,
    required String password,
    required String name,
    String? phone,
  }) async {
    try {
      final result = await _apiRepository.register(
        email: email,
        password: password,
        name: name,
        phone: phone,
      );

      if (result.success && result.data != null) {
        final token = result.data!['token'];
        final userId = result.data!['user_id'];

        final user = User(
          id: userId,
          name: name,
          email: email,
          phone: phone,
        );

        await _saveAuthData(token, user);
        return (user, null);
      } else {
        return (null, result.error);
      }
    } catch (e) {
      return (null, 'Ошибка сети: $e');
    }
  }

  /// Получение данных пользователя с API (публичный метод)
  Future<User?> getCurrentUserFromApi(String token, int userId) async {
    try {
      final result = await _apiRepository.getProfileData(
        userId: userId,
        token: token,
      );

      if (result.success && result.data != null) {
        final data = result.data!;
        
        // Парсим баланс как число
        int walletBalance = 0;
        if (data['balance'] != null) {
          final balanceStr = data['balance'].toString().replaceAll(' ', '').replaceAll(',', '.');
          walletBalance = (double.tryParse(balanceStr) ?? 0).toInt();
        }

        // Парсим tariffId как int
        int? tariffId;
        if (data['tariff_id'] != null) {
          tariffId = int.tryParse(data['tariff_id'].toString());
        }

        // Загружаем активные сервисы тарифа
        List<String>? activeServices;
        if (tariffId != null) {
          activeServices = await _getActiveTariffServices(token, userId);
        }

        // Заменяем localhost на baseUrl из конфигурации
        String? avatar = data['avatar'];
        if (avatar != null && avatar.contains('localhost')) {
          // Извлекаем host:port из baseUrl (например, '192.168.1.3:8000')
          final baseUrlHost = ApiConfig.baseUrl.replaceFirst('http://', '').replaceFirst('https://', '');
          // Заменяем localhost:port или localhost на baseUrl host
          avatar = avatar.replaceAll(RegExp(r'localhost(:\d+)?'), baseUrlHost);
        }
        
        // Получаем реферальную ссылку
        String? referralLink;
        if (data['ref'] != null && data['ref']['link'] != null) {
          referralLink = data['ref']['link'].toString();
          if (kDebugMode) {
            debugPrint('[ApiAuthService] 🔗 Referral link from API: $referralLink');
          }
        } else {
          if (kDebugMode) {
            debugPrint('[ApiAuthService] ⚠️ No referral link in API response');
          }
        }

        return User(
          id: userId,
          name: data['name'] ?? '',
          surname: data['middlename'],
          last_name: data['surname'],
          shortname: data['nicname'],
          email: data['email'],
          phone: data['phone'],
          avatar: avatar,
          status: data['note_status']?.toString(), // Используем note_status вместо status
          token: token, // Добавляем токен в объект User
          isCompany: data['type_person'] == 'company',
          companyName: data['name_company'],
          safeDealEnabled: data['secure_status'] ?? false,
          bookingEnabled: data['delivery_status'] ?? false,
          walletBalance: walletBalance,
          tariffId: tariffId,
          activeServices: activeServices,
          referralLink: referralLink,
        );
      }
      
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ApiAuthService] Ошибка получения профиля: $e');
      }
      return null;
    }
  }

  /// Получение активных сервисов тарифа пользователя
  Future<List<String>?> _getActiveTariffServices(String token, int userId) async {
    try {
      if (kDebugMode) {
        debugPrint('[ApiAuthService] 🔵 Загрузка активных сервисов тарифа для userId: $userId');
      }
      
      final dio = DioClient.createDio();
      final response = await dio.get(
        '/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'profile/tariff/getData',
          'id_user': userId,
          'token': token,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data is String
            ? json.decode(response.data)
            : response.data;

        if (kDebugMode) {
          debugPrint('[ApiAuthService] 📥 Ответ тарифов: $data');
        }

        if (data is List && data.isNotEmpty) {
          // Ищем активный тариф (is_active: true)
          final activeTariff = data.firstWhere(
            (tariff) => tariff['is_active'] == true,
            orElse: () => null,
          );

          if (kDebugMode) {
            debugPrint('[ApiAuthService] 🔍 Активный тариф: $activeTariff');
          }

          if (activeTariff != null && activeTariff['active_services'] != null) {
            final services = activeTariff['active_services'];
            if (services is List) {
              final servicesList = services.map((s) => s.toString()).toList();
              if (kDebugMode) {
                debugPrint('[ApiAuthService] ✅ Активные сервисы: $servicesList');
              }
              return servicesList;
            }
          } else {
            if (kDebugMode) {
              debugPrint('[ApiAuthService] ⚠️ Активный тариф не найден или нет сервисов');
            }
          }
        } else {
          if (kDebugMode) {
            debugPrint('[ApiAuthService] ⚠️ Пустой ответ или не список');
          }
        }
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ApiAuthService] 🔴 Ошибка получения сервисов тарифа: $e');
      }
      return null;
    }
  }

  /// Сохранение данных авторизации в Hive
  Future<void> _saveAuthData(String token, User user, {bool isOAuth = false}) async {
    var box = Hive.box('user');
    await box.put('auth_token', token);
    await box.put('is_oauth', isOAuth); // Флаг OAuth авторизации
    
    if (kDebugMode) {
      debugPrint('[ApiAuthService] 🔑 Saving auth_token to Hive: ${token.substring(0, 10)}...${token.substring(token.length - 4)}');
      debugPrint('[ApiAuthService] 🔐 OAuth mode: $isOAuth');
    }
    
    await box.put('user', {
      'id': user.id,
      'name': user.name,
      'email': user.email,
      'phone': user.phone,
      'avatar': user.avatar,
      'status': user.status,
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
    
    if (kDebugMode) {
      debugPrint('[ApiAuthService] Данные авторизации сохранены');
      debugPrint('[ApiAuthService] 🔗 Saved referralLink: ${user.referralLink}');
      
      // Проверяем, что токен действительно сохранился
      final savedToken = box.get('auth_token');
      debugPrint('[ApiAuthService] 🔍 Verification - token in Hive: ${savedToken != null ? (savedToken as String).substring(0, 10) + '...' : 'NULL'}');
    }
  }

  /// Загрузка данных пользователя из Hive
  User? _loadUserFromHive() {
    var box = Hive.box('user');
    var userData = box.get('user');

    if (kDebugMode) {
      debugPrint('[ApiAuthService] 📦 Loading user from Hive...');
      debugPrint('[ApiAuthService] 🔗 referralLink in Hive: ${userData?['referralLink']}');
    }

    if (userData != null) {
      // Безопасное преобразование id
      final userId = userData['id'] is int 
          ? userData['id'] as int
          : int.parse(userData['id'].toString());
      
      // Безопасное преобразование walletBalance
      final walletBalance = userData['walletBalance'] is int
          ? userData['walletBalance'] as int
          : (userData['walletBalance'] != null ? int.parse(userData['walletBalance'].toString()) : 0);
      
      // Безопасное преобразование tariffId
      final tariffId = userData['tariffId'] == null
          ? null
          : (userData['tariffId'] is int 
              ? userData['tariffId'] as int
              : int.parse(userData['tariffId'].toString()));
      
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
        id: userId,
        name: userData['name'],
        last_name: userData['last_name'],
        surname: userData['surname'],
        phone: userData['phone'],
        email: userData['email'],
        avatar: userData['avatar'],
        status: userData['status'],
        shortname: userData['shortname'],
        isCompany: userData['isCompany'],
        companyName: userData['companyName'],
        safeDealEnabled: userData['safeDealEnabled'],
        ymoneyAccount: userData['ymoneyAccount'],
        bookingEnabled: userData['bookingEnabled'],
        cardNumber: userData['cardNumber'],
        showPhoneInListings: userData['showPhoneInListings'],
        walletBalance: walletBalance,
        tariffId: tariffId,
        activeServices: activeServices,
        referralLink: userData['referralLink'],
      );
    }
    
    return null;
  }

  /// OAuth авторизация через социальные сети
  /// 
  /// Принимает authorization code и возвращает пользователя
  Future<(User?, String?)> loginWithOAuth({
    required String provider,
    required String code,
    String? codeVerifier,
  }) async {
    try {
      lastError = null;

      if (kDebugMode) {
        debugPrint('[ApiAuthService] 🔐 OAuth login with $provider');
      }

      final result = await _apiRepository.oauthLogin(
        provider: provider,
        code: code,
        codeVerifier: codeVerifier,
      );

      if (result.success && result.data != null) {
        final token = result.data!['token'];
        final userId = result.data!['user_id'] is String
            ? int.parse(result.data!['user_id'])
            : result.data!['user_id'] as int;

        // Получаем данные пользователя
        final user = await getCurrentUserFromApi(token, userId);

        if (user != null) {
          // Сохраняем токен и данные пользователя
          await _saveAuthData(token, user);
          
          if (kDebugMode) {
            debugPrint('[ApiAuthService] ✅ OAuth login successful');
          }
          
          return (user, null);
        } else {
          lastError = 'Не удалось получить данные пользователя';
          return (null, lastError);
        }
      } else {
        lastError = result.error ?? 'Ошибка OAuth авторизации';
        return (null, lastError);
      }
    } catch (e) {
      lastError = 'Ошибка сети: $e';
      if (kDebugMode) {
        debugPrint('[ApiAuthService] ❌ OAuth error: $e');
      }
      return (null, lastError);
    }
  }

  /// Авторизация по токену (для OAuth deep link callback)
  Future<(User?, String?)> loginWithToken({
    required String token,
    required int userId,
  }) async {
    try {
      lastError = null;

      if (kDebugMode) {
        debugPrint('[ApiAuthService] 🔐 Login with token: ${token.substring(0, 10)}...');
      }

      // Получаем данные пользователя через oauthUrl (т.к. OAuth происходит там)
      final user = await _getCurrentUserFromOAuthApi(token, userId);

      if (user != null) {
        // Сохраняем токен и данные пользователя с флагом OAuth
        await _saveAuthData(token, user, isOAuth: true);
        
        if (kDebugMode) {
          debugPrint('[ApiAuthService] ✅ Token login successful');
        }
        
        return (user, null);
      } else {
        lastError = 'Не удалось получить данные пользователя';
        return (null, lastError);
      }
    } catch (e) {
      lastError = 'Ошибка сети: $e';
      if (kDebugMode) {
        debugPrint('[ApiAuthService] ❌ Token login error: $e');
      }
      return (null, lastError);
    }
  }

  /// Получение данных пользователя с OAuth API (используется для OAuth авторизации)
  Future<User?> _getCurrentUserFromOAuthApi(String token, int userId) async {
    try {
      if (kDebugMode) {
        debugPrint('[ApiAuthService] 🔵 Getting user data from OAuth API: ${ApiConfig.oauthUrl}');
      }

      final dio = DioClient.createDio();
      final response = await dio.post(
        '${ApiConfig.oauthUrl}/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'profile/card/getData',
          'id_user': userId,
          'token': token,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data is String
            ? json.decode(response.data)
            : response.data;

        if (kDebugMode) {
          debugPrint('[ApiAuthService] ✅ OAuth API response received');
        }

        // Парсим баланс как число
        int walletBalance = 0;
        if (data['balance'] != null) {
          final balanceStr = data['balance'].toString().replaceAll(' ', '').replaceAll(',', '.');
          walletBalance = (double.tryParse(balanceStr) ?? 0).toInt();
        }

        // Парсим tariffId как int
        int? tariffId;
        if (data['tariff_id'] != null) {
          tariffId = int.tryParse(data['tariff_id'].toString());
        }

        // Загружаем активные сервисы тарифа
        List<String>? activeServices;
        if (tariffId != null) {
          activeServices = await _getActiveTariffServicesFromOAuth(token, userId);
        }

        // Заменяем localhost на oauthUrl из конфигурации
        String? avatar = data['avatar'];
        if (avatar != null && avatar.contains('localhost')) {
          final oauthUrlHost = ApiConfig.oauthUrl.replaceFirst('http://', '').replaceFirst('https://', '');
          avatar = avatar.replaceAll(RegExp(r'localhost(:\d+)?'), oauthUrlHost);
        }
        
        // Получаем реферальную ссылку
        String? referralLink;
        if (data['ref'] != null && data['ref']['link'] != null) {
          referralLink = data['ref']['link'].toString();
          if (kDebugMode) {
            debugPrint('[ApiAuthService] 🔗 Referral link from OAuth API: $referralLink');
          }
        }

        return User(
          id: userId,
          name: data['name'] ?? '',
          surname: data['middlename'],
          last_name: data['surname'],
          shortname: data['nicname'],
          email: data['email'],
          phone: data['phone'],
          avatar: avatar,
          status: data['note_status']?.toString(),
          token: token,
          isCompany: data['type_person'] == 'company',
          companyName: data['name_company'],
          safeDealEnabled: data['secure_status'] ?? false,
          bookingEnabled: data['delivery_status'] ?? false,
          walletBalance: walletBalance,
          tariffId: tariffId,
          activeServices: activeServices,
          referralLink: referralLink,
        );
      }
      
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ApiAuthService] ❌ Ошибка получения профиля из OAuth API: $e');
      }
      return null;
    }
  }

  /// Получение активных сервисов тарифа через OAuth API
  Future<List<String>?> _getActiveTariffServicesFromOAuth(String token, int userId) async {
    try {
      if (kDebugMode) {
        debugPrint('[ApiAuthService] 🔵 Загрузка активных сервисов тарифа из OAuth API для userId: $userId');
      }
      
      final dio = DioClient.createDio();
      final response = await dio.get(
        '${ApiConfig.oauthUrl}/systems/api/controller.php',
        queryParameters: {
          'key': ApiConfig.apiKey,
          'route': 'profile/tariff/getData',
          'id_user': userId,
          'token': token,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data is String
            ? json.decode(response.data)
            : response.data;

        if (data is List && data.isNotEmpty) {
          final activeTariff = data.firstWhere(
            (tariff) => tariff['is_active'] == true,
            orElse: () => null,
          );

          if (activeTariff != null && activeTariff['active_services'] != null) {
            final services = activeTariff['active_services'];
            if (services is List) {
              final servicesList = services.map((s) => s.toString()).toList();
              if (kDebugMode) {
                debugPrint('[ApiAuthService] ✅ Активные сервисы из OAuth API: $servicesList');
              }
              return servicesList;
            }
          }
        }
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ApiAuthService] 🔴 Ошибка получения сервисов тарифа из OAuth API: $e');
      }
      return null;
    }
  }
}

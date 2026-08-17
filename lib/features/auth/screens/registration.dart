import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:hashtagg/shared/presentation/bloc/auth_bloc.dart';
import 'package:hashtagg/shared/presentation/utils.dart';
import 'package:hashtagg/core/network/auth_api_repository.dart';
import 'package:hashtagg/core/network/dio_client.dart';
import 'package:hashtagg/shared/domain/entities/user.dart';
import 'package:hashtagg/shared/infrastructure/services/api_auth_service.dart';
import 'package:hashtagg/core/network/api_config.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  late final TextEditingController _loginController;
  late final TextEditingController _passwordController;
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late final AuthApiRepository _authApi;

  bool _isLoading = false;
  bool _showCodeInput = false;
  String _confirmationTitle = '';

  @override
  void initState() {
    super.initState();
    _loginController = TextEditingController();
    _passwordController = TextEditingController();
    _nameController = TextEditingController();
    _codeController = TextEditingController();
    _authApi = AuthApiRepository(DioClient.createDio());
  }

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendVerificationCode() async {
    final login = _loginController.text.trim();
    final name = _nameController.text.trim();
    final password = _passwordController.text.trim();

    if (login.isEmpty) {
      showSwipeDownNotification(context, message: 'Укажите email');
      return;
    }

    if (name.isEmpty) {
      showSwipeDownNotification(context, message: 'Укажите ваше имя');
      return;
    }

    if (password.isEmpty || password.length < 6) {
      showSwipeDownNotification(context, message: 'Пароль должен быть от 6 символов');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Очищаем старые коды
      await _authApi.clearVerificationCodes(login: login);

      // Отправляем код
      final result = await _authApi.sendVerificationCode(
        login: login,
        name: name,
        password: password,
      );

      if (mounted) {
        setState(() => _isLoading = false);

        if (result.success && result.data != null) {
          final needsConfirmation = result.data!['confirmation'] == true;
          
          if (needsConfirmation) {
            setState(() {
              _showCodeInput = true;
              _confirmationTitle = result.data!['confirmation_title'] ?? 'Введите код подтверждения';
            });
            showSwipeDownNotification(context, message: 'Код отправлен на $login');
          } else {
            // Регистрация без подтверждения
            _register();
          }
        } else {
          showSwipeDownNotification(context, message: result.error ?? 'Ошибка отправки кода');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showSwipeDownNotification(context, message: 'Ошибка: $e');
      }
    }
  }

  Future<void> _register() async {
    final login = _loginController.text.trim();
    final name = _nameController.text.trim();
    final password = _passwordController.text.trim();
    final code = _codeController.text.trim();

    if (_showCodeInput && code.isEmpty) {
      showSwipeDownNotification(context, message: 'Введите код подтверждения');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await _authApi.registerWithCode(
        login: login,
        name: name,
        password: password,
        verifyCode: code,
      );

      if (mounted) {
        setState(() => _isLoading = false);

        if (result.success && result.data != null) {
          final token = result.data!['token'];
          final userId = result.data!['user_id'];

          print('🔍 [Registration] Token: $token, UserId: $userId');

          // Загружаем полные данные профиля с сервера
          final profileResult = await _authApi.getProfileData(
            userId: userId,
            token: token,
          );

          if (profileResult.success && profileResult.data != null) {
            final profileData = profileResult.data!;
            
            // Заменяем localhost на 192.168.1.3 в avatar URL
            String? avatar = profileData['avatar'];
            if (avatar != null && avatar.contains('localhost')) {
              avatar = ApiConfig.replaceMediaUrl(avatar);
            }
            
            // Сохраняем токен и полные данные пользователя в Hive
            var box = Hive.box('user');
            box.put('auth_token', token);
            box.put('user_id', userId);
            
            // Сохраняем полный объект user
            box.put('user', {
              'id': userId,
              'name': profileData['name'] ?? name,
              'email': profileData['email'] ?? login,
              'phone': profileData['phone'],
              'avatar': avatar,
              'status': profileData['status'],
              'last_name': profileData['surname'],
              'surname': profileData['middlename'],
              'shortname': profileData['nicname'],
              'isCompany': profileData['type_person'] == 'company',
              'companyName': profileData['name_company'],
              'safeDealEnabled': profileData['secure_status'] ?? false,
              'bookingEnabled': profileData['delivery_status'] ?? false,
            });

            print('✅ [Registration] Profile data loaded and saved');
          } else {
            // Если не удалось загрузить профиль, сохраняем минимальные данные
            var box = Hive.box('user');
            box.put('auth_token', token);
            box.put('user_id', userId);
            box.put('user', {
              'id': userId,
              'name': name,
              'email': login,
            });
            print('⚠️ [Registration] Saved minimal user data');
          }

          showSwipeDownNotification(context, message: 'Регистрация успешна!');
          
          // Переходим на главный экран
          if (mounted) {
            context.go('/');
            
            // Создаем объект User и обновляем AuthBloc напрямую
            if (profileResult.success && profileResult.data != null) {
              final profileData = profileResult.data!;
              final authBloc = context.read<AuthBloc>();
              
              // Заменяем localhost на 192.168.1.3 в avatar URL
              String? avatar = profileData['avatar'];
              if (avatar != null && avatar.contains('localhost')) {
                avatar = ApiConfig.replaceMediaUrl(avatar);
              }
              
              // Парсим tariffId
              int? tariffId;
              if (profileData['tariff_id'] != null) {
                tariffId = int.tryParse(profileData['tariff_id'].toString());
              }
              
              // Загружаем активные сервисы тарифа
              List<String>? activeServices;
              if (tariffId != null) {
                try {
                  final authService = ApiAuthService();
                  final updatedUser = await authService.getCurrentUserFromApi(token, userId);
                  if (updatedUser != null) {
                    activeServices = updatedUser.activeServices;
                    print('✅ [Registration] Loaded active services: $activeServices');
                  }
                } catch (e) {
                  print('🔴 [Registration] Error loading tariff services: $e');
                }
              }
              
              // Создаем User объект из загруженных данных
              final user = User(
                id: userId,
                name: profileData['name'] ?? name,
                email: profileData['email'] ?? login,
                phone: profileData['phone'],
                avatar: avatar,
                status: profileData['status'],
                last_name: profileData['surname'],
                surname: profileData['middlename'],
                shortname: profileData['nicname'],
                isCompany: profileData['type_person'] == 'company',
                companyName: profileData['name_company'],
                safeDealEnabled: profileData['secure_status'] ?? false,
                bookingEnabled: profileData['delivery_status'] ?? false,
                tariffId: tariffId,
                activeServices: activeServices,
              );
              
              // Обновляем AuthBloc с новым пользователем
              authBloc.add(UserUpdated(user));
              print('✅ [Registration] AuthBloc updated with user: ${user.name}, activeServices: ${user.activeServices}');
            } else {
              // Если профиль не загрузился, просто запускаем проверку
              context.read<AuthBloc>().add(AuthCheckRequested());
            }
          }
        } else {
          showSwipeDownNotification(context, message: result.error ?? 'Ошибка регистрации');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showSwipeDownNotification(context, message: 'Ошибка: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark 
          ? const Color(0xff151e27) // Первостепенный цвет для экрана регистрации
          : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark 
            ? const Color(0xff151e27) 
            : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: isDark 
              ? const Color(0xff151e27) 
              : Colors.white,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.only(
              top: 60,
              right: 20,
              left: 20,
              bottom: 60,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Регистрация',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    fontSize: 22,
                    fontWeight: const FontWeight(600),
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 20),
                
                // Email/Phone
                TextField(
                  controller: _loginController,
                  enabled: !_showCodeInput && !_isLoading,
                  style: GoogleFonts.montserrat(
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: isDark 
                        ? const Color(0xff233040) 
                        : const Color(0xff917dfa).withValues(alpha: 0.325),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    hintText: 'Email',
                    hintStyle: GoogleFonts.montserrat(
                      color: isDark ? Colors.white54 : null,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Password
                TextField(
                  controller: _passwordController,
                  enabled: !_showCodeInput && !_isLoading,
                  obscureText: true,
                  style: GoogleFonts.montserrat(
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: isDark 
                        ? const Color(0xff233040) 
                        : const Color(0xff917dfa).withValues(alpha: 0.325),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    hintText: 'Пароль',
                    hintStyle: GoogleFonts.montserrat(
                      color: isDark ? Colors.white54 : null,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Name
                TextField(
                  controller: _nameController,
                  enabled: !_showCodeInput && !_isLoading,
                  style: GoogleFonts.montserrat(
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: isDark 
                        ? const Color(0xff233040) 
                        : const Color(0xff917dfa).withValues(alpha: 0.325),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    hintText: 'Имя',
                    hintStyle: GoogleFonts.montserrat(
                      color: isDark ? Colors.white54 : null,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                  ),
                ),

                // Code input (показывается после отправки кода)
                if (_showCodeInput) ...[
                  const SizedBox(height: 20),
                  Text(
                    _confirmationTitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : const Color(0xff666666),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _codeController,
                    enabled: !_isLoading,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      fontSize: 24,
                      fontWeight: const FontWeight(600),
                      letterSpacing: 8,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark 
                          ? const Color(0xff233040) 
                          : const Color(0xff917dfa).withValues(alpha: 0.325),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      hintText: '••••',
                      hintStyle: GoogleFonts.montserrat(
                        color: isDark ? Colors.white54 : null,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Main button
                ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : (_showCodeInput ? _register : _sendVerificationCode),
                  style: ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(
                      _isLoading ? Colors.grey : const Color(0xff917dfa),
                    ),
                    padding: const WidgetStatePropertyAll(
                      EdgeInsets.only(top: 16, bottom: 16),
                    ),
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          _showCodeInput ? 'Зарегистрироваться' : 'Продолжить',
                          style: GoogleFonts.montserrat(
                            color: const Color(0xffffffff),
                          ),
                        ),
                ),

                // Resend code button
                if (_showCodeInput) ...[
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _isLoading ? null : _sendVerificationCode,
                    child: Text(
                      'Отправить код повторно',
                      style: GoogleFonts.montserrat(
                        color: const Color(0xff917dfa),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 10),

                // Login button
                ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          Navigator.pop(context);
                          context.push('/login');
                        },
                  style: ButtonStyle(
                    backgroundColor: const WidgetStatePropertyAll(Color(0xffffffff)),
                    padding: const WidgetStatePropertyAll(
                      EdgeInsets.only(top: 16, bottom: 16),
                    ),
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: Color(0xff917dfa), width: 1),
                      ),
                    ),
                  ),
                  child: Text(
                    'Войти',
                    style: GoogleFonts.montserrat(color: const Color(0xff917dfa)),
                  ),
                ),

                const SizedBox(height: 15),

                // Terms
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: GoogleFonts.montserrat(
                      fontSize: 10,
                      color: isDark ? Colors.white70 : Colors.black,
                      fontWeight: const FontWeight(400),
                      decoration: TextDecoration.none,
                    ),
                    text: 'Регистрируясь в приложении, вы принимаете условия\n',
                    children: [
                      TextSpan(
                        text: 'пользовательского соглашения',
                        style: GoogleFonts.montserrat(color: const Color(0xff917dfa)),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => context.push('/user-agreement'),
                      ),
                      const TextSpan(text: ' и '),
                      TextSpan(
                        text: 'политики \n конфиденциальности',
                        style: GoogleFonts.montserrat(color: const Color(0xff917dfa)),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => context.push('/privacy-policy'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

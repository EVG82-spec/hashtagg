
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hashtagg/shared/presentation/bloc/auth_bloc.dart';
import 'package:hashtagg/shared/presentation/utils.dart';
import 'package:hashtagg/shared/infrastructure/services/api_auth_service.dart';
import 'package:hashtagg/core/services/oauth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final TextEditingController _loginController;
  late final TextEditingController _passwordController;
  
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;
  
  final _authService = ApiAuthService();
  final _oauthService = OAuthService();

  @override
  void initState() {
    super.initState();
    _loginController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark 
          ? const Color(0xff151e27) // Первостепенный цвет для экрана входа
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
          onPressed: () {
            context.pop();
          },
        ),
      ),
      body: ListView(
        children: [
          Padding(
            padding: EdgeInsetsGeometry.only(
              top: 60,
              right: 20,
              left: 20,
              bottom: 60,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Войти',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      fontSize: 22,
                      fontWeight: FontWeight(600),
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  SizedBox(height: 20),
                  TextFormField(
                    controller: _loginController,
                    enabled: !_isLoading,
                    style: GoogleFonts.montserrat(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark 
                          ? const Color(0xff233040) // Второстепенный цвет для инпутов
                          : const Color(0xff917dfa).withValues(alpha: 0.325),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      hintText: 'Email',
                      hintStyle: GoogleFonts.montserrat(
                        color: isDark ? Colors.white54 : null,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      errorText: _errorMessage != null && _loginController.text.isEmpty 
                          ? 'Введите логин' 
                          : null,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Введите логин';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 20),
                  TextFormField(
                    controller: _passwordController,
                    enabled: !_isLoading,
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
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      errorText: _errorMessage != null && _passwordController.text.isEmpty 
                          ? 'Введите пароль' 
                          : null,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Введите пароль';
                      }
                      if (value.length < 6) {
                        return 'Пароль должен быть не менее 6 символов';
                      }
                      return null;
                    },
                  ),

                  // Блок отображения ошибки от API
                  if (_errorMessage != null) ...[
                    SizedBox(height: 20),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.red.shade700,
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: GoogleFonts.montserrat(
                                fontSize: 13,
                                color: Colors.red.shade700,
                                fontWeight: FontWeight(500),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: _isLoading ? null : _onLogin,
                    style: ButtonStyle(
                      backgroundColor: WidgetStatePropertyAll(Color(0xff917dfa)),
                      padding: WidgetStatePropertyAll(
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
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            "Войти",
                            style: GoogleFonts.montserrat(color: Color(0xffffffff)),
                          ),
                  ),

                  SizedBox(height: 10),

                  GestureDetector(
                    child: Text(
                      'Забыли пароль?',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight(500),
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    onTap: _isLoading ? null : () {
                      context.pop();
                      context.push('/restore-password');
                    },
                  ),

                  SizedBox(height: 15),

                  // Разделитель "или через сервисы"
                  SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: Divider(color: isDark ? Colors.white24 : Colors.black26)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'или через сервисы',
                          style: GoogleFonts.montserrat(
                            fontSize: 13,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: isDark ? Colors.white24 : Colors.black26)),
                    ],
                  ),
                  SizedBox(height: 20),

                  // Кнопки OAuth
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Яндекс
                      _buildOAuthButton(
                        onTap: _onYandexLogin,
                        imageUrl: 'https://hashtagg.ru/public/media/others/media_social_yandex_61627.png',
                        label: 'Яндекс',
                      ),
                      SizedBox(width: 12),
                      
                      // VK
                      _buildOAuthButton(
                        onTap: _onVKLogin,
                        imageUrl: 'https://hashtagg.ru/public/media/others/media_social_vk_vkontakte_icon_124252.png',
                        label: 'VK',
                      ),
                      SizedBox(width: 12),
                      
                      // Apple
                      _buildOAuthButton(
                        onTap: _onAppleLogin,
                        isApple: true,
                        label: 'Apple',
                      ),
                    ],
                  ),

                  SizedBox(height: 20),

                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        color: isDark ? Colors.white70 : Colors.black,
                        fontWeight: FontWeight(400),
                        decoration: TextDecoration.none,
                      ),
                      text: 'Авторизуясь в приложении, вы принимаете условия\n',
                      children: [
                        TextSpan(
                          text: 'Пользовательского соглашения',
                          style: GoogleFonts.montserrat(color: Color(0xff917dfa)),
                          recognizer: TapGestureRecognizer()
                            ..onTap = _isLoading ? null : () {
                              context.push('/user-agreement');
                            },
                        ),
                        TextSpan(text: ' и '),
                        TextSpan(
                          text: 'политики \n конфиденциальности',
                          style: GoogleFonts.montserrat(color: Color(0xff917dfa)),
                          recognizer: TapGestureRecognizer()
                            ..onTap = _isLoading ? null : () {
                              context.push('/privacy-policy');
                            },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onLogin() async {
    // Сбрасываем предыдущую ошибку
    setState(() {
      _errorMessage = null;
    });

    // Валидация формы
    if (!_formKey.currentState!.validate()) {
      return;
    }

    var login = _loginController.text.trim();
    var password = _passwordController.text;

    setState(() {
      _isLoading = true;
    });

    try {
      // Вызов API авторизации
      final (user, error) = await _authService.loginWithErrors(login, password);

      if (user != null) {
        // Успешная авторизация
        if (mounted) {
          var state = context.read<AuthBloc>();
          state.add(UserUpdated(user));

          showSwipeDownNotification(context, message: 'Успешный вход');
          context.go('/profile');
        }
      } else {
        // Ошибка авторизации
        if (mounted) {
          setState(() {
            _errorMessage = error ?? 'Неверный логин или пароль';
          });
        }
      }
    } catch (e) {
      // Неожиданная ошибка
      if (mounted) {
        setState(() {
          _errorMessage = 'Ошибка подключения к серверу';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Виджет кнопки OAuth
  Widget _buildOAuthButton({
    required VoidCallback onTap,
    String? imageUrl,
    bool isApple = false,
    required String label,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isApple 
                ? (isDark ? Colors.black : Colors.black)
                : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border:  Border.all(
                    color: isDark ? Colors.white24 : Colors.black26,
                  )
          ),
          child: Center(
            child: isApple
                ? Icon(
                    Icons.apple,
                    color: Colors.white,
                    size: 28,
                  )
                : Image.network(
                    imageUrl!,
                    width: 32,
                    height: 32,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.error_outline,
                        color: Colors.grey,
                        size: 24,
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  /// Авторизация через Яндекс
  Future<void> _onYandexLogin() async {
    try {
      final result = await _oauthService.loginWithYandex();

      if (result == 'pending' && mounted) {
        // Браузер открыт, ждем callback через deep link
        showSwipeDownNotification(
          context, 
          message: 'Завершите авторизацию в браузере',
        );
      } else if (mounted) {
        showSwipeDownNotification(
          context, 
          message: 'Не удалось открыть браузер',
        );
      }
    } catch (e) {
      if (mounted) {
        showSwipeDownNotification(
          context, 
          message: 'Ошибка авторизации через Яндекс',
        );
      }
    }
  }

  /// Авторизация через VK
  Future<void> _onVKLogin() async {
    try {
      final result = await _oauthService.loginWithVK();

      if (result == 'pending' && mounted) {
        showSwipeDownNotification(
          context, 
          message: 'Завершите авторизацию в браузере',
        );
      } else if (mounted) {
        showSwipeDownNotification(
          context, 
          message: 'Не удалось открыть браузер',
        );
      }
    } catch (e) {
      if (mounted) {
        showSwipeDownNotification(
          context, 
          message: 'Ошибка авторизации через VK',
        );
      }
    }
  }

  /// Авторизация через Apple
  Future<void> _onAppleLogin() async {
    try {
      final result = await _oauthService.loginWithApple();

      if (result == 'pending' && mounted) {
        showSwipeDownNotification(
          context, 
          message: 'Завершите авторизацию в браузере',
        );
      } else if (mounted) {
        showSwipeDownNotification(
          context, 
          message: 'Не удалось открыть браузер',
        );
      }
    } catch (e) {
      if (mounted) {
        showSwipeDownNotification(
          context, 
          message: 'Ошибка авторизации через Apple',
        );
      }
    }
  }
}

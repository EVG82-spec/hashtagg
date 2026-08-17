import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hashtagg/shared/presentation/bloc/auth_bloc.dart';
import 'package:hashtagg/shared/presentation/utils.dart';
import 'package:hashtagg/core/network/auth_api_repository.dart';
import 'package:hashtagg/core/network/dio_client.dart';

class RestorePasswordScreen extends StatefulWidget {
  const RestorePasswordScreen({super.key});

  @override
  State<RestorePasswordScreen> createState() => _RestorePasswordScreen();
}

class _RestorePasswordScreen extends State<RestorePasswordScreen> {
  late final TextEditingController _loginController;
  late final AuthApiRepository _authApi;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loginController = TextEditingController();
    _authApi = AuthApiRepository(DioClient.createDio());
  }

  @override
  void dispose() {
    _loginController.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    final login = _loginController.text.trim();

    if (login.isEmpty) {
      showSwipeDownNotification(context, message: 'Укажите email');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await _authApi.recovery(login: login);

      if (mounted) {
        setState(() => _isLoading = false);

        if (result.success) {
          showSwipeDownNotification(
            context,
            message: 'Новый пароль отправлен на $login',
          );
          
          // Возвращаемся на экран входа
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              context.pop();
              context.push('/login');
            }
          });
        } else {
          showSwipeDownNotification(
            context,
            message: result.error ?? 'Ошибка восстановления пароля',
          );
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
      backgroundColor: isDark ? const Color(0xff151e27) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xff151e27) : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: isDark ? const Color(0xff151e27) : Colors.white,
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
                  'Восстановление пароля',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    fontSize: 22,
                    fontWeight: const FontWeight(600),
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Новый пароль будет отправлен на указанный email',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    color: const Color(0xff666666),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _loginController,
                  enabled: !_isLoading,
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

                ElevatedButton(
                  onPressed: _isLoading ? null : _restore,
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
                          "Восстановить",
                          style: GoogleFonts.montserrat(
                            color: const Color(0xffffffff),
                          ),
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

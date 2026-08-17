import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hashtagg/shared/presentation/bloc/auth_bloc.dart';
import 'package:hashtagg/shared/presentation/utils.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final TextEditingController _loginController;
  late final TextEditingController _passwordController;

  @override
  void initState() {
    var authBloc = context.read<AuthBloc>();

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
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
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
                  ),
                ),
                SizedBox(height: 20),
                TextField(
                  controller: _loginController,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Color(0xff917dfa).withValues(alpha: 0.325),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    hintText: 'Email',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                  ),
                ),
                SizedBox(height: 20),
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Color(0xff917dfa).withValues(alpha: 0.325),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    hintText: 'Пароль',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                  ),
                ),

                SizedBox(height: 20),

                ElevatedButton(
                  onPressed: () {
                    _onSave();
                  },
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
                  child: Text(
                    "Войти",
                    style: GoogleFonts.montserrat(color: Color(0xffffffff)),
                  ),
                ),

                SizedBox(height: 10),

                GestureDetector(
                  child: Text(
                    'Забыли пароль?',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(fontWeight: FontWeight(500)),
                  ),
                  onTap: () {
                    context.pop();
                    context.push('/restore-password');
                  },
                ),

                SizedBox(height: 15),

                RichText(
                  text: TextSpan(
                    style: DefaultTextStyle.of(context).style,
                    text: 'Авторизуясь в приложении, вы принимаете условия\n',
                    children: [
                      TextSpan(
                        text: 'Пользовательского соглашения',
                        style: GoogleFonts.montserrat(color: Color(0xff917dfa)),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            context.push('/user-agreement');
                          },
                      ),
                      TextSpan(text: ' и '),
                      TextSpan(
                        text: 'политики \n конфиденциальности',
                        style: GoogleFonts.montserrat(color: Color(0xff917dfa)),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            context.push('/privacy-policy');
                          },
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

  void _onSave() {
    var state = context.read<AuthBloc>();

    var login = _loginController.text;
    var password = _passwordController.text;

    state.add(LoginRequested('example@gmail.com', 'example_password'));

    showSwipeDownNotification(context, message: 'Успешный вход');
    context.push('/profile');
  }
}

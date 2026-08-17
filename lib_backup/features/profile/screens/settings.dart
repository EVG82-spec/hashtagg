import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hashtagg/shared/presentation/bloc/auth_bloc.dart';
import 'package:hashtagg/shared/presentation/utils.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hashtagg/core/network/profile_api_repository.dart';
import 'package:hashtagg/features/profile/bloc/profile_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:hashtagg/core/network/api_config.dart';
import 'package:hashtagg/core/services/permission_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _lastnameController;
  late final TextEditingController _surnameController;
  late final TextEditingController _shortnameController;
  late final TextEditingController _companyNameController;

  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _ymoneyController;
  late final TextEditingController _cardController;
  late final TextEditingController _currentPasswordController;
  late final TextEditingController _newPasswordController;
  late final TextEditingController _confirmPasswordController;

  late var phoneFormatter;

  bool _isCompany = false;
  bool _safeDealEnabled = false;
  bool _bookingEnabled = false;
  bool _showPhoneInListings = true;

  String? _phoneNumber;
  String? _email;
  
  // Для предпросмотра аватара
  File? _selectedAvatarFile;
  String? _selectedAvatarBase64;

  @override
  void initState() {
    super.initState();
    var authBloc = context.read<AuthBloc>();

    phoneFormatter = MaskTextInputFormatter(
      mask: '+7 (###) ###-##-##',
      filter: {"#": RegExp(r'[0-9]')},
      type: MaskAutoCompletionType.lazy,
    );

    _surnameController = TextEditingController();
    _lastnameController = TextEditingController();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _shortnameController = TextEditingController();
    _companyNameController = TextEditingController();
    _ymoneyController = TextEditingController();
    _cardController = TextEditingController();
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();

    // Загружаем данные из пользователя
    final user = authBloc.state.user;
    _nameController.text = user?.name ?? '';
    _lastnameController.text = user?.last_name ?? '';
    _surnameController.text = user?.surname ?? '';
    _shortnameController.text = user?.shortname ?? '';
    _companyNameController.text = user?.companyName ?? '';
    _ymoneyController.text = user?.ymoneyAccount ?? '';
    _cardController.text = user?.cardNumber ?? '';
    _phoneNumber = user?.phone;
    _email = user?.email;

    // Загружаем булевы значения
    _isCompany = user?.isCompany ?? false;
    _safeDealEnabled = user?.safeDealEnabled ?? false;
    _bookingEnabled = user?.bookingEnabled ?? false;
    _showPhoneInListings = user?.showPhoneInListings ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _lastnameController.dispose();
    _surnameController.dispose();
    _shortnameController.dispose();
    _companyNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _ymoneyController.dispose();
    _cardController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showPhoneModal() async {
    // Очищаем контроллер перед открытием
    _phoneController.clear();
    
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        // После построения виджета устанавливаем начальное значение
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_phoneController.text.isEmpty) {
            // Устанавливаем текст через маску
            _phoneController.value = phoneFormatter.updateMask(
              mask: '+7 (###) ###-##-##',
              filter: {"#": RegExp(r'[0-9]')},
            ).formatEditUpdate(
              TextEditingValue.empty,
              TextEditingValue(text: '7'),
            );
          }
        });
        
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Номер телефона',
                style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              TextField(
                controller: _phoneController,
                inputFormatters: [phoneFormatter],
                keyboardType: TextInputType.phone,
                autofocus: true,
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight(500),
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Color(0xff917dfa).withValues(alpha: 0.325),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  hintText: '+7 (___) ___-__-__',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                ),
              ),
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, _phoneController.text);
                  },
                  style: ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(Color(0xff917dfa)),
                    padding: WidgetStatePropertyAll(EdgeInsets.all(12)),
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  child: Text(
                    'Подтвердить',
                    style: GoogleFonts.montserrat(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    
    if (result != null && result.isNotEmpty) {
      await _savePhoneToServer(result);
    }
  }
  
  Future<void> _savePhoneToServer(String phone) async {
    // Показываем загрузку
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xff917dfa)),
      ),
    );
    
    try {
      final box = Hive.box('user');
      final token = box.get('auth_token') as String?;
      final userData = box.get('user') as Map?;
      
      if (token == null || userData == null) {
        throw Exception('Not authorized');
      }
      
      final userId = userData['id'] is int 
          ? userData['id'] as int
          : int.parse(userData['id'].toString());
      
      final profileApi = ProfileApiRepository();
      
      // Вызываем API для сохранения телефона
      final result = await profileApi.savePhone(
        userId: userId,
        token: token,
        phone: phone,
      );
      
      if (result['status'] == true) {
        // Проверяем нужна ли верификация по SMS
        final needsVerification = result['verify'] == true;
        
        if (!mounted) return;
        Navigator.pop(context); // Закрываем диалог загрузки
        
        if (needsVerification) {
          // Показываем диалог для ввода кода
          final verificationTitle = result['title'] ?? 'Укажите код из SMS';
          await _showPhoneVerificationDialog(phone, verificationTitle, userId, token);
        } else {
          // Телефон сохранен без верификации
          setState(() {
            _phoneNumber = phone;
          });
          
          // Обновляем userData в Hive
          final updatedUserData = Map<String, dynamic>.from(userData);
          updatedUserData['phone'] = phone;
          await box.put('user', updatedUserData);
          
          // Обновляем в AuthBloc
          var authBloc = context.read<AuthBloc>();
          var currentUser = authBloc.state.user;
          if (currentUser != null) {
            currentUser.phone = phone;
            authBloc.add(UserUpdated(currentUser));
          }
          
          print('✅ [Settings] Phone saved: $phone');
          
          showSwipeDownNotification(
            context,
            message: 'Номер телефона сохранен',
            duration: Duration(seconds: 2),
          );
        }
      } else {
        // Показываем ошибку от API
        if (!mounted) return;
        Navigator.pop(context);
        showSwipeDownNotification(
          context, 
          message: result['error'] ?? 'Ошибка сохранения телефона',
          duration: Duration(seconds: 2),
        );
      }
    } catch (e) {
      print('🔴 [Settings] Error saving phone: $e');
      if (mounted) {
        Navigator.pop(context);
        showSwipeDownNotification(
          context, 
          message: 'Ошибка сохранения телефона',
          duration: Duration(seconds: 2),
        );
      }
    }
  }
  
  Future<void> _showPhoneVerificationDialog(String phone, String title, int userId, String token) async {
    final codeController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          title,
          style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: codeController,
          keyboardType: TextInputType.number,
          maxLength: 4,
          autofocus: true,
          style: GoogleFonts.montserrat(fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Введите код',
            filled: true,
            fillColor: const Color(0xff917dfa).withValues(alpha: 0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Отмена',
              style: GoogleFonts.montserrat(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final code = codeController.text.trim();
              if (code.isEmpty) {
                showSwipeDownNotification(context, message: 'Введите код');
                return;
              }
              
              // Показываем загрузку
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(color: Color(0xff917dfa)),
                ),
              );
              
              try {
                final profileApi = ProfileApiRepository();
                final verifyResult = await profileApi.verifyPhone(
                  userId: userId,
                  token: token,
                  phone: phone,
                  code: code,
                );
                
                if (!mounted) return;
                Navigator.pop(context); // Закрываем загрузку
                
                if (verifyResult['status'] == true) {
                  setState(() {
                    _phoneNumber = phone;
                  });
                  
                  // Обновляем userData в Hive
                  final box = Hive.box('user');
                  final userData = box.get('user') as Map?;
                  if (userData != null) {
                    final updatedUserData = Map<String, dynamic>.from(userData);
                    updatedUserData['phone'] = phone;
                    await box.put('user', updatedUserData);
                  }
                  
                  // Обновляем в AuthBloc
                  var authBloc = context.read<AuthBloc>();
                  var currentUser = authBloc.state.user;
                  if (currentUser != null) {
                    currentUser.phone = phone;
                    authBloc.add(UserUpdated(currentUser));
                  }
                  
                  print('✅ [Settings] Phone verified and saved: $phone');
                  
                  Navigator.pop(context, true); // Закрываем диалог верификации
                  
                  showSwipeDownNotification(
                    context,
                    message: 'Телефон подтвержден',
                    duration: Duration(seconds: 2),
                  );
                } else {
                  showSwipeDownNotification(
                    context,
                    message: verifyResult['error'] ?? 'Ошибка верификации',
                    duration: Duration(seconds: 2),
                  );
                }
              } catch (e) {
                print('🔴 [Settings] Error verifying phone: $e');
                if (mounted) {
                  Navigator.pop(context);
                  showSwipeDownNotification(
                    context,
                    message: 'Ошибка верификации',
                    duration: Duration(seconds: 2),
                  );
                }
              }
            },
            style: ButtonStyle(
              backgroundColor: const WidgetStatePropertyAll(Color(0xff917dfa)),
            ),
            child: Text(
              'Подтвердить',
              style: GoogleFonts.montserrat(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    
    codeController.dispose();
  }

  void _showEmailModal() {
    final emailController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Электронная почта',
              style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            TextField(
              controller: emailController,
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight(500),
                fontSize: 15,
              ),
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                filled: true,
                fillColor: Color(0xff917dfa).withValues(alpha: 0.325),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                hintText: 'Введите email',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
              ),
            ),
            SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final email = emailController.text;
                  if (_validateEmail(email)) {
                    var authBloc = context.read<AuthBloc>();
                    var currentUser = authBloc.state.user;
                    if (currentUser != null) {
                      currentUser.email = email;
                      authBloc.add(UserUpdated(currentUser));
                    }
                    setState(() {
                      _email = email;
                    });
                    context.pop();
                    showSwipeDownNotification(
                      context,
                      message: 'Email успешно изменен',
                      duration: Duration(seconds: 2),
                    );
                  } else {
                    showSwipeDownNotification(
                      context,
                      message: 'Введите корректный email',
                      duration: Duration(seconds: 2),
                    );
                  }
                },
                style: ButtonStyle(
                  backgroundColor: WidgetStatePropertyAll(Color(0xff917dfa)),
                  padding: WidgetStatePropertyAll(EdgeInsets.all(12)),
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                child: Text(
                  'Подтвердить',
                  style: GoogleFonts.montserrat(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showYMoneyModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Укажите счет кошелька ЮMoney',
              style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            TextField(
              controller: _ymoneyController,
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight(500),
                fontSize: 15,
              ),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                filled: true,
                fillColor: Color(0xff917dfa).withValues(alpha: 0.325),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                hintText: 'Номер счета',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
              ),
            ),
            SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  var authBloc = context.read<AuthBloc>();
                  var currentUser = authBloc.state.user;
                  if (currentUser != null) {
                    currentUser.ymoneyAccount = _ymoneyController.text;
                    authBloc.add(UserUpdated(currentUser));
                  }
                  context.pop();
                  showSwipeDownNotification(
                    context,
                    message: 'Счет ЮMoney сохранен',
                    duration: Duration(seconds: 2),
                  );
                },
                style: ButtonStyle(
                  backgroundColor: WidgetStatePropertyAll(Color(0xff917dfa)),
                  padding: WidgetStatePropertyAll(EdgeInsets.all(12)),
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                child: Text(
                  'Сохранить',
                  style: GoogleFonts.montserrat(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCardModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Укажите номер банковской карты',
              style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            TextField(
              controller: _cardController,
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight(500),
                fontSize: 15,
              ),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                filled: true,
                fillColor: Color(0xff917dfa).withValues(alpha: 0.325),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                hintText: 'Номер карты',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
              ),
            ),
            SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  var authBloc = context.read<AuthBloc>();
                  var currentUser = authBloc.state.user;
                  if (currentUser != null) {
                    currentUser.cardNumber = _cardController.text;
                    authBloc.add(UserUpdated(currentUser));
                  }
                  context.pop();
                  showSwipeDownNotification(
                    context,
                    message: 'Карта успешно добавлена',
                    duration: Duration(seconds: 2),
                  );
                },
                style: ButtonStyle(
                  backgroundColor: WidgetStatePropertyAll(Color(0xff917dfa)),
                  padding: WidgetStatePropertyAll(EdgeInsets.all(12)),
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                child: Text(
                  'Сохранить',
                  style: GoogleFonts.montserrat(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPasswordModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) => BlocProvider.value(
        value: context.read<ProfileBloc>(),
        child: BlocListener<ProfileBloc, ProfileStateOld>(
          listener: (context, state) {
            if (state is PasswordChanged) {
              Navigator.of(context).pop();
              showSwipeDownNotification(
                context,
                message: 'Пароль успешно изменен',
                duration: Duration(seconds: 2),
              );
              _currentPasswordController.clear();
              _newPasswordController.clear();
              _confirmPasswordController.clear();
            } else if (state is ProfileError) {
              showSwipeDownNotification(
                context,
                message: state.message,
                duration: Duration(seconds: 2),
              );
            }
          },
          child: BlocBuilder<ProfileBloc, ProfileStateOld>(
            builder: (context, state) {
              final isLoading = state is ProfileLoading;
              
              return Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Смена пароля',
                      style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 20),
                    TextField(
                      controller: _currentPasswordController,
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight(500),
                        fontSize: 15,
                      ),
                      obscureText: true,
                      enabled: !isLoading,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Color(0xff917dfa).withValues(alpha: 0.325),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        hintText: 'Текущий пароль',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                      ),
                    ),
                    SizedBox(height: 15),
                    TextField(
                      controller: _newPasswordController,
                      obscureText: true,
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight(500),
                        fontSize: 15,
                      ),
                      enabled: !isLoading,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Color(0xff917dfa).withValues(alpha: 0.325),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        hintText: 'Новый пароль (минимум 6 символов)',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                      ),
                    ),
                    SizedBox(height: 15),
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight(500),
                        fontSize: 15,
                      ),
                      enabled: !isLoading,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Color(0xff917dfa).withValues(alpha: 0.325),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        hintText: 'Подтвердите новый пароль',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : () {
                          String? error = _validatePassword(
                            _currentPasswordController.text,
                            _newPasswordController.text,
                            _confirmPasswordController.text,
                          );

                          if (error != null) {
                            showSwipeDownNotification(
                              context,
                              message: error,
                              duration: Duration(seconds: 2),
                            );
                            return;
                          }

                          // Вызываем API через ProfileBloc
                          context.read<ProfileBloc>().add(
                            ChangePassword(
                              currentPassword: _currentPasswordController.text,
                              newPassword: _newPasswordController.text,
                            ),
                          );
                        },
                        style: ButtonStyle(
                          backgroundColor: WidgetStatePropertyAll(
                            isLoading ? Colors.grey : Color(0xff917dfa),
                          ),
                          padding: WidgetStatePropertyAll(EdgeInsets.all(12)),
                          shape: WidgetStatePropertyAll(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        child: isLoading
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                'Сохранить',
                                style: GoogleFonts.montserrat(color: Colors.white, fontSize: 16),
                              ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Подтверждение'),
        content: Text(
          'Вы действительно хотите удалить аккаунт? Восстановить его будет невозможно!',
        ),
        actions: [
          TextButton(
            onPressed: () {
              context.pop();
            },
            child: Text('Нет'),
          ),
          TextButton(
            onPressed: () {
              context.pop();
              showSwipeDownNotification(
                context,
                message: 'Аккаунт удален',
                duration: Duration(seconds: 2),
              );
            },
            child: Text('Да', style: GoogleFonts.montserrat(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadAvatar() async {
    final ImagePicker picker = ImagePicker();
    
    try {
      // Показываем выбор источника
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Выберите источник',
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 20),
              ListTile(
                leading: Icon(Icons.camera_alt, color: Color(0xff917dfa)),
                title: Text('Камера', style: GoogleFonts.montserrat()),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: Icon(Icons.photo_library, color: Color(0xff917dfa)),
                title: Text('Галерея', style: GoogleFonts.montserrat()),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );

      if (source == null) return;

      // Запрашиваем разрешения в зависимости от источника
      bool hasPermission = false;
      if (source == ImageSource.camera) {
        hasPermission = await PermissionService.requestCameraPermission(context);
      } else {
        hasPermission = await PermissionService.requestStoragePermission(context);
      }

      if (!hasPermission) {
        return;
      }

      // Выбираем изображение
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image == null) return;

      // Читаем файл и конвертируем в base64 для предпросмотра
      final file = File(image.path);
      final bytes = await file.readAsBytes();
      final base64String = base64Encode(bytes);

      // Сохраняем для предпросмотра
      setState(() {
        _selectedAvatarFile = file;
        _selectedAvatarBase64 = base64String;
      });

      if (mounted) {
        // showSwipeDownNotification(
        //   context,
        //   message: 'Фото выбрано. Нажмите "Сохранить" для применения',
        //   duration: Duration(seconds: 2),
        // );
      }
    } catch (e) {
      print('🔴 [Settings] Error picking avatar: $e');
      if (mounted) {
        showSwipeDownNotification(
          context,
          message: 'Ошибка выбора фото: ${e.toString()}',
          duration: Duration(seconds: 3),
        );
      }
    }
  }

  bool _validateEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  String? _validatePassword(
    String currentPassword,
    String newPassword,
    String confirmPassword,
  ) {
    if (currentPassword.isEmpty) {
      return 'Введите текущий пароль';
    }
    if (newPassword.isEmpty) {
      return 'Введите новый пароль';
    }
    if (newPassword.length < 6) {
      return 'Пароль должен содержать минимум 6 символов';
    }
    if (confirmPassword.isEmpty) {
      return 'Подтвердите новый пароль';
    }
    if (newPassword != confirmPassword) {
      return 'Пароли не совпадают';
    }
    if (currentPassword == newPassword) {
      return 'Новый пароль должен отличаться от текущего';
    }
    return null;
  }

  Widget _buildCustomToggle({
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: 50,
        height: 28,
        decoration: BoxDecoration(
          color: value 
              ? Color(0xff917dfa) 
              : (isDark ? const Color(0xff233040) : Color(0xffE0E0E0)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: AnimatedAlign(
          duration: Duration(milliseconds: 300),
          curve: Curves.bounceOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: EdgeInsets.all(2),
            width: value ? 24 : 20,
            height: value ? 24 : 20,
            decoration: BoxDecoration(
              color: value ? Colors.white : Color(0xff999999),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var authBloc = context.read<AuthBloc>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Theme.of(context).appBarTheme.backgroundColor,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
          onPressed: () => context.pop(),
        ),
        title: Text('Настройки', style: GoogleFonts.montserrat(color: isDark ? Colors.white : Colors.black)),
      ),
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 100),
            children: [
              // Аватар
              BlocBuilder<AuthBloc, AuthState>(
                builder: (context, state) {
                  final user = state.user;
                  String avatarUrl = user?.avatar ?? 'https://hashtagg.ru/media/others/no_avatar.png';
                  
                  // Заменяем localhost на 192.168.1.3:8000
                  avatarUrl = ApiConfig.replaceMediaUrl(avatarUrl);
                  
                  return GestureDetector(
                    onTap: _pickAndUploadAvatar,
                    child: Stack(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(1000),
                            image: _selectedAvatarFile != null
                                ? DecorationImage(
                                    image: FileImage(_selectedAvatarFile!),
                                    fit: BoxFit.cover,
                                  )
                                : DecorationImage(
                                    image: NetworkImage(avatarUrl),
                                    fit: BoxFit.cover,
                                  ),
                          ),
                        ),
                        Positioned(
                          bottom: 2,
                          left: 60,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(1000),
                              color: Color(0xff4CAF50),
                            ),
                            child: Icon(Icons.image, size: 14, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              SizedBox(height: 30),

              // Заголовок "Личные данные"
              Text(
                'Личные данные',
                style: GoogleFonts.montserrat(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),

              SizedBox(height: 20),

              // Свитч "Частное лицо" / "Компания"
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xff233040) : Color(0xffF5F5F5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _isCompany = false;
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !_isCompany
                                ? Color(0xff917dfa)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            'Частное лицо',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.montserrat(
                              color: !_isCompany
                                  ? Colors.white
                                  : (isDark ? Colors.grey[400] : Colors.black54),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _isCompany = true;
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _isCompany
                                ? Color(0xff917dfa)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            'Компания',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.montserrat(
                              color: _isCompany 
                                  ? Colors.white 
                                  : (isDark ? Colors.grey[400] : Colors.black54),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20),

              // Название компании (если выбрано)
              if (_isCompany) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Название компании',
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xff666666),
                      ),
                    ),
                    SizedBox(height: 5),
                    TextField(
                      controller: _companyNameController,
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight(500),
                        fontSize: 15,
                        height: 1.0,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        hintStyle: GoogleFonts.montserrat(
                          fontWeight: FontWeight(500),
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                        fillColor: isDark ? const Color(0xff233040) : Color(0xff917dfa).withValues(alpha: 0.325),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        hintText: '',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
              ],

              // Имя
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Имя',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xff666666),
                    ),
                  ),
                  SizedBox(height: 5),
                  TextField(
                    controller: _nameController,
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight(500),
                      fontSize: 15,
                      height: 1.0,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark ? const Color(0xff233040) : Color(0xff917dfa).withValues(alpha: 0.325),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      hintText: '',
                      hintStyle: GoogleFonts.montserrat(
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 20),

              // Фамилия
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Фамилия',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xff666666),
                    ),
                  ),
                  SizedBox(height: 5),
                  TextField(
                    controller: _lastnameController,
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight(500),
                      fontSize: 15,
                      height: 1.0,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark ? const Color(0xff233040) : Color(0xff917dfa).withValues(alpha: 0.325),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      hintText: '',
                      hintStyle: GoogleFonts.montserrat(
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 20),

              // Отчество
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Отчество',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xff666666),
                    ),
                  ),
                  SizedBox(height: 5),
                  TextField(
                    controller: _surnameController,
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight(500),
                      fontSize: 15,
                      height: 1.0,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark ? const Color(0xff233040) : Color(0xff917dfa).withValues(alpha: 0.325),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      hintText: '',
                      hintStyle: GoogleFonts.montserrat(
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 20),

              // Короткое имя
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Короткое имя',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xff666666),
                    ),
                  ),
                  SizedBox(height: 5),
                  TextField(
                    controller: _shortnameController,
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight(500),
                      fontSize: 15,
                      height: 1.0,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark ? const Color(0xff233040) : Color(0xff917dfa).withValues(alpha: 0.325),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      hintText: '',
                      hintStyle: GoogleFonts.montserrat(
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 20),

              // Номер телефона
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Номер телефона',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xff666666),
                    ),
                  ),
                  SizedBox(height: 5),
                  Container(
                    width: double.infinity,
                    child: IgnorePointer(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 20,
                        ),
                        decoration: BoxDecoration(
                          color: Color(0xff917dfa).withValues(alpha: 0.325),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _phoneNumber ??
                              'Укажите номер телефона, чтобы покупатели смогли с вами связываться',
                          style: GoogleFonts.montserrat(
                            color: _phoneNumber != null
                                ? (isDark ? Colors.white : Colors.black)
                                : (isDark ? Colors.white54 : Colors.black54),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _showPhoneModal,
                      style: ButtonStyle(
                        backgroundColor: WidgetStatePropertyAll(
                          isDark ? const Color(0xff233040) : Color(0xffffffff),
                        ),
                        padding: WidgetStatePropertyAll(EdgeInsets.all(12)),
                        shape: WidgetStatePropertyAll(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: isDark ? Colors.transparent : Color(0xff917dfa),
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                      child: Text(
                        'Добавить номер',
                        style: GoogleFonts.montserrat(
                          color: isDark ? Colors.white : Color(0xff917dfa),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 20),

              // Email
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Email',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xff666666),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    _email ?? authBloc.state.user?.email ?? 'example@mail.com',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _showEmailModal,
                      style: ButtonStyle(
                        backgroundColor: WidgetStatePropertyAll(
                          isDark ? const Color(0xff233040) : Color(0xffffffff),
                        ),
                        padding: WidgetStatePropertyAll(EdgeInsets.all(12)),
                        shape: WidgetStatePropertyAll(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: isDark ? Colors.transparent : Color(0xff917dfa),
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                      child: Text(
                        'Изменить email',
                        style: GoogleFonts.montserrat(
                          color: isDark ? Colors.white : Color(0xff917dfa),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 30),

              // Безопасная сделка
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Безопасная сделка',
                        style: GoogleFonts.montserrat(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      _buildCustomToggle(
                        value: _safeDealEnabled,
                        onChanged: (value) {
                          setState(() {
                            _safeDealEnabled = value;
                          });
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Color(0xff917dfa).withValues(alpha: 0.325),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Активируйте услугу, чтобы ваши товары были доступны для продажи по безопасной сделке с онлайн-оплатой',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        color: Colors.black87,
                        height: 1.25,
                      ),
                    ),
                  ),
                  if (_safeDealEnabled) ...[
                    SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _showYMoneyModal,
                        style: ButtonStyle(
                          backgroundColor: WidgetStatePropertyAll(
                            isDark ? const Color(0xff233040) : Color(0xffffffff),
                          ),
                          padding: WidgetStatePropertyAll(EdgeInsets.all(12)),
                          shape: WidgetStatePropertyAll(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                color: isDark ? Colors.transparent : Color(0xff917dfa),
                                width: 1,
                              ),
                            ),
                          ),
                        ),
                        child: Text(
                          'Добавить карту',
                          style: GoogleFonts.montserrat(
                            color: isDark ? Colors.white : Color(0xff917dfa),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              SizedBox(height: 30),

              // Бронирование/аренда
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Бронирование/аренда',
                        style: GoogleFonts.montserrat(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      _buildCustomToggle(
                        value: _bookingEnabled,
                        onChanged: (value) {
                          setState(() {
                            _bookingEnabled = value;
                          });
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Color(0xff917dfa).withValues(alpha: 0.325),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Добавьте номер банковской карты для приема онлайн-бронирования и аренды. Комиссия сервиса составляет до 12%',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        color: Colors.black87,
                        height: 1.25,
                      ),
                    ),
                  ),
                  if (_bookingEnabled) ...[
                    SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _showCardModal,
                        style: ButtonStyle(
                          backgroundColor: WidgetStatePropertyAll(
                            isDark ? const Color(0xff233040) : Color(0xffffffff),
                          ),
                          padding: WidgetStatePropertyAll(EdgeInsets.all(12)),
                          shape: WidgetStatePropertyAll(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                color: isDark ? Colors.transparent : Color(0xff917dfa),
                                width: 1,
                              ),
                            ),
                          ),
                        ),
                        child: Text(
                          'Добавить карту',
                          style: GoogleFonts.montserrat(
                            color: isDark ? Colors.white : Color(0xff917dfa),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              SizedBox(height: 30),

              // Общие настройки
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Общие настройки',
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Показывать мой телефон в\nобъявлениях',
                          style: GoogleFonts.montserrat(
                            fontSize: 15,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                      _buildCustomToggle(
                        value: _showPhoneInListings,
                        onChanged: (value) {
                          setState(() {
                            _showPhoneInListings = value;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),

              SizedBox(height: 30),

              // Изменить пароль
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _showPasswordModal,
                  style: ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(
                      isDark ? const Color(0xff233040) : Color(0xffffffff),
                    ),
                    padding: WidgetStatePropertyAll(EdgeInsets.all(12)),
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: isDark ? Colors.transparent : Color(0xff917dfa),
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                  child: Text(
                    'Изменить пароль',
                    style: GoogleFonts.montserrat(
                      color: isDark ? Colors.white : Color(0xff917dfa),
                    ),
                  ),
                ),
              ),

              SizedBox(height: 20),

              // Удалить аккаунт
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _showDeleteAccountDialog,
                  style: ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(Colors.red),
                    padding: WidgetStatePropertyAll(EdgeInsets.all(12)),
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  child: Text(
                    'Удалить аккаунт',
                    style: GoogleFonts.montserrat(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),

          // Кнопка Сохранить зафиксирована внизу
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: ElevatedButton(
              onPressed: () async {
                var authBloc = context.read<AuthBloc>();
                final name = _nameController.text;
                final last_name = _lastnameController.text;
                final surname = _surnameController.text;
                final shortname = _shortnameController.text;
                final companyName = _companyNameController.text;
                final ymoneyAccount = _ymoneyController.text;
                final cardNumber = _cardController.text;

                var currentUser = authBloc.state.user;
                if (currentUser == null) {
                  showSwipeDownNotification(
                    context,
                    message: 'Ошибка: пользователь не авторизован',
                    duration: Duration(seconds: 2),
                  );
                  return;
                }

                // Получаем токен
                var box = Hive.box('user');
                final token = box.get('auth_token');
                
                if (token == null) {
                  showSwipeDownNotification(
                    context,
                    message: 'Ошибка: токен не найден',
                    duration: Duration(seconds: 2),
                  );
                  return;
                }

                // Показываем индикатор загрузки
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => Center(
                    child: CircularProgressIndicator(
                      color: Color(0xff917dfa),
                    ),
                  ),
                );

                // Вызываем API
                final profileApi = ProfileApiRepository();
                
                // Если выбран новый аватар, сначала загружаем его
                String? avatarFileName;
                if (_selectedAvatarBase64 != null) {
                  print('🔵 [Settings] Uploading avatar via assets/save...');
                  
                  final uploadResult = await profileApi.uploadAvatarToTemp(
                    userId: currentUser.id,
                    token: token,
                    fileBase64: _selectedAvatarBase64!,
                  );

                  if (uploadResult['status'] == true) {
                    avatarFileName = uploadResult['data']['name'] as String;
                    print('✅ [Settings] Avatar uploaded: $avatarFileName');
                  } else {
                    // Закрываем индикатор загрузки
                    if (mounted) Navigator.pop(context);
                    
                    if (mounted) {
                      showSwipeDownNotification(
                        context,
                        message: 'Ошибка загрузки аватара: ${uploadResult['error']}',
                        duration: Duration(seconds: 2),
                      );
                    }
                    return;
                  }
                }
                
                final result = await profileApi.updateProfile(
                  token: token,
                  userId: currentUser.id,
                  name: name.isNotEmpty ? name : null,
                  surname: last_name.isNotEmpty ? last_name : null,
                  middleName: surname.isNotEmpty ? surname : null,
                  nicname: shortname.isNotEmpty ? shortname : null,
                  typePerson: _isCompany ? 'company' : 'user',
                  nameCompany: companyName.isNotEmpty ? companyName : null,
                  viewPhone: _showPhoneInListings ? 1 : 0,
                  secureStatus: _safeDealEnabled ? 1 : 0,
                  deliveryStatus: _bookingEnabled ? 1 : 0,
                  avatar: avatarFileName != null ? [{'name': avatarFileName}] : null,
                );

                // Закрываем индикатор загрузки
                if (mounted) Navigator.pop(context);

                if (result['status'] == true) {
                  // Если был загружен новый аватар, перезагружаем профиль
                  if (avatarFileName != null) {
                    final profileData = await profileApi.getProfile(
                      token: token,
                      userId: currentUser.id,
                    );

                    if (profileData['avatar'] != null) {
                      final newAvatarUrl = ApiConfig.replaceMediaUrl(
                        profileData['avatar'] as String
                      );
                      currentUser.avatar = newAvatarUrl;
                    }
                    
                    // Очищаем выбранный аватар
                    setState(() {
                      _selectedAvatarFile = null;
                      _selectedAvatarBase64 = null;
                    });
                  }
                  
                  // Обновляем локальные данные
                  currentUser.name = name;
                  currentUser.last_name = last_name;
                  currentUser.surname = surname;
                  currentUser.shortname = shortname;
                  currentUser.isCompany = _isCompany;
                  currentUser.companyName = companyName;
                  currentUser.safeDealEnabled = _safeDealEnabled;
                  currentUser.ymoneyAccount = ymoneyAccount;
                  currentUser.bookingEnabled = _bookingEnabled;
                  currentUser.cardNumber = cardNumber;
                  currentUser.showPhoneInListings = _showPhoneInListings;

                  authBloc.add(UserUpdated(currentUser));

                  if (mounted) {
                    showSwipeDownNotification(
                      context,
                      message: 'Данные успешно сохранены',
                      duration: Duration(seconds: 2),
                    );
                  }
                } else {
                  if (mounted) {
                    showSwipeDownNotification(
                      context,
                      message: result['errors'] ?? result['error'] ?? 'Ошибка сохранения данных',
                      duration: Duration(seconds: 2),
                    );
                  }
                }
              },
              style: ButtonStyle(
                backgroundColor: WidgetStatePropertyAll(Color(0xff917dfa)),
                padding: WidgetStatePropertyAll(EdgeInsets.all(16)),
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              child: Text(
                'Сохранить',
                style: GoogleFonts.montserrat(
                  color: Color(0xffffffff),
                  fontSize: 14,
                  fontWeight: FontWeight(600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

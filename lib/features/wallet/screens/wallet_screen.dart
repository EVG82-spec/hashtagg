import 'dart:math';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hashtagg/shared/presentation/bloc/auth_bloc.dart';
import 'package:hashtagg/features/wallet/bloc/wallet_bloc.dart';
import 'package:hashtagg/features/profile/bloc/profile_bloc.dart';
import 'package:hashtagg/shared/domain/entities/user.dart';
import 'package:hashtagg/shared/presentation/screens/webview_screen.dart';
import 'package:hive/hive.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hashtagg/features/wallet/presentation/widgets/payment_waiting_modal.dart'; // Наш новый виджет



class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cardColor = _cardColors[Random().nextInt(_cardColors.length)];
    
    // Обновляем баланс пользователя после построения виджета
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshUserData();
    });
    
    // Загружаем историю транзакций
    final authState = context.read<AuthBloc>().state;
    if (authState.user != null) {
      final token = _getAuthToken();
      context.read<WalletBloc>().add(LoadWalletHistory(
        userId: authState.user!.id,
        token: token,
      ));
    }
  }

  // Набор из 8 светлых полупрозрачных цветов для карточки баланса
  static const _cardColors = [
    Color(0xff917dfa), // фиолетовый
    Color(0xff4fc3f7), // голубой
    Color(0xff81c784), // зелёный
    Color(0xffffb74d), // оранжевый
    Color(0xfff06292), // розовый
    Color(0xff4dd0e1), // бирюзовый
    Color(0xffaed581), // лаймовый
    Color(0xffff8a65), // коралловый
  ];

  late Color _cardColor;

  // Баланс берётся из AuthBloc

  // Выбранная платёжная система (по умолчанию используем первый доступный метод)
  final String _paymentMethod = 'Картой';
  final String _paymentProvider = 'ЮКасса';
  final String _codePayment = 'yookassa'; // Код платежной системы для API

  // История транзакций загружается из API через BLoC

  String _getAuthToken() {
    var box = Hive.box('user');
    return box.get('auth_token', defaultValue: '') as String;
  }

  String _formatBalance(int balance) {
    // Форматируем число с разделителем тысяч (пробелом)
    final str = balance.toString();
    final result = StringBuffer();
    var count = 0;
    
    for (var i = str.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        result.write(' ');
      }
      result.write(str[i]);
      count++;
    }
    
    return result.toString().split('').reversed.join('');
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onAmountTap(int? amount) {
    if (amount == null) {
      _showCustomAmountModal();
    } else {
      _showPaymentConfirmModal(amount);
    }
  }

  void _showPaymentConfirmModal(int amount) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xff233040) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => BlocListener<WalletBloc, WalletState>(
        listener: (context, state) {
          if (state is PaymentInitiated) {
            context.pop();
            _launchPaymentUrl(state.paymentLink, state.orderId);
          } else if (state is WalletError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom:
                MediaQuery.of(context).viewInsets.bottom +
                MediaQuery.of(context).padding.bottom +
                20,
          ),
          child: BlocBuilder<WalletBloc, WalletState>(
            builder: (context, walletState) {
              final isLoading = walletState is WalletLoading;
              
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 56,
                    color: Color(0xff917dfa),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Пополнение на $amount ₽',
                    style: GoogleFonts.montserrat(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Оплата через $_paymentProvider · $_paymentMethod',
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : () {
                        final authState = context.read<AuthBloc>().state;
                        if (authState.user != null) {
                          final token = _getAuthToken();
                          print('🔵 [WalletScreen] Sending InitiatePayment');
                          context.read<WalletBloc>().add(InitiatePayment(
                            userId: authState.user!.id,
                            token: token,
                            amount: amount.toDouble(),
                            codePayment: _codePayment,
                          ));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff917dfa),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isLoading
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Перейти к оплате',
                              style: GoogleFonts.montserrat(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _launchPaymentUrl(String url, int orderId) async {
    print('🔵 [WalletScreen] _launchPaymentUrl called');
    print('🔵 [WalletScreen] URL: $url');

    final uri = Uri.parse(url);

    // 1. Пытаемся открыть внешний браузер
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);

      // 2. Сразу показываем наше новое модальное окно ожидания
      if (mounted) {
        print('🟢 [WalletScreen] ОТКРЫВАЕМ НОВОЕ МОДАЛЬНОЕ ОКНО PaymentWaitingModal');
        showDialog(
          context: context,
          barrierDismissible: false, // Нельзя закрыть кликом вне окна
          builder: (context) => PaymentWaitingModal(
            orderId: orderId,
            onPaymentComplete: () {
              print('✅ [WalletScreen] Оплата подтверждена, обновляем данные...');
              _refreshUserData();

              final authState = context.read<AuthBloc>().state;
              if (authState.user != null) {
                final token = _getAuthToken();
                context.read<WalletBloc>().add(LoadWalletHistory(
                  userId: authState.user!.id,
                  token: token,
                ));
              }
            },
          ),
        );
      }
    } else {
      // 3. Если браузер не открылся, показываем опции (скопировать ссылку)
      _showPaymentLinkOptions(url, orderId);
    }
  }

  void _showPaymentLinkOptions(String url, int orderId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xff233040) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Icon(
                Icons.info_outline,
                size: 48,
                color: Colors.orange,
              ),
              const SizedBox(height: 16),
              Text(
                'Не удалось открыть браузер',
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Возможно, в настройках устройства заблокировано открытие внешних приложений',
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              // Кнопка "Скопировать ссылку"
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: url));
                    Navigator.pop(context);
                    _showPaymentWaitingDialog(orderId);
                  },
                  icon: const Icon(Icons.copy, color: Colors.white),
                  label: Text(
                    'Скопировать ссылку',
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff917dfa),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _showPaymentWaitingDialog(int orderId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PaymentWaitingModal( // <-- ЗДЕСЬ БЫЛО _PaymentWaitingDialog
        orderId: orderId,
        onPaymentComplete: () {
          // Обновляем баланс и историю
          _refreshUserData();
          final authState = context.read<AuthBloc>().state;
          if (authState.user != null) {
            final token = _getAuthToken();
            context.read<WalletBloc>().add(LoadWalletHistory(
              userId: authState.user!.id,
              token: token,
            ));
          }
        },
      ),
    );
  }

  void _showPaymentStatusDialog(int orderId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          'Оплата',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Вы завершили оплату?',
          style: GoogleFonts.montserrat(),
        ),
        actions: [
          TextButton(
            onPressed: () {
              context.pop();
            },
            child: Text(
              'Отмена',
              style: GoogleFonts.montserrat(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () {
              context.pop();
              _checkPaymentStatus(orderId);
            },
            child: Text(
              'Да, проверить',
              style: GoogleFonts.montserrat(color: Color(0xff917dfa)),
            ),
          ),
        ],
      ),
    );
  }

  void _checkPaymentStatus(int orderId) {
    final authState = context.read<AuthBloc>().state;
    if (authState.user != null) {
      final token = _getAuthToken();
      context.read<WalletBloc>().add(CheckPaymentStatus(
        userId: authState.user!.id,
        token: token,
        orderId: orderId,
      ));
    }
  }

  Future<void> _refreshUserData() async {
    print('🔵 [WalletScreen] Refreshing user data...');
    final authState = context.read<AuthBloc>().state;
    if (authState.user == null) {
      print('🔴 [WalletScreen] No user in AuthBloc');
      return;
    }

    try {
      final token = _getAuthToken();
      print('🔵 [WalletScreen] Token: ${token.isEmpty ? "EMPTY" : "present (${token.length} chars)"}');
      
      // Получаем обновленные данные профиля через ProfileApiRepository
      final profileRepo = context.read<ProfileBloc>().repository;
      final result = await profileRepo.getUserData(
        userId: authState.user!.id,
        token: token,
      );

      print('🔵 [WalletScreen] getUserData result: ${result['status']}');
      
      if (result['status'] == true) {
        final data = result['data'];
        print('🔵 [WalletScreen] Profile data received: ${data.keys}');
        
        // Парсим баланс (может быть строкой с символом валюты)
        final balanceStr = data['balance']?.toString() ?? '0';
        print('🔵 [WalletScreen] Balance string from API: "$balanceStr"');
        
        final balance = int.tryParse(balanceStr.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
        print('🔵 [WalletScreen] Parsed balance: $balance');
        
        // Обновляем пользователя в AuthBloc
        final updatedUser = authState.user!.copyWith(walletBalance: balance);
        context.read<AuthBloc>().add(UserUpdated(updatedUser));
        
        print('✅ [WalletScreen] User balance updated: $balance');
      } else {
        print('🔴 [WalletScreen] Failed to get user data: ${result['error']}');
      }
    } catch (e) {
      print('🔴 [WalletScreen] Failed to refresh user data: $e');
    }
  }

  void _showCustomAmountModal() {
    final controller = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xff233040) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom:
              MediaQuery.of(context).viewInsets.bottom +
              MediaQuery.of(context).padding.bottom +
              20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Введите сумму',
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: GoogleFonts.montserrat(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xff917dfa).withValues(alpha: 0.12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                hintText: 'Сумма в рублях',
                hintStyle: GoogleFonts.montserrat(
                  color: isDark ? Colors.white54 : Colors.grey,
                ),
                suffixText: '₽',
                suffixStyle: GoogleFonts.montserrat(
                  color: isDark ? Colors.white : Colors.black,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final amount = int.tryParse(controller.text);
                  if (amount != null && amount > 0) {
                    context.pop();
                    _showPaymentConfirmModal(amount);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff917dfa),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Пополнить',
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<WalletBloc, WalletState>(
      listener: (context, state) {
        if (state is PaymentStatusChecked) {
          if (state.isPaid) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Оплата успешно завершена!'),
                backgroundColor: Colors.green,
              ),
            );
            // Обновляем данные пользователя (включая баланс)
            _refreshUserData();
            // Перезагружаем историю
            final authState = context.read<AuthBloc>().state;
            if (authState.user != null) {
              final token = _getAuthToken();
              context.read<WalletBloc>().add(LoadWalletHistory(
                userId: authState.user!.id,
                token: token,
              ));
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Оплата еще не завершена'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      },
      child: Builder(
        builder: (context) {
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
              title: Text(
                'Кошелёк',
                style: GoogleFonts.montserrat(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
              bottom: TabBar(
                controller: _tabController,
                labelColor: const Color(0xff917dfa),
                unselectedLabelColor: isDark ? Colors.white54 : Colors.black54,
                indicatorColor: const Color(0xff917dfa),
                indicatorWeight: 2.5,
                labelStyle: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
                unselectedLabelStyle: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
                tabs: const [
                  Tab(text: 'Пополнение'),
                  Tab(text: 'История'),
                ],
              ),
            ),
            body: TabBarView(
              controller: _tabController,
              children: [_buildTopUpTab(), _buildHistoryTab()],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopUpTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return RefreshIndicator(
      onRefresh: () async {
        await _refreshUserData();
      },
      color: const Color(0xff917dfa),
      displacement: 60.0,
      child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Баланс
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
          decoration: BoxDecoration(
            color: isDark 
                ? const Color(0xff233040) // Второстепенный цвет в темной теме
                : _cardColor.withValues(alpha: 0.325), // Случайный цвет в светлой теме
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              BlocBuilder<AuthBloc, AuthState>(
                builder: (context, state) {
                  final balance = state.user?.walletBalance ?? 0;
                  return Text(
                    '${_formatBalance(balance)} ₽',
                    style: GoogleFonts.montserrat(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: Colors.white, // Всегда белый цвет для баланса
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Баланс кошелька',
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Платёжная система
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xff233040) : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Платежная система',
                style: GoogleFonts.montserrat(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  // Иконка карты
                  Container(
                    width: 40,
                    height: 28,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4FC3F7), Color(0xFF7E57C2)],
                      ),
                    ),
                    child: const Icon(
                      Icons.credit_card,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '$_paymentMethod  $_paymentProvider',
                    style: GoogleFonts.montserrat(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.keyboard_arrow_down,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Суммы пополнения
        _buildAmountTile(500),
        const SizedBox(height: 8),
        _buildAmountTile(1000),
        const SizedBox(height: 8),
        _buildAmountTile(3000),
        const SizedBox(height: 8),
        _buildAmountTile(null), // Другая сумма
      ],
      ),
    );
  }

  Widget _buildAmountTile(int? amount) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return InkWell(
      onTap: () => _onAmountTap(amount),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xff233040) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              amount != null ? '$amount ₽' : 'Другая сумма',
              style: GoogleFonts.montserrat(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return RefreshIndicator(
      onRefresh: () async {
        await _refreshUserData();
        final authState = context.read<AuthBloc>().state;
        if (authState.user != null) {
          final token = _getAuthToken();
          context.read<WalletBloc>().add(LoadWalletHistory(
            userId: authState.user!.id,
            token: token,
          ));
        }
        await Future.delayed(Duration(milliseconds: 500));
      },
      color: const Color(0xff917dfa),
      displacement: 60.0,
      child: BlocBuilder<WalletBloc, WalletState>(
      builder: (context, state) {
        if (state is WalletLoading) {
          return Center(
            child: CircularProgressIndicator(
              color: Color(0xff917dfa),
            ),
          );
        }
        
        if (state is WalletError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.grey[400],
                ),
                SizedBox(height: 16),
                Text(
                  state.message,
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        
        if (state is WalletHistoryLoaded) {
          if (state.history.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 64,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'История пуста',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: state.history.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = state.history[index];
              final action = item['action']?.toString() ?? '';
              final isTopUp = action == '+';
              final summa = item['summa']?.toString() ?? '0';
              final name = item['name']?.toString() ?? '';
              
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xff233040) : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isTopUp
                            ? const Color(0xff917dfa).withValues(alpha: 0.12)
                            : Colors.red.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isTopUp ? Icons.arrow_downward : Icons.arrow_upward,
                        color: isTopUp ? const Color(0xff917dfa) : Colors.red,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name.isNotEmpty ? name : (isTopUp ? 'Пополнение' : 'Списание'),
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${isTopUp ? '+' : '-'}$summa',
                      style: GoogleFonts.montserrat(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isTopUp ? const Color(0xff917dfa) : Colors.red,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        }
        
        // Initial state
        return Center(
          child: CircularProgressIndicator(
            color: Color(0xff917dfa),
          ),
        );
      },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:hashtagg/shared/presentation/bloc/auth_bloc.dart';
import 'package:hashtagg/features/profile/bloc/profile_bloc.dart';
import 'package:hashtagg/core/theme/theme_provider.dart';
import 'package:hashtagg/shared/presentation/screens/webview_screen.dart';
import 'package:hive/hive.dart';
import 'package:hashtagg/shared/presentation/bloc/navigation_notifier.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  static const _siteUrl = 'https://hashtagg.ru';

  @override
  void initState() {
    super.initState();
    // Обновляем баланс при открытии меню
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshUserBalance();
    });
  }

  Future<void> _refreshUserBalance() async {
    final authState = context.read<AuthBloc>().state;
    if (authState.user == null) return;

    try {
      final token = _getAuthToken();
      final profileRepo = context.read<ProfileBloc>().repository;
      final result = await profileRepo.getUserData(
        userId: authState.user!.id,
        token: token,
      );

      if (result['status'] == true) {
        final data = result['data'];
        final balanceStr = data['balance']?.toString() ?? '0';
        final balance = int.tryParse(balanceStr.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
        
        final updatedUser = authState.user!.copyWith(walletBalance: balance);
        context.read<AuthBloc>().add(UserUpdated(updatedUser));
      }
    } catch (e) {
      print('🔴 [MenuScreen] Failed to refresh balance: $e');
    }
  }

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

  void _openUrl(String path, [String? title]) {
    final url = '$_siteUrl$path';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WebViewScreen(
          url: url,
          title: title,
        ),
      ),
    );
  }

  // route — внутренний маршрут go_router; если null — открывается _siteUrl
  static const _menuItems = [
    (title: 'Правила подачи объявлений', route: '/rules'),
    (title: 'Запрещённые к публикации товары/услуги', route: '/prohibited'),
    (
      title: 'Пользовательское соглашение',
      route: '/polzovatelskoe-soglashenie',
    ),
    (title: 'Политика конфиденциальности', route: '/privacy-policy'),
    (
      title: 'Согласие на передачу и обработку персональных данных',
      route: '/polzovatelskoe-soglashenie',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
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
          'Меню',
          style: GoogleFonts.montserrat(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Theme.of(context).dividerColor, height: 1),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),

            // ── Карточки: Личный кабинет + Кошелёк ───────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          // Закрываем меню
                          Navigator.of(context).pop();
                          // Ждем завершения анимации закрытия меню
                          await Future.delayed(Duration(milliseconds: 400));
                          // Программно переключаем на вкладку профиля
                          if (context.mounted) {
                            context.read<NavigationNotifier>().selectProfile();
                            // Добавляем timestamp как query parameter для уникальности
                            final timestamp = DateTime.now().millisecondsSinceEpoch;
                            context.push('/profile?from=menu&t=$timestamp');
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark 
                                ? Theme.of(context).cardColor 
                                : const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: isDark 
                                      ? const Color(0xff151e27) 
                                      : Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.08,
                                      ),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.person_outline_rounded,
                                  color: isDark ? Colors.white : Color(0xFF5A6A85),
                                  size: 26,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Личный кабинет',
                                style: GoogleFonts.montserrat(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => context.push('/wallet'),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: isDark 
                                      ? const Color(0xff151e27) 
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.08,
                                      ),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.account_balance_wallet_outlined,
                                  color: isDark ? Colors.white : Color(0xFF5A6A85),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(height: 12),
                              BlocBuilder<AuthBloc, AuthState>(
                                builder: (context, state) {
                                  final balance =
                                      state.user?.walletBalance ?? 0;
                                  return Text(
                                    '${_formatBalance(balance)} ₽',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Наш блог ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: () => context.push('/blog'),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark 
                        ? Theme.of(context).cardColor 
                        : const Color(0xFFFFF3EE),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isDark 
                              ? const Color(0xff151e27) 
                              : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.edit_outlined,
                          color: isDark ? Colors.white : Color(0xFF5A6A85),
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Наш блог',
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
            Divider(height: 1, color: Theme.of(context).dividerColor),

            // ── Список пунктов ────────────────────────────────────────────
            ..._menuItems.map((item) => _buildMenuRow(item.title, item.route, isDark)),

            // ── Тёмная тема ───────────────────────────────────────────────
            Divider(height: 1, color: Theme.of(context).dividerColor),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Темная тема',
                      style: GoogleFonts.montserrat(
                        fontSize: 15,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  Switch(
                    value: themeProvider.isDarkMode,
                    onChanged: (v) => themeProvider.toggleTheme(),
                    activeThumbColor: const Color(0xff917dfa),
                    activeTrackColor: const Color(
                      0xff917dfa,
                    ).withValues(alpha: 0.4),
                  ),
                ],
              ),
            ),

            // ── Язык ──────────────────────────────────────────────────────
            Divider(height: 1, color: Theme.of(context).dividerColor),
            InkWell(
              onTap: () {},
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Язык',
                        style: GoogleFonts.montserrat(
                          fontSize: 15,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    // Флаг России
                    Text('🇷🇺', style: GoogleFonts.montserrat(fontSize: 20)),
                    const SizedBox(width: 6),
                    Text(
                      'Русский',
                      style: GoogleFonts.montserrat(
                        fontSize: 15,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.expand_more,
                      color: isDark ? Colors.white : Color(0xFFBDBDBD),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),

            Divider(height: 1, color: Theme.of(context).dividerColor),

            // ── Версия приложения ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Text(
                'Версия приложения 2.0.0',
                style: GoogleFonts.montserrat(
                  fontSize: 13,
                  color: const Color(0xFFAAAAAA),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuRow(String title, String? route, bool isDark) {
    return Column(
      children: [
        InkWell(
          onTap: route != null ? () => _openUrl(route, title) : () => _openUrl('', title),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.montserrat(
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: isDark ? Colors.white : Color(0xFFBDBDBD),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
        Divider(height: 1, color: Theme.of(context).dividerColor),
      ],
    );
  }
}

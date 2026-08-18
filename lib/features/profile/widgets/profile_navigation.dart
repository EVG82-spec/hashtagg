// lib/features/profile/widgets/profile_navigation.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hashtagg/shared/presentation/bloc/auth_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hashtagg/shared/presentation/bloc/subscriptions_bloc.dart';
import 'package:hashtagg/shared/presentation/utils.dart';
import 'package:hashtagg/features/profile/bloc/profile_bloc.dart' as profile;
import 'package:hashtagg/features/favorites/screens/favorites.dart';
import 'package:hashtagg/features/wallet/screens/wallet_screen.dart';
import 'package:hashtagg/features/tariffs/screens/tariffs_screen.dart';
import 'package:hashtagg/features/listing_packages/screens/listing_packages_screen.dart';
import 'package:hashtagg/features/shop/screens/my_shop_screen.dart';
import 'package:hashtagg/features/profile/screens/orders_screen.dart';
import 'package:hashtagg/features/subscriptions/screens/subscriptions_screen.dart';
import 'package:hashtagg/features/profile/screens/settings.dart';
import 'package:hashtagg/core/navigation/swipeable_route.dart';
import 'package:hive/hive.dart';
import 'package:dio/dio.dart';
import 'package:hashtagg/core/network/shop_api_repository.dart';

class ProfileNavigation extends StatefulWidget {
  const ProfileNavigation({super.key});

  @override
  State<ProfileNavigation> createState() => _ProfileNavigationState();
}

class _ProfileNavigationState extends State<ProfileNavigation> {

  String? _shopId;

  @override
  void initState() {
    super.initState();
    _loadShopId();
  }

  void _loadShopId() async {
    try {
      final box = Hive.box('user');
      final userData = box.get('user');

      if (userData == null) {
        print('⚠️ [ProfileNavigation] No user data');
        setState(() {
          _shopId = null;
        });
        return;
      }

      final userId = userData['id'];
      if (userId == null) {
        print('⚠️ [ProfileNavigation] No user id');
        setState(() {
          _shopId = null;
        });
        return;
      }

      print('🔍 [ProfileNavigation] Checking shops for user: $userId');

      // Получаем список магазинов через API
      final dio = Dio(BaseOptions(
        baseUrl: 'https://hashtagg.ru',
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      ));
      final repository = ShopApiRepository(dio);
      final shops = await repository.getShops();

      print('📦 [ProfileNavigation] Found ${shops.length} shops');

      // Ищем магазин текущего пользователя
      final userShop = shops.where((shop) => shop.userId == userId).firstOrNull;

      if (userShop != null) {
        setState(() {
          _shopId = userShop.id.toString();
        });
        print('✅ [ProfileNavigation] Shop found: id=${userShop.id}');
      } else {
        // 👇 ГЛАВНОЕ! ОЧИЩАЕМ _shopId, ЕСЛИ МАГАЗИНА НЕТ
        setState(() {
          _shopId = null;
        });
        print('⚠️ [ProfileNavigation] No shop for user: $userId');
      }
    } catch (e) {
      print('⚠️ [ProfileNavigation] Error loading shopId: $e');
      // 👇 ПРИ ОШИБКЕ ТОЖЕ ОЧИЩАЕМ
      setState(() {
        _shopId = null;
      });
    }
  }

  // 👇 ДОБАВЬ ЭТОТ МЕТОД СЮДА (ПОСЛЕ _loadShopId)
  bool _checkTariff() {
    try {
      final box = Hive.box('user');
      final userData = box.get('user');
      if (userData != null) {
        final activeServices = userData['activeServices'] as List? ?? [];
        return activeServices.contains('shop');
      }
    } catch (e) {
      print('⚠️ [ProfileNavigation] Error checking tariff: $e');
    }
    return false;
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = context.read<AuthBloc>();

    return Column(
      children: [
        // ===== 1. КОШЕЛЁК =====
        InkWell(
          onTap: () {
            Navigator.of(context, rootNavigator: true).push(
              createSwipeableRoute(builder: (_) => const WalletScreen()),
            );
          },
          splashColor: const Color(0xff917dfa).withOpacity(0.3),
          highlightColor: const Color(0xff917dfa).withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 10),
            child: Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 26,
                  color: isDark ? Colors.white : const Color(0xff666666),
                ),
                const SizedBox(width: 10),
                Text(
                  'Кошелёк',
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ===== 2. ПЛАТНЫЕ УСЛУГИ =====
        InkWell(
          onTap: () {
            Navigator.of(context, rootNavigator: true).push(
              createSwipeableRoute(builder: (_) => const TariffsScreen()),
            );
          },
          splashColor: const Color(0xff917dfa).withOpacity(0.3),
          highlightColor: const Color(0xff917dfa).withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 10),
            child: Row(
              children: [
                Icon(
                  Icons.business_center,
                  size: 26,
                  color: isDark ? Colors.white : const Color(0xff666666),
                ),
                const SizedBox(width: 10),
                Text(
                  'Платные услуги',
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ===== 3. ПАКЕТЫ ОБЪЯВЛЕНИЙ (СКРЫТО) =====
        Visibility(
          visible: false,
          child: InkWell(
            onTap: () {
              Navigator.of(context, rootNavigator: true).push(
                createSwipeableRoute(builder: (_) => const ListingPackagesScreen()),
              );
            },
            splashColor: const Color(0xff917dfa).withOpacity(0.3),
            highlightColor: const Color(0xff917dfa).withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.work_outline,
                    size: 26,
                    color: isDark ? Colors.white : const Color(0xff666666),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Пакеты объявлений',
                    style: GoogleFonts.montserrat(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ===== 4. МАГАЗИН =====
        InkWell(
          onTap: () {
            if (_shopId != null && _shopId!.isNotEmpty) {
              // ✅ ЕСТЬ МАГАЗИН → ОТКРЫВАЕМ
              context.push('/shop/$_shopId');
            } else {
              // ❌ НЕТ МАГАЗИНА → ПРОВЕРЯЕМ ТАРИФ И ПОКАЗЫВАЕМ ПРОМО
              final hasTariff = _checkTariff(); // Проверяем, есть ли услуга "shop"
              context.push('/shop/empty?hasTariff=$hasTariff');
            }
          },
          splashColor: const Color(0xff917dfa).withOpacity(0.3),
          highlightColor: const Color(0xff917dfa).withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 10),
            child: Row(
              children: [
                Icon(
                  Icons.store,
                  size: 26,
                  color: isDark ? Colors.white : const Color(0xff666666),
                ),
                const SizedBox(width: 10),
                Text(
                  'Магазин',
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ===== 5. ЗАКАЗЫ =====
        InkWell(
          onTap: () {
            Navigator.of(context, rootNavigator: true).push(
              createSwipeableRoute(builder: (_) => const OrdersScreen()),
            );
          },
          splashColor: const Color(0xff917dfa).withOpacity(0.3),
          highlightColor: const Color(0xff917dfa).withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 10),
            child: Row(
              children: [
                Icon(
                  Icons.shopping_cart,
                  size: 26,
                  color: isDark ? Colors.white : const Color(0xff666666),
                ),
                const SizedBox(width: 10),
                Text(
                  'Заказы',
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ===== 6. ИЗБРАННОЕ =====
        InkWell(
          onTap: () {
            Navigator.of(context, rootNavigator: true).push(
              createEdgeSwipeRoute(builder: (_) => const FavoritesScreen()),
            );
          },
          splashColor: const Color(0xff917dfa).withOpacity(0.3),
          highlightColor: const Color(0xff917dfa).withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 10),
            child: Row(
              children: [
                Icon(
                  Icons.favorite_outline_sharp,
                  size: 26,
                  color: isDark ? Colors.white : const Color(0xff666666),
                ),
                const SizedBox(width: 10),
                Text(
                  'Избранное',
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ===== 7. ПОДПИСКИ =====
        InkWell(
          onTap: () {
            Navigator.of(context, rootNavigator: true).push(
              createSwipeableRoute(builder: (_) => const SubscriptionsScreen()),
            );
          },
          splashColor: const Color(0xff917dfa).withOpacity(0.3),
          highlightColor: const Color(0xff917dfa).withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 10),
            child: Row(
              children: [
                Icon(
                  Icons.group,
                  size: 26,
                  color: isDark ? Colors.white : const Color(0xff666666),
                ),
                const SizedBox(width: 10),
                Text(
                  'Подписки',
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const Spacer(),
                BlocBuilder<profile.ProfileBloc, profile.ProfileStateOld>(
                  builder: (context, profileState) {
                    int count = 0;
                    if (profileState is profile.SubscriptionsLoaded) {
                      count = profileState.subscriptions.length;
                    }
                    if (count == 0) return const SizedBox.shrink();
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xff917dfa),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$count',
                        style: GoogleFonts.montserrat(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),

        // ===== 8. ПАРТНЕРСКАЯ ПРОГРАММА (СКРЫТО) =====
        Visibility(
          visible: false,
          child: InkWell(
            onTap: () {
              _showPartnerProgramModal(context);
            },
            splashColor: const Color(0xff917dfa).withOpacity(0.3),
            highlightColor: const Color(0xff917dfa).withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.payments,
                    size: 26,
                    color: isDark ? Colors.white : const Color(0xff666666),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Партнерская программа',
                    style: GoogleFonts.montserrat(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ===== 9. НАСТРОЙКИ =====
        InkWell(
          onTap: () {
            Navigator.of(context, rootNavigator: true).push(
              createSwipeableRoute(builder: (_) => const SettingsScreen()),
            );
          },
          splashColor: const Color(0xff917dfa).withOpacity(0.3),
          highlightColor: const Color(0xff917dfa).withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 10),
            child: Row(
              children: [
                Icon(
                  Icons.settings,
                  size: 26,
                  color: isDark ? Colors.white : const Color(0xff666666),
                ),
                const SizedBox(width: 10),
                Text(
                  'Настройки',
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ===== 10. ВЫЙТИ =====
        InkWell(
          onTap: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(
                  'Выход',
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                ),
                content: Text(
                  'Вы действительно хотите выйти из аккаунта?',
                  style: GoogleFonts.montserrat(),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(
                      'Отмена',
                      style: GoogleFonts.montserrat(),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(
                      'Выйти',
                      style: GoogleFonts.montserrat(color: Colors.red),
                    ),
                  ),
                ],
              ),
            );

            if (confirmed == true && context.mounted) {
              if (kDebugMode) {
                debugPrint("logout requested");
              }
              context.read<AuthBloc>().add(LogoutRequested());
              showSwipeDownNotification(
                context,
                message: 'Вы вышли из аккаунта',
                duration: const Duration(seconds: 2),
              );
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) {
                  context.go('/');
                }
              });
            }
          },
          splashColor: const Color(0xff917dfa).withOpacity(0.3),
          highlightColor: const Color(0xff917dfa).withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 10),
            child: Row(
              children: [
                Icon(
                  Icons.exit_to_app,
                  size: 26,
                  color: Colors.red,
                ),
                const SizedBox(width: 10),
                Text(
                  'Выйти',
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ===== МЕТОД ДЛЯ ПАРТНЕРСКОЙ ПРОГРАММЫ =====
  void _showPartnerProgramModal(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = context.read<AuthBloc>().state.user;
    final referralLink = user?.referralLink ?? 'https://hashtagg.gg/ru/ref/loading';

    if (kDebugMode) {
      debugPrint('🔗 [PartnerModal] User referralLink: ${user?.referralLink}');
      debugPrint('🔗 [PartnerModal] Display referralLink: $referralLink');
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: isDark ? const Color(0xff233040) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20.0,
            right: 20.0,
            top: 20.0,
            bottom: MediaQuery.of(context).padding.bottom + 20.0,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: Icon(
                    Icons.handshake,
                    size: 100,
                    color: const Color(0xff917dfa),
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    'Партнерская программа',
                    style: GoogleFonts.montserrat(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Распространяйте свою реферальную ссылку и получайте пожизненное вознаграждение от пополнения балоанса пользователем в размере 15% от суммы пополнения.',
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    color: isDark ? Colors.white : Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Ваша ссылка',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: referralLink));
                    showSwipeDownNotification(
                      context,
                      message: 'Ссылка скопирована в буфер обмена',
                      duration: const Duration(seconds: 2),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xff917dfa).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            referralLink,
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              color: const Color(0xff917dfa),
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.copy, size: 16, color: const Color(0xff917dfa)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}
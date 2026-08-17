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

class ProfileNavigation extends StatefulWidget {
  const ProfileNavigation({super.key});

  @override
  State<ProfileNavigation> createState() => _ProfileNavigationState();
}

class _ProfileNavigationState extends State<ProfileNavigation> {
  @override
  Widget build(BuildContext context) {
    var state = context.read<AuthBloc>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        InkWell(
          onTap: () {
            Navigator.of(context, rootNavigator: true).push(
              createSwipeableRoute(builder: (_) => const WalletScreen()),
            );
          },
          splashColor: Color(
            0xff917dfa,
          ).withValues(alpha: 0.3), // цвет всплеска
          highlightColor: Color(0xff917dfa).withValues(alpha: 0.1),
          child: Padding(
            padding: EdgeInsetsGeometry.only(
              left: 20,
              right: 20,
              top: 10,
              bottom: 10,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 26,
                  color: isDark ? Colors.white : Color(0xff666666),
                ),
                SizedBox(width: 10),
                Text(
                  'Кошелёк',
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight(400),
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),

        InkWell(
          onTap: () {
            Navigator.of(context, rootNavigator: true).push(
              createSwipeableRoute(builder: (_) => const TariffsScreen()),
            );
          },
          splashColor: Color(
            0xff917dfa,
          ).withValues(alpha: 0.3), // цвет всплеска
          highlightColor: Color(0xff917dfa).withValues(alpha: 0.1),
          child: Padding(
            padding: EdgeInsetsGeometry.only(
              left: 20,
              right: 20,
              top: 10,
              bottom: 10,
            ),
            child: Row(
              children: [
                Icon(Icons.business_center, size: 26, color: isDark ? Colors.white : Color(0xff666666)),
                SizedBox(width: 10),
                Text(
                  'Платные услуги',
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight(400),
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),

        InkWell(
          onTap: () {
            Navigator.of(context, rootNavigator: true).push(
              createSwipeableRoute(builder: (_) => const ListingPackagesScreen()),
            );
          },
          splashColor: Color(
            0xff917dfa,
          ).withValues(alpha: 0.3), // цвет всплеска
          highlightColor: Color(0xff917dfa).withValues(alpha: 0.1),
          child: Padding(
            padding: EdgeInsetsGeometry.only(
              left: 20,
              right: 20,
              top: 10,
              bottom: 10,
            ),
            child: Row(
              children: [
                Icon(Icons.work_outline, size: 26, color: isDark ? Colors.white : Color(0xff666666)),
                SizedBox(width: 10),
                Text(
                  'Пакеты объявлений',
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight(400),
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Магазин
        InkWell(
          onTap: () {
            Navigator.of(context, rootNavigator: true).push(
              createSwipeableRoute(builder: (_) => const MyShopScreen()),
            );
          },
          splashColor: Color(
            0xff917dfa,
          ).withValues(alpha: 0.3),
          highlightColor: Color(0xff917dfa).withValues(alpha: 0.1),
          child: Padding(
            padding: EdgeInsetsGeometry.only(
              left: 20,
              right: 20,
              top: 10,
              bottom: 10,
            ),
            child: Row(
              children: [
                Icon(Icons.store, size: 26, color: isDark ? Colors.white : Color(0xff666666)),
                SizedBox(width: 10),
                Text(
                  'Магазин',
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight(400),
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),

        InkWell(
          onTap: () {
            Navigator.of(context, rootNavigator: true).push(
              createSwipeableRoute(builder: (_) => const OrdersScreen()),
            );
          },
          splashColor: Color(
            0xff917dfa,
          ).withValues(alpha: 0.3), // цвет всплеска
          highlightColor: Color(0xff917dfa).withValues(alpha: 0.1),
          child: Padding(
            padding: EdgeInsetsGeometry.only(
              left: 20,
              right: 20,
              top: 10,
              bottom: 10,
            ),
            child: Row(
              children: [
                Icon(Icons.shopping_cart, size: 26, color: isDark ? Colors.white : Color(0xff666666)),
                SizedBox(width: 10),
                Text(
                  'Заказы',
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight(400),
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),

        InkWell(
          onTap: () {
            Navigator.of(context, rootNavigator: true).push(
              createEdgeSwipeRoute(builder: (_) => const FavoritesScreen()),
            );
          },
          splashColor: Color(
            0xff917dfa,
          ).withValues(alpha: 0.3), // цвет всплеска
          highlightColor: Color(0xff917dfa).withValues(alpha: 0.1),
          child: Padding(
            padding: EdgeInsetsGeometry.only(
              left: 20,
              right: 20,
              top: 10,
              bottom: 10,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.favorite_outline_sharp,
                  size: 26,
                  color: isDark ? Colors.white : Color(0xff666666),
                ),
                SizedBox(width: 10),
                Text(
                  'Избранное',
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight(400),
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),

        InkWell(
          onTap: () {
            Navigator.of(context, rootNavigator: true).push(
              createSwipeableRoute(builder: (_) => const SubscriptionsScreen()),
            );
          },
          splashColor: Color(
            0xff917dfa,
          ).withValues(alpha: 0.3), // цвет всплеска
          highlightColor: Color(0xff917dfa).withValues(alpha: 0.1),
          child: Padding(
            padding: EdgeInsetsGeometry.only(
              left: 20,
              right: 20,
              top: 10,
              bottom: 10,
            ),
            child: Row(
              children: [
                Icon(Icons.group, size: 26, color: isDark ? Colors.white : Color(0xff666666)),
                SizedBox(width: 10),
                Text(
                  'Подписки',
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight(400),
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                Spacer(),
                BlocBuilder<profile.ProfileBloc, profile.ProfileStateOld>(
                  builder: (context, profileState) {
                    int count = 0;
                    if (profileState is profile.SubscriptionsLoaded) {
                      count = profileState.subscriptions.length;
                    }
                    if (count == 0) return SizedBox.shrink();
                    return Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: Color(0xff917dfa),
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

        InkWell(
          onTap: () {
            _showPartnerProgramModal(context);
          },
          splashColor: Color(
            0xff917dfa,
          ).withValues(alpha: 0.3), // цвет всплеска
          highlightColor: Color(0xff917dfa).withValues(alpha: 0.1),
          child: Padding(
            padding: EdgeInsetsGeometry.only(
              left: 20,
              right: 20,
              top: 10,
              bottom: 10,
            ),
            child: Row(
              children: [
                Icon(Icons.payments, size: 26, color: isDark ? Colors.white : Color(0xff666666)),
                SizedBox(width: 10),
                Text(
                  'Партнерская программа',
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight(400),
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),

        InkWell(
          onTap: () {
            Navigator.of(context, rootNavigator: true).push(
              createSwipeableRoute(builder: (_) => SettingsScreen()),
            );
          },
          splashColor: Color(
            0xff917dfa,
          ).withValues(alpha: 0.3), // цвет всплеска
          highlightColor: Color(0xff917dfa).withValues(alpha: 0.1),
          child: Padding(
            padding: EdgeInsetsGeometry.only(
              left: 20,
              right: 20,
              top: 10,
              bottom: 10,
            ),
            child: Row(
              children: [
                Icon(Icons.settings, size: 26, color: isDark ? Colors.white : Color(0xff666666)),
                SizedBox(width: 10),
                Text(
                  'Настройки',
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight(400),
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),

        InkWell(
          onTap: () async {
            // Показываем диалог подтверждения
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
              
              // Выполняем выход
              state.add(LogoutRequested());
              
              // Показываем уведомление
              showSwipeDownNotification(
                context,
                message: 'Вы вышли из аккаунта',
                duration: Duration(seconds: 2),
              );
              
              // Переходим на главный экран через GoRouter после задержки
              // Используем SchedulerBinding чтобы избежать мутации во время layout
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) {
                  context.go('/');
                }
              });
            }
          },
          splashColor: Color(
            0xff917dfa,
          ).withValues(alpha: 0.3), // цвет всплеска
          highlightColor: Color(0xff917dfa).withValues(alpha: 0.1),
          child: Padding(
            padding: EdgeInsetsGeometry.only(
              left: 20,
              right: 20,
              top: 10,
              bottom: 10,
            ),
            child: Row(
              children: [
                Icon(Icons.exit_to_app, size: 26, color: Colors.red),
                SizedBox(width: 10),
                Text(
                  'Выйти',
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight(400),
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
}

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
              // Полоска сверху для свайпа
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              // Изображение 100x100 по центру
              Center(
                child: Icon(
                  Icons.handshake,
                  size: 100,
                  color: Color(0xff917dfa),
                ),
              ),
              const SizedBox(height: 20),
              // Центрированный заголовок
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
              // Серый текст с описанием
              Text(
                'Распространяйте свою реферальную ссылку и получайте пожизненное вознаграждение от пополнения балоанса пользователем в размере 15% от суммы пополнения.',
                style: GoogleFonts.montserrat(
                  fontSize: 13, 
                  color: isDark ? Colors.white : Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // Жирный заголовок "Ваша ссылка"
              Text(
                'Ваша ссылка',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              // Пурпурная ссылка
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: referralLink));
                  showSwipeDownNotification(
                    context,
                    message: 'Ссылка скопирована в буфер обмена',
                    duration: Duration(seconds: 2),
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Color(0xff917dfa).withValues(alpha: 0.1),
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
                            color: Color(0xff917dfa),
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.copy, size: 16, color: Color(0xff917dfa)),
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

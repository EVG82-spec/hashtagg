import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:full_swipe_back_gesture/full_swipe_back_gesture.dart';
import 'package:hashtagg/features/auth/screens/privacy_policy_screen.dart';
import 'package:hashtagg/features/search/screens/search_screen.dart';
import 'package:hashtagg/features/search/screens/search_filters_screen.dart';
import 'package:hashtagg/features/search/screens/map_screen.dart';
import 'package:hashtagg/features/auth/screens/registration.dart';
import 'package:hashtagg/features/auth/screens/restore_password.dart';
import 'package:hashtagg/features/auth/screens/user_agreement_screen.dart';
import 'package:hashtagg/features/chats/screens/chats_screen.dart';
import 'package:hashtagg/features/favorites/screens/favorites.dart';
import 'package:hashtagg/features/subscriptions/screens/subscriptions_screen.dart';
import 'package:hashtagg/features/blacklist/screens/blacklist_screen.dart';
import 'package:hashtagg/features/reviews/screens/reviews_screen.dart';
import 'package:hashtagg/features/user_profile/screens/user_profile_screen.dart';
import 'package:hashtagg/features/listing/screens/add_listing_screen.dart';
import 'package:hashtagg/features/listing/screens/edit_listing_screen.dart';
import 'package:hashtagg/features/listing/screens/listing_screen.dart';
import 'package:hashtagg/features/listing/screens/listing_loading_screen.dart';
import 'package:hashtagg/features/profile/screens/profile.dart';
import 'package:hashtagg/features/profile/screens/settings.dart';
import 'package:hashtagg/features/profile/screens/orders_screen.dart';
import 'package:hashtagg/features/wallet/screens/wallet_screen.dart';
import 'package:hashtagg/features/listing_packages/screens/listing_packages_screen.dart';
import 'package:hashtagg/features/listing_packages/screens/add_package_screen.dart';
import 'package:hashtagg/features/tariffs/screens/tariffs_screen.dart';
import 'package:hashtagg/features/tariffs/screens/ad_statistics_screen.dart';
import 'package:hashtagg/features/auth/screens/login.dart';
import 'package:hashtagg/features/home/screens/menu_screen.dart';
import 'package:hashtagg/features/home/screens/blog_screen.dart';
import 'package:hashtagg/features/home/screens/article_screen.dart';
import 'package:hashtagg/features/shops/screens/shop_detail_screen.dart';
import 'package:hashtagg/shared/presentation/widgets/navigation_bar.dart';
import '../features/home/screens/home_screen.dart';
import '../features/catalog/screens/catalog_screen.dart';
import 'package:hashtagg/features/shop/screens/shop_public_screen.dart';
import 'package:hashtagg/features/shop/screens/shop_empty_promo_screen.dart';
import 'package:hashtagg/features/shop/screens/shop_edit_screen.dart';
import 'package:hashtagg/diagnostic.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

// Экспортируем navigatorKey для использования в других местах
GlobalKey<NavigatorState> get rootNavigatorKey => _rootNavigatorKey;

/// Helper для создания CustomTransitionPage с iOS-стиль свайпом
CustomTransitionPage<T> buildSwipeablePage<T>({
  required Widget child,
  LocalKey? key,
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(1.0, 0.0);
      const end = Offset.zero;
      const curve = Curves.easeInOut;
      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
      return SlideTransition(position: animation.drive(tween), child: child);
    },
  );
}

// ============================================================
// _ShellScaffold - кастомная обертка для скрытия навигации при скролле
// ============================================================
class _ShellScaffold extends StatefulWidget {
  final Widget child;
  const _ShellScaffold({required this.child});

  @override
  State<_ShellScaffold> createState() => _ShellScaffoldState();
}

class _ShellScaffoldState extends State<_ShellScaffold> {
  bool _isNavVisible = true;
  double _maxScrollExtent = 0;

  void _onScroll(double offset, double maxScrollExtent) {
    _maxScrollExtent = maxScrollExtent;

    if (offset >= maxScrollExtent - 10) {
      // Достигнут самый низ → скрываем навигацию
      if (_isNavVisible) {
        setState(() => _isNavVisible = false);
      }
    } else {
      // Не внизу → показываем навигацию
      if (!_isNavVisible) {
        setState(() => _isNavVisible = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollUpdateNotification) {
            _onScroll(
              notification.metrics.pixels,
              notification.metrics.maxScrollExtent,
            );
          }
          return true;
        },
        child: Stack(
          children: [
            widget.child,
            AnimatedPositioned(
              left: 0,
              right: 0,
              bottom: _isNavVisible ? 0 : -80,
              duration: const Duration(milliseconds: 300),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: const MainNavigationBar(),
                ),
              ),
            ),
          ],
        ),
      ),
      extendBody: true,
    );
  }
}

// ============================================================
// РОУТЕР
// ============================================================
final router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  observers: [],
  redirect: (context, state) async {
    final String path = state.uri.path;
    final String fullUri = state.uri.toString();

    debugPrint('🔀 [GoRouter Redirect] path: $path');
    debugPrint('🔀 [GoRouter Redirect] fullUri: $fullUri');
    debugPrint(
      '🔀 [GoRouter Redirect] queryParameters: ${state.uri.queryParameters}',
    );

    if (path == '/callback' &&
        state.uri.queryParameters['status'] == 'success') {
      debugPrint(
        '🔀 [GoRouter Redirect] Detected OAuth callback success, redirecting to /',
      );
      return '/';
    }

    if (path == '/callback' && state.uri.queryParameters['status'] == 'error') {
      debugPrint(
        '🔀 [GoRouter Redirect] Detected OAuth callback error, redirecting to /',
      );
      return '/';
    }

    return null;
  },
  errorPageBuilder: (context, state) {
    return CupertinoPage(
      child: Scaffold(
        appBar: AppBar(title: const Text('Page not found')),
        body: const Center(child: Text('Page not found')),
      ),
    );
  },
  routes: [
    // ── Полноэкранные маршруты (без bottom nav) ──────────────────────────────
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/privacy-policy',
      pageBuilder: (context, state) =>
          CupertinoPage(child: PrivacyPolicyScreen()),
    ),

    GoRoute(
      path: '/diagnostic',
      builder: (context, state) => const DiagnosticScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/user-agreement',
      pageBuilder: (context, state) =>
          CupertinoPage(child: UserAgreementScreen()),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/login',
      pageBuilder: (context, state) => CupertinoPage(child: LoginScreen()),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/registration',
      pageBuilder: (context, state) =>
          CupertinoPage(child: RegistrationScreen()),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/restore-password',
      pageBuilder: (context, state) =>
          CupertinoPage(child: RestorePasswordScreen()),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/settings',
      pageBuilder: (context, state) => CupertinoPage(child: SettingsScreen()),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/orders',
      pageBuilder: (context, state) =>
          const CupertinoPage(child: OrdersScreen()),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/wallet',
      pageBuilder: (context, state) =>
          const CupertinoPage(child: WalletScreen()),
    ),
    GoRoute(
      path: '/payment/success',
      builder: (context, state) => const WalletScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/listing-packages',
      pageBuilder: (context, state) =>
          const CupertinoPage(child: ListingPackagesScreen()),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/listing-packages/add',
      pageBuilder: (context, state) =>
          const CupertinoPage(child: AddPackageScreen()),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/tariffs',
      pageBuilder: (context, state) =>
          const CupertinoPage(child: TariffsScreen()),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/ad-statistics/:adId',
      pageBuilder: (context, state) {
        final adId = int.parse(state.pathParameters['adId']!);
        return CupertinoPage(
          key: state.pageKey,
          child: AdStatisticsScreen(adId: adId),
        );
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/listing-add',
      pageBuilder: (context, state) =>
          const CupertinoPage(child: AddListingScreen()),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/listing-edit/:id',
      pageBuilder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return CupertinoPage(child: EditListingScreen(adId: id));
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/menu',
      pageBuilder: (context, state) => const CupertinoPage(child: MenuScreen()),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/blog',
      pageBuilder: (context, state) => const CupertinoPage(child: BlogScreen()),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/article/:articleId',
      pageBuilder: (context, state) {
        final articleId = int.parse(state.pathParameters['articleId']!);
        final extra = state.extra as Map<String, dynamic>?;
        return CupertinoPage(
          key: state.pageKey,
          child: ArticleScreen(
            articleId: articleId,
            catAlias: extra?['cat_alias'] as String?,
            articleAlias: extra?['article_alias'] as String?,
          ),
        );
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/favorites',
      pageBuilder: (context, state) =>
          const CupertinoPage(child: FavoritesScreen()),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/subscriptions',
      pageBuilder: (context, state) =>
          const CupertinoPage(child: SubscriptionsScreen()),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/blacklist',
      pageBuilder: (context, state) =>
          const CupertinoPage(child: BlacklistScreen()),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/user/:userId/reviews',
      pageBuilder: (context, state) {
        final userId = int.parse(state.pathParameters['userId']!);
        return CupertinoPage(
          key: state.pageKey,
          child: ReviewsScreen(userId: userId),
        );
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/user/:userId',
      pageBuilder: (context, state) {
        final userId = int.parse(state.pathParameters['userId']!);
        return CupertinoPage(child: UserProfileScreen(userId: userId));
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/shop/empty',
      pageBuilder: (context, state) {
        final hasTariff = state.uri.queryParameters['hasTariff'] == 'true';
        return CupertinoPage(child: ShopEmptyPromoScreen(hasTariff: hasTariff));
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/shop/edit/:shopId',
      pageBuilder: (context, state) {
        final shopId = state.pathParameters['shopId']!;
        return CupertinoPage(child: ShopEditScreen(shopId: shopId));
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/shop/:shopId',
      pageBuilder: (context, state) {
        final shopId = state.pathParameters['shopId']!;
        print('🚀🚀🚀 [Router] Opening shop: $shopId');
        print('🏪 Creating ShopPublicScreen with shopId: $shopId');
        return CupertinoPage(
          key: state.pageKey,
          child: ShopPublicScreen(shopId: shopId),
        );
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/search',
      pageBuilder: (context, state) {
        final query = state.uri.queryParameters['q'] ?? '';
        final extra = state.extra;

        if (extra is SearchFilters) {
          return CupertinoPage(
            child: SearchScreen(initialQuery: query, initialFilters: extra),
          );
        }

        if (extra is Map<String, dynamic>) {
          return CupertinoPage(
            child: SearchScreen(
              initialQuery: query,
              categoryId: extra['categoryId'] as int?,
              categoryName: extra['categoryName'] as String?,
            ),
          );
        }

        final category = extra as String?;
        return CupertinoPage(
          child: SearchScreen(initialQuery: query, categoryName: category),
        );
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/search/map',
      pageBuilder: (context, state) => const CupertinoPage(child: MapScreen()),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/listing/:itemId',
      pageBuilder: (context, state) {
        final itemId = state.pathParameters['itemId']!;
        return CupertinoPage(
          key: state.pageKey,
          child: ListingLoadingScreen(itemId: itemId),
        );
      },
    ),

    // ── Shell (с bottom nav + скрытие при скролле) ──────────────────────────
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return _ShellScaffold(child: child);
      },
      routes: [
        GoRoute(
          path: '/',
          pageBuilder: (context, state) =>
              const CupertinoPage(key: ValueKey('home'), child: HomeScreen()),
        ),
        GoRoute(
          path: '/catalog',
          pageBuilder: (context, state) =>
              CupertinoPage(child: CatalogScreen()),
        ),
        GoRoute(
          path: '/menu',
          pageBuilder: (context, state) => CupertinoPage(child: MenuScreen()),
        ),
        GoRoute(
          path: '/profile',
          pageBuilder: (context, state) {
            final sorting = state.uri.queryParameters['sorting'];
            return CupertinoPage(child: ProfileScreen(initialSorting: sorting));
          },
        ),
        GoRoute(
          path: '/chats',
          pageBuilder: (context, state) => CupertinoPage(child: ChatsScreen()),
        ),
      ],
    ),
  ],
);

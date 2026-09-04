import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:hashtagg/shared/presentation/bloc/auth_bloc.dart';
import 'package:hashtagg/core/utils/shop_access_checker.dart';
import 'package:hashtagg/features/shop/bloc/shop_bloc.dart';
import 'package:hashtagg/features/shop/bloc/shop_event.dart';
import 'package:hashtagg/features/shop/bloc/shop_state.dart';
import 'package:hashtagg/features/shop/models/shop.dart';
import 'package:hashtagg/core/navigation/swipeable_route.dart';
import 'package:hashtagg/features/shop/screens/shop_edit_screen.dart';
import 'package:hashtagg/features/shop/screens/shop_sliders_screen.dart';
import 'package:hashtagg/features/shop/screens/shop_pages_screen.dart';
import 'package:hashtagg/features/shop/screens/shop_settings_screen.dart';
import 'package:hashtagg/features/shop/screens/shop_stats_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MyShopScreen extends StatefulWidget {
  const MyShopScreen({super.key});

  @override
  State<MyShopScreen> createState() => _MyShopScreenState();
}

class _MyShopScreenState extends State<MyShopScreen> {
  @override
  void initState() {
    super.initState();
    _loadShop();
  }

  void _loadShop() {
    final authState = context.read<AuthBloc>().state;
    final user = authState.user;

    if (user != null) {
      // Проверяем доступ к магазину
      if (!ShopAccessChecker.hasShopAccess(user)) {
        return;
      }

      // Загружаем данные магазина по ID пользователя
      // API будет искать магазин где clients_shops_id_user = userId
      context.read<ShopBloc>().add(
        LoadShop(
          userId: user.id,
          token: user.token ?? '',
          shopId: user.id, // Передаем userId, но API должен искать по id_user
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = context.watch<AuthBloc>().state;
    final user = authState.user;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Мой магазин',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.bar_chart,
              color: isDark ? Colors.white : Colors.black,
            ),
            onPressed: () {
              final authState = context.read<AuthBloc>().state;
              if (authState.user != null) {
                context.read<ShopBloc>().add(
                  LoadShop(
                    userId: authState.user!.id,
                    token: authState.user!.token ?? '',
                    shopId: authState.user!.id,
                  ),
                );
              }
            },
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: _buildBody(context, user, isDark),
    );
  }

  Widget _buildBody(BuildContext context, user, bool isDark) {
    // Проверяем доступ к магазину
    if (!ShopAccessChecker.hasShopAccess(user)) {
      return _buildNoAccessView(isDark);
    }

    return BlocConsumer<ShopBloc, ShopState>(
      listener: (context, state) {
        if (state is ShopError) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message)));
        } else if (state is ShopCreated) {
          // Перезагружаем магазин после создания
          _loadShop();
        }
      },
      builder: (context, state) {
        if (state is ShopLoading) {
          return Center(
            child: CircularProgressIndicator(color: Color(0xff917dfa)),
          );
        }

        if (state is ShopNotFound) {
          return _buildCreateShopView(context, user, isDark);
        }

        if (state is ShopLoaded) {
          return _buildShopView(context, state.shop, user, isDark);
        }

        return Center(
          child: CircularProgressIndicator(color: Color(0xff917dfa)),
        );
      },
    );
  }

  Widget _buildNoAccessView(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 100, color: Colors.grey),
            SizedBox(height: 20),
            Text(
              'Доступ ограничен',
              style: GoogleFonts.montserrat(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            SizedBox(height: 10),
            Text(
              ShopAccessChecker.getAccessDeniedMessage(),
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(fontSize: 14, color: Colors.grey),
            ),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                // Переход на страницу тарифов
                context.push('/tariffs');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xff917dfa),
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Выбрать тариф',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateShopView(BuildContext context, user, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.store_outlined, size: 100, color: Color(0xff917dfa)),
            SizedBox(height: 20),
            Text(
              'У вас еще нет магазина',
              style: GoogleFonts.montserrat(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Создайте свой магазин и начните продавать',
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(fontSize: 14, color: Colors.grey),
            ),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                context.read<ShopBloc>().add(
                  CreateShop(userId: user.id, token: user.token ?? ''),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xff917dfa),
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Создать магазин',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShopView(BuildContext context, Shop shop, user, bool isDark) {
    return RefreshIndicator(
      onRefresh: () async {
        _loadShop();
      },
      color: Color(0xff917dfa),
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок магазина с превью
            _ShopHeaderCard(shop: shop, isDark: isDark),
            SizedBox(height: 16),

            // Статистика
            _ShopStatsRow(shop: shop, isDark: isDark),
            SizedBox(height: 24),

            // Кнопка редактирования
            _EditShopButton(shop: shop, user: user),
            SizedBox(height: 12),

            // Дополнительные кнопки
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.bar_chart,
                    label: 'Статистика',
                    onPressed: () {
                      Navigator.of(context, rootNavigator: true).push(
                        createSwipeableRoute(
                          builder: (_) => ShopStatsScreen(shop: shop),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.link,
                    label: 'Ссылки',
                    onPressed: () async {
                      final result =
                          await Navigator.of(context, rootNavigator: true).push(
                            createSwipeableRoute(
                              builder: (_) => ShopSettingsScreen(
                                shopId: shop.id,
                                initialLinks: shop.links ?? [],
                              ),
                            ),
                          );

                      if (result == true && context.mounted) {
                        _loadShop();
                      }
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),

            // Слайдеры
            if (shop.sliders != null && shop.sliders!.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _SectionHeader(title: 'Слайдеры', isDark: isDark),
                  TextButton(
                    onPressed: () async {
                      final result =
                          await Navigator.of(context, rootNavigator: true).push(
                            createSwipeableRoute(
                              builder: (_) => ShopSlidersScreen(
                                shopId: shop.id,
                                shopTitle: shop.title,
                                shopDescription: shop.description,
                                themeCategoryId: shop.themeCategoryId,
                                initialSliders: shop.sliders!,
                              ),
                            ),
                          );

                      if (result == true && context.mounted) {
                        _loadShop();
                      }
                    },
                    child: Text(
                      'Управление1',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        color: Color(0xff917dfa),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              _ShopSlidersSection(sliders: shop.sliders!, isDark: isDark),
              SizedBox(height: 24),
            ] else ...[
              _SectionHeader(title: 'Слайдеры', isDark: isDark),
              SizedBox(height: 12),
              _buildAddSlidersButton(context, shop),
              SizedBox(height: 24),
            ],

            // Страницы
            if (shop.pages != null && shop.pages!.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _SectionHeader(title: 'Страницы', isDark: isDark),
                  TextButton(
                    onPressed: () async {
                      final result =
                          await Navigator.of(context, rootNavigator: true).push(
                            createSwipeableRoute(
                              builder: (_) => ShopPagesScreen(
                                shopId: shop.id,
                                initialPages: shop.pages!,
                              ),
                            ),
                          );

                      if (result == true && context.mounted) {
                        _loadShop();
                      }
                    },
                    child: Text(
                      'Управление',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        color: Color(0xff917dfa),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              _ShopPagesSection(pages: shop.pages!, isDark: isDark),
              SizedBox(height: 24),
            ] else ...[
              _SectionHeader(title: 'Страницы', isDark: isDark),
              SizedBox(height: 12),
              _buildAddPagesButton(context, shop),
              SizedBox(height: 24),
            ],

            // Статус модерации
            if (shop.status != 1) ...[
              _ShopStatusCard(shop: shop, isDark: isDark),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAddSlidersButton(BuildContext context, Shop shop) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[850]
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[700]!
              : Colors.grey[300]!,
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.photo_library_outlined, size: 40, color: Colors.grey),
          SizedBox(height: 12),
          Text(
            'Нет слайдеров',
            style: GoogleFonts.montserrat(fontSize: 14, color: Colors.grey),
          ),
          SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () async {
              final result = await Navigator.of(context, rootNavigator: true)
                  .push(
                    createSwipeableRoute(
                      builder: (_) => ShopSlidersScreen(
                        shopId: shop.id,
                        shopTitle: shop.title,
                        shopDescription: shop.description,
                        themeCategoryId: shop.themeCategoryId,
                        initialSliders: [],
                      ),
                    ),
                  );

              if (result == true && context.mounted) {
                _loadShop();
              }
            },
            icon: Icon(Icons.add, color: Colors.white, size: 18),
            label: Text(
              'Добавить слайдеры1',
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xff917dfa),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddPagesButton(BuildContext context, Shop shop) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[850]
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[700]!
              : Colors.grey[300]!,
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.description_outlined, size: 40, color: Colors.grey),
          SizedBox(height: 12),
          Text(
            'Нет страниц',
            style: GoogleFonts.montserrat(fontSize: 14, color: Colors.grey),
          ),
          SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () async {
              final result = await Navigator.of(context, rootNavigator: true)
                  .push(
                    createSwipeableRoute(
                      builder: (_) =>
                          ShopPagesScreen(shopId: shop.id, initialPages: []),
                    ),
                  );

              if (result == true && context.mounted) {
                _loadShop();
              }
            },
            icon: Icon(Icons.add, color: Colors.white, size: 18),
            label: Text(
              'Добавить страницы1',
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xff917dfa),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShopHeaderCard extends StatelessWidget {
  final Shop shop;
  final bool isDark;

  const _ShopHeaderCard({required this.shop, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Логотип
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: shop.logo != null
                ? CachedNetworkImage(
                    imageUrl: shop.logo!,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey[300],
                      child: Icon(Icons.store, color: Colors.grey),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey[300],
                      child: Icon(Icons.store, color: Colors.grey),
                    ),
                  )
                : Container(
                    width: 60,
                    height: 60,
                    color: Colors.grey[300],
                    child: Icon(Icons.store, color: Colors.grey),
                  ),
          ),
          SizedBox(width: 16),
          // Информация
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shop.title,
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (shop.description != null &&
                    shop.description!.isNotEmpty) ...[
                  SizedBox(height: 4),
                  Text(
                    shop.description!,
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShopStatsRow extends StatelessWidget {
  final Shop shop;
  final bool isDark;

  const _ShopStatsRow({required this.shop, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Первый ряд: Объявления и Товары
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.shopping_bag_outlined,
                  value: shop.adsCount.toString(),
                  label: 'Объявления',
                  isDark: isDark,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.inventory_2_outlined,
                  value: shop.adsCount.toString(),
                  label: 'Товары',
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
        // Второй ряд: Подписчики на всю ширину
        SizedBox(
          width: double.infinity,
          child: _StatCard(
            icon: Icons.people_outline,
            value: shop.subscribersCount.toString(),
            label: 'Подписчики',
            isDark: isDark,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final bool isDark;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        children: [
          Icon(icon, color: Color(0xff917dfa), size: 24),
          SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.montserrat(fontSize: 11, color: Colors.grey),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _EditShopButton extends StatelessWidget {
  final Shop shop;
  final user;

  const _EditShopButton({required this.shop, required this.user});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          final result = await Navigator.of(context, rootNavigator: true).push(
            createSwipeableRoute(
              builder: (_) => ShopEditScreen(shopId: shop.id.toString()),
            ),
          );

          // Если вернулись с флагом обновления - перезагружаем магазин
          if (result == true && context.mounted) {
            context.read<ShopBloc>().add(
              LoadShop(
                userId: user.id,
                token: user.token ?? '',
                shopId: shop.id,
              ),
            );
          }
        },
        icon: Icon(Icons.edit, color: Colors.white),
        label: Text(
          'Редактировать магазин',
          style: GoogleFonts.montserrat(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xff917dfa),
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: Color(0xff917dfa), size: 20),
      label: Text(
        label,
        style: GoogleFonts.montserrat(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: isDark ? Colors.grey[850] : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        padding: EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
          ),
        ),
        elevation: 0,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final bool isDark;

  const _SectionHeader({required this.title, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.montserrat(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white : Colors.black,
      ),
    );
  }
}

class _ShopSlidersSection extends StatelessWidget {
  final List<ShopSlider> sliders;
  final bool isDark;

  const _ShopSlidersSection({required this.sliders, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: sliders.length,
        itemBuilder: (context, index) {
          final slider = sliders[index];
          return Container(
            width: 200,
            margin: EdgeInsets.only(right: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: slider.link,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[300],
                  child: Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[300],
                  child: Icon(Icons.image, color: Colors.grey),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ShopPagesSection extends StatelessWidget {
  final List<ShopPage> pages;
  final bool isDark;

  const _ShopPagesSection({required this.pages, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: pages.map((page) {
        return Container(
          margin: EdgeInsets.only(bottom: 12),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[850] : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.description_outlined, color: Color(0xff917dfa)),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      page.name,
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    if (page.text.isNotEmpty) ...[
                      SizedBox(height: 4),
                      Text(
                        _stripHtmlTags(page.text),
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// Удаляет HTML теги из текста для отображения в списке
String _stripHtmlTags(String html) {
  return html.replaceAll(RegExp(r'<[^>]*>'), '').trim();
}

class _ShopStatusCard extends StatelessWidget {
  final Shop shop;
  final bool isDark;

  const _ShopStatusCard({required this.shop, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final isModeration = shop.status == 0;
    final isRejected = shop.status == 2;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isRejected
            ? Colors.red.withOpacity(0.1)
            : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isRejected ? Colors.red : Colors.orange,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isRejected ? Icons.error_outline : Icons.info_outline,
            color: isRejected ? Colors.red : Colors.orange,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isModeration ? 'На модерации' : 'Отклонен',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isRejected ? Colors.red : Colors.orange,
                  ),
                ),
                if (shop.statusNote != null && shop.statusNote!.isNotEmpty) ...[
                  SizedBox(height: 4),
                  Text(
                    shop.statusNote!,
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

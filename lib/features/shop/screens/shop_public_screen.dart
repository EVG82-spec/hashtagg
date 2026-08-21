//G:\hashtagg_app\lib\features\shop\screens\shop_public_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hashtagg/features/shop/bloc/public/shop_public_bloc.dart';
import 'package:hashtagg/features/shop/bloc/public/shop_public_state.dart';
import 'package:hashtagg/features/shop/bloc/public/shop_public_event.dart';
import 'package:hashtagg/features/shop/widgets/shop_banner.dart';
import 'package:hashtagg/features/shop/widgets/shop_categories_bottom_sheet.dart';
import 'package:hashtagg/features/shop/widgets/shop_profile.dart';
import 'package:hashtagg/features/shop/widgets/shop_search_bar.dart';
import 'package:hashtagg/features/shop/widgets/shop_social_icons.dart';
import 'package:hashtagg/features/shop/widgets/shop_stats.dart';
import 'package:hashtagg/features/shop/widgets/shop_actions.dart';
import 'package:hashtagg/features/shop/widgets/shop_navigation.dart';
import 'package:hashtagg/features/shop/widgets/shop_ads_grid.dart';
import 'package:hashtagg/features/shop/widgets/shop_status_banner.dart';
import 'package:hashtagg/features/shop/models/shop.dart';

class ShopPublicScreen extends StatefulWidget {
  final String shopId;

  const ShopPublicScreen({Key? key, required this.shopId}) : super(key: key);

  @override
  State<ShopPublicScreen> createState() => _ShopPublicScreenState();
}

class _ShopPublicScreenState extends State<ShopPublicScreen> {
  int? _selectedPageId;
  String? _selectedPageContent;
  int? _currentStatus;
  bool _isLoading = true; // 👈 ДОБАВЛЯЕМ ФЛАГ

  @override
  void initState() {
    super.initState();
    // ✅ ЗАГРУЖАЕМ ДАННЫЕ В initState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        print(
          '🔄 [ShopPublic] initState: calling LoadPublicShop with forceRefresh=true',
        );
        print('🔄 [ShopPublic] initState - loading shop data');
        context.read<ShopPublicBloc>().add(
          LoadPublicShop(shopId: widget.shopId, forceRefresh: true),
        );
        print('✅ [ShopPublic] initState: LoadPublicShop event sent');
      }
    });
  }

  void _onPageSelected(int pageId) {
    print('📄 [ShopPublic] _onPageSelected: $pageId');

    setState(() {
      _selectedPageId = pageId;
    });

    if (pageId == 0) {
      setState(() {
        _selectedPageContent = null;
      });
      print('🏠 [ShopPublic] Switching to Главная');
    } else {
      final state = context.read<ShopPublicBloc>().state;
      if (state is ShopPublicLoaded) {
        final page = state.shop.pages?.firstWhere(
          (p) => p.id == pageId,
          orElse: () => null as ShopPage,
        );
        if (page != null) {
          setState(() {
            _selectedPageContent = page.text;
          });
          print(
            '📄 [ShopPublic] Page found: ${page.name}, content length: ${page.text.length}',
          );
        } else {
          setState(() {
            _selectedPageContent = null;
          });
          print('⚠️ [ShopPublic] Page not found: $pageId');
        }
      }
    }
  }

  String _stripHtmlTags(String html) {
    if (html.isEmpty) return '';
    return html.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ НЕ ЧИТАЕМ state В build()!

    return Scaffold(
      backgroundColor: Colors.white,
      // ❌ УБИРАЕМ СТАНДАРТНЫЙ AppBar
      // appBar: AppBar(...),

      // ✅ ДОБАВЛЯЕМ КАСТОМНЫЙ ХЕДЕР В body
      body: BlocBuilder<ShopPublicBloc, ShopPublicState>(
        builder: (context, state) {
          if (state is ShopPublicLoading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF8956FF),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Загрузка магазина...',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                ],
              ),
            );
          }

          if (state is ShopPublicLoaded) {
            final shop = state.shop;
            final ads = state.ads;

            print('🔍 [ShopPublic] ShopPublicLoaded');
            print('   pages count: ${shop.pages?.length ?? 0}');
            print('   status: ${shop.status}');

            // ✅ ВОЗВРАЩАЕМ КОЛОНКУ С ХЕДЕРОМ И КОНТЕНТОМ
            return Column(
              children: [
                // ✅ КАСТОМНЫЙ ХЕДЕР (вместо AppBar)
                _buildShopHeader(context, shop),
                // ✅ КОНТЕНТ (CustomScrollView)
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(child: ShopBanner(shop: shop)),
                      SliverToBoxAdapter(child: ShopStatusBanner(shop: shop)),
                      SliverToBoxAdapter(child: ShopProfile(shop: shop)),
                      SliverToBoxAdapter(child: ShopStats(shop: shop)),
                      SliverToBoxAdapter(child: ShopActions(shop: shop)),
                      SliverToBoxAdapter(
                        child: ShopNavigation(
                          shop: shop,
                          isEditing: false,
                          onPageSelected: _onPageSelected,
                          currentPageId: _selectedPageId,
                        ),
                      ),
                      if (_selectedPageId != null &&
                          _selectedPageId != 0 &&
                          _selectedPageContent != null)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Text(
                                _stripHtmlTags(_selectedPageContent!),
                                style: TextStyle(
                                  fontSize: 16,
                                  height: 1.6,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (_selectedPageId == null || _selectedPageId == 0)
                        SliverPadding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          sliver: ShopAdsGrid(ads: ads),
                        ),
                    ],
                  ),
                ),
              ],
            );
          }

          if (state is ShopPublicError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Ошибка загрузки',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    state.message,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      context.read<ShopPublicBloc>().add(
                        LoadPublicShop(
                          shopId: widget.shopId,
                          forceRefresh: true,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF8956FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                    ),
                    child: Text('Повторить'),
                  ),
                ],
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  // ✅ МЕТОД ДЛЯ СОЗДАНИЯ ХЕДЕРА
  Widget _buildShopHeader(BuildContext context, Shop shop) {
    return SafeArea(
      child: Container(
        // ❌ УБИРАЕМ color
        // color: Colors.white,

        // ✅ ЦВЕТ ПЕРЕНОСИМ В decoration
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white, // 👈 ПЕРЕНОСИМ СЮДА
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            // Кнопка "Назад"
            IconButton(
              icon: Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20),
              onPressed: () => Navigator.pop(context),
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(),
            ),
            SizedBox(width: 8),

            // Кнопка "Категории"
            GestureDetector(
              onTap: () {
                print('📂 [ShopHeader] Categories button tapped');
                _showCategoriesModal(context, shop);
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Color(0xFF8956FF),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Icon(Icons.grid_view, color: Colors.white, size: 18),
                    SizedBox(width: 4),
                  ],
                ),
              ),
            ),
            SizedBox(width: 12),

            // Поле поиска
            Expanded(child: ShopSearchBar(shopId: shop.id)),

            // Кнопка меню
            IconButton(
              icon: Icon(Icons.more_vert, color: Colors.black87),
              onPressed: () {},
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ МЕТОД ДЛЯ ОТКРЫТИЯ КАТЕГОРИЙ
  void _showCategoriesModal(BuildContext context, Shop shop) {
    print('📂 [ShopPublic] Opening categories modal');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ShopCategoriesBottomSheet(shop: shop),
    ).then((selectedCategoryId) {
      if (selectedCategoryId != null && selectedCategoryId is int) {
        print('📂 [ShopPublic] Category selected: $selectedCategoryId');
        // ✅ ЗАГРУЖАЕМ ТОВАРЫ ПО КАТЕГОРИИ
        _loadShopAdsByCategory(selectedCategoryId);
      } else {
        print('ℹ️ [ShopPublic] No category selected');
      }
    });
  }

  void _loadShopAdsByCategory(int categoryId) {
    print('📂 [ShopPublic] Loading ads for category: $categoryId');

    // ✅ ВЫЗЫВАЕМ BLoC ДЛЯ ЗАГРУЗКИ ТОВАРОВ ПО КАТЕГОРИИ
    context.read<ShopPublicBloc>().add(
      LoadPublicShop(
        shopId: widget.shopId,
        forceRefresh: true,
        categoryId: categoryId, // 👈 ПЕРЕДАЕМ КАТЕГОРИЮ
      ),
    );
  }
}

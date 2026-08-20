// lib/features/shop/screens/shop_public_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hashtagg/features/shop/bloc/public/shop_public_bloc.dart';
import 'package:hashtagg/features/shop/bloc/public/shop_public_state.dart';
import 'package:hashtagg/features/shop/bloc/public/shop_public_event.dart';
import 'package:hashtagg/features/shop/models/shop.dart';
import 'package:hashtagg/features/shop/widgets/shop_banner.dart';
import 'package:hashtagg/features/shop/widgets/shop_profile.dart';
import 'package:hashtagg/features/shop/widgets/shop_stats.dart';
import 'package:hashtagg/features/shop/widgets/shop_actions.dart';
import 'package:hashtagg/features/shop/widgets/shop_navigation.dart';
import 'package:hashtagg/features/shop/widgets/shop_ads_grid.dart';
import 'package:hashtagg/features/shop/widgets/shop_status_banner.dart';

class ShopPublicScreen extends StatefulWidget {
  final String shopId;

  const ShopPublicScreen({Key? key, required this.shopId}) : super(key: key);

  @override
  State<ShopPublicScreen> createState() => _ShopPublicScreenState();
}

class _ShopPublicScreenState extends State<ShopPublicScreen> {
  int? _selectedPageId;
  String? _selectedPageContent;

  void _onPageSelected(int pageId) {
    print('📄 [ShopPublic] _onPageSelected: $pageId');

    setState(() {
      _selectedPageId = pageId;
    });

    if (pageId == 0) {
      // Главная - показываем товары
      setState(() {
        _selectedPageContent = null;
      });
      print('🏠 [ShopPublic] Switching to Главная');
    } else {
      // Ищем страницу по id
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

  @override
  Widget build(BuildContext context) {
    context.read<ShopPublicBloc>().add(LoadPublicShop(shopId: widget.shopId));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Магазин',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert, color: Colors.black87),
            onPressed: () {
              // TODO: Меню магазина
            },
          ),
        ],
      ),
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
            print('   selectedPageId: $_selectedPageId');
            print('   has content: ${_selectedPageContent != null}');

            return CustomScrollView(
              slivers: [
                // 1. Баннер
                SliverToBoxAdapter(child: ShopBanner(shop: shop)),
                // 2. Статус
                SliverToBoxAdapter(child: ShopStatusBanner(shop: shop)),
                // 3. Профиль
                SliverToBoxAdapter(child: ShopProfile(shop: shop)),
                // 4. Статистика
                SliverToBoxAdapter(child: ShopStats(shop: shop)),
                // 5. Соцсети + подписка
                SliverToBoxAdapter(child: ShopActions(shop: shop)),
                // 6. Навигация (Главная + страницы)
                SliverToBoxAdapter(
                  child: ShopNavigation(
                    shop: shop,
                    isEditing: false,
                    onPageSelected: _onPageSelected,
                    currentPageId: _selectedPageId,
                  ),
                ),
                // 7. Контент страницы (если выбрана)
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
                          _stripHtmlTags(
                            _selectedPageContent!,
                          ), // 👈 ОЧИЩАЕМ ОТ HTML
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.6,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ),
                // 8. Товары (только если на главной)
                if (_selectedPageId == null || _selectedPageId == 0)
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    sliver: ShopAdsGrid(ads: ads),
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
                        LoadPublicShop(shopId: widget.shopId),
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

  String _stripHtmlTags(String html) {
    if (html.isEmpty) return '';
    return html.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  }
}

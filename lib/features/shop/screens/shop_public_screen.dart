// lib/features/shop/screens/shop_public_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hashtagg/features/shop/bloc/public/shop_public_bloc.dart';
import 'package:hashtagg/features/shop/bloc/public/shop_public_state.dart';
import 'package:hashtagg/features/shop/bloc/public/shop_public_event.dart';
import 'package:hashtagg/features/shop/widgets/shop_banner.dart';
import 'package:hashtagg/features/shop/widgets/shop_profile.dart';
import 'package:hashtagg/features/shop/widgets/shop_stats.dart';
import 'package:hashtagg/features/shop/widgets/shop_actions.dart';
import 'package:hashtagg/features/shop/widgets/shop_navigation.dart';
import 'package:hashtagg/features/shop/widgets/shop_ads_grid.dart';
import 'package:hashtagg/features/shop/widgets/shop_page_content.dart';
import 'package:hashtagg/features/shop/widgets/shop_empty_state.dart';
import 'package:hashtagg/features/shop/widgets/shop_status_banner.dart';


class ShopPublicScreen extends StatelessWidget {
  final String shopId;

  const ShopPublicScreen({Key? key, required this.shopId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    context.read<ShopPublicBloc>().add(LoadPublicShop(shopId: shopId));
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
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }

          if (state is ShopPublicLoaded) {
            final shop = state.shop;
            final ads = state.ads;

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: ShopBanner(shop: shop),
                ),
                SliverToBoxAdapter(
                  child: ShopStatusBanner(shop: shop), // 👈 ДОБАВИТЬ
                ),
                SliverToBoxAdapter(
                  child: ShopProfile(shop: shop),
                ),
                SliverToBoxAdapter(
                  child: ShopStats(shop: shop),
                ),
                SliverToBoxAdapter(
                  child: ShopActions(shop: shop),
                ),
                SliverToBoxAdapter(
                  child: ShopNavigation(shop: shop),
                ),
                // Товары (временно без страниц)
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
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      context.read<ShopPublicBloc>().add(
                        LoadPublicShop(shopId: shopId),
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

          return SizedBox.shrink();
        },
      ),
    );
  }
}
// lib/features/shop/widgets/shop_ads_grid.dart
import 'package:flutter/material.dart';
import 'package:hashtagg/core/network/home_api_repository.dart';
import 'shop_ad_card.dart';

class ShopAdsGrid extends StatelessWidget {
  final List<FeedAd> ads;

  const ShopAdsGrid({Key? key, required this.ads}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print('📊 [ShopAdsGrid] Building with ${ads.length} ads');

    if (ads.isNotEmpty) {
      final first = ads.first;
      print('📊 [ShopAdsGrid] FIRST AD:');
      print('   id: ${first.id}');
      print('   title: ${first.title}');
      print('   images: ${first.images}');
      print('   images length: ${first.images.length}');
      print('   price: ${first.price}');
    }

    if (ads.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.storefront_outlined, size: 64, color: Colors.grey.shade300),
              SizedBox(height: 16),
              Text('Товаров пока нет', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              Text('В этом магазине еще нет товаров', style: TextStyle(color: Colors.grey.shade500)),
            ],
          ),
        ),
      );
    }

    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.55,  // 👈 УВЕЛИЧИЛ ВЫСОТУ КАРТОЧКИ
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      delegate: SliverChildBuilderDelegate(
            (context, index) {
          final ad = ads[index];
          return ShopAdCard(ad: ad);
        },
        childCount: ads.length,
      ),
    );
  }
}
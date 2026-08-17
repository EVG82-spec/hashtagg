// lib/features/shop/widgets/shop_banner.dart
import 'package:flutter/material.dart';
import 'package:hashtagg/features/shop/models/shop.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ShopBanner extends StatelessWidget {
  final Shop shop;

  const ShopBanner({Key? key, required this.shop}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bannerUrl = shop.bannerUrl; // Используем геттер
    print('🖼️ [ShopBanner] bannerUrl: $bannerUrl');

    return Container(
      height: 250,
      width: double.infinity,
      decoration: BoxDecoration(
        image: bannerUrl != null && bannerUrl.isNotEmpty
            ? DecorationImage(
          image: CachedNetworkImageProvider(bannerUrl),
          fit: BoxFit.cover,
        )
            : null,
        color: Colors.grey.shade200,
      ),
      child: bannerUrl == null || bannerUrl.isEmpty
          ? Center(
        child: Icon(
          Icons.storefront,
          size: 64,
          color: Colors.grey.shade400,
        ),
      )
          : null,
    );
  }
}
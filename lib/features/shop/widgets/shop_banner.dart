// lib/features/shop/widgets/shop_banner.dart
import 'package:flutter/material.dart';
import 'package:hashtagg/features/shop/models/shop.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ShopBanner extends StatelessWidget {
  final Shop shop;
  final bool isEditing;
  final VoidCallback? onBannerTap;

  const ShopBanner({
    Key? key,
    required this.shop,
    this.isEditing = false,
    this.onBannerTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bannerUrl = shop.bannerUrl;
    final hasCustomBanner =
        shop.logo != null &&
        shop.logo!.isNotEmpty &&
        !shop.logo!.contains('icon_photo.png') &&
        !shop.logo!.contains('others/');
    final isDraft = shop.status == 3 && !hasCustomBanner;

    print('🖼️ [ShopBanner] build()');
    print('   shop.status: ${shop.status}');
    print('   shop.sliders: ${shop.sliders}');
    print('   bannerUrl: $bannerUrl');
    print('   isEditing: $isEditing');
    print('   isDraft: $isDraft');

    return GestureDetector(
      onTap: isEditing ? onBannerTap : null,
      child: Container(
        height: 250,
        width: double.infinity,
        decoration: BoxDecoration(
          image: isDraft
              ? const DecorationImage(
                  image: NetworkImage(
                    'https://hashtagg.ru/templates/img/bg.png',
                  ),
                  fit: BoxFit.cover,
                )
              : (bannerUrl != null && bannerUrl.isNotEmpty
                    ? DecorationImage(
                        image: CachedNetworkImageProvider(bannerUrl),
                        fit: BoxFit.cover,
                      )
                    : const DecorationImage(
                        image: NetworkImage(
                          'https://hashtagg.ru/templates/img/bg.png',
                        ),
                        fit: BoxFit.cover,
                      )),
          color: Colors.grey.shade200,
        ),
        child: isEditing
            ? Container(
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.3)),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.camera_alt,
                        size: 48,
                        color: Colors.white.withOpacity(0.8),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Нажмите чтобы изменить баннер',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

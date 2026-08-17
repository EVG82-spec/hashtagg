// lib/features/shop/widgets/shop_profile.dart
import 'package:flutter/material.dart';
import 'package:hashtagg/features/shop/models/shop.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ShopProfile extends StatelessWidget {
  final Shop shop;

  const ShopProfile({Key? key, required this.shop}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final avatarUrl = shop.avatarUrl; // Используем геттер
    print('🖼️ [ShopProfile] avatarUrl: $avatarUrl');

    return Container(
      padding: EdgeInsets.fromLTRB(15, 14, 15, 10),
      margin: EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Transform.translate(
            offset: Offset(0, -20),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
                image: avatarUrl != null && avatarUrl.isNotEmpty
                    ? DecorationImage(
                  image: CachedNetworkImageProvider(avatarUrl),
                  fit: BoxFit.cover,
                )
                    : DecorationImage(
                  image: AssetImage('assets/images/default_avatar.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              shop.title.isNotEmpty ? shop.title : 'Магазин',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
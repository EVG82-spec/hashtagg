// lib/features/shop/widgets/shop_profile.dart
import 'package:flutter/material.dart';
import 'package:hashtagg/features/shop/models/shop.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ShopProfile extends StatelessWidget {
  final Shop shop;
  final bool isEditing;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onTitleTap;

  const ShopProfile({
    Key? key,
    required this.shop,
    this.isEditing = false,
    this.onAvatarTap,
    this.onTitleTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final avatarUrl = shop.avatarUrl;

    print('🖼️ [ShopProfile] avatarUrl: $avatarUrl');
    print('🖼️ [ShopProfile] isEditing: $isEditing');

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
          // Аватарка
          GestureDetector(
            onTap: isEditing ? onAvatarTap : null,
            child: Transform.translate(
              offset: Offset(0, -20),
              child: Stack(
                children: [
                  Container(
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
                          : const DecorationImage(
                        image: NetworkImage('https://hashtagg.ru/templates/img/av.jpeg'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  if (isEditing)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Color(0xFF8956FF),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Icon(
                          Icons.camera_alt,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(width: 12),
          // Название - БЕЗ Expanded (используем Flexible)
          Flexible(
            child: GestureDetector(
              onTap: isEditing ? onTitleTap : null,
              child: Container(
                padding: isEditing ? EdgeInsets.symmetric(horizontal: 8, vertical: 4) : EdgeInsets.zero,
                decoration: isEditing
                    ? BoxDecoration(
                  border: Border.all(color: Color(0xFF8956FF), width: 1),
                  borderRadius: BorderRadius.circular(4),
                )
                    : null,
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        shop.title.isNotEmpty ? shop.title : 'Название магазина',
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
                    if (isEditing)
                      Icon(
                        Icons.edit,
                        size: 16,
                        color: Color(0xFF8956FF),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
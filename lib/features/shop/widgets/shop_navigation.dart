// lib/features/shop/widgets/shop_navigation.dart
import 'package:flutter/material.dart';
import 'package:hashtagg/features/shop/models/shop.dart';

class ShopNavigation extends StatelessWidget {
  final Shop shop;
  final bool isEditing;
  final VoidCallback? onAddPage;

  const ShopNavigation({
    Key? key,
    required this.shop,
    this.isEditing = false,
    this.onAddPage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final pages = shop.pages ?? [];

    // Если нет страниц - не показываем
    if (pages.isEmpty) {
      return SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Главная
            _NavButton(
              title: 'Главная',
              isActive: false,
              onTap: () {
                // TODO: Переключить на главную
              },
            ),
            SizedBox(width: 6),
            // Страницы
            ...pages.map((page) => Padding(
              padding: EdgeInsets.only(right: 6),
              child: _NavButton(
                title: page.name,
                isActive: false,
                onTap: () {
                  // TODO: Переключить на страницу
                },
              ),
            )),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final String title;
  final bool isActive;
  final VoidCallback onTap;

  const _NavButton({
    required this.title,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? Color(0xFFDCF4FF) : Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1A1F29),
          ),
        ),
      ),
    );
  }
}
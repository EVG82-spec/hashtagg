// lib/features/shop/widgets/shop_navigation.dart
import 'package:flutter/material.dart';
import 'package:hashtagg/features/shop/models/shop.dart';

class ShopNavigation extends StatelessWidget {
  final Shop shop;
  final bool isEditing;
  final VoidCallback? onAddPage;
  final Function(int)? onPageSelected;
  final int? currentPageId;

  const ShopNavigation({
    Key? key,
    required this.shop,
    this.isEditing = false,
    this.onAddPage,
    this.onPageSelected,
    this.currentPageId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final pages = shop.pages ?? [];

    print('🔍 [ShopNavigation] build()');
    print('   pages count: ${pages.length}');
    print('   isEditing: $isEditing');
    print('   currentPageId: $currentPageId');

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
        ),
      ),
      child: Column(
        children: [
          // Навигация по страницам
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Главная
                _NavButton(
                  title: 'Главная',
                  isActive: currentPageId == null,
                  onTap: () {
                    print('🏠 [ShopNavigation] Главная');
                    if (onPageSelected != null) {
                      onPageSelected!(0); // 0 = главная
                    }
                  },
                ),
                SizedBox(width: 6),
                // Страницы
                if (pages.isNotEmpty)
                  ...pages.map(
                    (page) => Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: _NavButton(
                        title: page.name,
                        isActive: currentPageId == page.id,
                        onTap: () {
                          print(
                            '📄 [ShopNavigation] Страница: ${page.name} (id: ${page.id})',
                          );
                          if (onPageSelected != null) {
                            onPageSelected!(page.id);
                          }
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Кнопка "Добавить страницу" (только в режиме редактирования)
          if (isEditing && onAddPage != null)
            Padding(
              padding: EdgeInsets.only(top: 12, left: 4, right: 4),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onAddPage,
                  icon: Icon(Icons.add, color: Colors.white, size: 20),
                  label: Text(
                    'Добавить страницу',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF8956FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    minimumSize: Size(double.infinity, 48),
                  ),
                ),
              ),
            ),
        ],
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
          border: isActive
              ? Border.all(color: Color(0xFF8956FF), width: 1.5)
              : null,
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isActive ? Color(0xFF8956FF) : Color(0xFF1A1F29),
          ),
        ),
      ),
    );
  }
}

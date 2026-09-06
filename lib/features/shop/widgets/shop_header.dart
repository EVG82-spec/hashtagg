// lib/features/shop/widgets/shop_header.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hashtagg/features/shop/models/shop.dart';
import 'package:hashtagg/features/shop/widgets/shop_categories_bottom_sheet.dart';

class ShopHeader extends StatelessWidget {
  final Shop shop;
  final bool isEditing;

  const ShopHeader({Key? key, required this.shop, this.isEditing = false})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          // Кнопка "Категории"
          GestureDetector(
            onTap: () => _showCategoriesModal(context),
            child: SizedBox(
              width: 20, // 👈 ШИРИНА
              height: 20, // 👈 ВЫСОТА
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  color: Color(0xFF8956FF),
                  borderRadius: BorderRadius.circular(80),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.grid_view,
                      color: Colors.white,
                      size: 20, // 👈 УВЕЛИЧИТЬ РАЗМЕР ИКОНКИ (было 16)
                    ),
                    SizedBox(width: 4), // 👈 УМЕНЬШИТЬ ОТСТУП (было 20)
                    Text(
                      'Категории',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(width: 20),
          // Поле поиска
          Expanded(
            child: GestureDetector(
              onTap: () {
                // Открыть SearchScreen с shopId
                context.push('/search?shop_id=${shop.id}');
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, color: Colors.grey.shade500, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Поиск',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Действия (в режиме редактора)
          if (isEditing)
            IconButton(
              icon: Icon(Icons.edit, color: Color(0xFF8956FF)),
              onPressed: () {},
            ),
        ],
      ),
    );
  }

  void _showCategoriesModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ShopCategoriesBottomSheet(shop: shop),
    );
  }
}

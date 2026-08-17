// lib/features/shop/widgets/shop_stats.dart
import 'package:flutter/material.dart';
import 'package:hashtagg/features/shop/models/shop.dart';

class ShopStats extends StatelessWidget {
  final Shop shop;

  const ShopStats({Key? key, required this.shop}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Используем правильные поля
    final reviewsCount = 0; // пока нет поля, ставим 0
    final adsCount = shop.adsCount;
    final subscribersCount = shop.subscribersCount;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Row(
        children: [
          _StatCard(
            number: reviewsCount,
            title: 'Отзывы',
          ),
          SizedBox(width: 8),
          _StatCard(
            number: adsCount,
            title: 'Товары',
          ),
          SizedBox(width: 8),
          _StatCard(
            number: subscribersCount,
            title: 'Подписчики',
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final int number;
  final String title;

  const _StatCard({
    required this.number,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade200, width: 1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              number.toString(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1F29),
              ),
            ),
            SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
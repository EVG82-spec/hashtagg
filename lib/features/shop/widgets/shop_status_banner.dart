// lib/features/shop/widgets/shop_status_banner.dart
import 'package:flutter/material.dart';
import 'package:hashtagg/features/shop/models/shop.dart';

class ShopStatusBanner extends StatelessWidget {
  final Shop shop;

  const ShopStatusBanner({Key? key, required this.shop}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // ❌ НЕ ПОКАЗЫВАЕМ СТАТУС ВЛАДЕЛЬЦУ
    if (shop.isOwner) {
      return const SizedBox.shrink();
    }

    // ❌ НЕ ПОКАЗЫВАЕМ СТАТУС "ЧЕРНОВИК" (3) — ЭТО ДЕФОЛТНЫЙ МАГАЗИН
    if (shop.status == 3) {
      return const SizedBox.shrink();
    }

    // ❌ НЕ ПОКАЗЫВАЕМ СТАТУС "НА МОДЕРАЦИИ" (0)
    if (shop.status == 0) {
      return const SizedBox.shrink();
    }

    // Статус 2 - отклонен (показываем)
    if (shop.status == 2) {
      return _buildRejectedBanner();
    }

    // Статус 1 - активен (ничего не показываем)
    return const SizedBox.shrink();
  }

  Widget _buildRejectedBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        border: Border.all(color: const Color(0xFFEF4444)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('❌', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Магазин не прошёл модерацию',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF991B1B),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Комментарий модератора:',
                  style: TextStyle(
                    color: Color(0xFF7F1D1D),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Text(
                    shop.statusNote ?? 'Причина не указана',
                    style: const TextStyle(
                      color: Color(0xFF991B1B),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Отклонён',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
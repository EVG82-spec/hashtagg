// lib/features/shop/widgets/shop_status_banner.dart
import 'package:flutter/material.dart';
import 'package:hashtagg/features/shop/models/shop.dart';

class ShopStatusBanner extends StatelessWidget {
  final Shop shop;

  const ShopStatusBanner({Key? key, required this.shop}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Показываем только владельцу
    if (!shop.isOwner) return SizedBox.shrink();

    // Статус 0 - на модерации
    if (shop.status == 0) {
      return _buildModerationBanner();
    }

    // Статус 2 - отклонен
    if (shop.status == 2) {
      return _buildRejectedBanner();
    }

    // Статус 3 - черновик, ничего не показываем
    return SizedBox.shrink();
  }

  Widget _buildModerationBanner() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Color(0xFFFEF3C7),
        border: Border.all(color: Color(0xFFF59E0B)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text('⏳', style: TextStyle(fontSize: 28)),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Магазин на модерации',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF92400E),
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'После проверки магазин станет доступен для всех пользователей.',
                  style: TextStyle(
                    color: Color(0xFF78350F),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Color(0xFFF59E0B),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'На проверке',
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

  Widget _buildRejectedBanner() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Color(0xFFFEE2E2),
        border: Border.all(color: Color(0xFFEF4444)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('❌', style: TextStyle(fontSize: 28)),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Магазин не прошёл модерацию',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF991B1B),
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Комментарий модератора:',
                  style: TextStyle(
                    color: Color(0xFF7F1D1D),
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Color(0xFFFCA5A5)),
                  ),
                  child: Text(
                    shop.statusNote ?? 'Причина не указана',
                    style: TextStyle(
                      color: Color(0xFF991B1B),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Color(0xFFEF4444),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
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
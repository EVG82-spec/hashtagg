// lib/features/shop/widgets/shop_qr_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hashtagg/features/shop/models/shop.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ShopQrWidget extends StatelessWidget {
  final Shop shop;
  final double size;

  const ShopQrWidget({Key? key, required this.shop, this.size = 100})
    : super(key: key);

  String get _shopUrl =>
      'https://hashtagg.ru/shop/${shop.slug ?? shop.idHash ?? shop.id}';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white70 : Colors.grey.shade600;
    final bgColor = isDark ? const Color(0xff1a1a2e) : Colors.white;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // QR-код (100x100)
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: QrImageView(
                data: _shopUrl,
                version: QrVersions.auto,
                size: size,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Информация
          Text(
            '📱 QR-код магазина',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Отсканируйте, чтобы открыть магазин',
            style: TextStyle(fontSize: 13, color: subtitleColor),
          ),
          const SizedBox(height: 16),

          // Ссылка на магазин
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xff2a2a3e) : const Color(0xFFF5F7FA),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? Colors.white24 : Colors.grey.shade200,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _shopUrl,
                    style: TextStyle(
                      fontSize: 13,
                      color: const Color(0xFF8956FF),
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _copyShopLink(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8956FF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.copy,
                      size: 16,
                      color: const Color(0xFF8956FF),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Кнопки: Поделиться и Копировать
          Row(
            children: [
              // Кнопка "Поделиться"
              Expanded(
                child: _buildActionButton(
                  icon: Icons.share,
                  label: 'Поделиться',
                  onTap: () => _shareLink(context),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              // Кнопка "Копировать"
              Expanded(
                child: _buildActionButton(
                  icon: Icons.copy,
                  label: 'Копировать',
                  onTap: () => _copyShopLink(context),
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF8956FF).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF8956FF).withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: const Color(0xFF8956FF)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF8956FF),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _copyShopLink(BuildContext context) {
    Clipboard.setData(ClipboardData(text: _shopUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Ссылка скопирована!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _shareLink(BuildContext context) async {
    try {
      await Share.share(
        '📱 Магазин ${shop.title}\n$_shopUrl',
        subject: shop.title,
      );
    } catch (e) {
      _copyShopLink(context);
    }
  }
}

class _QrButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _QrButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF8956FF).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF8956FF)),
        ),
      ),
    );
  }
}

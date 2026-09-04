// lib/features/shop/widgets/shop_qr_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hashtagg/features/shop/models/shop.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ShopQrWidget extends StatelessWidget {
  final Shop shop;

  const ShopQrWidget({Key? key, required this.shop}) : super(key: key);

  String get _shopUrl => 'https://hashtagg.ru/shop/${shop.idHash}';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // QR-код
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: QrImageView(
                data: _shopUrl,
                version: QrVersions.auto,
                size: 60,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Информация
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📱 QR-код магазина',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Отсканируйте, чтобы открыть магазин на телефоне',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          // Кнопки
          Row(
            children: [
              _QrButton(
                icon: Icons.share,
                tooltip: 'Поделиться ссылкой',
                onTap: () => _shareLink(context),
              ),
              const SizedBox(width: 4),
              _QrButton(
                icon: Icons.copy,
                tooltip: 'Копировать ссылку',
                onTap: () => _copyShopLink(context),
              ),
            ],
          ),
        ],
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
      await Share.share('Магазин ${shop.title}\n$_shopUrl');
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

// lib/features/shop/widgets/shop_actions.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hashtagg/features/shop/models/shop.dart';
import 'package:go_router/go_router.dart';
import 'shop_management_modal.dart';
import 'package:hashtagg/features/shop/bloc/shop_bloc.dart';

class ShopActions extends StatelessWidget {
  final Shop shop;
  final bool isEditing;
  final VoidCallback? onSocialEdit;

  const ShopActions({
    Key? key,
    required this.shop,
    this.isEditing = false,
    this.onSocialEdit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isOwner = shop.isOwner;

    // Берем ссылки из shop.links
    final List<Map<String, String>> socialLinks = [];

    if (shop.links != null) {
      for (var link in shop.links!) {
        if (link.link != null && link.link!.isNotEmpty) {
          String iconType = 'link';
          final text = (link.text ?? '').toLowerCase();
          if (text.contains('telegram') ||
              text.contains('tg') ||
              text.contains('телеграм')) {
            iconType = 'tg';
          } else if (text.contains('vk') || text.contains('вк')) {
            iconType = 'vk';
          } else if (text.contains('whatsapp') || text.contains('вацап')) {
            iconType = 'whatsapp';
          }

          socialLinks.add({
            'icon': iconType,
            'url': link.link!,
            'text': link.text ?? '',
          });
        }
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        children: [
          // ── Первая строка: Кнопка подписки/управления + соцсети ──
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    if (isOwner) {
                      _showShopManagement(context);
                    } else {
                      _handleSubscribe(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8956FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    minimumSize: const Size(double.infinity, 48),
                    elevation: 0,
                  ),
                  child: Text(
                    isOwner ? 'Управление' : 'Подписаться',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ── Вторая строка: Кнопка "Добавить товар" (только для владельца) ──
          if (isOwner) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.push('/listing-add'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8956FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  minimumSize: const Size(double.infinity, 48),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add, size: 20, color: Colors.white),
                    const SizedBox(width: 8),
                    const Text(
                      'Добавить товар',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getSocialIcon(String type) {
    switch (type) {
      case 'tg':
        return 'assets/icons/tg.png';
      case 'vk':
        return 'assets/icons/vk.png';
      case 'whatsapp':
        return 'assets/icons/whatsapp.png';
      default:
        return 'assets/icons/link.png';
    }
  }

  void _handleSubscribe(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Функция подписки в разработке'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showShopManagement(BuildContext context) {
    print('🔧 [ShopActions] Opening management modal');

    final shopBloc = context.read<ShopBloc>(); // 👈 ПОЛУЧАЕМ BLoc

    showDialog(
      context: context,
      builder: (_) => ShopManagementModal(
        shop: shop,
        shopBloc: shopBloc, // 👈 ПЕРЕДАЕМ
      ),
    );
  }
}

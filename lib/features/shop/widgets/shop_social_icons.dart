// lib/features/shop/widgets/shop_social_icons.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hashtagg/features/shop/models/shop.dart';

class ShopSocialIcons extends StatelessWidget {
  final Shop shop;
  final bool isEditing;
  final VoidCallback? onEdit;

  const ShopSocialIcons({
    Key? key,
    required this.shop,
    this.isEditing = false,
    this.onEdit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final links = shop.links ?? [];

    final Map<String, String> socialLinks = {};
    for (var link in links) {
      final text = link.text?.toLowerCase() ?? '';
      if (text.contains('telegram') || text.contains('tg')) {
        socialLinks['telegram'] = link.link ?? '';
      } else if (text.contains('vk')) {
        socialLinks['vk'] = link.link ?? '';
      } else if (text.contains('max')) {
        socialLinks['max'] = link.link ?? '';
      }
    }

    print('🔗 [ShopSocialIcons] build()');
    print('   links count: ${links.length}');
    print('   isEditing: $isEditing');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Заголовок (только в режиме редактирования)
          if (isEditing)
            Text(
              'Социальные сети',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1F2937),
              ),
            )
          else
            const SizedBox.shrink(),

          Row(
            children: [
              // Контейнер с иконками
              Container(
                height: 45,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF8956FF),
                  borderRadius: BorderRadius.circular(80),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _SocialIcon(
                      iconUrl: 'https://hashtagg.ru/templates/img/tg.png',
                      url: socialLinks['telegram'] ?? '',
                      isEditing: isEditing,
                      label: 'Telegram',
                    ),
                    const SizedBox(width: 5),
                    _SocialIcon(
                      iconUrl: 'https://hashtagg.ru/templates/img/vk.png',
                      url: socialLinks['vk'] ?? '',
                      isEditing: isEditing,
                      label: 'VK',
                    ),
                    const SizedBox(width: 5),
                    _SocialIcon(
                      iconUrl: 'https://hashtagg.ru/templates/img/max.png',
                      url: socialLinks['max'] ?? '',
                      isEditing: isEditing,
                      label: 'Max',
                    ),
                  ],
                ),
              ),
              // ✅ КАРАНДАШИК ДЛЯ РЕДАКТИРОВАНИЯ (только в режиме редактора)
              if (isEditing && onEdit != null)
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: GestureDetector(
                    onTap: onEdit,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Color(0xFF8956FF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.edit,
                        size: 20,
                        color: Color(0xFF8956FF),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SocialIcon extends StatelessWidget {
  final String iconUrl;
  final String url;
  final bool isEditing;
  final String label;

  const _SocialIcon({
    required this.iconUrl,
    required this.url,
    required this.isEditing,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        if (url.isNotEmpty) {
          // ✅ В ПАБЛИК РЕЖИМЕ - ОТКРЫВАЕМ ССЫЛКУ
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        } else if (isEditing) {
          // ✅ В РЕЖИМЕ РЕДАКТОРА - ПОДСКАЗКА
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Добавьте ссылку для $label через карандаш ✏️'),
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          // ✅ В ПАБЛИК РЕЖИМЕ БЕЗ ССЫЛКИ - НИЧЕГО НЕ ДЕЛАЕМ
          print('ℹ️ [_SocialIcon] $label: no link set');
        }
      },
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Image.network(
            iconUrl,
            width: 20,
            height: 20,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              print('❌ [_SocialIcon] Failed to load $label: $error');
              return Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.link, size: 12, color: Colors.grey.shade400),
              );
            },
          ),
        ),
      ),
    );
  }
}
